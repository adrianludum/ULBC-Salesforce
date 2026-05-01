/**
 * ULBC_ContactTriggerHandler
 * Phase 2A: Gone Away → HasOptedOutOfEmail (one-way)
 * Phase 3C: Auto-assign Trust ID on insert (ULBC-XXXX sequential)
 */
// without sharing: assignTrustId queries the global max ULBC_Trust_ID__c
// to compute the next sequential ID. Guest users (used by the Stripe
// webhook to insert Contacts) cannot see existing Contacts under
// private-OWD orgs, which made the query return empty and caused
// "ULBC-0001" to be reassigned to every new Contact.
public without sharing class ULBC_ContactTriggerHandler {

    public static void handleGoneAway(List<Contact> newContacts, Map<Id, Contact> oldMap) {
        for (Contact c : newContacts) {
            Boolean isGoneAway = c.ULBC_Gone_Away__c == true;
            if (oldMap == null) {
                // INSERT: only force opt-out when Gone_Away is true. Previously
                // this branch always overwrote HasOptedOutOfEmail to mirror
                // Gone_Away — silently clobbering any opt-out preference set
                // by the inserting source (Stripe webhook, admin entry, data
                // import). That broke per-record consent for the new mass
                // email system. Now: only mirror Gone_Away when it's set.
                if (isGoneAway) {
                    c.HasOptedOutOfEmail = true;
                }
            } else {
                // UPDATE: bidirectional sync only when Gone_Away actually
                // changes. Setting Gone_Away=true forces opt-out on; clearing
                // Gone_Away clears opt-out (long-standing behavior — see
                // ULBC_GoneAwayTrigger_Test.test_update_clearGoneAway_clearsOptOut).
                Boolean wasGoneAway = oldMap.containsKey(c.Id)
                    && oldMap.get(c.Id).ULBC_Gone_Away__c == true;
                if (isGoneAway != wasGoneAway) {
                    c.HasOptedOutOfEmail = isGoneAway;
                }
            }
        }
    }

    public static void assignTrustId(List<Contact> newContacts) {
        List<Contact> needsId = new List<Contact>();
        for (Contact c : newContacts) {
            if (String.isBlank(c.ULBC_Trust_ID__c)) {
                needsId.add(c);
            }
        }
        if (needsId.isEmpty()) {
            return;
        }

        Integer maxNum = 0;
        List<Contact> existing = [
            SELECT ULBC_Trust_ID__c FROM Contact
            WHERE ULBC_Trust_ID__c LIKE 'ULBC-%'
            ORDER BY ULBC_Trust_ID__c DESC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            String lastId = existing[0].ULBC_Trust_ID__c;
            String numPart = lastId.substringAfter('ULBC-');
            if (numPart.isNumeric()) {
                maxNum = Integer.valueOf(numPart);
            }
        }

        for (Contact c : needsId) {
            maxNum++;
            c.ULBC_Trust_ID__c = 'ULBC-' + String.valueOf(maxNum).leftPad(4, '0');
        }
    }
}
