@IsTest
private class ULBC_StripeFields_Test {

    /**
     * Phase 5A.1 — Stripe data model tests.
     *
     * Covers:
     *   - Field existence on Contact and CampaignMember (catches accidental field deletion)
     *   - External ID + Unique enforcement on ULBC_Stripe_Customer_ID__c (Contact)
     *   - External ID + Unique enforcement on ULBC_Stripe_Payment_ID__c (CampaignMember)
     *   - ULBC_Donation_Link__c formula renders correctly when DonationBaseURL is set
     *   - ULBC_Donation_Link__c gracefully handles null DonationBaseURL
     */

    @TestSetup
    static void setupData() {
        // Set the org-default custom setting value so the formula has a base URL to work with.
        ULBC_Stripe_Settings__c settings = new ULBC_Stripe_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            DonationBaseURL__c = 'https://test.example.com/donate'
        );
        insert settings;

        // Two test contacts with distinct TrustIDs.
        Contact c1 = new Contact(
            FirstName = 'Test',
            LastName = 'Donor One',
            Email = 'donor1@test.example.com',
            ULBC_Trust_ID__c = 'ULBC-TEST-001'
        );
        Contact c2 = new Contact(
            FirstName = 'Test',
            LastName = 'Donor Two',
            Email = 'donor2@test.example.com',
            ULBC_Trust_ID__c = 'ULBC-TEST-002'
        );
        insert new List<Contact>{ c1, c2 };

        // Test campaign for the CampaignMember uniqueness test.
        Campaign camp = new Campaign(
            Name = 'Test Stripe Event',
            IsActive = true
        );
        insert camp;
    }

    /**
     * Field existence — guards against accidental deletion or rename.
     * Each describe call throws if the field is missing.
     */
    @IsTest
    static void test_fieldsExist() {
        Map<String, Schema.SObjectField> contactFields =
            Schema.SObjectType.Contact.fields.getMap();
        Map<String, Schema.SObjectField> cmFields =
            Schema.SObjectType.CampaignMember.fields.getMap();

        System.assert(
            contactFields.containsKey('ulbc_stripe_customer_id__c'),
            'Contact.ULBC_Stripe_Customer_ID__c must exist (Phase 5A.1, Decision 5.10).'
        );
        System.assert(
            contactFields.containsKey('ulbc_donation_link__c'),
            'Contact.ULBC_Donation_Link__c must exist (Phase 5A.1, Decision 5.15).'
        );
        System.assert(
            cmFields.containsKey('ulbc_stripe_payment_id__c'),
            'CampaignMember.ULBC_Stripe_Payment_ID__c must exist (Phase 5A.1, Decision 5.10).'
        );
    }

    /**
     * External ID flag is set on both Stripe ID fields.
     * Without External ID, upserts from the webhook handler will not work.
     */
    @IsTest
    static void test_externalIdFlagsSet() {
        Schema.DescribeFieldResult customerIdDesc =
            Contact.ULBC_Stripe_Customer_ID__c.getDescribe();
        Schema.DescribeFieldResult paymentIdDesc =
            CampaignMember.ULBC_Stripe_Payment_ID__c.getDescribe();

        System.assert(
            customerIdDesc.isExternalId(),
            'Contact.ULBC_Stripe_Customer_ID__c must be flagged External ID.'
        );
        System.assert(
            customerIdDesc.isUnique(),
            'Contact.ULBC_Stripe_Customer_ID__c must be flagged Unique.'
        );
        System.assert(
            paymentIdDesc.isExternalId(),
            'CampaignMember.ULBC_Stripe_Payment_ID__c must be flagged External ID.'
        );
        System.assert(
            paymentIdDesc.isUnique(),
            'CampaignMember.ULBC_Stripe_Payment_ID__c must be flagged Unique.'
        );
    }

    /**
     * Uniqueness — assigning the same Stripe Customer ID to two Contacts must fail.
     * Simulates the case where the webhook handler accidentally tries to write the same
     * Stripe customer to a different Salesforce Contact (which would silently corrupt the
     * matching key without this constraint).
     */
    @IsTest
    static void test_stripeCustomerId_uniquenessEnforced() {
        List<Contact> contacts = [
            SELECT Id FROM Contact
            WHERE ULBC_Trust_ID__c LIKE 'ULBC-TEST-%'
            ORDER BY ULBC_Trust_ID__c
        ];
        System.assertEquals(2, contacts.size(), 'Test setup should produce 2 contacts.');

        // First write: succeeds.
        contacts[0].ULBC_Stripe_Customer_ID__c = 'cus_DUPLICATE_TEST';
        update contacts[0];

        // Second write with the same value to a DIFFERENT Contact: must fail.
        contacts[1].ULBC_Stripe_Customer_ID__c = 'cus_DUPLICATE_TEST';

        Test.startTest();
        Boolean caught = false;
        try {
            update contacts[1];
        } catch (DmlException e) {
            caught = true;
            System.assert(
                e.getMessage().containsIgnoreCase('duplicate')
                    || e.getMessage().containsIgnoreCase('unique'),
                'Expected duplicate/unique violation, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(caught,
            'Uniqueness constraint on ULBC_Stripe_Customer_ID__c was not enforced.');
    }

    /**
     * Uniqueness — same Stripe Payment ID on two CampaignMembers must fail.
     * Simulates a webhook retry storm where the same payment is delivered twice.
     */
    @IsTest
    static void test_stripePaymentId_uniquenessEnforced() {
        Contact c1 = [SELECT Id FROM Contact WHERE ULBC_Trust_ID__c = 'ULBC-TEST-001' LIMIT 1];
        Contact c2 = [SELECT Id FROM Contact WHERE ULBC_Trust_ID__c = 'ULBC-TEST-002' LIMIT 1];
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Stripe Event' LIMIT 1];

        CampaignMember cm1 = new CampaignMember(
            CampaignId = camp.Id,
            ContactId = c1.Id,
            ULBC_Stripe_Payment_ID__c = 'pi_DUPLICATE_TEST'
        );
        insert cm1;

        CampaignMember cm2 = new CampaignMember(
            CampaignId = camp.Id,
            ContactId = c2.Id,
            ULBC_Stripe_Payment_ID__c = 'pi_DUPLICATE_TEST'
        );

        Test.startTest();
        Boolean caught = false;
        try {
            insert cm2;
        } catch (DmlException e) {
            caught = true;
            System.assert(
                e.getMessage().containsIgnoreCase('duplicate')
                    || e.getMessage().containsIgnoreCase('unique'),
                'Expected duplicate/unique violation, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(caught,
            'Uniqueness constraint on CampaignMember.ULBC_Stripe_Payment_ID__c was not enforced.');
    }

    /**
     * Donation Link formula renders the personalised URL using the Custom Setting base.
     */
    @IsTest
    static void test_donationLinkFormula_rendersCorrectly() {
        Contact c = [
            SELECT ULBC_Trust_ID__c, ULBC_Donation_Link__c
            FROM Contact
            WHERE ULBC_Trust_ID__c = 'ULBC-TEST-001'
            LIMIT 1
        ];

        String expected = 'https://test.example.com/donate?ulbc_trust_id=ULBC-TEST-001';
        System.assertEquals(expected, c.ULBC_Donation_Link__c,
            'Donation Link formula should concatenate Custom Setting base URL with Trust ID.');
    }

    /**
     * Formula behaviour when DonationBaseURL is null — should render as just the param string,
     * NOT throw a formula exception. Catches mistaken use of formulaTreatBlanksAs config.
     */
    @IsTest
    static void test_donationLinkFormula_handlesNullBaseURL() {
        // Wipe the base URL value.
        ULBC_Stripe_Settings__c settings = ULBC_Stripe_Settings__c.getOrgDefaults();
        settings.DonationBaseURL__c = null;
        update settings;

        Contact c = [
            SELECT ULBC_Trust_ID__c, ULBC_Donation_Link__c
            FROM Contact
            WHERE ULBC_Trust_ID__c = 'ULBC-TEST-001'
            LIMIT 1
        ];

        // Formula should NOT throw — it should produce a string starting with the param key.
        // Salesforce treats null text concatenation as empty string when formulaTreatBlanksAs=BlankAsZero.
        System.assertNotEquals(null, c.ULBC_Donation_Link__c,
            'Donation Link formula should never return null — it concatenates a literal param key.');
        System.assert(
            c.ULBC_Donation_Link__c.contains('ulbc_trust_id=ULBC-TEST-001'),
            'Donation Link should still contain the param even with null base URL. Got: '
                + c.ULBC_Donation_Link__c
        );
    }
}
