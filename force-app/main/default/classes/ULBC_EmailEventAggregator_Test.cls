/**
 * ULBC_EmailEventAggregator_Test
 *
 * Roll-up correctness, idempotency (events marked aggregated never
 * reprocessed), orphan handling, multi-event chronology.
 */
@IsTest
private class ULBC_EmailEventAggregator_Test {

    private static ULBC_Email_Send_Recipient__c rcpt;

    @TestSetup
    static void setup() {
        Campaign c = new Campaign(Name = 'Agg Test', IsActive = true);
        insert c;
        Contact ct = new Contact(LastName = 'Agg', Email = 'agg@example.com',
                                   ULBC_Trust_ID__c = 'ULBC-AGG');
        insert ct;
        ULBC_Email_Send__c send = new ULBC_Email_Send__c(
            ULBC_Campaign__c = c.Id,
            ULBC_Email_Template_DevName__c = 'tpl',
            ULBC_Status__c = 'Sent',
            ULBC_Recipient_Count__c = 1,
            ULBC_Initiated_By__c = UserInfo.getUserId()
        );
        insert send;
        ULBC_Email_Send_Recipient__c r = new ULBC_Email_Send_Recipient__c(
            ULBC_Email_Send__c = send.Id,
            ULBC_Contact__c = ct.Id,
            ULBC_Trust_ID__c = ct.ULBC_Trust_ID__c,
            ULBC_Email_Address__c = ct.Email,
            ULBC_Token__c = 'agg-token-1',
            ULBC_Status__c = 'Sent',
            ULBC_Open_Count__c = 0,
            ULBC_Click_Count__c = 0
        );
        insert r;
    }

    private static ULBC_Email_Send_Recipient__c reload() {
        return [SELECT Id, ULBC_Open_Count__c, ULBC_First_Open_At__c,
                       ULBC_Click_Count__c, ULBC_First_Click_At__c, ULBC_Last_Click_URL__c
                FROM ULBC_Email_Send_Recipient__c
                WHERE ULBC_Token__c = 'agg-token-1' LIMIT 1];
    }

    @IsTest
    static void test_aggregate_setsFirstOpenAndIncrementsCount() {
        ULBC_Email_Send_Recipient__c r = reload();
        Datetime t1 = System.now().addMinutes(-30);
        Datetime t2 = System.now().addMinutes(-20);
        Datetime t3 = System.now().addMinutes(-10);

        insert new List<ULBC_Email_Event__c>{
            new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
                ULBC_Event_Type__c = 'Open', ULBC_Occurred_At__c = t2,
                ULBC_Aggregated__c = false),
            new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
                ULBC_Event_Type__c = 'Open', ULBC_Occurred_At__c = t1,
                ULBC_Aggregated__c = false),
            new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
                ULBC_Event_Type__c = 'Open', ULBC_Occurred_At__c = t3,
                ULBC_Aggregated__c = false)
        };

        Test.startTest();
        ULBC_EmailEventAggregator.AggregateResult res = ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();

        System.assertEquals(3, res.eventsAggregated);
        System.assertEquals(1, res.recipientsTouched);

        ULBC_Email_Send_Recipient__c after = reload();
        System.assertEquals(3, after.ULBC_Open_Count__c);
        System.assertEquals(t1, after.ULBC_First_Open_At__c,
            'First Open At = earliest event timestamp');
    }

    @IsTest
    static void test_aggregate_handlesClicksWithUrlAndChronology() {
        ULBC_Email_Send_Recipient__c r = reload();
        Datetime t1 = System.now().addMinutes(-15);
        Datetime t2 = System.now().addMinutes(-5);
        insert new List<ULBC_Email_Event__c>{
            new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
                ULBC_Event_Type__c = 'Click', ULBC_URL__c = 'https://example.com/a',
                ULBC_Occurred_At__c = t1, ULBC_Aggregated__c = false),
            new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
                ULBC_Event_Type__c = 'Click', ULBC_URL__c = 'https://example.com/b',
                ULBC_Occurred_At__c = t2, ULBC_Aggregated__c = false)
        };

        Test.startTest();
        ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();

        ULBC_Email_Send_Recipient__c after = reload();
        System.assertEquals(2, after.ULBC_Click_Count__c);
        System.assertEquals(t1, after.ULBC_First_Click_At__c);
        System.assertEquals('https://example.com/b', after.ULBC_Last_Click_URL__c,
            'Last Click URL = most recent in chronology');
    }

    @IsTest
    static void test_aggregate_doesNotReprocessAggregatedEvents() {
        ULBC_Email_Send_Recipient__c r = reload();
        insert new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
            ULBC_Event_Type__c = 'Open', ULBC_Occurred_At__c = System.now(),
            ULBC_Aggregated__c = false);

        Test.startTest();
        ULBC_EmailEventAggregator.aggregate();
        // Run again — should be a no-op since the event is now aggregated
        ULBC_EmailEventAggregator.AggregateResult second = ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();

        System.assertEquals(0, second.eventsAggregated);
        ULBC_Email_Send_Recipient__c after = reload();
        System.assertEquals(1, after.ULBC_Open_Count__c, 'Counter not double-incremented');
    }

    @IsTest
    static void test_aggregate_orphanEventIsClearedNotReprocessed() {
        // Orphan = Recipient = null (e.g. unknown token from public endpoint)
        insert new ULBC_Email_Event__c(ULBC_Recipient__c = null,
            ULBC_Event_Type__c = 'Open', ULBC_Occurred_At__c = System.now(),
            ULBC_Aggregated__c = false);

        Test.startTest();
        ULBC_EmailEventAggregator.AggregateResult res = ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();

        System.assertEquals(1, res.eventsAggregated);
        System.assertEquals(1, res.orphansCleared);
        System.assertEquals(0, res.recipientsTouched);

        Integer pending = [SELECT COUNT() FROM ULBC_Email_Event__c WHERE ULBC_Aggregated__c = false];
        System.assertEquals(0, pending, 'Orphans must still be marked aggregated');
    }

    @IsTest
    static void test_aggregate_unsubscribeAndBounce_doNotIncrementOpenOrClickCounts() {
        ULBC_Email_Send_Recipient__c r = reload();
        insert new List<ULBC_Email_Event__c>{
            new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
                ULBC_Event_Type__c = 'Unsubscribe', ULBC_Occurred_At__c = System.now(),
                ULBC_Aggregated__c = false),
            new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
                ULBC_Event_Type__c = 'Bounce', ULBC_Occurred_At__c = System.now(),
                ULBC_Aggregated__c = false)
        };

        Test.startTest();
        ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();

        ULBC_Email_Send_Recipient__c after = reload();
        System.assertEquals(0, after.ULBC_Open_Count__c);
        System.assertEquals(0, after.ULBC_Click_Count__c);
    }

    @IsTest
    static void test_aggregate_unsubscribe_stampsRecipientAndOptsOutContact() {
        ULBC_Email_Send_Recipient__c r = reload();
        Datetime unsubAt = System.now().addMinutes(-3);
        insert new ULBC_Email_Event__c(
            ULBC_Recipient__c = r.Id,
            ULBC_Event_Type__c = 'Unsubscribe',
            ULBC_Occurred_At__c = unsubAt,
            ULBC_Aggregated__c = false
        );

        Test.startTest();
        ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();

        ULBC_Email_Send_Recipient__c after = [
            SELECT ULBC_Unsubscribed_At__c, ULBC_Contact__c
            FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Token__c = 'agg-token-1' LIMIT 1
        ];
        System.assertEquals(unsubAt, after.ULBC_Unsubscribed_At__c,
            'Recipient.Unsubscribed_At stamped from event time');

        Contact c = [SELECT HasOptedOutOfEmail FROM Contact WHERE Id = :after.ULBC_Contact__c];
        System.assertEquals(true, c.HasOptedOutOfEmail,
            'Contact.HasOptedOutOfEmail flipped by aggregator');
    }

    @IsTest
    static void test_aggregate_unsubscribe_idempotentOnRepeatEvents() {
        ULBC_Email_Send_Recipient__c r = reload();
        Datetime first = System.now().addMinutes(-30);
        Datetime second = System.now().addMinutes(-10);
        insert new ULBC_Email_Event__c(
            ULBC_Recipient__c = r.Id,
            ULBC_Event_Type__c = 'Unsubscribe',
            ULBC_Occurred_At__c = first,
            ULBC_Aggregated__c = false
        );
        ULBC_EmailEventAggregator.aggregate();

        // Second unsub event later — Unsubscribed_At must not be overwritten.
        insert new ULBC_Email_Event__c(
            ULBC_Recipient__c = r.Id,
            ULBC_Event_Type__c = 'Unsubscribe',
            ULBC_Occurred_At__c = second,
            ULBC_Aggregated__c = false
        );

        Test.startTest();
        ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();

        ULBC_Email_Send_Recipient__c after = [
            SELECT ULBC_Unsubscribed_At__c FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Token__c = 'agg-token-1' LIMIT 1
        ];
        System.assertEquals(first, after.ULBC_Unsubscribed_At__c,
            'First Unsubscribed_At preserved across multiple events');
    }

    @IsTest
    static void test_aggregate_emptyQueue_returnsZero() {
        Test.startTest();
        ULBC_EmailEventAggregator.AggregateResult res = ULBC_EmailEventAggregator.aggregate();
        Test.stopTest();
        System.assertEquals(0, res.eventsAggregated);
    }

    @IsTest
    static void test_schedulable_executeRunsAggregateInTestContext() {
        // In test context the rescheduler short-circuits so we only verify
        // that execute() invokes aggregate() without erroring.
        ULBC_Email_Send_Recipient__c r = reload();
        insert new ULBC_Email_Event__c(ULBC_Recipient__c = r.Id,
            ULBC_Event_Type__c = 'Open', ULBC_Occurred_At__c = System.now(),
            ULBC_Aggregated__c = false);

        Test.startTest();
        new ULBC_EmailEventAggregator().execute(null);
        Test.stopTest();

        ULBC_Email_Send_Recipient__c after = reload();
        System.assertEquals(1, after.ULBC_Open_Count__c);
    }
}
