trigger ULBC_ContactTrigger on Contact (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            ULBC_ContactTriggerHandler.handleGoneAway(Trigger.new, Trigger.oldMap);
        }
    }
}
