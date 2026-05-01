/**
 * ULBC_EmailSendController_Test
 *
 * Smoke tests for the Aura facade. Real Messaging.renderStoredEmailTemplate
 * paths can't run cleanly in tests (template DML restrictions) — those are
 * exercised end-to-end against a scratch org with a seeded template.
 */
@IsTest
private class ULBC_EmailSendController_Test {

    @TestSetup
    static void setup() {
        ULBC_Email_Settings__c s = ULBC_Email_Settings__c.getOrgDefaults();
        if (s == null || s.Id == null) {
            s = new ULBC_Email_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        s.TrackingBaseURL__c = 'https://ulbc.example/donate';
        s.EnableTracking__c = true;
        upsert s;

        Campaign c = new Campaign(Name = 'Ctrl Test', IsActive = true);
        insert c;
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Eligible', Email = 'a@example.com',
                        ULBC_Trust_ID__c = 'ULBC-1'),
            new Contact(LastName = 'OptedOut', Email = 'b@example.com',
                        HasOptedOutOfEmail = true,
                        ULBC_Trust_ID__c = 'ULBC-2')
        };
        insert contacts;
        for (Contact ct : contacts) {
            insert new CampaignMember(CampaignId = c.Id, ContactId = ct.Id, Status = 'Sent');
        }
    }

    private static Id getCampaignId() {
        return [SELECT Id FROM Campaign WHERE Name = 'Ctrl Test' LIMIT 1].Id;
    }

    @IsTest
    static void test_previewRecipients_returnsCounts() {
        ULBC_EmailSendController.PreviewCounts pc =
            ULBC_EmailSendController.previewRecipients(getCampaignId(), null);
        System.assertEquals(2, pc.total);
        System.assertEquals(1, pc.eligible);
        System.assertEquals(1, pc.suppressed);
        System.assertEquals(1, pc.suppressionByReason.get('OptedOut'));
        System.assertNotEquals(null, pc.firstEligibleContactId);
    }

    @IsTest
    static void test_previewRecipients_filterJsonParsed() {
        String filter = '{"campaignMemberStatuses":["Sent"],"requireTrustId":true}';
        ULBC_EmailSendController.PreviewCounts pc =
            ULBC_EmailSendController.previewRecipients(getCampaignId(), filter);
        System.assertEquals(2, pc.total, 'Both members are Status=Sent and have Trust IDs');
    }

    @IsTest
    static void test_listTemplates_returnsListWithoutError() {
        // No templates exist in the scratch test context; just verify the
        // method returns cleanly (empty list is fine).
        List<ULBC_EmailSendController.TemplateOption> opts =
            ULBC_EmailSendController.listTemplates('ULBC_Bulk');
        System.assertNotEquals(null, opts);
    }

    @IsTest
    static void test_enqueueSend_handledExceptionSurfacedAsAuraHandled() {
        // Template doesn't exist, but enqueueSend itself doesn't validate
        // templates — so the failure must come from "no eligible recipients"
        // or another HandledException path. Use an empty Campaign.
        Campaign empty = new Campaign(Name = 'Empty Ctrl', IsActive = true);
        insert empty;
        try {
            ULBC_EmailSendController.enqueueSend(empty.Id, 'tpl', null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // Expected
        }
    }

    @IsTest
    static void test_previewRender_unknownTemplate_throws() {
        try {
            ULBC_EmailSendController.previewRender(getCampaignId(), 'no_such_tpl', null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // expected
        }
    }
}
