/**
 * ULBC_StripeCheckoutController_Test
 *
 * Unit tests for the Stripe Checkout Session creation controller. Uses
 * HttpCalloutMock to capture and assert against the form body the
 * controller sends to Stripe — this is where Decision 5.9 (amended
 * 2026-04-27 — `ulbc_trust_id`) is enforced as a contract test.
 *
 * Phase 5A.4.
 */
@isTest
private class ULBC_StripeCheckoutController_Test {

    // 15-char fake Campaign Id (701 prefix, alphanumeric); no checksum needed.
    private static final String FAKE_FUND_ID = '7010X000000ABCD';

    private class StripeMock implements HttpCalloutMock {
        public Integer status = 200;
        public String responseBody = '{"id":"cs_test_xyz","url":"https://checkout.stripe.com/c/pay/cs_test_xyz"}';
        public String capturedBody;
        public Map<String, String> capturedFormParams;
        public String capturedEndpoint;
        public String capturedMethod;
        public String capturedContentType;

        public HttpResponse respond(HttpRequest req) {
            capturedEndpoint = req.getEndpoint();
            capturedMethod = req.getMethod();
            capturedContentType = req.getHeader('Content-Type');
            capturedBody = req.getBody();
            capturedFormParams = parseForm(req.getBody());

            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            return res;
        }

        private Map<String, String> parseForm(String body) {
            Map<String, String> out = new Map<String, String>();
            if (String.isBlank(body)) return out;
            for (String pair : body.split('&')) {
                Integer eq = pair.indexOf('=');
                if (eq <= 0) continue;
                String k = EncodingUtil.urlDecode(pair.substring(0, eq), 'UTF-8');
                String v = EncodingUtil.urlDecode(pair.substring(eq + 1), 'UTF-8');
                out.put(k, v);
            }
            return out;
        }
    }

    @TestSetup
    static void setup() {
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        if (s == null) s = new ULBC_Stripe_Settings__c();
        if (s.SetupOwnerId == null) s.SetupOwnerId = UserInfo.getOrganizationId();
        s.DonationBaseURL__c = 'https://example.test/donate';
        s.EventsBaseURL__c = 'https://example.test/events';
        s.WebhookSigningSecret__c = 'whsec_test';
        upsert s;

        insert new Campaign(Name = 'Test Fund', IsActive = true);
        insert new Campaign(Name = 'Spring Dinner', IsActive = true, ULBC_Ticket_Price__c = 50);
    }

    private static Id fundId() {
        return [SELECT Id FROM Campaign WHERE Name = 'Test Fund' LIMIT 1].Id;
    }

    private static Id eventId() {
        return [SELECT Id FROM Campaign WHERE Name = 'Spring Dinner' LIMIT 1].Id;
    }

    // ── Donation tests ───────────────────────────────────────────────

    @isTest
    static void test_donation_minimal_happyPath() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);
        Id fund = fundId();

        Test.startTest();
        String url = ULBC_StripeCheckoutController.createDonationSession(
            25.00, fund, null, false, null, 'One-Off'
        );
        Test.stopTest();

        System.assertEquals('https://checkout.stripe.com/c/pay/cs_test_xyz', url);
        System.assertEquals('POST', m.capturedMethod);
        System.assert(m.capturedEndpoint.endsWith('/v1/checkout/sessions'),
            'Wrong endpoint: ' + m.capturedEndpoint);
        System.assertEquals('application/x-www-form-urlencoded', m.capturedContentType);

        Map<String, String> body = m.capturedFormParams;
        System.assertEquals('payment', body.get('mode'));
        System.assertEquals('card', body.get('payment_method_types[]'));
        System.assertEquals('gbp', body.get('line_items[0][price_data][currency]'));
        System.assertEquals('2500', body.get('line_items[0][price_data][unit_amount]'));
        System.assertEquals('1', body.get('line_items[0][quantity]'));
        System.assertEquals('donation', body.get('metadata[intent]'));
        System.assertEquals(String.valueOf(fund), body.get('metadata[fund]'));
        System.assertEquals('false', body.get('metadata[gift_aid]'));
        System.assertEquals('One-Off', body.get('metadata[gift_type]'));
        System.assert(!body.containsKey('metadata[ulbc_trust_id]'),
            'ulbc_trust_id key should be omitted when not supplied');
        System.assert(!body.containsKey('metadata[gift_aid_postcode]'),
            'gift_aid_postcode key should be omitted when gift_aid=false');
        System.assert(body.get('success_url').startsWith('https://example.test/donate'),
            'success_url base wrong: ' + body.get('success_url'));
        System.assert(body.get('success_url').contains('status=success'));
        System.assert(body.get('success_url').contains('session_id={CHECKOUT_SESSION_ID}'));
        System.assert(body.get('cancel_url').contains('status=cancelled'));
    }

    @isTest
    static void test_donation_withGiftAidAndPostcode() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        ULBC_StripeCheckoutController.createDonationSession(
            10.00, fundId(), null, true, 'SW1A 1AA', 'One-Off'
        );
        Test.stopTest();

        System.assertEquals('true', m.capturedFormParams.get('metadata[gift_aid]'));
        System.assertEquals('SW1A 1AA', m.capturedFormParams.get('metadata[gift_aid_postcode]'));
    }

    @isTest
    static void test_donation_withTrustId() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        ULBC_StripeCheckoutController.createDonationSession(
            10.00, fundId(), 'ULBC-0001', false, null, 'One-Off'
        );
        Test.stopTest();

        System.assertEquals('ULBC-0001', m.capturedFormParams.get('metadata[ulbc_trust_id]'));
    }

    @isTest
    static void test_donation_noFund_isAllowed() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        ULBC_StripeCheckoutController.createDonationSession(
            5.00, null, null, false, null, 'One-Off'
        );
        Test.stopTest();

        System.assert(!m.capturedFormParams.containsKey('metadata[fund]'),
            'fund metadata key should be absent when no fund supplied');
    }

    @isTest
    static void test_donation_recurringMappedThrough() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        ULBC_StripeCheckoutController.createDonationSession(
            10.00, fundId(), null, false, null, 'Recurring'
        );
        Test.stopTest();

        // Controller passes Decision 5.9 contract value through unchanged;
        // server-side handler maps to picklist value.
        System.assertEquals('Recurring', m.capturedFormParams.get('metadata[gift_type]'));
    }

    @isTest
    static void test_donation_belowMinimum_throws() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createDonationSession(
                0.50, fundId(), null, false, null, 'One-Off'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().contains('Minimum'), e.getMessage());
        }
        Test.stopTest();

        System.assert(threw, 'Below-minimum donation must throw');
        System.assertEquals(null, m.capturedBody, 'No callout should have been made');
    }

    @isTest
    static void test_donation_giftAidWithoutPostcode_throws() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createDonationSession(
                10.00, fundId(), null, true, null, 'One-Off'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().toLowerCase().contains('postcode'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    @isTest
    static void test_donation_invalidFund_throws() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createDonationSession(
                10.00, FAKE_FUND_ID, null, false, null, 'One-Off'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().toLowerCase().contains('fund'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    // ── Event ticket tests ───────────────────────────────────────────

    @isTest
    static void test_event_happyPath() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);
        Id evt = eventId();

        Test.startTest();
        String url = ULBC_StripeCheckoutController.createEventSession(evt, 2, null);
        Test.stopTest();

        System.assertEquals('https://checkout.stripe.com/c/pay/cs_test_xyz', url);
        Map<String, String> body = m.capturedFormParams;
        System.assertEquals('event_ticket', body.get('metadata[intent]'));
        System.assertEquals(String.valueOf(evt), body.get('metadata[campaign_id]'));
        System.assertEquals('5000', body.get('line_items[0][price_data][unit_amount]'));
        System.assertEquals('2', body.get('line_items[0][quantity]'));
        System.assert(body.get('success_url').contains('id=' + evt),
            'success_url should include campaign id: ' + body.get('success_url'));
    }

    @isTest
    static void test_event_withTrustId() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        ULBC_StripeCheckoutController.createEventSession(eventId(), 1, 'ULBC-0042');
        Test.stopTest();

        System.assertEquals('ULBC-0042', m.capturedFormParams.get('metadata[ulbc_trust_id]'));
    }

    @isTest
    static void test_event_invalidCampaign_throws() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createEventSession(FAKE_FUND_ID, 1, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw);
    }

    @isTest
    static void test_event_zeroQty_throws() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createEventSession(eventId(), 0, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw);
    }

    @isTest
    static void test_event_noTicketPrice_throws() {
        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            // fundId() Campaign has no ticket price set
            ULBC_StripeCheckoutController.createEventSession(fundId(), 1, null);
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().toLowerCase().contains('ticket price'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    // ── HTTP error handling ──────────────────────────────────────────

    @isTest
    static void test_stripe4xx_surfacesStripeMessage() {
        StripeMock m = new StripeMock();
        m.status = 400;
        m.responseBody = '{"error":{"message":"Invalid currency","type":"invalid_request_error"}}';
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createDonationSession(
                10.00, fundId(), null, false, null, 'One-Off'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().contains('Invalid currency'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    @isTest
    static void test_stripe5xx_surfacesGenericMessage() {
        StripeMock m = new StripeMock();
        m.status = 503;
        m.responseBody = 'gateway down';
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createDonationSession(
                10.00, fundId(), null, false, null, 'One-Off'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().contains('503'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    @isTest
    static void test_stripeMissingUrl_throws() {
        StripeMock m = new StripeMock();
        m.responseBody = '{"id":"cs_test_xyz"}';  // No url field
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createDonationSession(
                10.00, fundId(), null, false, null, 'One-Off'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().toLowerCase().contains('url'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    // ── Custom Setting validation ────────────────────────────────────

    @isTest
    static void test_missingDonationBaseUrl_throws() {
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        s.DonationBaseURL__c = null;
        update s;

        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createDonationSession(
                10.00, fundId(), null, false, null, 'One-Off'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().toLowerCase().contains('donate page url'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    @isTest
    static void test_missingEventsBaseUrl_throws() {
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        s.EventsBaseURL__c = null;
        update s;

        StripeMock m = new StripeMock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.createEventSession(eventId(), 1, null);
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().toLowerCase().contains('events page url'), e.getMessage());
        }
        Test.stopTest();
        System.assert(threw);
    }

    // ── EventInfo wire ──────────────────────────────────────────────

    @isTest
    static void test_getEventInfo_happyPath() {
        Id evt = eventId();

        Test.startTest();
        ULBC_StripeCheckoutController.EventInfo info =
            ULBC_StripeCheckoutController.getEventInfo(evt);
        Test.stopTest();

        System.assertEquals(evt, info.id);
        System.assertEquals('Spring Dinner', info.name);
        System.assertEquals(50, info.ticketPrice);
    }

    @isTest
    static void test_getEventInfo_invalidId_throws() {
        Test.startTest();
        Boolean threw = false;
        try {
            ULBC_StripeCheckoutController.getEventInfo(FAKE_FUND_ID);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw);
    }
}
