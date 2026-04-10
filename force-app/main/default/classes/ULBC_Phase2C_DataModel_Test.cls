/**
 * ULBC_Phase2C_DataModel_Test
 *
 * Verifies that all Phase 2C metadata is deployed and accessible:
 *   - Contact Gift Aid fields (6 fields)
 *   - Opportunity Phase 2C fields (6 fields)
 *   - ULBC_Subscription__c object + 8 fields
 *   - ULBC_Tyrian_Membership__c object + 8 fields
 *
 * No business logic in Phase 2C — these tests confirm the data model
 * is structurally correct and writable. Follows the same pattern as
 * ULBC_ContactDataModel_Test (Phase 1).
 *
 * Target: 8 tests, bringing total from 63 → 71 passing.
 */
@isTest
private class ULBC_Phase2C_DataModel_Test {

    // ── Shared test data ────────────────────────────────────────────────────

    private static Contact makeContact() {
        Contact c = new Contact(
            FirstName = 'Phase2C',
            LastName  = 'TestContact',
            ULBC_Primary_Contact_Type__c = 'Alumni',
            ULBC_GDPR_Legal_Basis__c     = 'Legitimate Interests'
        );
        insert c;
        return c;
    }

    // ── Contact Gift Aid fields ──────────────────────────────────────────────

    @isTest
    static void testContactGiftAidFields_SetAndRead() {
        Contact c = makeContact();

        c.ULBC_Gift_Aid_Eligible__c          = true;
        c.ULBC_Gift_Aid_Declaration_Date__c  = Date.newInstance(2026, 1, 15);
        c.ULBC_Gift_Aid_Declaration_Source__c = 'Online';
        c.ULBC_Gift_Aid_Postcode__c          = 'SW1A 1AA';
        c.ULBC_Gift_Aid_Valid_From__c        = Date.newInstance(2022, 1, 15);
        c.ULBC_Gift_Aid_Valid_To__c          = null; // open-ended

        Test.startTest();
        update c;
        Test.stopTest();

        Contact result = [
            SELECT ULBC_Gift_Aid_Eligible__c,
                   ULBC_Gift_Aid_Declaration_Date__c,
                   ULBC_Gift_Aid_Declaration_Source__c,
                   ULBC_Gift_Aid_Postcode__c,
                   ULBC_Gift_Aid_Valid_From__c,
                   ULBC_Gift_Aid_Valid_To__c
            FROM Contact WHERE Id = :c.Id
        ];

        System.assertEquals(true,                          result.ULBC_Gift_Aid_Eligible__c,           'Gift Aid Eligible should be true');
        System.assertEquals(Date.newInstance(2026, 1, 15), result.ULBC_Gift_Aid_Declaration_Date__c,   'Declaration date mismatch');
        System.assertEquals('Online',                      result.ULBC_Gift_Aid_Declaration_Source__c, 'Declaration source mismatch');
        System.assertEquals('SW1A 1AA',                    result.ULBC_Gift_Aid_Postcode__c,           'Postcode mismatch');
        System.assertEquals(Date.newInstance(2022, 1, 15), result.ULBC_Gift_Aid_Valid_From__c,         'Valid From mismatch');
        System.assertNotEquals(null, result.Id, 'Contact should exist');
    }

    @isTest
    static void testContactGiftAidFields_DefaultFalse() {
        // Gift Aid Eligible must default to false on a fresh contact
        Contact c = makeContact();
        Contact result = [SELECT ULBC_Gift_Aid_Eligible__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals(false, result.ULBC_Gift_Aid_Eligible__c, 'Gift Aid Eligible default should be false');
    }

    // ── Opportunity Phase 2C fields ──────────────────────────────────────────

    @isTest
    static void testOpportunityPhase2CFields_SetAndRead() {
        Contact c = makeContact();

        Opportunity opp = new Opportunity(
            Name        = 'Phase2C Test Gift',
            StageName   = 'Closed Won',
            CloseDate   = Date.today(),
            Amount      = 250.00
        );
        // NPSP requires Primary Contact via npe01__OppPayment__c or ContactRoles;
        // set AccountId via NPSP household — safest to leave blank in test
        insert opp;

        opp.ULBC_Gift_Type__c          = 'One-off';
        opp.ULBC_Fund_Type__c          = 'Unrestricted';
        opp.ULBC_Gift_Aid_Eligible__c  = true;
        opp.ULBC_Gift_Aid_Claimed_Date__c = Date.newInstance(2026, 3, 31);
        opp.ULBC_Gift_Source__c        = 'Alumni';
        opp.ULBC_Stripe_Payment_ID__c  = 'pi_test_placeholder_001';

        Test.startTest();
        update opp;
        Test.stopTest();

        Opportunity result = [
            SELECT ULBC_Gift_Type__c,
                   ULBC_Fund_Type__c,
                   ULBC_Gift_Aid_Eligible__c,
                   ULBC_Gift_Aid_Claimed_Date__c,
                   ULBC_Gift_Source__c,
                   ULBC_Stripe_Payment_ID__c
            FROM Opportunity WHERE Id = :opp.Id
        ];

        System.assertEquals('One-off',                     result.ULBC_Gift_Type__c,            'Gift Type mismatch');
        System.assertEquals('Unrestricted',                result.ULBC_Fund_Type__c,            'Fund Type mismatch');
        System.assertEquals(true,                          result.ULBC_Gift_Aid_Eligible__c,    'Opp Gift Aid Eligible mismatch');
        System.assertEquals(Date.newInstance(2026, 3, 31), result.ULBC_Gift_Aid_Claimed_Date__c,'Claimed Date mismatch');
        System.assertEquals('Alumni',                      result.ULBC_Gift_Source__c,          'Gift Source mismatch');
        System.assertEquals('pi_test_placeholder_001',     result.ULBC_Stripe_Payment_ID__c,    'Stripe ID mismatch');
    }

    @isTest
    static void testOpportunityGiftAidEligible_DefaultFalse() {
        Opportunity opp = new Opportunity(
            Name      = 'GA Default Test',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount    = 50.00
        );
        insert opp;
        Opportunity result = [SELECT ULBC_Gift_Aid_Eligible__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(false, result.ULBC_Gift_Aid_Eligible__c, 'Opp Gift Aid Eligible default should be false');
    }

    // ── ULBC_Subscription__c ─────────────────────────────────────────────────

    @isTest
    static void testSubscription_CreateAndRead() {
        Contact c = makeContact();

        ULBC_Subscription__c sub = new ULBC_Subscription__c(
            ULBC_Contact__c          = c.Id,
            ULBC_Amount__c           = 100.00,
            ULBC_Frequency__c        = 'Annual',
            ULBC_Status__c           = 'Active',
            ULBC_Start_Date__c       = Date.newInstance(2026, 1, 1),
            ULBC_Last_Payment_Date__c = Date.newInstance(2026, 1, 1),
            ULBC_Next_Payment_Date__c = Date.newInstance(2027, 1, 1),
            ULBC_Stripe_Payment_ID__c = 'sub_test_placeholder_001'
        );

        Test.startTest();
        insert sub;
        Test.stopTest();

        ULBC_Subscription__c result = [
            SELECT ULBC_Contact__c,
                   ULBC_Amount__c,
                   ULBC_Frequency__c,
                   ULBC_Status__c,
                   ULBC_Start_Date__c,
                   ULBC_Last_Payment_Date__c,
                   ULBC_Next_Payment_Date__c,
                   ULBC_Stripe_Payment_ID__c
            FROM ULBC_Subscription__c WHERE Id = :sub.Id
        ];

        System.assertEquals(c.Id,                          result.ULBC_Contact__c,           'Contact lookup mismatch');
        System.assertEquals(100.00,                        result.ULBC_Amount__c,            'Amount mismatch');
        System.assertEquals('Annual',                      result.ULBC_Frequency__c,         'Frequency mismatch');
        System.assertEquals('Active',                      result.ULBC_Status__c,            'Status mismatch');
        System.assertEquals(Date.newInstance(2026, 1, 1),  result.ULBC_Start_Date__c,        'Start Date mismatch');
        System.assertEquals(Date.newInstance(2026, 1, 1),  result.ULBC_Last_Payment_Date__c, 'Last Payment Date mismatch');
        System.assertEquals(Date.newInstance(2027, 1, 1),  result.ULBC_Next_Payment_Date__c, 'Next Payment Date mismatch');
        System.assertEquals('sub_test_placeholder_001',    result.ULBC_Stripe_Payment_ID__c, 'Stripe ID mismatch');
    }

    @isTest
    static void testSubscription_AutoNumberName() {
        // Verifies auto-number format SUB-{0000} is applied
        Contact c = makeContact();
        ULBC_Subscription__c sub = new ULBC_Subscription__c(
            ULBC_Contact__c    = c.Id,
            ULBC_Amount__c     = 100.00,
            ULBC_Frequency__c  = 'Annual',
            ULBC_Status__c     = 'Active',
            ULBC_Start_Date__c = Date.today()
        );
        insert sub;
        ULBC_Subscription__c result = [SELECT Name FROM ULBC_Subscription__c WHERE Id = :sub.Id];
        System.assert(result.Name.startsWith('SUB-'), 'Subscription Name should follow SUB-{0000} format, got: ' + result.Name);
    }

    // ── ULBC_Tyrian_Membership__c ────────────────────────────────────────────

    @isTest
    static void testTyrianMembership_CreateAndRead() {
        Contact c = makeContact();

        ULBC_Tyrian_Membership__c mem = new ULBC_Tyrian_Membership__c(
            ULBC_Contact__c          = c.Id,
            ULBC_Amount__c           = 75.00,
            ULBC_Frequency__c        = 'Annual',
            ULBC_Status__c           = 'Active',
            ULBC_Start_Date__c       = Date.newInstance(2026, 1, 1),
            ULBC_Last_Payment_Date__c = Date.newInstance(2026, 1, 1),
            ULBC_Next_Payment_Date__c = Date.newInstance(2027, 1, 1),
            ULBC_Stripe_Payment_ID__c = 'sub_tyrian_placeholder_001'
        );

        Test.startTest();
        insert mem;
        Test.stopTest();

        ULBC_Tyrian_Membership__c result = [
            SELECT ULBC_Contact__c,
                   ULBC_Amount__c,
                   ULBC_Frequency__c,
                   ULBC_Status__c,
                   ULBC_Start_Date__c,
                   ULBC_Last_Payment_Date__c,
                   ULBC_Next_Payment_Date__c,
                   ULBC_Stripe_Payment_ID__c
            FROM ULBC_Tyrian_Membership__c WHERE Id = :mem.Id
        ];

        System.assertEquals(c.Id,                          result.ULBC_Contact__c,           'Contact lookup mismatch');
        System.assertEquals(75.00,                         result.ULBC_Amount__c,            'Amount mismatch');
        System.assertEquals('Annual',                      result.ULBC_Frequency__c,         'Frequency mismatch');
        System.assertEquals('Active',                      result.ULBC_Status__c,            'Status mismatch');
        System.assertEquals(Date.newInstance(2026, 1, 1),  result.ULBC_Start_Date__c,        'Start Date mismatch');
        System.assertEquals(Date.newInstance(2026, 1, 1),  result.ULBC_Last_Payment_Date__c, 'Last Payment Date mismatch');
        System.assertEquals(Date.newInstance(2027, 1, 1),  result.ULBC_Next_Payment_Date__c, 'Next Payment Date mismatch');
        System.assertEquals('sub_tyrian_placeholder_001',  result.ULBC_Stripe_Payment_ID__c, 'Stripe ID mismatch');
    }

    @isTest
    static void testTyrianMembership_AutoNumberName() {
        // Verifies auto-number format TYR-{0000} is applied
        Contact c = makeContact();
        ULBC_Tyrian_Membership__c mem = new ULBC_Tyrian_Membership__c(
            ULBC_Contact__c    = c.Id,
            ULBC_Amount__c     = 75.00,
            ULBC_Frequency__c  = 'Annual',
            ULBC_Status__c     = 'Active',
            ULBC_Start_Date__c = Date.today()
        );
        insert mem;
        ULBC_Tyrian_Membership__c result = [SELECT Name FROM ULBC_Tyrian_Membership__c WHERE Id = :mem.Id];
        System.assert(result.Name.startsWith('TYR-'), 'Membership Name should follow TYR-{0000} format, got: ' + result.Name);
    }
}
