@IsTest
private class ULBC_StripeWebhook_Test {

    @TestSetup
    static void setup() {
        Campaign c = new Campaign(
            Name = 'Test Dinner 2025',
            Type = 'Event',
            Status = 'Planned',
            IsActive = true
        );
        insert c;
    }

    private static String buildCheckoutEvent(String campaignId, String eventType) {
        return buildCheckoutEventWithGuests(campaignId, eventType, '');
    }

    private static String buildCheckoutEventWithGuests(String campaignId, String eventType, String guestMeta) {
        String metaExtra = String.isNotBlank(guestMeta) ? ',' + guestMeta : '';
        return '{' +
            '"type": "' + eventType + '",' +
            '"data": {' +
                '"object": {' +
                    '"id": "cs_test_123",' +
                    '"payment_intent": "pi_test_456",' +
                    '"amount_total": 7500,' +
                    '"currency": "gbp",' +
                    '"customer_details": {' +
                        '"email": "test@example.com",' +
                        '"name": "Jane Smith"' +
                    '},' +
                    '"metadata": {' +
                        '"campaign_id": "' + campaignId + '",' +
                        '"quantity": "3"' +
                        metaExtra +
                    '}' +
                '}' +
            '}' +
        '}';
    }

    @IsTest
    static void test_checkoutCompleted_createsContactAndOpportunity() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Dinner 2025' LIMIT 1];
        String body = buildCheckoutEvent(camp.Id, 'checkout.session.completed');

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200');

        // Verify Contact created
        List<Contact> contacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Email = 'test@example.com'];
        System.assertEquals(1, contacts.size(), 'Contact should be created');
        System.assertEquals('Jane', contacts[0].FirstName);
        System.assertEquals('Smith', contacts[0].LastName);

        // Verify Opportunity created
        List<Opportunity> opps = [SELECT Id, Amount, ULBC_Stripe_Payment_ID__c FROM Opportunity WHERE npsp__Primary_Contact__c = :contacts[0].Id];
        System.assertEquals(1, opps.size(), 'Opportunity should be created');
        System.assertEquals(75.00, opps[0].Amount, 'Amount should be £75');
        System.assertEquals('pi_test_456', opps[0].ULBC_Stripe_Payment_ID__c);

        // Verify CampaignMember created
        List<CampaignMember> members = [SELECT Id, Status FROM CampaignMember WHERE ContactId = :contacts[0].Id AND CampaignId = :camp.Id];
        System.assertEquals(1, members.size(), 'CampaignMember should be created');
        System.assertEquals('Purchased', members[0].Status);
    }

    @IsTest
    static void test_existingContact_doesNotDuplicate() {
        Contact existing = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'test@example.com',
            ULBC_Trust_ID__c = 'ULBC-STRIPE-1'
        );
        insert existing;

        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Dinner 2025' LIMIT 1];
        String body = buildCheckoutEvent(camp.Id, 'checkout.session.completed');

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'test@example.com'];
        System.assertEquals(1, contacts.size(), 'Should not create duplicate contact');
    }

    @IsTest
    static void test_ignoredEventType() {
        String body = '{"type": "payment_intent.created", "data": {"object": {}}}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Should return 200 for ignored events');
    }

    @IsTest
    static void test_missingEmail_returns400() {
        String body = '{' +
            '"type": "checkout.session.completed",' +
            '"data": {' +
                '"object": {' +
                    '"id": "cs_test_999",' +
                    '"amount_total": 5000,' +
                    '"customer_details": {' +
                        '"name": "No Email"' +
                    '},' +
                    '"metadata": {}' +
                '}' +
            '}' +
        '}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400 for missing email');
    }

    @IsTest
    static void test_duplicateCampaignMember_noDuplicate() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Dinner 2025' LIMIT 1];

        Contact c = new Contact(FirstName = 'Repeat', LastName = 'Buyer', Email = 'repeat@example.com', ULBC_Trust_ID__c = 'ULBC-STRIPE-2');
        insert c;

        // Ensure Purchased status exists
        insert new CampaignMemberStatus(CampaignId = camp.Id, Label = 'Purchased', SortOrder = 4, IsDefault = false, HasResponded = true);
        insert new CampaignMember(CampaignId = camp.Id, ContactId = c.Id, Status = 'Purchased');

        String body = buildCheckoutEvent(camp.Id, 'checkout.session.completed');
        // Override email to match existing
        body = body.replace('test@example.com', 'repeat@example.com');
        body = body.replace('Jane Smith', 'Repeat Buyer');

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        List<CampaignMember> members = [SELECT Id FROM CampaignMember WHERE ContactId = :c.Id AND CampaignId = :camp.Id];
        System.assertEquals(1, members.size(), 'Should not create duplicate CampaignMember');
    }

    @IsTest
    static void test_guestsCreatedFromMetadata() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Dinner 2025' LIMIT 1];

        String guestMeta =
            '"guest_1_name": "Bob Jones",' +
            '"guest_1_email": "bob@example.com",' +
            '"guest_2_name": "Alice Green",' +
            '"guest_2_email": "alice@example.com"';

        String body = buildCheckoutEventWithGuests(camp.Id, 'checkout.session.completed', guestMeta);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

        // Buyer + 2 guests = 3 CampaignMembers
        List<CampaignMember> members = [SELECT Id, Status, ContactId FROM CampaignMember WHERE CampaignId = :camp.Id];
        System.assertEquals(3, members.size(), 'Should have buyer + 2 guests');

        // Verify guest contacts created
        List<Contact> bob = [SELECT Id, ULBC_Acquisition_Channel__c FROM Contact WHERE Email = 'bob@example.com'];
        System.assertEquals(1, bob.size(), 'Guest Bob should be created');
        System.assertEquals('Event Guest', bob[0].ULBC_Acquisition_Channel__c);

        List<Contact> alice = [SELECT Id FROM Contact WHERE Email = 'alice@example.com'];
        System.assertEquals(1, alice.size(), 'Guest Alice should be created');
    }

    @IsTest
    static void test_guestWithNameOnly_noEmail() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Dinner 2025' LIMIT 1];

        String guestMeta = '"guest_1_name": "Charlie NoEmail"';

        String body = buildCheckoutEventWithGuests(camp.Id, 'checkout.session.completed', guestMeta);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ULBC_StripeWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

        // Buyer + 1 guest = 2 CampaignMembers
        List<CampaignMember> members = [SELECT Id FROM CampaignMember WHERE CampaignId = :camp.Id];
        System.assertEquals(2, members.size(), 'Should have buyer + 1 name-only guest');

        List<Contact> charlie = [SELECT Id, LastName FROM Contact WHERE LastName = 'NoEmail' AND FirstName = 'Charlie'];
        System.assertEquals(1, charlie.size(), 'Name-only guest should be created');
    }
}
