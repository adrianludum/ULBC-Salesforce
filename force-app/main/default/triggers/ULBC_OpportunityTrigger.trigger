/**
 * ULBC_OpportunityTrigger
 * Fires donor tier recalculation after any Opportunity change.
 */
trigger ULBC_OpportunityTrigger on Opportunity (
    after insert, after update, after delete, after undelete
) {
    Set<Id> contactIds = new Set<Id>();
    List<Opportunity> opps = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (Opportunity opp : opps) {
        if (opp.npe01__Contact_Id_for_Role__c != null) {
            contactIds.add(opp.npe01__Contact_Id_for_Role__c);
        }
    }
    if (Trigger.isUpdate) {
        for (Opportunity opp : Trigger.old) {
            if (opp.npe01__Contact_Id_for_Role__c != null) {
                contactIds.add(opp.npe01__Contact_Id_for_Role__c);
            }
        }
    }
    if (!contactIds.isEmpty()) {
        ULBC_DonorTierEngine.recalculate(contactIds);
    }
}
