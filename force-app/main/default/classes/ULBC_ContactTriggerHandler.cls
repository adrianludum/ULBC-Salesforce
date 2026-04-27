/**
 * ULBC_ContactTriggerHandler
 * Phase 2A: Gone Away → HasOptedOutOfEmail (one-way)
 * Phase 3C: Auto-assign TrustID on insert (ULBC-XXXX sequential)
 */
public with sharing class ULBC_ContactTriggerHandler {

    public static void handleGoneAway(List<Contact> newContacts, Map<Id, Contact> oldMap) {
        for (Contact c : newContacts) {
            Boolean wasGoneAway = (oldMap != null && oldMap.containsKey(c.Id))
                ? oldMap.get(c.Id).ULBC_Gone_Away__c
                : false;
            Boolean isGoneAway = c.ULBC_Gone_Away__c == true;
            if (isGoneAway != wasGoneAway || oldMap == null) {
                c.HasOptedOutOfEmail = isGoneAway ? true : false;
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
