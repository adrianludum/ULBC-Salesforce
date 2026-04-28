/**
 * ULBC_StripeWebhook_Test
 *
 * Phase 5A.2 tests — signature verification + log-row writing.
 * Phase 5A.3 will add tests for typed handlers (donation / event_ticket).
 */
@IsTest
private class ULBC_StripeWebhook_Test {

    private static final String SECRET = 'whsec_test_secret_for_unit_tests_only_0123456789abcdef';

    @TestSetup
    static void setup() {
        // Seed a Custom Setting org-default with the test signing secret.
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        if (s == null || s.Id == null) {
            s = new ULBC_Stripe_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        s.WebhookSigningSecret__c = SECRET;
        upsert s;
    }

    // ── Helpers ────────────────────────────────────────────────────────

    private static String sampleEvent(String eventId, String eventType) {
        return '{"id":"' + eventId + '","object":"event","type":"' + eventType +
               '","data":{"object":{"id":"cs_test_001"}}}';
    }

    private static String hmacHex(String body, Long ts, String secret) {
        Blob mac = Crypto.generateMac('HmacSHA256',
            Blob.valueOf(ts + '.' + body),
            Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac);
    }

    private static String buildSignatureHeader(String body, Long ts, String secret) {
        return 't=' + ts + ',v1=' + hmacHex(body, ts, secret);
    }

    private static void mockRequest(String body, String sigHeader) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = (body == null) ? null : Blob.valueOf(body);
        if (sigHeader != null) req.headers.put('Stripe-Signature', sigHeader);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    private static ULBC_Webhook_Log__c latestLog() {
        return [
            SELECT Id, ULBC_Status__c, ULBC_Stripe_Event_ID__c, ULBC_Stripe_Event_Type__c,
                   ULBC_Raw_Payload__c, ULBC_Error_Message__c, ULBC_Stripe_Timestamp__c,
                   ULBC_Payload_Truncated__c
            FROM ULBC_Webhook_Log__c ORDER BY CreatedDate DESC LIMIT 1
        ];
    }

    // ── Tests ──────────────────────────────────────────────────────────

    @IsTest
    static void test_validSignature_logsAndReturns200() {
        String body = sampleEvent('evt_test_001', 'checkout.session.completed');
        Long ts = System.now().getTime() / 1000;
        mockRequest(body, buildSignatureHeader(body, ts, SECRET));

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Valid signature should return 200');

        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Verified', log.ULBC_Status__c);
        System.assertEquals('evt_test_001', log.ULBC_Stripe_Event_ID__c);
        System.assertEquals('checkout.session.completed', log.ULBC_Stripe_Event_Type__c);
        System.assertEquals(body, log.ULBC_Raw_Payload__c, 'Full payload should be stored');
        System.assertEquals(false, log.ULBC_Payload_Truncated__c);
        System.assertNotEquals(null, log.ULBC_Stripe_Timestamp__c, 'Stripe ts should be parsed');
    }

    @IsTest
    static void test_invalidSignature_returns400AndLogsFailure() {
        String body = sampleEvent('evt_test_002', 'checkout.session.completed');
        Long ts = System.now().getTime() / 1000;
        // Sign with the WRONG secret on purpose
        mockRequest(body, buildSignatureHeader(body, ts, 'whsec_some_other_secret'));

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Signature Invalid', log.ULBC_Status__c);
        System.assert(log.ULBC_Error_Message__c.toLowerCase().contains('signature'),
            'Error should mention signature mismatch. Got: ' + log.ULBC_Error_Message__c);
    }

    @IsTest
    static void test_missingSignatureHeader_returns400() {
        mockRequest(sampleEvent('evt_x', 'a.b'), null);

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('Signature Missing', latestLog().ULBC_Status__c);
    }

    @IsTest
    static void test_staleTimestamp_returns400() {
        String body = sampleEvent('evt_stale', 'checkout.session.completed');
        Long staleTs = (System.now().getTime() / 1000) - (6 * 60 * 60);  // 6 hours ago
        mockRequest(body, buildSignatureHeader(body, staleTs, SECRET));

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Signature Expired', log.ULBC_Status__c);
        System.assert(log.ULBC_Error_Message__c.contains('tolerance'),
            'Error should mention tolerance window. Got: ' + log.ULBC_Error_Message__c);
    }

    @IsTest
    static void test_missingSecret_returns500() {
        // Wipe the secret seeded in setup
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        s.WebhookSigningSecret__c = null;
        update s;

        mockRequest(sampleEvent('evt_x', 'checkout.session.completed'),
                    't=1700000000,v1=abc');

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Error', log.ULBC_Status__c);
        System.assert(log.ULBC_Error_Message__c.contains('WebhookSigningSecret__c'),
            'Error should mention the missing setting field. Got: ' + log.ULBC_Error_Message__c);
    }

    @IsTest
    static void test_malformedJsonBody_returns400AfterSignaturePass() {
        // Signature is computed on the raw bytes — malformed JSON can still verify.
        String body = '{not valid json';
        Long ts = System.now().getTime() / 1000;
        mockRequest(body, buildSignatureHeader(body, ts, SECRET));

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Malformed', log.ULBC_Status__c);
    }

    @IsTest
    static void test_signatureWithExtraSchemes_acceptsV1Match() {
        // Stripe headers can contain v0= and additional v1= entries during rotation.
        String body = sampleEvent('evt_rot', 'checkout.session.completed');
        Long ts = System.now().getTime() / 1000;
        String correctV1 = ULBC_StripeWebhook_Test.hmacHex(body, ts, SECRET);
        String header = 't=' + ts +
            ',v0=should_be_ignored' +
            ',v1=0000000000000000000000000000000000000000000000000000000000000000' +
            ',v1=' + correctV1;
        mockRequest(body, header);

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Should accept when any v1 candidate matches');
        System.assertEquals('Verified', latestLog().ULBC_Status__c);
    }

    @IsTest
    static void test_duplicateEventId_returns200WithDuplicateStatus() {
        // First delivery succeeds, second with same event_id is a Stripe replay.
        String body = sampleEvent('evt_dup_001', 'checkout.session.completed');
        Long ts = System.now().getTime() / 1000;
        String sig = buildSignatureHeader(body, ts, SECRET);

        Test.startTest();

        mockRequest(body, sig);
        ULBC_StripeWebhook.handlePost();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('Verified', latestLog().ULBC_Status__c);

        // Second delivery (replay)
        mockRequest(body, sig);
        ULBC_StripeWebhook.handlePost();

        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Replay should ack with 200 so Stripe stops retrying');
        Integer logCount = [SELECT COUNT() FROM ULBC_Webhook_Log__c
                            WHERE ULBC_Stripe_Event_ID__c = 'evt_dup_001'];
        System.assertEquals(1, logCount, 'Unique constraint should prevent duplicate row');
    }

    @IsTest
    static void test_constantTimeEquals_lengthMismatchAndDiffPaths() {
        System.assert(!ULBC_StripeWebhook.constantTimeEquals('abc', 'abcd'));
        System.assert(!ULBC_StripeWebhook.constantTimeEquals(null, 'x'));
        System.assert(!ULBC_StripeWebhook.constantTimeEquals('x', null));
        System.assert(ULBC_StripeWebhook.constantTimeEquals('abc', 'abc'));
        System.assert(!ULBC_StripeWebhook.constantTimeEquals('abc', 'abd'));
    }
}
