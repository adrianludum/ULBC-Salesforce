/**
 * ULBC_XeroIncomeImporterQueueable
 *
 * Phase 6A — Queueable wrapper around ULBC_XeroIncomeImporter.runPage().
 * Chains itself for the next page if the previous response indicated more
 * pages remain, up to MAX_PAGES_PER_RUN (safety bound on a single run).
 * Apex test mode does not chain — tests drive subsequent pages directly
 * by calling runPage().
 *
 * Decisions: 6.9–6.12.
 */
public without sharing class ULBC_XeroIncomeImporterQueueable
    implements Queueable, Database.AllowsCallouts {

    public static final Integer MAX_PAGES_PER_RUN = 50;

    private final Integer pageNumber;
    private final DateTime watermarkOverride;

    public ULBC_XeroIncomeImporterQueueable(Integer pageNumber, DateTime watermarkOverride) {
        this.pageNumber = pageNumber;
        this.watermarkOverride = watermarkOverride;
    }

    public void execute(QueueableContext ctx) {
        ULBC_XeroIncomeImporter.PageResult r =
            ULBC_XeroIncomeImporter.runPage(this.pageNumber, this.watermarkOverride);

        Boolean shouldChain = r != null
            && r.hasMore
            && r.status == 'Success'
            && this.pageNumber < MAX_PAGES_PER_RUN
            && !Test.isRunningTest();

        if (shouldChain) {
            // Pass the same effective watermark forward so subsequent pages
            // see a consistent cursor (Xero sorts ascending by UpdatedDateUTC).
            DateTime nextWatermark = (this.watermarkOverride != null)
                ? this.watermarkOverride
                : r.watermarkBefore;
            System.enqueueJob(new ULBC_XeroIncomeImporterQueueable(
                this.pageNumber + 1, nextWatermark));
        }
    }
}