/**
 * ULBC_EmailEventAggregator
 *
 * Reads unaggregated rows from ULBC_Email_Event__c and folds them onto
 * the parent ULBC_Email_Send_Recipient__c (counters + first-event
 * timestamps). The recipient updates then propagate to ULBC_Email_Send__c
 * roll-up summaries naturally.
 *
 * Why decouple from the public endpoint: a forwarded email or MPP
 * pre-fetch can fire many opens per minute. Updating the parent rollup
 * directly causes row-lock contention. The Site endpoint does only blind
 * inserts; this class processes them asynchronously and in bulk.
 *
 * Cadence: self-rescheduling every 5 minutes. Each invocation processes
 * up to 5,000 events. If volume exceeds that, the next run picks up the
 * remainder. Tests do not reschedule.
 */
public with sharing class ULBC_EmailEventAggregator implements Schedulable {

    @TestVisible
    private static final Integer MAX_EVENTS_PER_RUN = 5000;

    @TestVisible
    private static final Integer RESCHEDULE_DELAY_MINUTES = 5;

    /** Result of one aggregation pass. */
    public class AggregateResult {
        public Integer eventsAggregated;
        public Integer recipientsTouched;
        public Integer orphansCleared;

        public AggregateResult(Integer e, Integer r, Integer o) {
            this.eventsAggregated = e;
            this.recipientsTouched = r;
            this.orphansCleared = o;
        }
    }

    public void execute(SchedulableContext sc) {
        aggregate();
        if (!Test.isRunningTest()) {
            scheduleNext();
        }
    }

    /**
     * Process up to MAX_EVENTS_PER_RUN unaggregated events, fold into
     * Recipient counters, mark events aggregated. Public+static so tests
     * (and a runbook one-off Anonymous Apex run) can call directly.
     */
    public static AggregateResult aggregate() {
        List<ULBC_Email_Event__c> events = [
            SELECT Id, ULBC_Recipient__c, ULBC_Event_Type__c, ULBC_Occurred_At__c, ULBC_URL__c
            FROM ULBC_Email_Event__c
            WHERE ULBC_Aggregated__c = false
            ORDER BY ULBC_Occurred_At__c ASC
            LIMIT :MAX_EVENTS_PER_RUN
        ];
        if (events.isEmpty()) return new AggregateResult(0, 0, 0);

        Set<Id> recipientIds = new Set<Id>();
        Integer orphans = 0;
        for (ULBC_Email_Event__c e : events) {
            if (e.ULBC_Recipient__c == null) {
                orphans++;
            } else {
                recipientIds.add(e.ULBC_Recipient__c);
            }
        }

        Map<Id, ULBC_Email_Send_Recipient__c> recipients =
            new Map<Id, ULBC_Email_Send_Recipient__c>([
                SELECT Id,
                       ULBC_Open_Count__c, ULBC_First_Open_At__c,
                       ULBC_Click_Count__c, ULBC_First_Click_At__c, ULBC_Last_Click_URL__c
                FROM ULBC_Email_Send_Recipient__c
                WHERE Id IN :recipientIds
            ]);

        for (ULBC_Email_Event__c e : events) {
            if (e.ULBC_Recipient__c == null) continue;
            ULBC_Email_Send_Recipient__c r = recipients.get(e.ULBC_Recipient__c);
            if (r == null) continue; // recipient was deleted between insert and aggregate

            if (e.ULBC_Event_Type__c == 'Open') {
                r.ULBC_Open_Count__c = nullSafePlusOne(r.ULBC_Open_Count__c);
                if (r.ULBC_First_Open_At__c == null
                        || (e.ULBC_Occurred_At__c != null
                            && r.ULBC_First_Open_At__c > e.ULBC_Occurred_At__c)) {
                    r.ULBC_First_Open_At__c = e.ULBC_Occurred_At__c;
                }
            } else if (e.ULBC_Event_Type__c == 'Click') {
                r.ULBC_Click_Count__c = nullSafePlusOne(r.ULBC_Click_Count__c);
                if (r.ULBC_First_Click_At__c == null
                        || (e.ULBC_Occurred_At__c != null
                            && r.ULBC_First_Click_At__c > e.ULBC_Occurred_At__c)) {
                    r.ULBC_First_Click_At__c = e.ULBC_Occurred_At__c;
                }
                if (String.isNotBlank(e.ULBC_URL__c)) {
                    r.ULBC_Last_Click_URL__c = e.ULBC_URL__c;
                }
            }
            // Unsubscribe / Bounce are recorded as events but do not roll up to counts.
        }

        if (!recipients.isEmpty()) update recipients.values();

        for (ULBC_Email_Event__c e : events) e.ULBC_Aggregated__c = true;
        update events;

        return new AggregateResult(events.size(), recipients.size(), orphans);
    }

    private static Decimal nullSafePlusOne(Decimal current) {
        return (current == null ? 0 : current) + 1;
    }

    /**
     * Schedule the next run RESCHEDULE_DELAY_MINUTES from now. Job names
     * include the timestamp so successive runs don't collide. Old job
     * AsyncApexJob entries are cleaned up by Salesforce automatically when
     * the run completes — but they linger as CompletedJob rows and can be
     * pruned manually if needed.
     */
    @TestVisible
    private static void scheduleNext() {
        Datetime next = System.now().addMinutes(RESCHEDULE_DELAY_MINUTES);
        String cron = '0 ' + next.minute() + ' ' + next.hour() + ' '
            + next.day() + ' ' + next.month() + ' ? ' + next.year();
        String name = 'ULBC_EmailEventAggregator_' + next.format('yyyyMMddHHmm');
        try {
            System.schedule(name, cron, new ULBC_EmailEventAggregator());
        } catch (Exception e) {
            // Already scheduled at this minute — benign, swallow.
            System.debug(LoggingLevel.WARN,
                'ULBC_EmailEventAggregator reschedule failed (already scheduled?): '
                + e.getMessage());
        }
    }

    /**
     * Bootstrap entry point. Call once from Anonymous Apex to start the
     * self-rescheduling loop:
     *   ULBC_EmailEventAggregator.start();
     */
    public static String start() {
        Datetime first = System.now().addMinutes(1);
        String cron = '0 ' + first.minute() + ' ' + first.hour() + ' '
            + first.day() + ' ' + first.month() + ' ? ' + first.year();
        return System.schedule('ULBC_EmailEventAggregator_bootstrap',
            cron, new ULBC_EmailEventAggregator());
    }
}
