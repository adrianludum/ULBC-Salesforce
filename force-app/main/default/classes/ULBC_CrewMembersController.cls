public with sharing class ULBC_CrewMembersController {

    public class CrewMember {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Decimal position;
        @AuraEnabled public String college;
        @AuraEnabled public String yearGroup;
    }

    @AuraEnabled(cacheable=true)
    public static List<CrewMember> getCrewMembers(String crewCode) {
        if (String.isBlank(crewCode)) {
            return new List<CrewMember>();
        }

        List<ULBC_Crew_History__c> records = [
            SELECT Id, ULBC_Contact__c, ULBC_Contact__r.FirstName,
                   ULBC_Contact__r.LastName, ULBC_Contact__r.ULBC_Year_Group__c,
                   ULBC_Rowing_Position__c
            FROM ULBC_Crew_History__c
            WHERE ULBC_Crew_Code__c = :crewCode
            ORDER BY ULBC_Rowing_Position__c ASC NULLS LAST
        ];

        // Collect contact IDs for education lookup
        Set<Id> contactIds = new Set<Id>();
        for (ULBC_Crew_History__c ch : records) {
            contactIds.add(ch.ULBC_Contact__c);
        }

        // Get college from Education History (first record per contact)
        Map<Id, String> collegeMap = new Map<Id, String>();
        if (!contactIds.isEmpty()) {
            for (ULBC_Education_History__c eh : [
                SELECT ULBC_Contact__c, ULBC_Institution__c
                FROM ULBC_Education_History__c
                WHERE ULBC_Contact__c IN :contactIds
                AND ULBC_Institution__c != null
                ORDER BY ULBC_Start_Year__c DESC NULLS LAST
            ]) {
                if (!collegeMap.containsKey(eh.ULBC_Contact__c)) {
                    collegeMap.put(eh.ULBC_Contact__c, eh.ULBC_Institution__c);
                }
            }
        }

        List<CrewMember> members = new List<CrewMember>();
        for (ULBC_Crew_History__c ch : records) {
            CrewMember m = new CrewMember();
            m.recordId = ch.Id;
            m.contactId = ch.ULBC_Contact__c;
            m.firstName = ch.ULBC_Contact__r.FirstName;
            m.lastName = ch.ULBC_Contact__r.LastName;
            m.position = ch.ULBC_Rowing_Position__c;
            m.yearGroup = ch.ULBC_Contact__r.ULBC_Year_Group__c;
            m.college = collegeMap.get(ch.ULBC_Contact__c);
            members.add(m);
        }
        return members;
    }

    @AuraEnabled(cacheable=true)
    public static String getCrewCode(Id recordId) {
        String objType = recordId.getSObjectType().getDescribe().getName();
        if (objType == 'ULBC_Crew_History__c') {
            List<ULBC_Crew_History__c> recs = [
                SELECT ULBC_Crew_Code__c FROM ULBC_Crew_History__c WHERE Id = :recordId LIMIT 1
            ];
            return recs.isEmpty() ? null : recs[0].ULBC_Crew_Code__c;
        } else if (objType == 'Crews__c') {
            List<SObject> recs = Database.query(
                'SELECT Name FROM Crews__c WHERE Id = :recordId LIMIT 1'
            );
            return recs.isEmpty() ? null : (String) recs[0].get('Name');
        }
        return null;
    }
}
