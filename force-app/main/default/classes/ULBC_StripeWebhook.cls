/**
 * ULBC_StripeWebhook
 *
 * Public Apex REST endpoint receiving Stripe webhook deliveries.
 * Verifies the Stripe-Signature header (HMAC-SHA256 over `t.body`)
 * against the signing secret in ULBC_Stripe_Settings__c, then writes
 * a ULBC_Webhook_Log__c row for every delivery attempt.
 *
 * Phase 5A.2: signature verification + logging only — no business logic.
 * Phase 5A.3 will add typed handlers (intent=donation / event_ticket)
 * dispatched off the verified payload.
 *
 * Idempotency: ULBC_Stripe_Event_ID__c is Unique. Replays of an already
 * logged event_id raise a DUPLICATE_VALUE error which is caught and
 * recorded as Status = Duplicate, response 200 (Stripe should stop retrying).
 *
 * Endpoint: /services/apexrest/stripe/webhook
 * Decisions: 5.9 (metadata contract), 5.11 (public REST + signature verify).
 */
@RestResource(urlMapping='/stripe/webhook')
global with sharing class ULBC_StripeWebhook {

    @TestVisible
    private static final Integer TIMESTAMP_TOLERANCE_SECONDS = 300;

    @TestVisible
    private static final Integer PAYLOAD_MAX_LENGTH = 131072;

    @TestVisible
    private static final String SIGNATURE_HEADER = 'Stripe-Signature';

    global class WebhookResult {
        global Boolean success;
        global String message;
        global String logId;
    }

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String body = (req.requestBody != null) ? req.requestBody.toString() : '';
        String sigHeader = readHeader(req, SIGNATURE_HEADER);

        Boolean truncated = body.length() > PAYLOAD_MAX_LENGTH;
        ULBC_Webhook_Log__c log = new ULBC_Webhook_Log__c(
            ULBC_Processed_At__c = System.now(),
            ULBC_Signature_Header__c = sigHeader,
            ULBC_Raw_Payload__c = truncated ? body.substring(0, PAYLOAD_MAX_LENGTH) : body,
            ULBC_Payload_Truncated__c = truncated,
            ULBC_Status__c = 'Error'
        );

        WebhookResult result = new WebhookResult();

        try {
            String secret = getSigningSecret();
            if (String.isBlank(secret)) {
                finish(log, 'Error',
                    'ULBC_Stripe_Settings__c.WebhookSigningSecret__c is empty — webhook cannot be verified.',
                    result, res, 500, false, 'Webhook signing secret not configured');
                return;
            }

            if (String.isBlank(sigHeader)) {
                finish(log, 'Signature Missing',
                    'No Stripe-Signature header on the request.',
                    result, res, 400, false, 'Missing Stripe-Signature header');
                return;
            }

            VerifyResult v = verifySignature(body, sigHeader, secret, System.now());
            if (v.tsParsed != null) {
                log.ULBC_Stripe_Timestamp__c = Datetime.newInstance(v.tsParsed * 1000L);
            }
            if (!v.ok) {
                finish(log, v.status, v.reason, result, res, 400,
                       false, 'Signature verification failed: ' + v.reason);
                return;
            }

            // Signature verified. Pull event id + type for the log row.
            try {
                Map<String, Object> evt = (Map<String, Object>) JSON.deserializeUntyped(body);
                log.ULBC_Stripe_Event_ID__c = (String) evt.get('id');
                log.ULBC_Stripe_Event_Type__c = (String) evt.get('type');
            } catch (Exception parseErr) {
                finish(log, 'Malformed',
                    'Body verified by signature but is not valid JSON: ' + parseErr.getMessage(),
                    result, res, 400, false, 'Body not valid JSON');
                return;
            }

            finish(log, 'Verified',
                'Signature verified. Phase 5A.2 logs only — no handler dispatched yet.',
                result, res, 200, true,
                'Received ' + log.ULBC_Stripe_Event_Type__c);

        } catch (Exception e) {
            finish(log, 'Error',
                'Unexpected error: ' + e.getMessage() + '\n' + e.getStackTraceString(),
                result, res, 500, false, e.getMessage());
        }
    }

    // ── Signature verification ──────────────────────────────────────────

    @TestVisible
    private class VerifyResult {
        Boolean ok;
        /** When ok=false, the Status picklist value to record. */
        String status;
        String reason;
        /** Parsed Stripe timestamp (epoch seconds) — populated when t= parsed, regardless of ok. */
        Long tsParsed;
        VerifyResult(Boolean ok, String status, String reason, Long tsParsed) {
            this.ok = ok; this.status = status; this.reason = reason; this.tsParsed = tsParsed;
        }
    }

    @TestVisible
    private static VerifyResult verifySignature(String body, String header, String secret, Datetime now) {
        Map<String, List<String>> parts = parseSigHeader(header);

        if (!parts.containsKey('t') || parts.get('t').isEmpty()) {
            return new VerifyResult(false, 'Signature Invalid', 'Header missing t= timestamp', null);
        }
        if (!parts.containsKey('v1') || parts.get('v1').isEmpty()) {
            return new VerifyResult(false, 'Signature Invalid', 'Header missing v1= signature', null);
        }

        Long ts;
        try {
            ts = Long.valueOf(parts.get('t')[0]);
        } catch (Exception e) {
            return new VerifyResult(false, 'Signature Invalid', 'Header t= not a valid integer', null);
        }

        Long nowSeconds = now.getTime() / 1000;
        if (Math.abs(nowSeconds - ts) > TIMESTAMP_TOLERANCE_SECONDS) {
            return new VerifyResult(false, 'Signature Expired',
                'Timestamp outside tolerance window (' + TIMESTAMP_TOLERANCE_SECONDS + 's). Header t=' + ts + ', now=' + nowSeconds,
                ts);
        }

        String signedPayload = String.valueOf(ts) + '.' + body;
        Blob mac = Crypto.generateMac('HmacSHA256',
            Blob.valueOf(signedPayload), Blob.valueOf(secret));
        String expected = EncodingUtil.convertToHex(mac);

        for (String candidate : parts.get('v1')) {
            if (constantTimeEquals(expected, candidate)) {
                return new VerifyResult(true, 'Verified', null, ts);
            }
        }
        return new VerifyResult(false, 'Signature Invalid',
            'No v1 signature in header matched the computed HMAC', ts);
    }

    @TestVisible
    private static Map<String, List<String>> parseSigHeader(String header) {
        Map<String, List<String>> out = new Map<String, List<String>>();
        if (String.isBlank(header)) return out;

        for (String segment : header.split(',')) {
            String trimmed = segment.trim();
            Integer eq = trimmed.indexOf('=');
            if (eq <= 0) continue;
            String k = trimmed.substring(0, eq).trim();
            String v = trimmed.substring(eq + 1).trim();
            if (!out.containsKey(k)) out.put(k, new List<String>());
            out.get(k).add(v);
        }
        return out;
    }

    /**
     * Length-aware comparison that does not short-circuit on the first
     * mismatched character. Apex executes on the server with HTTPS in
     * front — timing leakage is extremely low — but the cost is trivial.
     */
    @TestVisible
    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        if (a.length() != b.length()) return false;
        Integer diff = 0;
        for (Integer i = 0; i < a.length(); i++) {
            diff |= a.charAt(i) ^ b.charAt(i);
        }
        return diff == 0;
    }

    // ── Helpers ────────────────────────────────────────────────────────

    @TestVisible
    private static String getSigningSecret() {
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        return (s == null) ? null : s.WebhookSigningSecret__c;
    }

    private static String readHeader(RestRequest req, String name) {
        if (req == null || req.headers == null) return null;
        for (String key : req.headers.keySet()) {
            if (key.equalsIgnoreCase(name)) return req.headers.get(key);
        }
        return null;
    }

    private static void finish(ULBC_Webhook_Log__c log, String status, String errorMessage,
                                WebhookResult result, RestResponse res,
                                Integer statusCode, Boolean success, String message) {
        log.ULBC_Status__c = status;
        log.ULBC_Error_Message__c = (errorMessage != null && errorMessage.length() > 4096)
            ? errorMessage.substring(0, 4096) : errorMessage;
        try {
            insert log;
            result.logId = log.Id;
        } catch (DmlException dmlErr) {
            // Unique constraint on event_id catches Stripe replays. Surface as Duplicate.
            if (dmlErr.getMessage() != null && dmlErr.getMessage().contains('DUPLICATE_VALUE')) {
                log.Id = null;
                log.ULBC_Status__c = 'Duplicate';
                log.ULBC_Error_Message__c = 'Event ID already logged — Stripe replay.';
                try {
                    // Cannot reinsert with the same unique value; query the prior row to return its Id.
                    if (String.isNotBlank(log.ULBC_Stripe_Event_ID__c)) {
                        List<ULBC_Webhook_Log__c> prior = [
                            SELECT Id FROM ULBC_Webhook_Log__c
                            WHERE ULBC_Stripe_Event_ID__c = :log.ULBC_Stripe_Event_ID__c
                            LIMIT 1
                        ];
                        if (!prior.isEmpty()) result.logId = prior[0].Id;
                    }
                } catch (Exception ignore) { /* best-effort */ }
                statusCode = 200;  // Acknowledge replay so Stripe stops retrying.
                success = true;
                message = 'Duplicate event — already logged';
            } else {
                System.debug(LoggingLevel.ERROR, 'Webhook log insert failed: ' + dmlErr.getMessage());
                if (Test.isRunningTest()) throw dmlErr;
            }
        }

        result.success = success;
        result.message = message;
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(result));
    }
}
