/**
 * ULBC_ContactMatcher
 *
 * Implements the Stripe-payment → Salesforce Contact match priority
 * defined in Decision 5.8:
 *   1. metadata.ulbc_trust_id        (TrustID from personalised link)
 *   2. Stripe Customer ID match      (Contact.ULBC_Stripe_Customer_ID__c)
 *   3. Email match                   (Contact.Email or ULBC_Secondary_Email__c)
 *   4. Create new Contact            (Acquisition Channel from caller)
 *
 * Phase 5A.3.
 */
// without sharing: invoked only via signature-verified Stripe webhook
// dispatch. Guest users (the Site running user) cannot see records they
// just created or other Contacts in private-OWD orgs, which would block
// the post-insert re-query and the match-priority lookups.
public without sharing class ULBC_ContactMatcher {

    public class MatchResult {
        public Contact contact;
        /** Which step matched (1-4). 4 = newly created. */
        public Integer matchedBy;
        /** Human-readable note for the webhook log. */
        public String note;

        public MatchResult(Contact contact, Integer matchedBy, String note) {
            this.contact = contact;
            this.matchedBy = matchedBy;
            this.note = note;
        }
    }

    public class Inputs {
        public String trustId;
        public String stripeCustomerId;
        public String email;
        public String name;            // "Firstname Lastname" — used only when creating
        public String acquisitionChannel; // picklist value for new Contacts
    }

    /**
     * Find an existing Contact via the Decision 5.8 priority order, or
     * create one when no match is found. Always returns a persisted
     * Contact with Id populated.
     */
    public static MatchResult findOrCreate(Inputs inputs) {
        // 1. TrustID
        if (String.isNotBlank(inputs.trustId)) {
            List<Contact> byTrust = [
                SELECT Id, AccountId, FirstName, LastName, Email,
                       ULBC_Trust_ID__c, ULBC_Stripe_Customer_ID__c
                FROM Contact
                WHERE ULBC_Trust_ID__c = :inputs.trustId
                LIMIT 1
            ];
            if (!byTrust.isEmpty()) {
                return new MatchResult(byTrust[0], 1,
                    'Matched on TrustID ' + inputs.trustId);
            }
        }

        // 2. Stripe Customer ID
        if (String.isNotBlank(inputs.stripeCustomerId)) {
            List<Contact> byCust = [
                SELECT Id, AccountId, FirstName, LastName, Email,
                       ULBC_Trust_ID__c, ULBC_Stripe_Customer_ID__c
                FROM Contact
                WHERE ULBC_Stripe_Customer_ID__c = :inputs.stripeCustomerId
                LIMIT 1
            ];
            if (!byCust.isEmpty()) {
                return new MatchResult(byCust[0], 2,
                    'Matched on Stripe Customer ID ' + inputs.stripeCustomerId);
            }
        }

        // 3. Email — primary or secondary
        if (String.isNotBlank(inputs.email)) {
            List<Contact> byEmail = [
                SELECT Id, AccountId, FirstName, LastName, Email,
                       ULBC_Trust_ID__c, ULBC_Stripe_Customer_ID__c
                FROM Contact
                WHERE Email = :inputs.email OR ULBC_Secondary_Email__c = :inputs.email
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!byEmail.isEmpty()) {
                return new MatchResult(byEmail[0], 3,
                    'Matched on email ' + inputs.email);
            }
        }

        // 4. Create.
        String firstName = '';
        String lastName = (String.isNotBlank(inputs.email) ? inputs.email : 'Unknown');
        if (String.isNotBlank(inputs.name)) {
            String trimmed = inputs.name.trim();
            Integer space = trimmed.lastIndexOf(' ');
            if (space > 0) {
                firstName = trimmed.substring(0, space).trim();
                lastName = trimmed.substring(space + 1).trim();
            } else {
                lastName = trimmed;
            }
        }

        Contact c = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = inputs.email,
            ULBC_Acquisition_Channel__c = inputs.acquisitionChannel,
            ULBC_GDPR_Legal_Basis__c = 'Consent',
            ULBC_Primary_Contact_Type__c = 'Other'
        );
        insert c;

        // Re-query so AccountId (set by NPSP household trigger) is populated.
        return new MatchResult(
            [SELECT Id, AccountId, FirstName, LastName, Email,
                    ULBC_Trust_ID__c, ULBC_Stripe_Customer_ID__c
             FROM Contact WHERE Id = :c.Id],
            4,
            'Created new Contact (Acquisition Channel: ' + inputs.acquisitionChannel + ')'
        );
    }

    /**
     * Update Contact.ULBC_Stripe_Customer_ID__c when Stripe sends one and
     * the Contact has no existing value. No-op if Contact already has one
     * (we don't overwrite — could indicate a different Stripe customer
     * was previously linked, which is worth investigating manually).
     */
    public static Boolean linkStripeCustomerId(Contact c, String stripeCustomerId) {
        if (c == null || String.isBlank(stripeCustomerId)) return false;
        if (String.isNotBlank(c.ULBC_Stripe_Customer_ID__c)) return false;

        update new Contact(Id = c.Id, ULBC_Stripe_Customer_ID__c = stripeCustomerId);
        return true;
    }
}
