/**
 * ULBC_EmailTrackingResource
 *
 * Public Apex REST endpoints hit by recipients' email clients. One class
 * with one urlMapping and three logical handlers selected by request URI:
 *
 *   GET /services/apexrest/email/open?t=TOKEN
 *     → 200 image/gif (43-byte transparent 1×1)
 *
 *   GET /services/apexrest/email/click?t=TOKEN&u=ENC_URL
 *     → 302 Location: decoded(ENC_URL)
 *
 *   GET /services/apexrest/email/unsub?t=TOKEN
 *     → 200 text/html confirmation page
 *     → side-effect: Contact.HasOptedOutOfEmail = true
 *
 * Design rules:
 *  - Unknown token → still 200 / still 302 / still confirmation. Never
 *    leak token validity, never break user experience to fix tracking.
 *  - Endpoint INSERTS an ULBC_Email_Event__c row only — never updates
 *    Recipient or Send rollups directly. ULBC_EmailEventAggregator does
 *    that asynchronously to avoid row-lock contention on high-volume opens.
 *  - IPs are hashed with a configurable salt. Raw IPs never persisted.
 *  - Endpoint runs as the Site Guest User; class is `without sharing` so
 *    the guest can insert event rows and update Contact opt-out without
 *    exposing the rest of the data model.
 */
@RestResource(urlMapping='/email/*')
global without sharing class ULBC_EmailTrackingResource {

    /** 43-byte 1×1 transparent GIF, base64-encoded. */
    @TestVisible
    private static final String PIXEL_GIF_BASE64 =
        'R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==';

    @TestVisible
    private static final String UNSUB_CONFIRMATION_HTML =
        '<!doctype html><html><head><meta charset="utf-8">' +
        '<title>Unsubscribed</title>' +
        '<style>body{font-family:system-ui,sans-serif;max-width:560px;margin:4em auto;padding:0 1em;color:#222;}</style>' +
        '</head><body>' +
        '<h1>You have been unsubscribed</h1>' +
        '<p>You will no longer receive marketing emails from ULBC Trust.</p>' +
        '<p>Transactional notices (donation receipts, ticket confirmations) ' +
        'will still be sent — these are not marketing.</p>' +
        '<p>If this was a mistake, please reply to any recent email from us.</p>' +
        '</body></html>';

    @HttpGet
    global static void handleGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String uri = (req.requestURI == null) ? '' : req.requestURI;

        try {
            if (uri.endsWithIgnoreCase('/email/open')) {
                handleOpen(req, res);
            } else if (uri.endsWithIgnoreCase('/email/click')) {
                handleClick(req, res);
            } else if (uri.endsWithIgnoreCase('/email/unsub')) {
                handleUnsub(req, res);
            } else {
                res.statusCode = 404;
                res.addHeader('Content-Type', 'text/plain');
                res.responseBody = Blob.valueOf('Not found');
            }
        } catch (Exception e) {
            // Never leak internal errors to recipients. Log + return a benign response
            // appropriate to the URI shape.
            System.debug(LoggingLevel.ERROR, 'ULBC_EmailTrackingResource error: '
                + e.getMessage() + '\n' + e.getStackTraceString());
            if (uri.endsWithIgnoreCase('/email/click')) {
                String url = readParam(req, 'u');
                if (String.isNotBlank(url)) {
                    res.statusCode = 302;
                    res.addHeader('Location', safeDecode(url));
                    return;
                }
            }
            res.statusCode = 200;
            res.addHeader('Content-Type', 'image/gif');
            res.responseBody = EncodingUtil.base64Decode(PIXEL_GIF_BASE64);
        }
    }

    // ── Open ───────────────────────────────────────────────────────────

    private static void handleOpen(RestRequest req, RestResponse res) {
        String token = readParam(req, 't');
        recordEvent(token, 'Open', null, req);

        res.statusCode = 200;
        res.addHeader('Content-Type', 'image/gif');
        res.addHeader('Cache-Control', 'no-store, max-age=0');
        res.responseBody = EncodingUtil.base64Decode(PIXEL_GIF_BASE64);
    }

    // ── Click ──────────────────────────────────────────────────────────

    private static void handleClick(RestRequest req, RestResponse res) {
        String token = readParam(req, 't');
        String encodedUrl = readParam(req, 'u');
        if (String.isBlank(encodedUrl)) {
            res.statusCode = 400;
            res.addHeader('Content-Type', 'text/plain');
            res.responseBody = Blob.valueOf('Missing destination URL');
            return;
        }
        String decodedUrl = safeDecode(encodedUrl);

        // Only accept absolute http(s) URLs to prevent open-redirect abuse.
        String lower = decodedUrl.toLowerCase();
        if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
            res.statusCode = 400;
            res.addHeader('Content-Type', 'text/plain');
            res.responseBody = Blob.valueOf('Invalid destination URL');
            return;
        }

        recordEvent(token, 'Click', decodedUrl, req);

        res.statusCode = 302;
        res.addHeader('Location', decodedUrl);
        res.addHeader('Cache-Control', 'no-store, max-age=0');
    }

    // ── Unsubscribe ────────────────────────────────────────────────────

    private static void handleUnsub(RestRequest req, RestResponse res) {
        String token = readParam(req, 't');
        recordEvent(token, 'Unsubscribe', null, req);

        // Set HasOptedOutOfEmail + stamp Recipient.Unsubscribed_At
        if (String.isNotBlank(token)) {
            List<ULBC_Email_Send_Recipient__c> rcpts = [
                SELECT Id, ULBC_Contact__c, ULBC_Unsubscribed_At__c
                FROM ULBC_Email_Send_Recipient__c
                WHERE ULBC_Token__c = :token
                LIMIT 1
            ];
            if (!rcpts.isEmpty()) {
                ULBC_Email_Send_Recipient__c r = rcpts[0];
                if (r.ULBC_Unsubscribed_At__c == null) {
                    r.ULBC_Unsubscribed_At__c = System.now();
                    update r;
                }
                if (r.ULBC_Contact__c != null) {
                    Contact c = new Contact(Id = r.ULBC_Contact__c, HasOptedOutOfEmail = true);
                    update c;
                }
            }
        }

        res.statusCode = 200;
        res.addHeader('Content-Type', 'text/html; charset=utf-8');
        res.addHeader('Cache-Control', 'no-store, max-age=0');
        res.responseBody = Blob.valueOf(UNSUB_CONFIRMATION_HTML);
    }

    // ── Event insertion ────────────────────────────────────────────────

    @TestVisible
    private static void recordEvent(String token, String eventType, String url, RestRequest req) {
        Id recipientId = null;
        if (String.isNotBlank(token)) {
            List<ULBC_Email_Send_Recipient__c> rcpts = [
                SELECT Id FROM ULBC_Email_Send_Recipient__c
                WHERE ULBC_Token__c = :token LIMIT 1
            ];
            if (!rcpts.isEmpty()) recipientId = rcpts[0].Id;
        }

        ULBC_Email_Event__c evt = new ULBC_Email_Event__c(
            ULBC_Recipient__c = recipientId,
            ULBC_Event_Type__c = eventType,
            ULBC_URL__c = url,
            ULBC_Occurred_At__c = System.now(),
            ULBC_User_Agent__c = truncate(readHeader(req, 'User-Agent'), 255),
            ULBC_IP_Hash__c = hashIP(readHeader(req, 'X-Forwarded-For')),
            ULBC_Aggregated__c = false
        );
        insert evt;
    }

    @TestVisible
    private static String hashIP(String ipHeader) {
        if (String.isBlank(ipHeader)) return null;
        // X-Forwarded-For may be a comma-separated list — first entry is the client.
        String ip = ipHeader.split(',')[0].trim();
        if (String.isBlank(ip)) return null;

        ULBC_Email_Settings__c s = ULBC_Email_Settings__c.getOrgDefaults();
        String salt = (s == null || s.IPHashSalt__c == null) ? '' : s.IPHashSalt__c;
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(salt + ip));
        return EncodingUtil.convertToHex(digest);
    }

    // ── Helpers ────────────────────────────────────────────────────────

    private static String readParam(RestRequest req, String name) {
        if (req == null || req.params == null) return null;
        return req.params.get(name);
    }

    private static String readHeader(RestRequest req, String name) {
        if (req == null || req.headers == null) return null;
        for (String key : req.headers.keySet()) {
            if (key.equalsIgnoreCase(name)) return req.headers.get(key);
        }
        return null;
    }

    @TestVisible
    private static String safeDecode(String encoded) {
        if (String.isBlank(encoded)) return encoded;
        try {
            return EncodingUtil.urlDecode(encoded, 'UTF-8');
        } catch (Exception e) {
            return encoded;
        }
    }

    private static String truncate(String s, Integer max) {
        if (s == null) return null;
        return s.length() > max ? s.substring(0, max) : s;
    }
}
