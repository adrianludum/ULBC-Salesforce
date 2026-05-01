/**
 * ULBC_EmailSendQueueable_Test
 *
 * Tests status transitions and the template-not-found failure path. Real
 * Messaging.sendEmail success path is exercised end-to-end against a
 * scratch org with a seeded EmailTemplate (see runbook), not in unit tests
 * (EmailTemplate cannot be DML'd cleanly).
 */
@IsTest
private class ULBC_EmailSendQueueable_Test {

    @TestSetup
    static void setup() {
        ULBC_Email_Settings__c s = ULBC_Email_Settings__c.getOrgDefaults();
        if (s == null || s.Id == null) {
            s = new ULBC_Email_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        s.TrackingBaseURL__c = 'https://ulbc.example/donate';
        s.EnableTracking__c = true;
        upsert s;
    }

    private static ULBC_Email_Send__c buildSendWithRecipients(Integer recipientCount, String templateDevName) {
        Campaign c = new Campaign(Name = 'Q Test', IsActive = true);
        insert c;
        ULBC_Email_Send__c send = new ULBC_Email_Send__c(
            ULBC_Campaign__c = c.Id,
            ULBC_Email_Template_DevName__c = templateDevName,
            ULBC_Status__c = 'Queued',
            ULBC_Recipient_Count__c = recipientCount,
            ULBC_Initiated_By__c = UserInfo.getUserId()
        );
        insert send;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < recipientCount; i++) {
            contacts.add(new Contact(LastName = 'R' + i, Email = 'r' + i + '@example.com',
                                      ULBC_Trust_ID__c = 'ULBC-' + i));
        }
        insert contacts;

        List<ULBC_Email_Send_Recipient__c> rcpts = new List<ULBC_Email_Send_Recipient__c>();
        for (Integer i = 0; i < recipientCount; i++) {
            rcpts.add(new ULBC_Email_Send_Recipient__c(
                ULBC_Email_Send__c = send.Id,
                ULBC_Contact__c = contacts[i].Id,
                ULBC_Trust_ID__c = contacts[i].ULBC_Trust_ID__c,
                ULBC_Email_Address__c = contacts[i].Email,
                ULBC_Token__c = 'tok' + i + EncodingUtil.base64Encode(Crypto.generateAesKey(128)).left(28).replace('+', '-').replace('/', '_'),
                ULBC_Status__c = 'Pending',
                ULBC_Open_Count__c = 0,
                ULBC_Click_Count__c = 0
            ));
        }
        insert rcpts;
        return send;
    }

    @IsTest
    static void test_execute_templateNotFound_marksSendAndAllPendingFailed() {
        ULBC_Email_Send__c send = buildSendWithRecipients(3, 'definitely_not_a_real_template_xyz');

        Test.startTest();
        System.enqueueJob(new ULBC_EmailSendQueueable(send.Id));
        Test.stopTest();

        ULBC_Email_Send__c after = [
            SELECT ULBC_Status__c, ULBC_Sent_At__c FROM ULBC_Email_Send__c WHERE Id = :send.Id
        ];
        System.assertEquals('Failed', after.ULBC_Status__c);
        System.assertNotEquals(null, after.ULBC_Sent_At__c, 'Sent_At stamped on terminal transition');

        Integer failedCount = [
            SELECT COUNT() FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :send.Id AND ULBC_Status__c = 'Failed'
        ];
        System.assertEquals(3, failedCount, 'All Pending recipients marked Failed');

        for (ULBC_Email_Send_Recipient__c r : [
            SELECT ULBC_Suppression_Reason__c FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :send.Id
        ]) {
            System.assertEquals('SendException', r.ULBC_Suppression_Reason__c);
        }
    }

    @IsTest
    static void test_execute_cancelledSend_isNoOp() {
        ULBC_Email_Send__c send = buildSendWithRecipients(2, 'whatever');
        send.ULBC_Status__c = 'Cancelled';
        update send;

        Test.startTest();
        System.enqueueJob(new ULBC_EmailSendQueueable(send.Id));
        Test.stopTest();

        ULBC_Email_Send__c after = [SELECT ULBC_Status__c FROM ULBC_Email_Send__c WHERE Id = :send.Id];
        System.assertEquals('Cancelled', after.ULBC_Status__c, 'Status untouched');

        Integer pending = [
            SELECT COUNT() FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :send.Id AND ULBC_Status__c = 'Pending'
        ];
        System.assertEquals(2, pending, 'Recipients untouched');
    }

    @IsTest
    static void test_execute_alreadySent_isNoOp() {
        ULBC_Email_Send__c send = buildSendWithRecipients(1, 'whatever');
        send.ULBC_Status__c = 'Sent';
        update send;

        Test.startTest();
        System.enqueueJob(new ULBC_EmailSendQueueable(send.Id));
        Test.stopTest();

        ULBC_Email_Send__c after = [SELECT ULBC_Status__c FROM ULBC_Email_Send__c WHERE Id = :send.Id];
        System.assertEquals('Sent', after.ULBC_Status__c);
    }

    @IsTest
    static void test_resolveTemplate_blankDevName_returnsNull() {
        System.assertEquals(null, ULBC_EmailSendQueueable.resolveTemplate(null));
        System.assertEquals(null, ULBC_EmailSendQueueable.resolveTemplate(''));
        System.assertEquals(null, ULBC_EmailSendQueueable.resolveTemplate('   '));
    }

    @IsTest
    static void test_resolveTemplate_unknownDevName_returnsNull() {
        System.assertEquals(null,
            ULBC_EmailSendQueueable.resolveTemplate('definitely_not_a_real_template_zzz'));
    }
}
