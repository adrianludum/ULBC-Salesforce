/**
 * ULBC_DonorTierEngine_Test
 * Phase 2B — Donor Tier Engine tests
 */
@IsTest
private class ULBC_DonorTierEngine_Test {

    private static Contact makeContact(String trustId) {
        Contact c = new Contact(
            FirstName = 'Test', LastName = 'Donor',
            ULBC_Trust_ID__c = trustId,
            ULBC_Primary_Contact_Type__c = 'Alumni',
            Email = trustId + '@example.com'
        );
        insert c;
        return c;
    }

    private static Opportunity makeOpp(Id contactId, Decimal amount, Date closeDate) {
        return new Opportunity(
            Name = 'Test Gift ' + amount,
            StageName = 'Closed Won',
            CloseDate = closeDate,
            Amount = amount,
            npe01__Contact_Id_for_Role__c = contactId
        );
    }

    private static Contact reloadContact(Id contactId) {
        return [
            SELECT Id, ULBC_Donor_Tier__c, ULBC_Rolling_12m_Giving__c,
                   ULBC_Last_Gift_Date__c, ULBC_Upgrade_Prospect__c,
                   ULBC_Next_Tier_Threshold__c, ULBC_Gap_To_Next_Tier__c,
                   ULBC_Tier_Progress_Pct__c
            FROM   Contact WHERE Id = :contactId
        ];
    }

    @IsTest static void test_noGifts_tierIsProspect() {
        Contact c = makeContact('ULBC-TIER-P-001');
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Prospect', r.ULBC_Donor_Tier__c, 'No gifts = Prospect');
        System.assertEquals(0, r.ULBC_Rolling_12m_Giving__c, 'No gifts = £0');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, 'Prospect has no upgrade alert');
    }

    @IsTest static void test_giftUnder240_tierIsStandard() {
        Contact c = makeContact('ULBC-TIER-S-001');
        insert makeOpp(c.Id, 100, Date.today().addDays(-30));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c, '£100 = Standard');
        System.assertEquals(100, r.ULBC_Rolling_12m_Giving__c, 'Rolling total £100');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, '£100 below 80% threshold');
    }

    @IsTest static void test_giftAt192_triggersUpgradeAlert_Standard() {
        Contact c = makeContact('ULBC-TIER-S-002');
        insert makeOpp(c.Id, 192, Date.today().addDays(-10));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c,        '£192 = Standard');
        System.assertEquals(true,       r.ULBC_Upgrade_Prospect__c,  '£192 = 80% → upgrade alert');
        System.assertEquals(240,        r.ULBC_Next_Tier_Threshold__c,'Next threshold £240');
        System.assertEquals(48,         r.ULBC_Gap_To_Next_Tier__c,  'Gap = £48');
    }

    @IsTest static void test_giftAt239_isStandard_notPatron() {
        Contact c = makeContact('ULBC-TIER-S-003');
        insert makeOpp(c.Id, 239, Date.today().addDays(-5));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals('Standard', reloadContact(c.Id).ULBC_Donor_Tier__c, '£239 = Standard');
    }

    @IsTest static void test_giftAt241_tierIsPatron() {
        Contact c = makeContact('ULBC-TIER-PAT-001');
        insert makeOpp(c.Id, 241, Date.today().addDays(-20));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Patron', r.ULBC_Donor_Tier__c, '£241 = Patron');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, '£241 below 80% of £1,000');
    }

    @IsTest static void test_giftAt800_triggersUpgradeAlert_Patron() {
        Contact c = makeContact('ULBC-TIER-PAT-002');
        insert makeOpp(c.Id, 800, Date.today().addDays(-15));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Patron', r.ULBC_Donor_Tier__c,        '£800 = Patron');
        System.assertEquals(true,     r.ULBC_Upgrade_Prospect__c,  '£800 = 80% → upgrade alert');
        System.assertEquals(1000,     r.ULBC_Next_Tier_Threshold__c,'Next threshold £1,000');
        System.assertEquals(200,      r.ULBC_Gap_To_Next_Tier__c,  'Gap = £200');
    }

    @IsTest static void test_giftAt999_isPatron_notMajor() {
        Contact c = makeContact('ULBC-TIER-PAT-003');
        insert makeOpp(c.Id, 999, Date.today().addDays(-5));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals('Patron', reloadContact(c.Id).ULBC_Donor_Tier__c, '£999 = Patron');
    }

    @IsTest static void test_giftAt1000_tierIsMajor() {
        Contact c = makeContact('ULBC-TIER-M-001');
        insert makeOpp(c.Id, 1000, Date.today().addDays(-10));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Major', r.ULBC_Donor_Tier__c, '£1,000 = Major');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, 'Major has no upgrade alert');
    }

    @IsTest static void test_largeGift_15000_isMajor() {
        Contact c = makeContact('ULBC-TIER-M-002');
        insert makeOpp(c.Id, 15000, Date.today().addDays(-5));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Major', r.ULBC_Donor_Tier__c,           '£15,000 = Major');
        System.assertEquals(15000,   r.ULBC_Rolling_12m_Giving__c,   'Rolling total £15,000');
        System.assertEquals(false,   r.ULBC_Upgrade_Prospect__c,     'Major has no upgrade alert');
    }

    @IsTest static void test_giftOver24MonthsAgo_tierIsLapsed() {
        Contact c = makeContact('ULBC-TIER-L-001');
        insert makeOpp(c.Id, 500, Date.today().addMonths(-25));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Lapsed', r.ULBC_Donor_Tier__c,         'Gift 25m ago = Lapsed');
        System.assertEquals(0,        r.ULBC_Rolling_12m_Giving__c, 'Outside 12m = £0');
        System.assertEquals(false,    r.ULBC_Upgrade_Prospect__c,   'Lapsed has no upgrade alert');
    }

    @IsTest static void test_giftAt23Months_isNotLapsed() {
        Contact c = makeContact('ULBC-TIER-L-002');
        insert makeOpp(c.Id, 300, Date.today().addMonths(-23));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertNotEquals('Lapsed', reloadContact(c.Id).ULBC_Donor_Tier__c, '23m ago is not Lapsed');
    }

    @IsTest static void test_rollingWindow_excludesOldGifts() {
        Contact c = makeContact('ULBC-TIER-W-001');
        insert new List<Opportunity>{
            makeOpp(c.Id, 150, Date.today().addDays(-30)),
            makeOpp(c.Id, 200, Date.today().addMonths(-14))
        };
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals(150,      r.ULBC_Rolling_12m_Giving__c, 'Only £150 within 12m counts');
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c,       '£150 = Standard');
    }

    @IsTest static void test_rollingWindow_multipleGiftsWithin12m() {
        Contact c = makeContact('ULBC-TIER-W-002');
        insert new List<Opportunity>{
            makeOpp(c.Id, 200, Date.today().addDays(-10)),
            makeOpp(c.Id, 250, Date.today().addDays(-60)),
            makeOpp(c.Id, 200, Date.today().addDays(-200))
        };
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals(650,     r.ULBC_Rolling_12m_Giving__c, '£200+£250+£200 = £650');
        System.assertEquals('Patron', r.ULBC_Donor_Tier__c,        '£650 = Patron');
    }

    @IsTest static void test_lastGiftDate_isCorrect() {
        Contact c = makeContact('ULBC-TIER-D-001');
        Date recentDate = Date.today().addDays(-5);
        Date olderDate  = Date.today().addDays(-90);
        insert new List<Opportunity>{
            makeOpp(c.Id, 100, olderDate),
            makeOpp(c.Id, 100, recentDate)
        };
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals(recentDate, reloadContact(c.Id).ULBC_Last_Gift_Date__c, 'Last gift date must be most recent');
    }

    @IsTest static void test_tierDowngrade_whenGiftDeleted() {
        Contact c = makeContact('ULBC-TIER-DOWN-001');
        Opportunity bigGift = makeOpp(c.Id, 1200, Date.today().addDays(-30));
        insert bigGift;
        ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        System.assertEquals('Major', reloadContact(c.Id).ULBC_Donor_Tier__c, 'Precondition: Major');
        insert makeOpp(c.Id, 100, Date.today().addDays(-10));
        Test.startTest();
            delete bigGift;
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c,           'After deleting £1,200 = Standard');
        System.assertEquals(100,        r.ULBC_Rolling_12m_Giving__c,   'Rolling total = £100');
    }

    @IsTest static void test_bulk_recalculate50Contacts() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 50; i++) {
            contacts.add(new Contact(
                FirstName='Bulk', LastName='Donor'+i,
                ULBC_Trust_ID__c='ULBC-BULK-TIER-'+String.valueOf(i).leftPad(3,'0'),
                ULBC_Primary_Contact_Type__c='Alumni'
            ));
        }
        insert contacts;
        List<Opportunity> opps = new List<Opportunity>();
        for (Contact c : contacts) {
            opps.add(makeOpp(c.Id, 300, Date.today().addDays(-10)));
        }
        insert opps;
        Set<Id> contactIds = new Map<Id,Contact>(contacts).keySet();
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(contactIds);
        Test.stopTest();
        System.assertEquals(50, [SELECT COUNT() FROM Contact
            WHERE ULBC_Trust_ID__c LIKE 'ULBC-BULK-TIER-%' AND ULBC_Donor_Tier__c = 'Patron'],
            'All 50 bulk contacts must be Patron');
    }

    @IsTest static void test_jade_progressionToMajor() {
        Contact jade = new Contact(
            FirstName='Jade', LastName='Smith',
            ULBC_Trust_ID__c='ULBC-JADE-TIER-001',
            ULBC_Primary_Contact_Type__c='Alumni'
        );
        insert jade;
        insert makeOpp(jade.Id, 15000, Date.today().addDays(-30));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ jade.Id });
        Test.stopTest();
        Contact r = reloadContact(jade.Id);
        System.assertEquals('Major', r.ULBC_Donor_Tier__c,          'Jade = Major');
        System.assertEquals(15000,   r.ULBC_Rolling_12m_Giving__c,  '£15,000 rolling total');
        System.assertEquals(false,   r.ULBC_Upgrade_Prospect__c,    'Major = no upgrade alert');
        System.assertNotEquals(null,  r.ULBC_Last_Gift_Date__c,      'Last gift date populated');
    }
}
