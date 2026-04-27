@IsTest
private class ULBC_CrewMembersController_Test {

    @TestSetup
    static void setup() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 4; i++) {
            contacts.add(new Contact(
                FirstName = 'Rower' + i,
                LastName = 'Test',
                ULBC_Trust_ID__c = 'ULBC-CREW-' + i,
                ULBC_Year_Group__c = '202' + i
            ));
        }
        insert contacts;

        // Add education for first contact
        insert new ULBC_Education_History__c(
            ULBC_Contact__c = contacts[0].Id,
            ULBC_Institution__c = 'St Johns',
            ULBC_Start_Year__c = 2020
        );

        List<ULBC_Crew_History__c> crews = new List<ULBC_Crew_History__c>();
        for (Integer i = 0; i < 3; i++) {
            crews.add(new ULBC_Crew_History__c(
                ULBC_Contact__c = contacts[i].Id,
                ULBC_Crew_Code__c = '23Tow',
                ULBC_Rowing_Position__c = i + 1,
                ULBC_Year__c = 2023,
                ULBC_Regatta__c = 'HRR'
            ));
        }
        crews.add(new ULBC_Crew_History__c(
            ULBC_Contact__c = contacts[3].Id,
            ULBC_Crew_Code__c = '23Diff',
            ULBC_Rowing_Position__c = 1
        ));
        insert crews;
    }

    @IsTest
    static void test_getCrewMembers_returnsMembersWithDetails() {
        List<ULBC_CrewMembersController.CrewMember> result =
            ULBC_CrewMembersController.getCrewMembers('23Tow');
        System.assertEquals(3, result.size(), 'Should return 3 crew members');
        System.assertEquals('Rower0', result[0].firstName, 'First member by position');
        System.assertEquals('St Johns', result[0].college, 'College should be populated');
        System.assertEquals('2020', result[0].yearGroup, 'Year group should be populated');
    }

    @IsTest
    static void test_getCrewMembers_returnsEmptyForBlank() {
        List<ULBC_CrewMembersController.CrewMember> result =
            ULBC_CrewMembersController.getCrewMembers('');
        System.assertEquals(0, result.size(), 'Blank code should return empty list');
    }

    @IsTest
    static void test_getCrewMembers_returnsEmptyForNull() {
        List<ULBC_CrewMembersController.CrewMember> result =
            ULBC_CrewMembersController.getCrewMembers(null);
        System.assertEquals(0, result.size(), 'Null code should return empty list');
    }

    @IsTest
    static void test_getCrewMembers_orderedByPosition() {
        List<ULBC_CrewMembersController.CrewMember> result =
            ULBC_CrewMembersController.getCrewMembers('23Tow');
        for (Integer i = 0; i < result.size() - 1; i++) {
            System.assert(
                result[i].position <= result[i + 1].position,
                'Results should be ordered by seat position'
            );
        }
    }

    @IsTest
    static void test_getCrewCode_crewHistory() {
        ULBC_Crew_History__c ch = [
            SELECT Id FROM ULBC_Crew_History__c WHERE ULBC_Crew_Code__c = '23Tow' LIMIT 1
        ];
        String code = ULBC_CrewMembersController.getCrewCode(ch.Id);
        System.assertEquals('23Tow', code, 'Should return crew code from Crew History');
    }
}
