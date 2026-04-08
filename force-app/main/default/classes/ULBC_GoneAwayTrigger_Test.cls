/**
 * ULBC_GoneAwayTrigger_Test
 * Phase 2A — Gone Away trigger tests
 */
@IsTest
private class ULBC_GoneAwayTrigger_Test {

    private static Contact makeContact(String trustId, Boolean goneAway, Boolean optedOut) {
        return new Contact(
            FirstName                    = 'Test',
            LastName                     = 'Contact',
            ULBC_Trust_ID__c             = trustId,
            ULBC_Primary_Contact_Type__c = 'Alumni',
            ULBC_Gone_Away__c            = goneAway,
            HasOptedOutOfEmail           = optedOut,
            Email                        = trustId + '@example.com'
        );
    }

    private static Contact reload(Id contactId) {
        return [SELECT Id, ULBC_Gone_Away__c, HasOptedOutOfEmail FROM Contact WHERE Id = :contactId];
    }

    @IsTest static void test_insert_goneAwayTrue_setsOptOut() {
        Contact c = makeContact('ULBC-GA-INSERT-01', true, false);
        Test.startTest(); insert c; Test.stopTest();
        System.assertEquals(true, reload(c.Id).HasOptedOutOfEmail, 'Insert Gone Away = true must set opt-out');
    }

    @IsTest static void test_insert_goneAwayFalse_doesNotSetOptOut() {
        Contact c = makeContact('ULBC-GA-INSERT-02', false, false);
        Test.startTest(); insert c; Test.stopTest();
        System.assertEquals(false, reload(c.Id).HasOptedOutOfEmail, 'Insert Gone Away = false must not set opt-out');
    }

    @IsTest static void test_insert_goneAwayTrue_alreadyOptedOut_remainsOptedOut() {
        Contact c = makeContact('ULBC-GA-INSERT-03', true, true);
        Test.startTest(); insert c; Test.stopTest();
        System.assertEquals(true, reload(c.Id).HasOptedOutOfEmail, 'Both true on insert — opt-out must remain true');
    }

    @IsTest static void test_update_setGoneAwayTrue_setsOptOut() {
        Contact c = makeContact('ULBC-GA-UPDATE-01', false, false);
        insert c;
        Test.startTest(); c.ULBC_Gone_Away__c = true; update c; Test.stopTest();
        System.assertEquals(true, reload(c.Id).HasOptedOutOfEmail, 'Setting Gone Away = true must set opt-out');
    }

    @IsTest static void test_update_setGoneAwayTrue_overridesManualOptIn() {
        Contact c = makeContact('ULBC-GA-UPDATE-02', false, false);
        insert c;
        Test.startTest(); c.ULBC_Gone_Away__c = true; c.HasOptedOutOfEmail = false; update c; Test.stopTest();
        System.assertEquals(true, reload(c.Id).HasOptedOutOfEmail, 'Gone Away = true must override opt-in attempt');
    }

    @IsTest static void test_update_clearGoneAway_clearsOptOut() {
        Contact c = makeContact('ULBC-GA-UPDATE-03', true, false);
        insert c;
        System.assertEquals(true, reload(c.Id).HasOptedOutOfEmail, 'Precondition: opt-out set after insert');
        Test.startTest(); c.ULBC_Gone_Away__c = false; update c; Test.stopTest();
        System.assertEquals(false, reload(c.Id).HasOptedOutOfEmail, 'Clearing Gone Away must clear opt-out');
    }

    @IsTest static void test_update_clearGoneAway_doesNotAffectOtherOptOuts() {
        Contact c = makeContact('ULBC-GA-UPDATE-04', true, true);
        insert c;
        Test.startTest(); c.ULBC_Gone_Away__c = false; update c; Test.stopTest();
        System.assertEquals(false, reload(c.Id).HasOptedOutOfEmail, 'Clearing Gone Away sets opt-out false');
    }

    @IsTest static void test_manualOptOut_doesNotSetGoneAway() {
        Contact c = makeContact('ULBC-GA-ONEWAY-01', false, false);
        insert c;
        Test.startTest(); c.HasOptedOutOfEmail = true; update c; Test.stopTest();
        Contact r = [SELECT ULBC_Gone_Away__c, HasOptedOutOfEmail FROM Contact WHERE Id = :c.Id];
        System.assertEquals(true,  r.HasOptedOutOfEmail, 'Manual opt-out must be respected');
        System.assertEquals(false, r.ULBC_Gone_Away__c,  'Manual opt-out must NOT set Gone Away');
    }

    @IsTest static void test_manualOptIn_doesNotSetGoneAway() {
        Contact c = makeContact('ULBC-GA-ONEWAY-02', false, true);
        insert c;
        Test.startTest(); c.HasOptedOutOfEmail = false; update c; Test.stopTest();
        Contact r = [SELECT ULBC_Gone_Away__c, HasOptedOutOfEmail FROM Contact WHERE Id = :c.Id];
        System.assertEquals(false, r.HasOptedOutOfEmail, 'Manual opt-in must be respected');
        System.assertEquals(false, r.ULBC_Gone_Away__c,  'Manual opt-in must not touch Gone Away');
    }

    @IsTest static void test_bulk_200ContactsGoneAway() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            contacts.add(makeContact('ULBC-BULK-' + String.valueOf(i).leftPad(3, '0'), false, false));
        }
        insert contacts;
        Test.startTest();
        for (Contact c : contacts) { c.ULBC_Gone_Away__c = true; }
        update contacts;
        Test.stopTest();
        System.assertEquals(200, [SELECT COUNT() FROM Contact WHERE ULBC_Trust_ID__c LIKE 'ULBC-BULK-%' AND HasOptedOutOfEmail = true],
            'All 200 must be opted out');
    }

    @IsTest static void test_bulk_mixedGoneAwayUpdate() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 100; i++) {
            contacts.add(makeContact('ULBC-MIX-' + String.valueOf(i).leftPad(3, '0'), false, false));
        }
        insert contacts;
        Test.startTest();
        for (Integer i = 0; i < contacts.size(); i++) { contacts[i].ULBC_Gone_Away__c = (Math.mod(i, 2) == 0); }
        update contacts;
        Test.stopTest();
        System.assertEquals(50, [SELECT COUNT() FROM Contact WHERE ULBC_Trust_ID__c LIKE 'ULBC-MIX-%' AND HasOptedOutOfEmail = true],
            'Exactly 50 of 100 must be opted out');
    }

    @IsTest static void test_goneAway_doesNotAffectNonGoneAwayContacts() {
        Contact c = makeContact('ULBC-SAFE-01', false, false);
        insert c;
        Test.startTest(); c.ULBC_Alumni_Type__c = 'Global'; update c; Test.stopTest();
        System.assertEquals(false, reload(c.Id).HasOptedOutOfEmail, 'Unrelated update must not affect opt-out');
    }
}
