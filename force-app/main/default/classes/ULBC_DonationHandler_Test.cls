/**
 * ULBC_DonationHandler_Test
 *
 * Phase 5A.3 — donation flow:
 *   - happy path with TrustID match
 *   - new donor (no match) → Contact created with Acquisition Channel = "Stripe Donation"
 *   - Gift Aid declared → Opportunity flagged eligible AND Contact declaration captured
 *   - existing declaration not overwritten
 *   - fund matches a Campaign → Opportunity.CampaignId set
 *   - fund missing/invalid → Opportunity created without Campaign, note in Description
 */
@IsTest
private class ULBC_DonationHandler_Test {

    private static Map<String, Object> session(String email, String name,
                                                Decimal amountPounds,
                                                Map<String, Object> meta) {
        Map<String, Object> custDetails = new Map<String, Object>{
            'email' => email, 'name' => name
        };
        return new Map<String, Object>{
            'id' => 'cs_donation_' + Crypto.getRandomLong(),
            'payment_intent' => 'pi_donation_' + Crypto.getRandomLong(),
            'customer' => 'cus_donation_' + Crypto.getRandomLong(),
            'amount_total' => Integer.valueOf(amountPounds * 100),
            'currency' => 'gbp',
            'customer_details' => custDetails,
            'metadata' => meta
        };
    }

    @IsTest
    static void test_donation_matchesByTrustId_andCreatesOpportunity() {
        Contact existing = new Contact(FirstName = 'Loyal', LastName = 'Donor',
                                       Email = 'loyal@example.com',
                                       ULBC_Trust_ID__c = 'ULBC-DONOR-1');
        insert existing;

        Map<String, Object> session = session(
            'loyal@example.com', 'Loyal Donor', 100,
            new Map<String, Object>{
                'ulbc_trust_id' => 'ULBC-DONOR-1',
                'gift_type' => 'One-Off',
                'gift_aid' => 'false'
            });

        Test.startTest();
        ULBC_DonationHandler.Result r = ULBC_DonationHandler.handle(session);
        Test.stopTest();

        System.assert(r.success);
        System.assertEquals(existing.Id, r.contactId, 'Should match by TrustID');

        Opportunity opp = [SELECT Amount, ULBC_Gift_Type__c, ULBC_Gift_Source__c,
                                  ULBC_Gift_Aid_Eligible__c, npsp__Primary_Contact__c
                           FROM Opportunity WHERE Id = :r.opportunityId];
        System.assertEquals(100, opp.Amount);
        System.assertEquals('One-off', opp.ULBC_Gift_Type__c);
        System.assertEquals('Digital', opp.ULBC_Gift_Source__c);
        System.assertEquals(false, opp.ULBC_Gift_Aid_Eligible__c);
        System.assertEquals(existing.Id, opp.npsp__Primary_Contact__c);
    }

    @IsTest
    static void test_donation_recurringMapsToRegular() {
        Map<String, Object> session = session(
            'recurring@example.com', 'Recur Person', 50,
            new Map<String, Object>{ 'gift_type' => 'Recurring', 'gift_aid' => 'false' });

        Test.startTest();
        ULBC_DonationHandler.Result r = ULBC_DonationHandler.handle(session);
        Test.stopTest();

        Opportunity opp = [SELECT ULBC_Gift_Type__c FROM Opportunity WHERE Id = :r.opportunityId];
        System.assertEquals('Regular', opp.ULBC_Gift_Type__c);
    }

    @IsTest
    static void test_newDonor_createsContactWithStripeDonationChannel() {
        Map<String, Object> session = session(
            'brand-new@example.com', 'Brand New', 25,
            new Map<String, Object>{ 'gift_type' => 'One-Off', 'gift_aid' => 'false' });

        Test.startTest();
        ULBC_DonationHandler.Result r = ULBC_DonationHandler.handle(session);
        Test.stopTest();

        Contact c = [SELECT FirstName, LastName, Email, ULBC_Acquisition_Channel__c,
                            ULBC_Stripe_Customer_ID__c
                     FROM Contact WHERE Id = :r.contactId];
        System.assertEquals('Brand', c.FirstName);
        System.assertEquals('New', c.LastName);
        System.assertEquals('brand-new@example.com', c.Email);
        System.assertEquals('Stripe Donation', c.ULBC_Acquisition_Channel__c);
        System.assertNotEquals(null, c.ULBC_Stripe_Customer_ID__c,
            'Stripe Customer ID should be linked on first payment');
    }

    @IsTest
    static void test_giftAid_declaredFirstTime_capturesContactDeclaration() {
        Contact c = new Contact(FirstName = 'No', LastName = 'Declaration',
                                Email = 'newdec@example.com',
                                ULBC_Trust_ID__c = 'ULBC-NEWDEC');
        insert c;

        Map<String, Object> session = session(
            'newdec@example.com', 'No Declaration', 200,
            new Map<String, Object>{
                'ulbc_trust_id' => 'ULBC-NEWDEC',
                'gift_type' => 'One-Off',
                'gift_aid' => 'true',
                'gift_aid_postcode' => 'SW1A 1AA'
            });

        Test.startTest();
        ULBC_DonationHandler.Result r = ULBC_DonationHandler.handle(session);
        Test.stopTest();

        Contact updated = [SELECT ULBC_Gift_Aid_Eligible__c, ULBC_Gift_Aid_Declaration_Date__c,
                                  ULBC_Gift_Aid_Postcode__c, ULBC_Gift_Aid_Declaration_Source__c
                           FROM Contact WHERE Id = :c.Id];
        System.assertEquals(true, updated.ULBC_Gift_Aid_Eligible__c);
        System.assertEquals(Date.today(), updated.ULBC_Gift_Aid_Declaration_Date__c);
        System.assertEquals('SW1A 1AA', updated.ULBC_Gift_Aid_Postcode__c);
        System.assertEquals('Online', updated.ULBC_Gift_Aid_Declaration_Source__c);

        Opportunity opp = [SELECT ULBC_Gift_Aid_Eligible__c FROM Opportunity WHERE Id = :r.opportunityId];
        System.assertEquals(true, opp.ULBC_Gift_Aid_Eligible__c);
    }

    @IsTest
    static void test_giftAid_existingDeclaration_notOverwritten() {
        Contact c = new Contact(FirstName = 'Has', LastName = 'Decl',
                                Email = 'hasdec@example.com',
                                ULBC_Trust_ID__c = 'ULBC-HASDEC',
                                ULBC_Gift_Aid_Eligible__c = true,
                                ULBC_Gift_Aid_Declaration_Date__c = Date.newInstance(2024, 1, 1),
                                ULBC_Gift_Aid_Postcode__c = 'OLD 1AA');
        insert c;

        Map<String, Object> session = session(
            'hasdec@example.com', 'Has Decl', 50,
            new Map<String, Object>{
                'ulbc_trust_id' => 'ULBC-HASDEC',
                'gift_type' => 'One-Off',
                'gift_aid' => 'true',
                'gift_aid_postcode' => 'NEW 1AA'
            });

        Test.startTest();
        ULBC_DonationHandler.handle(session);
        Test.stopTest();

        Contact reloaded = [SELECT ULBC_Gift_Aid_Declaration_Date__c, ULBC_Gift_Aid_Postcode__c
                            FROM Contact WHERE Id = :c.Id];
        System.assertEquals(Date.newInstance(2024, 1, 1), reloaded.ULBC_Gift_Aid_Declaration_Date__c,
            'Existing declaration date must not be overwritten');
        System.assertEquals('OLD 1AA', reloaded.ULBC_Gift_Aid_Postcode__c,
            'Existing postcode must not be overwritten');
    }

    @IsTest
    static void test_fund_validCampaignId_linksOpportunityToCampaign() {
        Campaign fund = new Campaign(Name = 'Test Restricted Fund', Type = 'Fund', IsActive = true);
        insert fund;

        Map<String, Object> session = session(
            'fund@example.com', 'Fund Donor', 75,
            new Map<String, Object>{
                'fund' => fund.Id,
                'gift_type' => 'One-Off',
                'gift_aid' => 'false'
            });

        Test.startTest();
        ULBC_DonationHandler.Result r = ULBC_DonationHandler.handle(session);
        Test.stopTest();

        Opportunity opp = [SELECT CampaignId FROM Opportunity WHERE Id = :r.opportunityId];
        System.assertEquals(fund.Id, opp.CampaignId);
    }

    @IsTest
    static void test_fund_invalidId_opportunityCreatedWithoutCampaignAndNoteInDescription() {
        // 18 chars but not a real Campaign
        String fakeId = '7010000000000000AA';

        Map<String, Object> session = session(
            'invalid@example.com', 'Invalid Fund', 30,
            new Map<String, Object>{
                'fund' => fakeId,
                'gift_type' => 'One-Off',
                'gift_aid' => 'false'
            });

        Test.startTest();
        ULBC_DonationHandler.Result r = ULBC_DonationHandler.handle(session);
        Test.stopTest();

        Opportunity opp = [SELECT CampaignId, Description FROM Opportunity WHERE Id = :r.opportunityId];
        System.assertEquals(null, opp.CampaignId);
        System.assert(opp.Description.contains('not found'),
            'Description should note the invalid fund id');
    }
}
