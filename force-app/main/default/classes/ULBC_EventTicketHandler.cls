/**
 * ULBC_EventTicketHandler
 *
 * Handles Stripe checkout.session.completed events with metadata.intent = "event_ticket".
 * Finds or creates the buyer Contact (Decision 5.8), creates a CampaignMember on
 * the named Event Campaign with Status="Purchased", and a Closed Won Opportunity
 * for the ticket revenue with the Stripe Payment ID stamped on the CampaignMember.
 *
 * Decision 5.9 metadata contract (event_ticket subset):
 *   - campaign_id           : Salesforce Campaign 18-char Id (REQUIRED)
 *   - ulbc_trust_id         : ULBC-XXXX (optional — primary match key)
 *
 * Phase 5A.3.
 */
// without sharing: invoked only via signature-verified Stripe webhook
// dispatch (security boundary already enforced). Guest user sharing
// would block the CampaignMember and Opportunity inserts.
public without sharing class ULBC_EventTicketHandler {

    private static final String CM_STATUS_PURCHASED = 'Purchased';

    public class Result {
        public Boolean success;
        public String message;
        public Id contactId;
        public Id opportunityId;
        public Id campaignMemberId;
    }

    public class HandlerException extends Exception {}

    public static Result handle(Map<String, Object> session) {
        Result r = new Result();

        Map<String, Object> meta = (Map<String, Object>) session.get('metadata');
        Map<String, Object> custDetails = (Map<String, Object>) session.get('customer_details');

        String campaignIdRaw = readMeta(meta, 'campaign_id');
        if (String.isBlank(campaignIdRaw)) {
            throw new HandlerException(
                'metadata.campaign_id is required for intent=event_ticket');
        }

        // Validate Campaign exists
        List<Campaign> camps = [SELECT Id, Name FROM Campaign WHERE Id = :campaignIdRaw LIMIT 1];
        if (camps.isEmpty()) {
            throw new HandlerException(
                'metadata.campaign_id "' + campaignIdRaw + '" did not match any Campaign');
        }
        Campaign camp = camps[0];

        String email = (custDetails != null) ? (String) custDetails.get('email') : null;
        String fullName = (custDetails != null) ? (String) custDetails.get('name') : null;
        String stripeCustomerId = (String) session.get('customer');
        String paymentIntentId = (String) session.get('payment_intent');
        String sessionId = (String) session.get('id');

        Decimal amount = parseAmount(session);
        String currencyCode = (String) session.get('currency');

        String trustId = readMeta(meta, 'ulbc_trust_id');

        // 1. Find or create Contact
        ULBC_ContactMatcher.Inputs inputs = new ULBC_ContactMatcher.Inputs();
        inputs.trustId = trustId;
        inputs.stripeCustomerId = stripeCustomerId;
        inputs.email = email;
        inputs.name = fullName;
        inputs.acquisitionChannel = 'Stripe Event Registration';
        ULBC_ContactMatcher.MatchResult mr = ULBC_ContactMatcher.findOrCreate(inputs);

        ULBC_ContactMatcher.linkStripeCustomerId(mr.contact, stripeCustomerId);

        // 2. Ensure the Purchased status exists on this Campaign
        ensurePurchasedStatus(camp.Id);

        // 3. Create or update CampaignMember
        Id cmId = upsertCampaignMember(mr.contact.Id, camp.Id, paymentIntentId);

        // 4. Create the Opportunity for ticket revenue
        String displayName = (String.isNotBlank(fullName) ? fullName : 'Anonymous');
        Opportunity opp = new Opportunity(
            AccountId = mr.contact.AccountId,
            npsp__Primary_Contact__c = mr.contact.Id,
            Name = displayName + ' — ' + camp.Name + ' Ticket',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = amount,
            CampaignId = camp.Id,
            ULBC_Gift_Type__c = 'Event Ticket',
            ULBC_Gift_Source__c = 'Event',
            ULBC_Stripe_Payment_ID__c = paymentIntentId,
            Description = 'Stripe Session: ' + sessionId +
                          ' | Currency: ' + (currencyCode != null ? currencyCode.toUpperCase() : 'GBP')
        );
        insert opp;

        r.success = true;
        r.contactId = mr.contact.Id;
        r.opportunityId = opp.Id;
        r.campaignMemberId = cmId;
        r.message = 'Ticket £' + amount + ' for ' + camp.Name + ' recorded. ' + mr.note;
        return r;
    }

    // ── helpers ──────────────────────────────────────────────────────

    private static String readMeta(Map<String, Object> meta, String key) {
        if (meta == null) return null;
        Object v = meta.get(key);
        return (v == null) ? null : String.valueOf(v);
    }

    private static Decimal parseAmount(Map<String, Object> session) {
        Object total = session.get('amount_total');
        if (total == null) return 0;
        Decimal pence = Decimal.valueOf(String.valueOf(total));
        return pence / 100;
    }

    private static void ensurePurchasedStatus(Id campaignId) {
        List<CampaignMemberStatus> existing = [
            SELECT Id FROM CampaignMemberStatus
            WHERE CampaignId = :campaignId AND Label = :CM_STATUS_PURCHASED
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            try {
                insert new CampaignMemberStatus(
                    CampaignId = campaignId,
                    Label = CM_STATUS_PURCHASED,
                    SortOrder = 4,
                    IsDefault = false,
                    HasResponded = true
                );
            } catch (DmlException ignore) {
                // Race: another transaction created it. Safe to ignore.
            }
        }
    }

    private static Id upsertCampaignMember(Id contactId, Id campaignId, String paymentIntentId) {
        List<CampaignMember> existing = [
            SELECT Id FROM CampaignMember
            WHERE ContactId = :contactId AND CampaignId = :campaignId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            update new CampaignMember(
                Id = existing[0].Id,
                Status = CM_STATUS_PURCHASED,
                ULBC_Stripe_Payment_ID__c = paymentIntentId
            );
            return existing[0].Id;
        }
        CampaignMember cm = new CampaignMember(
            CampaignId = campaignId,
            ContactId = contactId,
            Status = CM_STATUS_PURCHASED,
            ULBC_Stripe_Payment_ID__c = paymentIntentId
        );
        insert cm;
        return cm.Id;
    }
}
