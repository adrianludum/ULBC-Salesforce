/**
 * ULBC_DonationHandler
 *
 * Handles Stripe checkout.session.completed events with metadata.intent = "donation".
 * Creates a Closed Won Opportunity, finds or creates the donor Contact
 * (per Decision 5.8), and captures Gift Aid declaration data per Decision 2.10.
 *
 * Decision 5.9 metadata contract (donation subset):
 *   - fund                  : Salesforce Campaign 18-char Id (optional in v1 — slug
 *                             support deferred; if missing or invalid, Opportunity
 *                             is created without a Campaign link)
 *   - ulbc_trust_id         : ULBC-XXXX (optional — primary match key)
 *   - gift_aid              : "true" | "false"
 *   - gift_aid_postcode     : postcode string (when gift_aid="true")
 *   - gift_type             : "One-Off" | "Recurring"
 *
 * Phase 5A.3.
 */
public with sharing class ULBC_DonationHandler {

    public class Result {
        public Boolean success;
        public String message;
        public Id contactId;
        public Id opportunityId;
    }

    public static Result handle(Map<String, Object> session) {
        Result r = new Result();

        Map<String, Object> meta = (Map<String, Object>) session.get('metadata');
        Map<String, Object> custDetails = (Map<String, Object>) session.get('customer_details');

        String email = (custDetails != null) ? (String) custDetails.get('email') : null;
        String fullName = (custDetails != null) ? (String) custDetails.get('name') : null;
        String stripeCustomerId = (String) session.get('customer');
        String paymentIntentId = (String) session.get('payment_intent');
        String sessionId = (String) session.get('id');

        Decimal amount = parseAmount(session);
        String currencyCode = (String) session.get('currency');

        String trustId = readMeta(meta, 'ulbc_trust_id');
        String fundCampaignId = readMeta(meta, 'fund');
        String giftType = readMeta(meta, 'gift_type');
        Boolean giftAid = 'true'.equalsIgnoreCase(readMeta(meta, 'gift_aid'));
        String giftAidPostcode = readMeta(meta, 'gift_aid_postcode');

        // 1. Find or create Contact
        ULBC_ContactMatcher.Inputs inputs = new ULBC_ContactMatcher.Inputs();
        inputs.trustId = trustId;
        inputs.stripeCustomerId = stripeCustomerId;
        inputs.email = email;
        inputs.name = fullName;
        inputs.acquisitionChannel = 'Stripe Donation';
        ULBC_ContactMatcher.MatchResult mr = ULBC_ContactMatcher.findOrCreate(inputs);

        // 2. Link Stripe Customer ID if new for this Contact
        ULBC_ContactMatcher.linkStripeCustomerId(mr.contact, stripeCustomerId);

        // 3. Update Gift Aid declaration on Contact if newly declared
        Boolean newDeclaration = false;
        if (giftAid) {
            Contact existing = [
                SELECT Id, ULBC_Gift_Aid_Declaration_Date__c, ULBC_Gift_Aid_Eligible__c
                FROM Contact WHERE Id = :mr.contact.Id LIMIT 1
            ];
            if (existing.ULBC_Gift_Aid_Declaration_Date__c == null) {
                update new Contact(
                    Id = mr.contact.Id,
                    ULBC_Gift_Aid_Eligible__c = true,
                    ULBC_Gift_Aid_Declaration_Date__c = Date.today(),
                    ULBC_Gift_Aid_Declaration_Source__c = 'Online',
                    ULBC_Gift_Aid_Postcode__c = giftAidPostcode,
                    ULBC_Gift_Aid_Valid_From__c = Date.today()
                );
                newDeclaration = true;
            }
        }

        // 4. Resolve fund Campaign (validate it exists)
        Id campaignId = null;
        if (String.isNotBlank(fundCampaignId)) {
            List<Campaign> camps = [
                SELECT Id FROM Campaign WHERE Id = :fundCampaignId LIMIT 1
            ];
            if (!camps.isEmpty()) campaignId = camps[0].Id;
        }

        // 5. Create Opportunity
        String giftTypePicklist = mapGiftType(giftType);
        String displayName = (String.isNotBlank(fullName) ? fullName : 'Anonymous');
        Opportunity opp = new Opportunity(
            AccountId = mr.contact.AccountId,
            npsp__Primary_Contact__c = mr.contact.Id,
            Name = displayName + ' — Donation',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = amount,
            CampaignId = campaignId,
            ULBC_Gift_Type__c = giftTypePicklist,
            ULBC_Gift_Source__c = 'Digital',
            ULBC_Stripe_Payment_ID__c = paymentIntentId,
            ULBC_Gift_Aid_Eligible__c = giftAid,
            Description = 'Stripe Session: ' + sessionId +
                          ' | Currency: ' + (currencyCode != null ? currencyCode.toUpperCase() : 'GBP') +
                          (campaignId == null && String.isNotBlank(fundCampaignId)
                              ? ' | NOTE: fund="' + fundCampaignId + '" not found, Campaign left blank'
                              : '')
        );
        insert opp;

        r.success = true;
        r.contactId = mr.contact.Id;
        r.opportunityId = opp.Id;
        r.message = 'Donation £' + amount + ' recorded. ' + mr.note +
                    (newDeclaration ? '. Gift Aid declaration captured.' : '') +
                    (giftAid ? ' Gift Aid eligible.' : '');
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

    /**
     * Decision 5.9 contract uses "One-Off" / "Recurring".
     * ULBC_Gift_Type__c picklist uses "One-off" / "Regular".
     * Map the contract value to the picklist value; default One-off.
     */
    private static String mapGiftType(String contractValue) {
        if (String.isBlank(contractValue)) return 'One-off';
        if ('Recurring'.equalsIgnoreCase(contractValue)) return 'Regular';
        return 'One-off';
    }
}
