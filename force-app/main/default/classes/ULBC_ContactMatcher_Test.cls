/**
 * ULBC_ContactMatcher_Test
 *
 * Phase 5A.3 — verifies the four-tier match priority from Decision 5.8:
 *   1. TrustID
 *   2. Stripe Customer ID
 *   3. Email (primary or secondary)
 *   4. Create
 */
@IsTest
private class ULBC_ContactMatcher_Test {

    @TestSetup
    static void seed() {
        insert new List<Contact>{
            new Contact(FirstName = 'Trust', LastName = 'Match',
                        Email = 'trust@example.com',
                        ULBC_Trust_ID__c = 'ULBC-MATCH-1'),
            new Contact(FirstName = 'Cust', LastName = 'Match',
                        Email = 'cust@example.com',
                        ULBC_Trust_ID__c = 'ULBC-MATCH-2',
                        ULBC_Stripe_Customer_ID__c = 'cus_existing_001'),
            new Contact(FirstName = 'Email', LastName = 'Match',
                        Email = 'primary@example.com',
                        ULBC_Trust_ID__c = 'ULBC-MATCH-3',
                        ULBC_Secondary_Email__c = 'secondary@example.com')
        };
    }

    private static ULBC_ContactMatcher.Inputs basicInputs() {
        ULBC_ContactMatcher.Inputs inputs = new ULBC_ContactMatcher.Inputs();
        inputs.acquisitionChannel = 'Stripe Donation';
        return inputs;
    }

    @IsTest
    static void test_matchByTrustId_returnsExistingContact() {
        ULBC_ContactMatcher.Inputs inputs = basicInputs();
        inputs.trustId = 'ULBC-MATCH-1';
        // Even if Stripe Customer ID and email don't match, TrustID wins
        inputs.stripeCustomerId = 'cus_irrelevant';
        inputs.email = 'who@example.com';

        ULBC_ContactMatcher.MatchResult r = ULBC_ContactMatcher.findOrCreate(inputs);
        System.assertEquals(1, r.matchedBy);
        System.assertEquals('ULBC-MATCH-1', r.contact.ULBC_Trust_ID__c);
    }

    @IsTest
    static void test_matchByStripeCustomerId_whenNoTrustId() {
        ULBC_ContactMatcher.Inputs inputs = basicInputs();
        inputs.stripeCustomerId = 'cus_existing_001';
        inputs.email = 'who@example.com';

        ULBC_ContactMatcher.MatchResult r = ULBC_ContactMatcher.findOrCreate(inputs);
        System.assertEquals(2, r.matchedBy);
        System.assertEquals('ULBC-MATCH-2', r.contact.ULBC_Trust_ID__c);
    }

    @IsTest
    static void test_matchByPrimaryEmail() {
        ULBC_ContactMatcher.Inputs inputs = basicInputs();
        inputs.email = 'primary@example.com';

        ULBC_ContactMatcher.MatchResult r = ULBC_ContactMatcher.findOrCreate(inputs);
        System.assertEquals(3, r.matchedBy);
        System.assertEquals('ULBC-MATCH-3', r.contact.ULBC_Trust_ID__c);
    }

    @IsTest
    static void test_matchBySecondaryEmail() {
        ULBC_ContactMatcher.Inputs inputs = basicInputs();
        inputs.email = 'secondary@example.com';

        ULBC_ContactMatcher.MatchResult r = ULBC_ContactMatcher.findOrCreate(inputs);
        System.assertEquals(3, r.matchedBy);
        System.assertEquals('ULBC-MATCH-3', r.contact.ULBC_Trust_ID__c);
    }

    @IsTest
    static void test_noMatch_createsNewContact() {
        ULBC_ContactMatcher.Inputs inputs = basicInputs();
        inputs.email = 'totally-new@example.com';
        inputs.name = 'Brand New';

        Test.startTest();
        ULBC_ContactMatcher.MatchResult r = ULBC_ContactMatcher.findOrCreate(inputs);
        Test.stopTest();

        System.assertEquals(4, r.matchedBy);
        System.assertNotEquals(null, r.contact.Id);
        Contact c = [SELECT FirstName, LastName, ULBC_Acquisition_Channel__c
                     FROM Contact WHERE Id = :r.contact.Id];
        System.assertEquals('Brand', c.FirstName);
        System.assertEquals('New', c.LastName);
        System.assertEquals('Stripe Donation', c.ULBC_Acquisition_Channel__c);
    }

    @IsTest
    static void test_noMatch_singleNamePartGoesToLastName() {
        ULBC_ContactMatcher.Inputs inputs = basicInputs();
        inputs.email = 'mononym@example.com';
        inputs.name = 'Madonna';

        ULBC_ContactMatcher.MatchResult r = ULBC_ContactMatcher.findOrCreate(inputs);

        Contact c = [SELECT FirstName, LastName FROM Contact WHERE Id = :r.contact.Id];
        System.assert(String.isBlank(c.FirstName), 'FirstName should be blank');
        System.assertEquals('Madonna', c.LastName);
    }

    @IsTest
    static void test_linkStripeCustomerId_setsWhenBlank() {
        Contact c = new Contact(LastName = 'NeedsCusId');
        insert c;
        c = [SELECT Id, ULBC_Stripe_Customer_ID__c FROM Contact WHERE Id = :c.Id];

        Boolean linked = ULBC_ContactMatcher.linkStripeCustomerId(c, 'cus_new_link');
        System.assert(linked);
        System.assertEquals('cus_new_link',
            [SELECT ULBC_Stripe_Customer_ID__c FROM Contact WHERE Id = :c.Id].ULBC_Stripe_Customer_ID__c);
    }

    @IsTest
    static void test_linkStripeCustomerId_doesNotOverwrite() {
        Contact c = [SELECT Id, ULBC_Stripe_Customer_ID__c FROM Contact
                     WHERE ULBC_Stripe_Customer_ID__c = 'cus_existing_001'];
        Boolean linked = ULBC_ContactMatcher.linkStripeCustomerId(c, 'cus_different');
        System.assert(!linked, 'Should refuse to overwrite an existing Customer ID');

        Contact reloaded = [SELECT ULBC_Stripe_Customer_ID__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals('cus_existing_001', reloaded.ULBC_Stripe_Customer_ID__c);
    }
}
