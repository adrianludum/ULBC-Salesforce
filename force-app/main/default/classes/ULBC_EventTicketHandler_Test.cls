/**
 * ULBC_EventTicketHandler_Test
 *
 * Phase 5A.3 — event ticket flow:
 *   - happy path: matches/creates Contact, creates CampaignMember + Opp
 *   - missing campaign_id raises HandlerException
 *   - invalid campaign_id raises HandlerException
 *   - repeat purchase by same Contact updates the existing CampaignMember (no dup)
 *   - new attendee gets Acquisition Channel = "Stripe Event Registration"
 */
@IsTest
private class ULBC_EventTicketHandler_Test {

    @TestSetup
    static void seed() {
        insert new Campaign(Name = 'Spring Dinner 2026', Type = 'Event',
                            Status = 'Planned', IsActive = true);
    }

    private static Map<String, Object> session(String email, String name,
                                                Decimal amountPounds,
                                                Map<String, Object> meta) {
        Map<String, Object> custDetails = new Map<String, Object>{
            'email' => email, 'name' => name
        };
        return new Map<String, Object>{
            'id' => 'cs_ticket_' + Crypto.getRandomLong(),
            'payment_intent' => 'pi_ticket_' + Crypto.getRandomLong(),
            'customer' => 'cus_ticket_' + Crypto.getRandomLong(),
            'amount_total' => Integer.valueOf(amountPounds * 100),
            'currency' => 'gbp',
            'customer_details' => custDetails,
            'metadata' => meta
        };
    }

    @IsTest
    static void test_happyPath_createsContactCampaignMemberAndOpportunity() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Spring Dinner 2026'];
        Map<String, Object> sess = session('attendee@example.com', 'New Attendee', 75,
            new Map<String, Object>{
                'campaign_id' => camp.Id
            });

        Test.startTest();
        ULBC_EventTicketHandler.Result r = ULBC_EventTicketHandler.handle(sess);
        Test.stopTest();

        System.assert(r.success);

        Contact c = [SELECT FirstName, LastName, ULBC_Acquisition_Channel__c
                     FROM Contact WHERE Id = :r.contactId];
        System.assertEquals('New', c.FirstName);
        System.assertEquals('Attendee', c.LastName);
        System.assertEquals('Stripe Event Registration', c.ULBC_Acquisition_Channel__c);

        CampaignMember cm = [SELECT Status, ULBC_Stripe_Payment_ID__c
                             FROM CampaignMember WHERE Id = :r.campaignMemberId];
        System.assertEquals('Purchased', cm.Status);
        System.assertNotEquals(null, cm.ULBC_Stripe_Payment_ID__c);

        Opportunity opp = [SELECT Amount, ULBC_Gift_Type__c, ULBC_Gift_Source__c, CampaignId
                           FROM Opportunity WHERE Id = :r.opportunityId];
        System.assertEquals(75, opp.Amount);
        System.assertEquals('Event Ticket', opp.ULBC_Gift_Type__c);
        System.assertEquals('Event', opp.ULBC_Gift_Source__c);
        System.assertEquals(camp.Id, opp.CampaignId);
    }

    @IsTest
    static void test_missingCampaignId_throwsHandlerException() {
        Map<String, Object> sess = session('x@example.com', 'No Camp', 50,
            new Map<String, Object>());

        Boolean threw = false;
        try {
            ULBC_EventTicketHandler.handle(sess);
        } catch (ULBC_EventTicketHandler.HandlerException e) {
            threw = true;
            System.assert(e.getMessage().contains('campaign_id'));
        }
        System.assert(threw);
    }

    @IsTest
    static void test_invalidCampaignId_throwsHandlerException() {
        Map<String, Object> sess = session('x@example.com', 'Bad Camp', 50,
            new Map<String, Object>{ 'campaign_id' => '7010000000000000AA' });

        Boolean threw = false;
        try {
            ULBC_EventTicketHandler.handle(sess);
        } catch (ULBC_EventTicketHandler.HandlerException e) {
            threw = true;
            System.assert(e.getMessage().contains('did not match'));
        }
        System.assert(threw);
    }

    @IsTest
    static void test_repeatPurchase_updatesExistingCampaignMember() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Spring Dinner 2026'];
        Contact c = new Contact(FirstName = 'Repeat', LastName = 'Buyer',
                                Email = 'repeat@example.com',
                                ULBC_Trust_ID__c = 'ULBC-REPEAT-1');
        insert c;
        // Pre-existing CampaignMember (e.g. invited)
        // Need the Invited status to exist — Campaign defaults provide it.
        insert new CampaignMember(CampaignId = camp.Id, ContactId = c.Id, Status = 'Sent');

        Map<String, Object> sess = session('repeat@example.com', 'Repeat Buyer', 75,
            new Map<String, Object>{
                'campaign_id' => camp.Id,
                'ulbc_trust_id' => 'ULBC-REPEAT-1'
            });

        Test.startTest();
        ULBC_EventTicketHandler.Result r = ULBC_EventTicketHandler.handle(sess);
        Test.stopTest();

        Integer cmCount = [SELECT COUNT() FROM CampaignMember
                           WHERE CampaignId = :camp.Id AND ContactId = :c.Id];
        System.assertEquals(1, cmCount, 'Should not duplicate CampaignMember');

        CampaignMember cm = [SELECT Status, ULBC_Stripe_Payment_ID__c
                             FROM CampaignMember WHERE Id = :r.campaignMemberId];
        System.assertEquals('Purchased', cm.Status);
        System.assertNotEquals(null, cm.ULBC_Stripe_Payment_ID__c);
    }
}
