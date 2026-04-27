/**
 * ULBC_Phase3A_Campaign_Test
 *
 * Verifies Campaign (Fund) data model for Phase 3A:
 *   - Campaign records can be created with Type = Fund
 *   - All 7 standing fund names are valid
 *   - Campaigns can be linked to Opportunities (donation → fund allocation)
 *   - Campaign Members can be added (for event attendance in future phases)
 *
 * Note: Standing fund Campaign records are data, not metadata — they exist
 * in the live org but not in test context. These tests create their own
 * records to validate the schema.
 *
 * Run with: sf apex run test --class-names ULBC_Phase3A_Campaign_Test --code-coverage --target-org ulbc
 */
@isTest
private class ULBC_Phase3A_Campaign_Test {

    private static final List<String> FUND_NAMES = new List<String>{
        'Unrestricted / General',
        'ULBC Women\'s Group',
        'Equipment / Fleet',
        'Event',
        'Scholarship',
        'Bursary',
        'Coaching'
    };

    @TestSetup
    static void makeData() {
        List<Campaign> funds = new List<Campaign>();
        for (String name : FUND_NAMES) {
            funds.add(new Campaign(
                Name        = name,
                Type        = 'Fund',
                Status      = 'In Progress',
                IsActive    = true,
                Description = 'Test fund: ' + name
            ));
        }
        insert funds;
    }

    // ── Campaign creation and field values ─────────────────────────────────

    @isTest
    static void test_sevenFundCampaignsCreated() {
        List<Campaign> funds = [SELECT Id FROM Campaign WHERE Type = 'Fund'];
        System.assertEquals(7, funds.size(), 'All 7 standing fund campaigns must exist');
    }

    @isTest
    static void test_allFundCampaignsAreActive() {
        List<Campaign> inactive = [
            SELECT Name FROM Campaign WHERE Type = 'Fund' AND IsActive = false
        ];
        System.assertEquals(0, inactive.size(), 'All fund campaigns must be active');
    }

    @isTest
    static void test_fundCampaignFieldValues() {
        Campaign fund = [
            SELECT Name, Type, Status, IsActive, Description
            FROM Campaign WHERE Name = 'Scholarship' LIMIT 1
        ];
        System.assertEquals('Fund',        fund.Type,     'Type must be Fund');
        System.assertEquals('In Progress', fund.Status,   'Status must be In Progress');
        System.assertEquals(true,          fund.IsActive, 'Must be active');
        System.assertNotEquals(null,        fund.Description, 'Description must be set');
    }

    // ── Opportunity linked to Campaign (donation → fund) ──────────────────

    @isTest
    static void test_opportunityLinkedToCampaign() {
        Campaign fund = [SELECT Id FROM Campaign WHERE Name = 'Unrestricted / General' LIMIT 1];

        Opportunity opp = new Opportunity(
            Name       = 'Test Donation to Fund',
            StageName  = 'Closed Won',
            CloseDate  = Date.today(),
            Amount     = 100.00,
            CampaignId = fund.Id
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity result = [SELECT CampaignId FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(fund.Id, result.CampaignId, 'Donation must link to fund Campaign');
    }

    // ── Campaign Member (for future event attendance) ─────────────────────

    @isTest
    static void test_campaignMemberCanBeAdded() {
        Campaign eventCamp = [SELECT Id FROM Campaign WHERE Name = 'Event' LIMIT 1];

        Contact c = new Contact(
            FirstName = 'CampaignMember',
            LastName  = 'TestContact',
            ULBC_Primary_Contact_Type__c = 'Alumni'
        );
        insert c;

        CampaignMember cm = new CampaignMember(
            CampaignId = eventCamp.Id,
            ContactId  = c.Id,
            Status     = 'Sent'
        );

        Test.startTest();
        insert cm;
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :eventCamp.Id],
            'Campaign Member must be created on Event campaign');
    }
}
