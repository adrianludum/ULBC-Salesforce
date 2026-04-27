/**
 * ULBC_Phase3D_Event_Test
 *
 * Verifies Event data model for Phase 3D:
 *   - Event Campaign records with Type = 'Event' and custom fields
 *   - CampaignMember statuses: Invited, Registered, Attended, No-Show
 *   - Permission set FLS on custom Campaign fields
 *
 * Run with: sf apex run test --class-names ULBC_Phase3D_Event_Test --code-coverage --target-org ulbc
 */
@isTest
private class ULBC_Phase3D_Event_Test {

    @TestSetup
    static void makeData() {
        Campaign evt = new Campaign(
            Name        = 'Annual Dinner 2026',
            Type        = 'Event',
            Status      = 'Planned',
            IsActive    = true,
            StartDate   = Date.newInstance(2026, 6, 20),
            EndDate     = Date.newInstance(2026, 6, 20),
            Description = 'Black-tie dinner at Leander Club',
            ULBC_Start_Time__c  = Time.newInstance(18, 30, 0, 0),
            ULBC_End_Time__c    = Time.newInstance(23, 0, 0, 0),
            ULBC_Venue__c       = 'Leander Club, Henley-on-Thames',
            ULBC_Ticket_Price__c = 85.00
        );
        insert evt;

        // Create statuses for this campaign
        // Default statuses (Sent, Responded) exist automatically; add custom ones
        List<CampaignMemberStatus> statuses = new List<CampaignMemberStatus>();
        statuses.add(new CampaignMemberStatus(
            CampaignId  = evt.Id,
            Label       = 'Invited',
            SortOrder   = 3,
            IsDefault   = false,
            HasResponded = false
        ));
        statuses.add(new CampaignMemberStatus(
            CampaignId  = evt.Id,
            Label       = 'Registered',
            SortOrder   = 4,
            IsDefault   = false,
            HasResponded = true
        ));
        statuses.add(new CampaignMemberStatus(
            CampaignId  = evt.Id,
            Label       = 'Attended',
            SortOrder   = 5,
            IsDefault   = false,
            HasResponded = true
        ));
        statuses.add(new CampaignMemberStatus(
            CampaignId  = evt.Id,
            Label       = 'No-Show',
            SortOrder   = 6,
            IsDefault   = false,
            HasResponded = false
        ));
        insert statuses;

        Contact c = new Contact(
            FirstName = 'Event',
            LastName  = 'TestAttendee',
            ULBC_Primary_Contact_Type__c = 'Alumni'
        );
        insert c;
    }

    // ── Event Campaign creation and fields ──────────────────────────────

    @isTest
    static void test_eventCampaignCreatedWithCorrectType() {
        Campaign evt = [
            SELECT Name, Type, Status, IsActive, StartDate, EndDate, Description
            FROM Campaign WHERE Type = 'Event' LIMIT 1
        ];
        System.assertEquals('Event',   evt.Type,   'Campaign Type must be Event');
        System.assertEquals('Planned', evt.Status, 'Status must be Planned');
        System.assertEquals(true,      evt.IsActive, 'Must be active');
        System.assertEquals('Annual Dinner 2026', evt.Name, 'Name must match');
        System.assertEquals(Date.newInstance(2026, 6, 20), evt.StartDate, 'StartDate must match');
        System.assertEquals(Date.newInstance(2026, 6, 20), evt.EndDate, 'EndDate must match');
        System.assertNotEquals(null, evt.Description, 'Description must be set');
    }

    @isTest
    static void test_eventCampaignCustomFields() {
        Campaign evt = [
            SELECT ULBC_Start_Time__c, ULBC_End_Time__c, ULBC_Venue__c, ULBC_Ticket_Price__c
            FROM Campaign WHERE Type = 'Event' LIMIT 1
        ];
        System.assertEquals(Time.newInstance(18, 30, 0, 0), evt.ULBC_Start_Time__c, 'Start Time must be 18:30');
        System.assertEquals(Time.newInstance(23, 0, 0, 0),  evt.ULBC_End_Time__c,   'End Time must be 23:00');
        System.assertEquals('Leander Club, Henley-on-Thames', evt.ULBC_Venue__c, 'Venue must match');
        System.assertEquals(85.00, evt.ULBC_Ticket_Price__c, 'Ticket Price must be 85.00');
    }

    // ── CampaignMember statuses ─────────────────────────────────────────

    @isTest
    static void test_campaignMemberInvitedStatus() {
        Campaign evt = [SELECT Id FROM Campaign WHERE Type = 'Event' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'TestAttendee' LIMIT 1];

        CampaignMember cm = new CampaignMember(
            CampaignId = evt.Id,
            ContactId  = c.Id,
            Status     = 'Invited'
        );

        Test.startTest();
        insert cm;
        Test.stopTest();

        CampaignMember result = [SELECT Status FROM CampaignMember WHERE Id = :cm.Id];
        System.assertEquals('Invited', result.Status, 'Status must be Invited');
    }

    @isTest
    static void test_campaignMemberRegisteredStatus() {
        Campaign evt = [SELECT Id FROM Campaign WHERE Type = 'Event' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'TestAttendee' LIMIT 1];

        CampaignMember cm = new CampaignMember(
            CampaignId = evt.Id,
            ContactId  = c.Id,
            Status     = 'Invited'
        );
        insert cm;

        Test.startTest();
        cm.Status = 'Registered';
        update cm;
        Test.stopTest();

        CampaignMember result = [SELECT Status FROM CampaignMember WHERE Id = :cm.Id];
        System.assertEquals('Registered', result.Status, 'Status must be Registered');
    }

    @isTest
    static void test_campaignMemberAttendedStatus() {
        Campaign evt = [SELECT Id FROM Campaign WHERE Type = 'Event' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'TestAttendee' LIMIT 1];

        CampaignMember cm = new CampaignMember(
            CampaignId = evt.Id,
            ContactId  = c.Id,
            Status     = 'Attended'
        );

        Test.startTest();
        insert cm;
        Test.stopTest();

        CampaignMember result = [SELECT Status, HasResponded FROM CampaignMember WHERE Id = :cm.Id];
        System.assertEquals('Attended', result.Status, 'Status must be Attended');
        System.assertEquals(true, result.HasResponded, 'Attended must count as responded');
    }

    @isTest
    static void test_campaignMemberNoShowStatus() {
        Campaign evt = [SELECT Id FROM Campaign WHERE Type = 'Event' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'TestAttendee' LIMIT 1];

        CampaignMember cm = new CampaignMember(
            CampaignId = evt.Id,
            ContactId  = c.Id,
            Status     = 'No-Show'
        );

        Test.startTest();
        insert cm;
        Test.stopTest();

        CampaignMember result = [SELECT Status, HasResponded FROM CampaignMember WHERE Id = :cm.Id];
        System.assertEquals('No-Show', result.Status, 'Status must be No-Show');
        System.assertEquals(false, result.HasResponded, 'No-Show must not count as responded');
    }

    @isTest
    static void test_eventCampaignLinkedToContact() {
        Campaign evt = [SELECT Id FROM Campaign WHERE Type = 'Event' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'TestAttendee' LIMIT 1];

        CampaignMember cm = new CampaignMember(
            CampaignId = evt.Id,
            ContactId  = c.Id,
            Status     = 'Registered'
        );
        insert cm;

        System.assertEquals(1,
            [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :evt.Id AND ContactId = :c.Id],
            'Contact must be linked to event Campaign as CampaignMember');
    }

    // ── Permission set FLS ──────────────────────────────────────────────

    @isTest
    static void test_eventOrgFLSOnCustomFields() {
        List<FieldPermissions> fps = [
            SELECT Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE Parent.Name = 'ULBC_Event_Organiser'
              AND SobjectType = 'Campaign'
              AND Field IN (
                  'Campaign.ULBC_Start_Time__c',
                  'Campaign.ULBC_End_Time__c',
                  'Campaign.ULBC_Venue__c',
                  'Campaign.ULBC_Ticket_Price__c'
              )
        ];
        System.assertEquals(4, fps.size(), 'Event Organiser must have FLS on all 4 custom Campaign fields');
        for (FieldPermissions fp : fps) {
            System.assertEquals(true, fp.PermissionsRead, fp.Field + ' must be readable');
            System.assertEquals(true, fp.PermissionsEdit, fp.Field + ' must be editable');
        }
    }
}
