trigger ULBC_ContactTrigger on Contact (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ULBC_ContactTriggerHandler.assignTrustId(Trigger.new);
        }
        if (Trigger.isInsert || Trigger.isUpdate) {
            ULBC_ContactTriggerHandler.handleGoneAway(Trigger.new, Trigger.oldMap);
        }
    }
}
