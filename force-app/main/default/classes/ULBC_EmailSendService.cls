/**
 * ULBC_EmailSendService
 *
 * Public entry point for starting a custom mass-email send.
 *
 * Orchestrates:
 *   1. Validate inputs
 *   2. Resolve recipients via ULBC_EmailRecipientResolver
 *   3. Reject when zero eligible recipients
 *   4. Create the ULBC_Email_Send__c parent (Status=Draft)
 *   5. Materialise one ULBC_Email_Send_Recipient__c per resolved row
 *      (Status=Pending for eligible, Status=Suppressed for suppressed)
 *   6. Stamp Recipient_Count + Status=Queued
 *   7. Enqueue ULBC_EmailSendQueueable
 *
 * Template existence is NOT validated here — the Queueable resolves the
 * template at send time, and the LWC composer's preview catches typos
 * before enqueue. Decoupling keeps this service pure-orchestration.
 */
public with sharing class ULBC_EmailSendService {

    /** Settings for what gets included. Mirrors the LWC composer's filter UI. */
    public class FilterSpec {
        public Set<String> campaignMemberStatuses;
        public Boolean requireTrustId = false;

        public FilterSpec() {}

        public ULBC_EmailRecipientResolver.RecipientFilter toResolverFilter() {
            ULBC_EmailRecipientResolver.RecipientFilter f =
                new ULBC_EmailRecipientResolver.RecipientFilter();
            f.campaignMemberStatuses = this.campaignMemberStatuses;
            f.requireTrustId = (this.requireTrustId == true);
            return f;
        }
    }

    /** Result of a successful enqueue. */
    public class EnqueueResult {
        public Id sendId;
        public Integer eligibleCount;
        public Integer suppressedCount;
        public Integer totalRecipientRows;
        /** When non-null, the Queueable was scheduled and this is its job Id. */
        public Id queueableJobId;
    }

    public class HandledException extends Exception {}

    /**
     * Build the Send + Recipients and enqueue the Queueable.
     *
     * @param campaignId       required
     * @param templateDevName  EmailTemplate.DeveloperName, required
     * @param subject          subject snapshot, optional (can be null)
     * @param filter           null = default
     * @param initiatedBy      User Id stamped on the Send; defaults to running user
     */
    public static EnqueueResult enqueue(Id campaignId, String templateDevName,
                                         String subject, FilterSpec filter, Id initiatedBy) {
        if (campaignId == null) {
            throw new HandledException('campaignId is required');
        }
        if (String.isBlank(templateDevName)) {
            throw new HandledException('templateDevName is required');
        }

        ULBC_EmailRecipientResolver.RecipientFilter rf =
            (filter == null) ? new FilterSpec().toResolverFilter() : filter.toResolverFilter();

        List<ULBC_EmailRecipientResolver.Resolved> resolved =
            ULBC_EmailRecipientResolver.resolve(campaignId, rf);

        Integer eligible = 0;
        for (ULBC_EmailRecipientResolver.Resolved r : resolved) {
            if (r.isEligible()) eligible++;
        }
        if (eligible == 0) {
            throw new HandledException(
                'No eligible recipients for this Campaign + filter combination. ' +
                resolved.size() + ' members were considered; all were suppressed or excluded.');
        }

        ULBC_Email_Send__c send = new ULBC_Email_Send__c(
            ULBC_Campaign__c = campaignId,
            ULBC_Email_Template_DevName__c = templateDevName,
            ULBC_Subject__c = subject,
            ULBC_Status__c = 'Draft',
            ULBC_Recipient_Count__c = resolved.size(),
            ULBC_Filter_Snapshot__c = JSON.serialize(filter),
            ULBC_Initiated_By__c = (initiatedBy == null) ? UserInfo.getUserId() : initiatedBy
        );
        insert send;

        List<ULBC_Email_Send_Recipient__c> rows = new List<ULBC_Email_Send_Recipient__c>();
        List<String> tokens = ULBC_EmailTokenService.generate(resolved.size());
        Integer i = 0;
        for (ULBC_EmailRecipientResolver.Resolved r : resolved) {
            rows.add(new ULBC_Email_Send_Recipient__c(
                ULBC_Email_Send__c = send.Id,
                ULBC_Contact__c = r.contact.Id,
                ULBC_Trust_ID__c = r.contact.ULBC_Trust_ID__c,
                ULBC_Email_Address__c = r.email,
                ULBC_Token__c = tokens[i++],
                ULBC_Status__c = (r.suppressionReason == null) ? 'Pending' : 'Suppressed',
                ULBC_Suppression_Reason__c = r.suppressionReason,
                ULBC_Open_Count__c = 0,
                ULBC_Click_Count__c = 0
            ));
        }
        insert rows;

        send.ULBC_Status__c = 'Queued';
        update send;

        EnqueueResult result = new EnqueueResult();
        result.sendId = send.Id;
        result.eligibleCount = eligible;
        result.suppressedCount = resolved.size() - eligible;
        result.totalRecipientRows = resolved.size();
        result.queueableJobId = System.enqueueJob(new ULBC_EmailSendQueueable(send.Id));
        return result;
    }
}
