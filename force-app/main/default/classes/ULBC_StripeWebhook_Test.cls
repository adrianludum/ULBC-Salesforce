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
    static void test_validSignature_unhandledEventType_isIgnored() {
        // 'ping' is not checkout.session.completed → Ignored under 5A.3 dispatch.
        String body = sampleEvent('evt_test_001', 'ping');
        Long ts = System.now().getTime() / 1000;
        mockRequest(body, buildSignatureHeader(body, ts, SECRET));

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Ignored', log.ULBC_Status__c);
        System.assertEquals('evt_test_001', log.ULBC_Stripe_Event_ID__c);
        System.assertEquals('ping', log.ULBC_Stripe_Event_Type__c);
        System.assertEquals(body, log.ULBC_Raw_Payload__c);
        System.assertNotEquals(null, log.ULBC_Stripe_Timestamp__c);
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
        String body = sampleEvent('evt_rot', 'ping');
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
        System.assertEquals('Ignored', latestLog().ULBC_Status__c);
    }

    @IsTest
    static void test_duplicateEventId_returns200WithDuplicateStatus() {
        // First delivery succeeds (Ignored — non-checkout type), second with same
        // event_id is a Stripe replay; Unique violation caught and marked Duplicate.
        String body = sampleEvent('evt_dup_001', 'ping');
        Long ts = System.now().getTime() / 1000;
        String sig = buildSignatureHeader(body, ts, SECRET);

        Test.startTest();

        mockRequest(body, sig);
        ULBC_StripeWebhook.handlePost();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('Ignored', latestLog().ULBC_Status__c);

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

    // ── Dispatch tests (Phase 5A.3) ────────────────────────────────────

    /**
     * Build a checkout.session.completed event with arbitrary metadata.
     * The session.id, customer email and amount are fixed to keep tests terse.
     */
    private static String buildCheckoutEvent(String eventId, Map<String, String> meta) {
        String metaJson = (meta == null) ? '{}' : JSON.serialize(meta);
        return '{"id":"' + eventId + '","object":"event","type":"checkout.session.completed",' +
               '"data":{"object":{' +
                   '"id":"cs_test_xyz",' +
                   '"payment_intent":"pi_test_xyz",' +
                   '"customer":"cus_test_xyz",' +
                   '"amount_total":5000,' +
                   '"currency":"gbp",' +
                   '"customer_details":{"email":"buyer@example.com","name":"Test Buyer"},' +
                   '"metadata":' + metaJson +
               '}}}';
    }

    private static void postCheckout(String eventId, Map<String, String> meta) {
        String body = buildCheckoutEvent(eventId, meta);
        Long ts = System.now().getTime() / 1000;
        mockRequest(body, buildSignatureHeader(body, ts, SECRET));
        ULBC_StripeWebhook.handlePost();
    }

    @IsTest
    static void test_dispatch_donation_marksProcessed() {
        Test.startTest();
        postCheckout('evt_donation_1', new Map<String, String>{
            'intent' => 'donation',
            'gift_type' => 'One-Off',
            'gift_aid' => 'false'
        });
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Processed', log.ULBC_Status__c);

        Integer oppCount = [SELECT COUNT() FROM Opportunity
                            WHERE ULBC_Stripe_Payment_ID__c = 'pi_test_xyz'];
        System.assertEquals(1, oppCount, 'Donation Opportunity should be created');
    }

    @IsTest
    static void test_dispatch_eventTicket_marksProcessed() {
        Campaign camp = new Campaign(Name = 'Test Dispatch Event', Type = 'Event',
                                     Status = 'Planned', IsActive = true);
        insert camp;

        Test.startTest();
        postCheckout('evt_ticket_1', new Map<String, String>{
            'intent' => 'event_ticket',
            'campaign_id' => camp.Id
        });
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('Processed', latestLog().ULBC_Status__c);

        Integer cmCount = [SELECT COUNT() FROM CampaignMember
                           WHERE CampaignId = :camp.Id];
        System.assertEquals(1, cmCount, 'CampaignMember should be created');
    }

    @IsTest
    static void test_dispatch_subscription_isIgnored() {
        Test.startTest();
        postCheckout('evt_sub_1', new Map<String, String>{ 'intent' => 'subscription' });
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('Ignored', latestLog().ULBC_Status__c);
        System.assertEquals(0, [SELECT COUNT() FROM Opportunity
                                WHERE ULBC_Stripe_Payment_ID__c = 'pi_test_xyz']);
    }

    @IsTest
    static void test_dispatch_missingIntent_returnsError() {
        Test.startTest();
        postCheckout('evt_no_intent', new Map<String, String>());
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Error', log.ULBC_Status__c);
        System.assert(log.ULBC_Error_Message__c.contains('intent'));
    }

    @IsTest
    static void test_dispatch_unknownIntent_returnsError() {
        Test.startTest();
        postCheckout('evt_bad_intent', new Map<String, String>{ 'intent' => 'unknown_thing' });
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Error', log.ULBC_Status__c);
        System.assert(log.ULBC_Error_Message__c.contains('Unknown'));
    }

    @IsTest
    static void test_dispatch_eventTicketHandlerThrows_marksError() {
        // event_ticket handler requires campaign_id — omit it to force an exception.
        Test.startTest();
        postCheckout('evt_ticket_no_camp', new Map<String, String>{ 'intent' => 'event_ticket' });
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        ULBC_Webhook_Log__c log = latestLog();
        System.assertEquals('Error', log.ULBC_Status__c);
        System.assert(log.ULBC_Error_Message__c.contains('campaign_id'));
    }
}
