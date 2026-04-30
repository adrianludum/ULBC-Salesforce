/**
 * ULBC_XeroImportSchedulable
 *
 * Phase 6A — registered with System.schedule() to fire daily (typically
 * 02:00 UTC, cron '0 0 2 * * ?'). Each fire enqueues page 1 of the
 * importer; the queueable then chains forward through any further pages.
 *
 * Decisions: 6.9.
 */
public without sharing class ULBC_XeroImportSchedulable implements Schedulable {

    public void execute(SchedulableContext ctx) {
        System.enqueueJob(new ULBC_XeroIncomeImporterQueueable(1, null));
    }
}