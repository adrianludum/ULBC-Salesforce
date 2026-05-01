/**
 * ULBC_EmailRecipientResolver
 *
 * Given a Campaign + filter spec, returns one Resolved row per
 * eligible-or-suppressed Contact that the Send should materialise.
 *
 * Suppression vs filter:
 *   - "Filter" rules (CampaignMember status mismatch, missing Trust ID
 *     when requireTrustId=true) drop a Contact entirely — no Recipient
 *     row is created.
 *   - "Suppression" rules (missing email, opted out, bounced, duplicate
 *     email) leave the Contact in the result set with a non-null
 *     suppressionReason — a Recipient row is created with Status=Suppressed
 *     so the audit trail shows everyone considered.
 *
 * Pure logic (one SOQL). No DML. No Messaging API.
 */
public with sharing class ULBC_EmailRecipientResolver {

    /** One Contact resolved against the filter. */
    public class Resolved {
        public Contact contact;
        public String email;
        public String campaignMemberStatus;
        /** null when eligible; one of OptedOut / Bounced / MissingEmail / Duplicate when suppressed. */
        public String suppressionReason;

        public Resolved(Contact c, String email, String status, String suppression) {
            this.contact = c;
            this.email = email;
            this.campaignMemberStatus = status;
            this.suppressionReason = suppression;
        }

        public Boolean isEligible() { return suppressionReason == null; }
    }

    /** Filter spec. All fields optional; nulls mean "no filter". */
    public class RecipientFilter {
        /** When non-null+non-empty, only CampaignMembers with one of these Statuses are kept. */
        public Set<String> campaignMemberStatuses;
        /** When true, Contacts with blank ULBC_Trust_ID__c are filtered out entirely. */
        public Boolean requireTrustId = false;

        public RecipientFilter() {}
    }

    /**
     * Resolve recipients for a Campaign.
     *
     * @param campaignId required
     * @param filter     null acts as default filter (all members, no Trust ID requirement)
     */
    public static List<Resolved> resolve(Id campaignId, RecipientFilter filter) {
        if (campaignId == null) {
            throw new IllegalArgumentException('campaignId is required');
        }
        RecipientFilter f = (filter == null) ? new RecipientFilter() : filter;

        List<CampaignMember> members = [
            SELECT Status,
                   ContactId,
                   Contact.Id,
                   Contact.LastName,
                   Contact.Email,
                   Contact.HasOptedOutOfEmail,
                   Contact.EmailBouncedDate,
                   Contact.ULBC_Trust_ID__c
            FROM CampaignMember
            WHERE CampaignId = :campaignId
              AND ContactId != null
            ORDER BY Contact.CreatedDate ASC
        ];

        List<Resolved> out = new List<Resolved>();
        Set<String> emailsSeen = new Set<String>();

        for (CampaignMember cm : members) {
            Contact c = cm.Contact;
            if (c == null) continue;

            // Filter rules — drop entirely
            if (f.campaignMemberStatuses != null && !f.campaignMemberStatuses.isEmpty()
                    && !f.campaignMemberStatuses.contains(cm.Status)) {
                continue;
            }
            if (f.requireTrustId == true && String.isBlank(c.ULBC_Trust_ID__c)) {
                continue;
            }

            // Suppression rules — keep with reason
            String email = (c.Email == null) ? null : c.Email.trim().toLowerCase();

            if (String.isBlank(email)) {
                out.add(new Resolved(c, c.Email, cm.Status, 'MissingEmail'));
                continue;
            }
            if (c.HasOptedOutOfEmail == true) {
                out.add(new Resolved(c, c.Email, cm.Status, 'OptedOut'));
                continue;
            }
            if (c.EmailBouncedDate != null) {
                out.add(new Resolved(c, c.Email, cm.Status, 'Bounced'));
                continue;
            }
            if (emailsSeen.contains(email)) {
                out.add(new Resolved(c, c.Email, cm.Status, 'Duplicate'));
                continue;
            }
            emailsSeen.add(email);
            out.add(new Resolved(c, c.Email, cm.Status, null));
        }
        return out;
    }

    public class IllegalArgumentException extends Exception {}
}
