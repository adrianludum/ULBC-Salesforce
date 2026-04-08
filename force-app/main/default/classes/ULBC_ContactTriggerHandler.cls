/**
 * ULBC_ContactTriggerHandler
 * Phase 2A: Gone Away → HasOptedOutOfEmail (one-way)
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
}
