/**
 * ULBC_Phase3C_Access_Test
 *
 * Verifies Phase 3C deliverables:
 *   - 5 role permission sets deploy and are queryable
 *   - Auto-TrustID assignment on Contact insert (ULBC-XXXX sequential)
 *   - TrustID not overwritten when pre-set (migration scenario)
 *   - Bulk TrustID assignment
 *   - Current Athletes list view filter logic
 *
 * Run with: sf apex run test --class-names ULBC_Phase3C_Access_Test --code-coverage --target-org ulbc
 */
@isTest
private class ULBC_Phase3C_Access_Test {

    // ── Permission set existence ────────────────────────────────────────

    @isTest
    static void test_fundraiserPermissionSetExists() {
        List<PermissionSet> ps = [SELECT Id, Label FROM PermissionSet WHERE Name = 'ULBC_Fundraiser'];
        System.assertEquals(1, ps.size(), 'ULBC_Fundraiser permission set must exist');
    }

    @isTest
    static void test_financePermissionSetExists() {
        List<PermissionSet> ps = [SELECT Id, Label FROM PermissionSet WHERE Name = 'ULBC_Finance'];
        System.assertEquals(1, ps.size(), 'ULBC_Finance permission set must exist');
    }

    @isTest
    static void test_eventOrganiserPermissionSetExists() {
        List<PermissionSet> ps = [SELECT Id, Label FROM PermissionSet WHERE Name = 'ULBC_Event_Organiser'];
        System.assertEquals(1, ps.size(), 'ULBC_Event_Organiser permission set must exist');
    }

    @isTest
    static void test_coachPermissionSetExists() {
        List<PermissionSet> ps = [SELECT Id, Label FROM PermissionSet WHERE Name = 'ULBC_Coach'];
        System.assertEquals(1, ps.size(), 'ULBC_Coach permission set must exist');
    }

    @isTest
    static void test_boathouseManagerPermissionSetExists() {
        List<PermissionSet> ps = [SELECT Id, Label FROM PermissionSet WHERE Name = 'ULBC_Boathouse_Manager'];
        System.assertEquals(1, ps.size(), 'ULBC_Boathouse_Manager permission set must exist');
    }

    // ── Coach permission set includes Lead object access ────────────────

    @isTest
    static void test_coachHasLeadObjectAccess() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ULBC_Coach' LIMIT 1];
        List<ObjectPermissions> ops = [
            SELECT SobjectType, PermissionsCreate, PermissionsRead, PermissionsEdit
            FROM ObjectPermissions
            WHERE ParentId = :ps.Id AND SobjectType = 'Lead'
        ];
        System.assertEquals(1, ops.size(), 'Coach must have Lead object permissions');
        System.assertEquals(true, ops[0].PermissionsCreate, 'Coach must be able to create Leads');
        System.assertEquals(true, ops[0].PermissionsRead, 'Coach must be able to read Leads');
        System.assertEquals(true, ops[0].PermissionsEdit, 'Coach must be able to edit Leads');
    }

    // ── Fundraiser has NO Lead object access ────────────────────────────

    @isTest
    static void test_fundraiserHasNoLeadAccess() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ULBC_Fundraiser' LIMIT 1];
        List<ObjectPermissions> ops = [
            SELECT SobjectType FROM ObjectPermissions
            WHERE ParentId = :ps.Id AND SobjectType = 'Lead'
        ];
        System.assertEquals(0, ops.size(), 'Fundraiser must not have Lead object permissions');
    }

    // ── Boathouse Manager has NO Lead object access ─────────────────────

    @isTest
    static void test_boathouseManagerHasNoLeadAccess() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ULBC_Boathouse_Manager' LIMIT 1];
        List<ObjectPermissions> ops = [
            SELECT SobjectType FROM ObjectPermissions
            WHERE ParentId = :ps.Id AND SobjectType = 'Lead'
        ];
        System.assertEquals(0, ops.size(), 'Boathouse Manager must not have Lead object permissions');
    }

    // ── Event Organiser has Campaign access but NO Opportunity ───────────

    @isTest
    static void test_eventOrganiserHasCampaignButNotOpportunity() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ULBC_Event_Organiser' LIMIT 1];
        List<ObjectPermissions> campaign = [
            SELECT SobjectType FROM ObjectPermissions
            WHERE ParentId = :ps.Id AND SobjectType = 'Campaign'
        ];
        List<ObjectPermissions> opp = [
            SELECT SobjectType FROM ObjectPermissions
            WHERE ParentId = :ps.Id AND SobjectType = 'Opportunity'
        ];
        System.assertEquals(1, campaign.size(), 'Event Organiser must have Campaign access');
        System.assertEquals(0, opp.size(), 'Event Organiser must not have Opportunity access');
    }

    // ── Auto-TrustID assignment ─────────────────────────────────────────

    @isTest
    static void test_autoTrustIdAssignedOnInsert() {
        Contact c = new Contact(
            FirstName = 'New',
            LastName  = 'Athlete',
            ULBC_Primary_Contact_Type__c = 'Athlete-Student'
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Contact result = [SELECT ULBC_Trust_ID__c FROM Contact WHERE Id = :c.Id];
        System.assertNotEquals(null, result.ULBC_Trust_ID__c, 'TrustID must be auto-assigned');
        System.assert(result.ULBC_Trust_ID__c.startsWith('ULBC-'), 'TrustID must start with ULBC-');
    }

    @isTest
    static void test_autoTrustIdIsSequential() {
        Contact c1 = new Contact(
            FirstName = 'First',
            LastName  = 'Athlete',
            ULBC_Primary_Contact_Type__c = 'Athlete-Student'
        );
        insert c1;

        Contact c2 = new Contact(
            FirstName = 'Second',
            LastName  = 'Athlete',
            ULBC_Primary_Contact_Type__c = 'Athlete-Student'
        );

        Test.startTest();
        insert c2;
        Test.stopTest();

        Contact r1 = [SELECT ULBC_Trust_ID__c FROM Contact WHERE Id = :c1.Id];
        Contact r2 = [SELECT ULBC_Trust_ID__c FROM Contact WHERE Id = :c2.Id];

        Integer num1 = Integer.valueOf(r1.ULBC_Trust_ID__c.substringAfter('ULBC-'));
        Integer num2 = Integer.valueOf(r2.ULBC_Trust_ID__c.substringAfter('ULBC-'));
        System.assertEquals(num1 + 1, num2, 'TrustIDs must be sequential');
    }

    @isTest
    static void test_trustIdNotOverwrittenWhenPreSet() {
        Contact c = new Contact(
            FirstName = 'Migrated',
            LastName  = 'Alumni',
            ULBC_Primary_Contact_Type__c = 'Alumni',
            ULBC_Trust_ID__c = 'ULBC-9999'
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Contact result = [SELECT ULBC_Trust_ID__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('ULBC-9999', result.ULBC_Trust_ID__c,
            'Pre-set TrustID must not be overwritten');
    }

    @isTest
    static void test_bulkTrustIdAssignment() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName  = 'Contact' + i,
                ULBC_Primary_Contact_Type__c = 'Athlete-Student'
            ));
        }

        Test.startTest();
        insert contacts;
        Test.stopTest();

        Set<String> trustIds = new Set<String>();
        for (Contact c : [SELECT ULBC_Trust_ID__c FROM Contact WHERE Id IN :contacts]) {
            System.assertNotEquals(null, c.ULBC_Trust_ID__c, 'Every contact must have a TrustID');
            System.assert(c.ULBC_Trust_ID__c.startsWith('ULBC-'), 'TrustID must start with ULBC-');
            trustIds.add(c.ULBC_Trust_ID__c);
        }
        System.assertEquals(200, trustIds.size(), 'All 200 TrustIDs must be unique');
    }

    @isTest
    static void test_trustIdContinuesFromExisting() {
        Contact existing = new Contact(
            FirstName = 'Existing',
            LastName  = 'Alumni',
            ULBC_Primary_Contact_Type__c = 'Alumni',
            ULBC_Trust_ID__c = 'ULBC-0050'
        );
        insert existing;

        Contact newContact = new Contact(
            FirstName = 'New',
            LastName  = 'Athlete',
            ULBC_Primary_Contact_Type__c = 'Athlete-Student'
        );

        Test.startTest();
        insert newContact;
        Test.stopTest();

        Contact result = [SELECT ULBC_Trust_ID__c FROM Contact WHERE Id = :newContact.Id];
        System.assertEquals('ULBC-0051', result.ULBC_Trust_ID__c,
            'TrustID must continue from highest existing number');
    }

    // ── Current Athletes list view filter logic ─────────────────────────

    @isTest
    static void test_currentAthletesFilterLogic() {
        Contact athlete = new Contact(
            FirstName = 'Active',
            LastName  = 'Rower',
            ULBC_Primary_Contact_Type__c = 'Athlete-Student'
        );
        Contact alumnus = new Contact(
            FirstName = 'Former',
            LastName  = 'Rower',
            ULBC_Primary_Contact_Type__c = 'Alumni'
        );
        insert new List<Contact>{ athlete, alumnus };

        List<Contact> athletes = [
            SELECT Id FROM Contact
            WHERE ULBC_Primary_Contact_Type__c = 'Athlete-Student'
        ];
        System.assertEquals(1, athletes.size(), 'Only Athlete-Student contacts appear in athlete filter');
        System.assertEquals(athlete.Id, athletes[0].Id);
    }
}
