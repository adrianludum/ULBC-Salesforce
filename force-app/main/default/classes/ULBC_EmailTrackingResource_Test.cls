/**
 * ULBC_EmailTrackingResource_Test
 *
 * Verifies open/click/unsub semantics: correct response shape, event log
 * insertion, opt-out side effect, no-leak behaviour for unknown tokens.
 */
@IsTest
private class ULBC_EmailTrackingResource_Test {

    private static final String KNOWN_TOKEN = 'known-token-aBcDeFgHiJkLmN012345';
    private static final String UNKNOWN_TOKEN = 'totally-unknown-token-xyz000000';

    @TestSetup
    static void setup() {
        ULBC_Email_Settings__c s = ULBC_Email_Settings__c.getOrgDefaults();
        if (s == null || s.Id == null) {
            s = new ULBC_Email_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        s.IPHashSalt__c = 'test-salt-abc';
        upsert s;

        Campaign c = new Campaign(Name = 'Tracking Test', IsActive = true);
        insert c;
        Contact ct = new Contact(LastName = 'Tracker', Email = 'track@example.com',
                                   ULBC_Trust_ID__c = 'ULBC-T');
        insert ct;

        ULBC_Email_Send__c send = new ULBC_Email_Send__c(
            ULBC_Campaign__c = c.Id,
            ULBC_Email_Template_DevName__c = 'tpl',
            ULBC_Status__c = 'Sent',
            ULBC_Recipient_Count__c = 1,
            ULBC_Initiated_By__c = UserInfo.getUserId()
        );
        insert send;

        ULBC_Email_Send_Recipient__c rcpt = new ULBC_Email_Send_Recipient__c(
            ULBC_Email_Send__c = send.Id,
            ULBC_Contact__c = ct.Id,
            ULBC_Trust_ID__c = ct.ULBC_Trust_ID__c,
            ULBC_Email_Address__c = ct.Email,
            ULBC_Token__c = KNOWN_TOKEN,
            ULBC_Status__c = 'Sent',
            ULBC_Open_Count__c = 0,
            ULBC_Click_Count__c = 0
        );
        insert rcpt;
    }

    private static void mockRequest(String uri, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'GET';
        if (params != null) {
            for (String k : params.keySet()) req.params.put(k, params.get(k));
        }
        req.headers.put('User-Agent', 'TestAgent/1.0');
        req.headers.put('X-Forwarded-For', '203.0.113.42');
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    private static Id getRecipientId() {
        return [SELECT Id FROM ULBC_Email_Send_Recipient__c
                WHERE ULBC_Token__c = :KNOWN_TOKEN LIMIT 1].Id;
    }

    // ── Open ───────────────────────────────────────────────────────────

    @IsTest
    static void test_open_returns200AndGifAndInsertsEvent() {
        mockRequest('/services/apexrest/email/open',
            new Map<String, String>{ 't' => KNOWN_TOKEN });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        System.assertEquals('image/gif', res.headers.get('Content-Type'));
        System.assert(res.responseBody != null && res.responseBody.size() > 0,
            'GIF body should be present');
        System.assert(res.headers.get('Cache-Control').containsIgnoreCase('no-store'));

        List<ULBC_Email_Event__c> events = [
            SELECT ULBC_Event_Type__c, ULBC_Recipient__c, ULBC_IP_Hash__c, ULBC_User_Agent__c, ULBC_Aggregated__c
            FROM ULBC_Email_Event__c
        ];
        System.assertEquals(1, events.size());
        System.assertEquals('Open', events[0].ULBC_Event_Type__c);
        System.assertEquals(getRecipientId(), events[0].ULBC_Recipient__c);
        System.assertEquals(false, events[0].ULBC_Aggregated__c);
        System.assert(String.isNotBlank(events[0].ULBC_IP_Hash__c), 'IP must be hashed not raw');
        System.assertNotEquals('203.0.113.42', events[0].ULBC_IP_Hash__c);
        System.assertEquals(64, events[0].ULBC_IP_Hash__c.length(), 'SHA-256 hex length');
    }

    @IsTest
    static void test_open_unknownToken_stillReturns200AndInsertsOrphanEvent() {
        mockRequest('/services/apexrest/email/open',
            new Map<String, String>{ 't' => UNKNOWN_TOKEN });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Must not leak token validity via status code');
        List<ULBC_Email_Event__c> events = [
            SELECT ULBC_Recipient__c FROM ULBC_Email_Event__c
        ];
        System.assertEquals(1, events.size());
        System.assertEquals(null, events[0].ULBC_Recipient__c,
            'Unknown token → orphan event with null Recipient');
    }

    @IsTest
    static void test_open_missingToken_stillReturns200() {
        mockRequest('/services/apexrest/email/open', null);

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    // ── Click ──────────────────────────────────────────────────────────

    @IsTest
    static void test_click_redirects302WithDecodedUrl() {
        String dest = 'https://example.com/page?q=hello world';
        String enc = EncodingUtil.urlEncode(dest, 'UTF-8');
        mockRequest('/services/apexrest/email/click',
            new Map<String, String>{ 't' => KNOWN_TOKEN, 'u' => enc });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(302, res.statusCode);
        System.assertEquals(dest, res.headers.get('Location'),
            'Location header carries the decoded destination');

        ULBC_Email_Event__c evt = [
            SELECT ULBC_Event_Type__c, ULBC_URL__c FROM ULBC_Email_Event__c LIMIT 1
        ];
        System.assertEquals('Click', evt.ULBC_Event_Type__c);
        System.assertEquals(dest, evt.ULBC_URL__c);
    }

    @IsTest
    static void test_click_unknownToken_stillRedirects() {
        String dest = 'https://example.com/x';
        mockRequest('/services/apexrest/email/click',
            new Map<String, String>{ 't' => UNKNOWN_TOKEN, 'u' => EncodingUtil.urlEncode(dest, 'UTF-8') });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        System.assertEquals(302, RestContext.response.statusCode,
            'Unknown token must not break the user — still redirect');
    }

    @IsTest
    static void test_click_missingUrl_returns400() {
        mockRequest('/services/apexrest/email/click',
            new Map<String, String>{ 't' => KNOWN_TOKEN });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void test_click_nonHttpUrl_rejected400() {
        // Open-redirect prevention: javascript:, ftp:, file: must be rejected.
        mockRequest('/services/apexrest/email/click',
            new Map<String, String>{ 't' => KNOWN_TOKEN,
                                      'u' => EncodingUtil.urlEncode('javascript:alert(1)', 'UTF-8') });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'Non-http(s) URLs must be rejected to prevent open-redirect abuse');
    }

    // ── Unsubscribe ────────────────────────────────────────────────────

    @IsTest
    static void test_unsub_insertsEventOnly_aggregatorAppliesOptOut() {
        // The endpoint only records the Unsubscribe event — actual opt-out
        // (Recipient.Unsubscribed_At + Contact.HasOptedOutOfEmail) is applied
        // by ULBC_EmailEventAggregator, which has the necessary CRUD that
        // Salesforce's Guest User license denies.
        mockRequest('/services/apexrest/email/unsub',
            new Map<String, String>{ 't' => KNOWN_TOKEN });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        System.assert(res.headers.get('Content-Type').containsIgnoreCase('text/html'));
        System.assert(res.responseBody.toString().contains('unsubscribed'));

        // Contact + Recipient are NOT updated synchronously here.
        Contact c = [SELECT HasOptedOutOfEmail FROM Contact WHERE Email = 'track@example.com'];
        System.assertEquals(false, c.HasOptedOutOfEmail,
            'Contact opt-out is deferred to the aggregator');
        ULBC_Email_Send_Recipient__c r = [
            SELECT ULBC_Unsubscribed_At__c FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Token__c = :KNOWN_TOKEN
        ];
        System.assertEquals(null, r.ULBC_Unsubscribed_At__c,
            'Recipient stamp deferred to the aggregator');

        // The event itself IS recorded immediately.
        ULBC_Email_Event__c evt = [
            SELECT ULBC_Event_Type__c, ULBC_Recipient__c FROM ULBC_Email_Event__c LIMIT 1
        ];
        System.assertEquals('Unsubscribe', evt.ULBC_Event_Type__c);
        System.assertEquals(getRecipientId(), evt.ULBC_Recipient__c);
    }

    @IsTest
    static void test_unsub_unknownToken_stillReturnsConfirmation() {
        mockRequest('/services/apexrest/email/unsub',
            new Map<String, String>{ 't' => UNKNOWN_TOKEN });

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Unknown token still shows the confirmation page (do not leak)');

        // No Contact has been opted out (deferred to aggregator anyway, and
        // an unknown token produces an orphan event the aggregator ignores).
        Contact c = [SELECT HasOptedOutOfEmail FROM Contact WHERE Email = 'track@example.com'];
        System.assertEquals(false, c.HasOptedOutOfEmail);
    }

    // ── Routing ────────────────────────────────────────────────────────

    @IsTest
    static void test_unknownPath_returns404() {
        mockRequest('/services/apexrest/email/banana', null);

        Test.startTest();
        ULBC_EmailTrackingResource.handleGet();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    // ── IP hashing ─────────────────────────────────────────────────────

    @IsTest
    static void test_hashIP_xForwardedForList_usesFirstIP() {
        String h1 = ULBC_EmailTrackingResource.hashIP('203.0.113.1, 10.0.0.1, 10.0.0.2');
        String h2 = ULBC_EmailTrackingResource.hashIP('203.0.113.1');
        System.assertEquals(h1, h2, 'First entry of XFF list should be hashed');
    }

    @IsTest
    static void test_hashIP_blankReturnsNull() {
        System.assertEquals(null, ULBC_EmailTrackingResource.hashIP(null));
        System.assertEquals(null, ULBC_EmailTrackingResource.hashIP(''));
    }
}
