/**
 * ULBC_Phase4_Migration_Test
 *
 * Verifies new fields added for Phase 4 migration:
 *   - Contact: Profession, Other Interests, Special Skills, Follow Up Notes
 *   - Crew History: Rowing Position
 *   - Permission set FLS on new fields
 *
 * Run with: sf apex run test --class-names ULBC_Phase4_Migration_Test --code-coverage --target-org ulbc
 */
@isTest
private class ULBC_Phase4_Migration_Test {

    @TestSetup
    static void makeData() {
        Contact c = new Contact(
            FirstName = 'Migration',
            LastName  = 'TestContact',
            ULBC_Primary_Contact_Type__c = 'Alumni',
            ULBC_Profession__c           = 'Software Engineer',
            ULBC_Other_Interests__c      = 'Cycling, Theatre',
            ULBC_Special_Skills__c       = 'Coaching',
            ULBC_Follow_Up_Notes__c      = 'Follow up re: annual dinner attendance'
        );
        insert c;

        ULBC_Crew_History__c crew = new ULBC_Crew_History__c(
            ULBC_Contact__c          = c.Id,
            ULBC_Crew_Code__c        = '24G',
            ULBC_Year__c             = 2024,
            ULBC_Regatta__c          = 'Henley Royal Regatta',
            ULBC_Event__c            = 'Grand',
            ULBC_Crew_Name__c        = 'Henley Grand 2024',
            ULBC_Result__c           = 'Semi-Final',
            ULBC_Rowing_Position__c  = 5
        );
        insert crew;
    }

    // ── Contact migration fields ────────────────────────────────────────

    @isTest
    static void test_contactMigrationFields() {
        Contact c = [
            SELECT ULBC_Profession__c, ULBC_Other_Interests__c,
                   ULBC_Special_Skills__c, ULBC_Follow_Up_Notes__c
            FROM Contact WHERE LastName = 'TestContact' LIMIT 1
        ];
        System.assertEquals('Software Engineer', c.ULBC_Profession__c, 'Profession must match');
        System.assertEquals('Cycling, Theatre', c.ULBC_Other_Interests__c, 'Other Interests must match');
        System.assertEquals('Coaching', c.ULBC_Special_Skills__c, 'Special Skills must match');
        System.assertEquals('Follow up re: annual dinner attendance', c.ULBC_Follow_Up_Notes__c, 'Follow Up Notes must match');
    }

    // ── Crew History rowing position ────────────────────────────────────

    @isTest
    static void test_crewHistoryRowingPosition() {
        ULBC_Crew_History__c crew = [
            SELECT ULBC_Rowing_Position__c, ULBC_Crew_Code__c
            FROM ULBC_Crew_History__c WHERE ULBC_Crew_Code__c = '24G' LIMIT 1
        ];
        System.assertEquals(5, crew.ULBC_Rowing_Position__c, 'Rowing Position must be 5');
    }

    // ── Permission set FLS ──────────────────────────────────────────────

    @isTest
    static void test_fullAccessFLSOnMigrationFields() {
        List<FieldPermissions> fps = [
            SELECT Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE Parent.Name = 'ULBC_Full_Access'
              AND Field IN (
                  'Contact.ULBC_Profession__c',
                  'Contact.ULBC_Other_Interests__c',
                  'Contact.ULBC_Special_Skills__c',
                  'Contact.ULBC_Follow_Up_Notes__c',
                  'ULBC_Crew_History__c.ULBC_Rowing_Position__c'
              )
        ];
        System.assertEquals(5, fps.size(), 'Full Access must have FLS on all 5 new fields');
        for (FieldPermissions fp : fps) {
            System.assertEquals(true, fp.PermissionsRead, fp.Field + ' must be readable');
            System.assertEquals(true, fp.PermissionsEdit, fp.Field + ' must be editable');
        }
    }

    @isTest
    static void test_coachFLSReadOnlyOnMigrationFields() {
        List<FieldPermissions> fps = [
            SELECT Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE Parent.Name = 'ULBC_Coach'
              AND Field IN (
                  'Contact.ULBC_Profession__c',
                  'Contact.ULBC_Other_Interests__c',
                  'Contact.ULBC_Special_Skills__c',
                  'Contact.ULBC_Follow_Up_Notes__c',
                  'ULBC_Crew_History__c.ULBC_Rowing_Position__c'
              )
        ];
        System.assertEquals(5, fps.size(), 'Coach must have FLS on all 5 new fields');
        for (FieldPermissions fp : fps) {
            System.assertEquals(true, fp.PermissionsRead, fp.Field + ' must be readable');
            System.assertEquals(false, fp.PermissionsEdit, fp.Field + ' must NOT be editable');
        }
    }
}
