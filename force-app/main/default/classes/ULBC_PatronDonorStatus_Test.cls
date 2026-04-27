/**
 * ULBC_PatronDonorStatus_Test
 *
 * Tests for:
 *   - ULBC_Patron_Status__c picklist field on Contact
 *   - ULBC_Donor_Status__c formula field on Contact
 *   - ULBC_Legacy_Membership__c text field on Contact
 *
 * Run with: sf apex run test --class-names ULBC_PatronDonorStatus_Test --code-coverage
 */
@IsTest
private class ULBC_PatronDonorStatus_Test {

    @IsTest
    static void testPatronStatusDefaultsToNonPatron() {
        Contact c = new Contact(FirstName = 'Test', LastName = 'Default');
        insert c;

        Contact result = [SELECT ULBC_Patron_Status__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Non-Patron', result.ULBC_Patron_Status__c,
            'New contacts should default to Non-Patron');
    }

    @IsTest
    static void testPatronStatusPicklistValues() {
        List<String> expected = new List<String>{
            'Non-Patron', 'Patron', 'Honorary Patron', 'Lapsed Patron'
        };
        List<Contact> contacts = new List<Contact>();
        for (String status : expected) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = status,
                ULBC_Patron_Status__c = status
            ));
        }
        insert contacts;

        List<Contact> results = [
            SELECT LastName, ULBC_Patron_Status__c FROM Contact
            WHERE Id IN :contacts
        ];
        // Build a map of LastName → status, since LastName was set to the status value.
        Map<String, String> actualByLastName = new Map<String, String>();
        for (Contact result : results) {
            actualByLastName.put(result.LastName, result.ULBC_Patron_Status__c);
        }
        for (String status : expected) {
            System.assertEquals(status, actualByLastName.get(status),
                'Patron Status should accept: ' + status);
        }
    }

    @IsTest
    static void testDonorStatusFormula_NonDonor() {
        Contact c = new Contact(
            FirstName = 'Never', LastName = 'Gave',
            ULBC_Is_Donor__c = false
        );
        insert c;

        Contact result = [SELECT ULBC_Donor_Status__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Non-Donor', result.ULBC_Donor_Status__c,
            'Non-donor should show Non-Donor status');
    }

    @IsTest
    static void testDonorStatusFormula_CurrentDonor() {
        Contact c = new Contact(
            FirstName = 'Active', LastName = 'Giver',
            ULBC_Is_Donor__c = true,
            ULBC_Donor_Tier__c = 'Patron'
        );
        insert c;

        Contact result = [SELECT ULBC_Donor_Status__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Current Donor', result.ULBC_Donor_Status__c,
            'Donor with Patron tier should show Current Donor');
    }

    @IsTest
    static void testDonorStatusFormula_CurrentDonorStandard() {
        Contact c = new Contact(
            FirstName = 'Standard', LastName = 'Giver',
            ULBC_Is_Donor__c = true,
            ULBC_Donor_Tier__c = 'Standard'
        );
        insert c;

        Contact result = [SELECT ULBC_Donor_Status__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Current Donor', result.ULBC_Donor_Status__c,
            'Donor with Standard tier should show Current Donor');
    }

    @IsTest
    static void testDonorStatusFormula_CurrentDonorMajor() {
        Contact c = new Contact(
            FirstName = 'Major', LastName = 'Giver',
            ULBC_Is_Donor__c = true,
            ULBC_Donor_Tier__c = 'Major'
        );
        insert c;

        Contact result = [SELECT ULBC_Donor_Status__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Current Donor', result.ULBC_Donor_Status__c,
            'Donor with Major tier should show Current Donor');
    }

    @IsTest
    static void testDonorStatusFormula_LapsedDonor() {
        Contact c = new Contact(
            FirstName = 'Former', LastName = 'Giver',
            ULBC_Is_Donor__c = true,
            ULBC_Donor_Tier__c = 'Lapsed'
        );
        insert c;

        Contact result = [SELECT ULBC_Donor_Status__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Lapsed Donor', result.ULBC_Donor_Status__c,
            'Donor with Lapsed tier should show Lapsed Donor');
    }

    @IsTest
    static void testLegacyMembershipField() {
        Contact c = new Contact(
            FirstName = 'Old', LastName = 'Member',
            ULBC_Legacy_Membership__c = 'Patron, Honorary'
        );
        insert c;

        Contact result = [SELECT ULBC_Legacy_Membership__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Patron, Honorary', result.ULBC_Legacy_Membership__c,
            'Legacy Membership should store FileMaker membership subtype');
    }

    @IsTest
    static void testPatronAndDonorStatusIndependent() {
        // A lapsed donor can still be an active patron member
        Contact c = new Contact(
            FirstName = 'Phil', LastName = 'Norman',
            ULBC_Is_Donor__c = true,
            ULBC_Donor_Tier__c = 'Lapsed',
            ULBC_Patron_Status__c = 'Patron',
            ULBC_Legacy_Membership__c = 'Patron'
        );
        insert c;

        Contact result = [
            SELECT ULBC_Donor_Status__c, ULBC_Patron_Status__c, ULBC_Legacy_Membership__c
            FROM Contact WHERE Id = :c.Id
        ];
        System.assertEquals('Lapsed Donor', result.ULBC_Donor_Status__c,
            'Donor Status should reflect giving activity');
        System.assertEquals('Patron', result.ULBC_Patron_Status__c,
            'Patron Status should be independent of giving');
        System.assertEquals('Patron', result.ULBC_Legacy_Membership__c,
            'Legacy Membership should be preserved');
    }
}
