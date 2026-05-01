/**
 * ULBC_EmailSendService_Test
 *
 * Orchestration: Send + Recipient materialisation, suppression flagging,
 * empty-result rejection. Does not assert on actual email delivery — that's
 * the Queueable's responsibility, tested elsewhere.
 */
@IsTest
private class ULBC_EmailSendService_Test {

    @TestSetup
    static void setup() {
        ULBC_Email_Settings__c s = ULBC_Email_Settings__c.getOrgDefaults();
        if (s == null || s.Id == null) {
            s = new ULBC_Email_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        s.TrackingBaseURL__c = 'https://ulbc.example/donate';
        s.EnableTracking__c = true;
        upsert s;

        Campaign c = new Campaign(Name = 'Service Test Campaign', IsActive = true);
        insert c;

        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Eligible', Email = 'a@example.com',
                        ULBC_Trust_ID__c = 'ULBC-A'),
            new Contact(LastName = 'OptedOut', Email = 'b@example.com',
                        HasOptedOutOfEmail = true,
                        ULBC_Trust_ID__c = 'ULBC-B'),
            new Contact(LastName = 'Dupe1', Email = 'shared@example.com',
                        ULBC_Trust_ID__c = 'ULBC-C'),
            new Contact(LastName = 'Dupe2', Email = 'shared@example.com',
                        ULBC_Trust_ID__c = 'ULBC-D')
        };
        insert contacts;

        List<CampaignMember> members = new List<CampaignMember>();
        for (Contact ct : contacts) {
            members.add(new CampaignMember(CampaignId = c.Id, ContactId = ct.Id, Status = 'Sent'));
        }
        insert members;
    }

    private static Id getCampaignId() {
        return [SELECT Id FROM Campaign WHERE Name = 'Service Test Campaign' LIMIT 1].Id;
    }

    @IsTest
    static void test_enqueue_createsSendAndRecipientsWithCorrectStatuses() {
        Test.startTest();
        ULBC_EmailSendService.EnqueueResult result = ULBC_EmailSendService.enqueue(
            getCampaignId(), 'no_such_template_devname', 'Test Subject', null, null);
        Test.stopTest();

        System.assertNotEquals(null, result.sendId);
        // 4 contacts → 4 recipient rows: 1 Eligible, 1 OptedOut, 2 Dupes (1 Eligible + 1 Duplicate)
        System.assertEquals(4, result.totalRecipientRows);
        System.assertEquals(2, result.eligibleCount, 'Eligible + one of the dupes');
        System.assertEquals(2, result.suppressedCount, 'OptedOut + one Duplicate');

        ULBC_Email_Send__c send = [
            SELECT ULBC_Status__c, ULBC_Recipient_Count__c, ULBC_Subject__c, ULBC_Initiated_By__c
            FROM ULBC_Email_Send__c WHERE Id = :result.sendId
        ];
        // After enqueue + Test.stopTest, the Queueable has run synchronously and
        // failed (template doesn't exist) — Send transitions to Failed.
        System.assertEquals('Failed', send.ULBC_Status__c,
            'Queueable should have failed because template is missing');
        System.assertEquals(4, send.ULBC_Recipient_Count__c);
        System.assertEquals(UserInfo.getUserId(), send.ULBC_Initiated_By__c);

        Map<String, Integer> statusCounts = new Map<String, Integer>();
        for (ULBC_Email_Send_Recipient__c r : [
            SELECT ULBC_Status__c FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :result.sendId
        ]) {
            Integer existing = statusCounts.containsKey(r.ULBC_Status__c)
                ? statusCounts.get(r.ULBC_Status__c) : 0;
            statusCounts.put(r.ULBC_Status__c, existing + 1);
        }
        // Eligibles started Pending — Queueable failed them → Failed.
        // Suppressed stayed Suppressed.
        System.assertEquals(2, statusCounts.get('Suppressed'),
            'Suppressed rows preserved across enqueue + Queueable run');
        System.assertEquals(2, statusCounts.get('Failed'),
            'Eligible rows marked Failed when Queueable cannot find template');
    }

    @IsTest
    static void test_enqueue_persistsTrustIdOnRecipientRows() {
        Test.startTest();
        ULBC_EmailSendService.EnqueueResult result = ULBC_EmailSendService.enqueue(
            getCampaignId(), 'no_such_template', null, null, null);
        Test.stopTest();

        Set<String> trustIds = new Set<String>();
        for (ULBC_Email_Send_Recipient__c r : [
            SELECT ULBC_Trust_ID__c FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :result.sendId
        ]) {
            trustIds.add(r.ULBC_Trust_ID__c);
        }
        System.assert(trustIds.contains('ULBC-A'));
        System.assert(trustIds.contains('ULBC-B'));
    }

    @IsTest
    static void test_enqueue_uniqueTokensPerRecipient() {
        Test.startTest();
        ULBC_EmailSendService.EnqueueResult result = ULBC_EmailSendService.enqueue(
            getCampaignId(), 'no_such_template', null, null, null);
        Test.stopTest();

        Set<String> tokens = new Set<String>();
        Integer rows = 0;
        for (ULBC_Email_Send_Recipient__c r : [
            SELECT ULBC_Token__c FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :result.sendId
        ]) {
            tokens.add(r.ULBC_Token__c);
            rows++;
        }
        System.assertEquals(rows, tokens.size(), 'Every recipient must have a distinct token');
    }

    @IsTest
    static void test_enqueue_nullCampaignId_throws() {
        try {
            ULBC_EmailSendService.enqueue(null, 'tpl', null, null, null);
            System.assert(false, 'Expected HandledException');
        } catch (ULBC_EmailSendService.HandledException e) {
            System.assert(e.getMessage().containsIgnoreCase('campaignId'));
        }
    }

    @IsTest
    static void test_enqueue_blankTemplateDevName_throws() {
        try {
            ULBC_EmailSendService.enqueue(getCampaignId(), null, null, null, null);
            System.assert(false, 'Expected HandledException');
        } catch (ULBC_EmailSendService.HandledException e) {
            System.assert(e.getMessage().containsIgnoreCase('templateDevName'));
        }
    }

    @IsTest
    static void test_enqueue_whenNoEligibleRecipients_throws() {
        // Create a campaign with only opted-out contacts.
        Campaign c = new Campaign(Name = 'All Opted Out', IsActive = true);
        insert c;
        Contact opt = new Contact(LastName = 'AllOpt', Email = 'x@example.com',
                                    HasOptedOutOfEmail = true, ULBC_Trust_ID__c = 'X');
        insert opt;
        insert new CampaignMember(CampaignId = c.Id, ContactId = opt.Id, Status = 'Sent');

        try {
            ULBC_EmailSendService.enqueue(c.Id, 'tpl', null, null, null);
            System.assert(false, 'Expected HandledException');
        } catch (ULBC_EmailSendService.HandledException e) {
            System.assert(e.getMessage().containsIgnoreCase('no eligible'));
        }
    }
}
