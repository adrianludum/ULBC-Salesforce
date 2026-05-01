/**
 * ULBC_EmailRecipientResolver_Test
 *
 * Filter rules drop entirely; suppression rules keep with reason.
 */
@IsTest
private class ULBC_EmailRecipientResolver_Test {

    @TestSetup
    static void setup() {
        Campaign c = new Campaign(Name = 'Test Newsletter 2026', IsActive = true);
        insert c;

        // Seven contacts, each exercising a different code path.
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Eligible1', Email = 'a@example.com',
                        ULBC_Trust_ID__c = 'ULBC-001'),
            new Contact(LastName = 'Eligible2', Email = 'b@example.com',
                        ULBC_Trust_ID__c = 'ULBC-002'),
            new Contact(LastName = 'OptedOut', Email = 'c@example.com',
                        HasOptedOutOfEmail = true,
                        ULBC_Trust_ID__c = 'ULBC-003'),
            new Contact(LastName = 'Bounced', Email = 'd@example.com',
                        EmailBouncedDate = Datetime.now().addDays(-10),
                        EmailBouncedReason = 'Test bounce',
                        ULBC_Trust_ID__c = 'ULBC-004'),
            new Contact(LastName = 'MissingEmail', Email = null,
                        ULBC_Trust_ID__c = 'ULBC-005'),
            new Contact(LastName = 'Dupe1', Email = 'shared@example.com',
                        ULBC_Trust_ID__c = 'ULBC-006'),
            new Contact(LastName = 'Dupe2', Email = 'shared@example.com',
                        ULBC_Trust_ID__c = 'ULBC-007'),
            // No Trust ID — used by the requireTrustId test
            new Contact(LastName = 'NoTrustId', Email = 'e@example.com')
        };
        insert contacts;

        List<CampaignMember> members = new List<CampaignMember>();
        for (Contact ct : contacts) {
            CampaignMember cm = new CampaignMember(
                CampaignId = c.Id,
                ContactId = ct.Id,
                Status = (ct.LastName == 'Eligible2') ? 'Responded' : 'Sent'
            );
            members.add(cm);
        }
        insert members;
    }

    private static Id getCampaignId() {
        return [SELECT Id FROM Campaign WHERE Name = 'Test Newsletter 2026' LIMIT 1].Id;
    }

    // ── Default filter ─────────────────────────────────────────────────

    @IsTest
    static void test_resolve_defaultFilter_returnsEverybodyWithCorrectReasons() {
        List<ULBC_EmailRecipientResolver.Resolved> out =
            ULBC_EmailRecipientResolver.resolve(getCampaignId(), null);

        // 8 members → 8 resolved rows (no filter dropping anyone).
        System.assertEquals(8, out.size(), 'All 8 members should be resolved');

        Map<String, ULBC_EmailRecipientResolver.Resolved> byLastName =
            new Map<String, ULBC_EmailRecipientResolver.Resolved>();
        for (ULBC_EmailRecipientResolver.Resolved r : out) {
            byLastName.put(r.contact.LastName, r);
        }

        System.assertEquals(null, byLastName.get('Eligible1').suppressionReason);
        System.assertEquals(null, byLastName.get('Eligible2').suppressionReason);
        System.assertEquals(null, byLastName.get('NoTrustId').suppressionReason,
            'NoTrustId is eligible by default — requireTrustId is false');
        System.assertEquals('OptedOut', byLastName.get('OptedOut').suppressionReason);
        System.assertEquals('Bounced', byLastName.get('Bounced').suppressionReason);
        System.assertEquals('MissingEmail', byLastName.get('MissingEmail').suppressionReason);

        // One of Dupe1/Dupe2 is eligible, the other is Duplicate — order depends on CreatedDate.
        ULBC_EmailRecipientResolver.Resolved dupe1 = byLastName.get('Dupe1');
        ULBC_EmailRecipientResolver.Resolved dupe2 = byLastName.get('Dupe2');
        Integer eligibleDupes = (dupe1.suppressionReason == null ? 1 : 0)
                              + (dupe2.suppressionReason == null ? 1 : 0);
        System.assertEquals(1, eligibleDupes,
            'Exactly one of the duplicate-email contacts should be eligible');
    }

    @IsTest
    static void test_resolve_dedupeIsCaseInsensitive() {
        // Add a third dupe with mixed case to confirm trim+lowercase normalisation.
        Contact extra = new Contact(LastName = 'DupeCase', Email = 'SHARED@EXAMPLE.COM',
                                     ULBC_Trust_ID__c = 'ULBC-008');
        insert extra;
        insert new CampaignMember(CampaignId = getCampaignId(), ContactId = extra.Id,
                                   Status = 'Sent');

        List<ULBC_EmailRecipientResolver.Resolved> out =
            ULBC_EmailRecipientResolver.resolve(getCampaignId(), null);

        ULBC_EmailRecipientResolver.Resolved dupeCase = null;
        for (ULBC_EmailRecipientResolver.Resolved r : out) {
            if (r.contact.LastName == 'DupeCase') dupeCase = r;
        }
        System.assertNotEquals(null, dupeCase);
        System.assertEquals('Duplicate', dupeCase.suppressionReason,
            'Case-different duplicate must still be detected');
    }

    // ── Status filter ──────────────────────────────────────────────────

    @IsTest
    static void test_resolve_statusFilter_dropsNonMatchingMembers() {
        ULBC_EmailRecipientResolver.RecipientFilter f =
            new ULBC_EmailRecipientResolver.RecipientFilter();
        f.campaignMemberStatuses = new Set<String>{ 'Responded' };

        List<ULBC_EmailRecipientResolver.Resolved> out =
            ULBC_EmailRecipientResolver.resolve(getCampaignId(), f);

        System.assertEquals(1, out.size(),
            'Only "Eligible2" has Status=Responded');
        System.assertEquals('Eligible2', out[0].contact.LastName);
    }

    // ── Trust ID requirement ───────────────────────────────────────────

    @IsTest
    static void test_resolve_requireTrustId_dropsContactsWithoutTrustId() {
        ULBC_EmailRecipientResolver.RecipientFilter f =
            new ULBC_EmailRecipientResolver.RecipientFilter();
        f.requireTrustId = true;

        List<ULBC_EmailRecipientResolver.Resolved> out =
            ULBC_EmailRecipientResolver.resolve(getCampaignId(), f);

        for (ULBC_EmailRecipientResolver.Resolved r : out) {
            System.assertNotEquals('NoTrustId', r.contact.LastName,
                'requireTrustId=true must drop contacts with blank Trust ID entirely');
        }
        System.assertEquals(7, out.size(),
            '7 of 8 contacts have a Trust ID');
    }

    // ── Validation ─────────────────────────────────────────────────────

    @IsTest
    static void test_resolve_nullCampaignId_throws() {
        try {
            ULBC_EmailRecipientResolver.resolve(null, null);
            System.assert(false, 'Expected IllegalArgumentException');
        } catch (ULBC_EmailRecipientResolver.IllegalArgumentException e) {
            System.assert(e.getMessage().containsIgnoreCase('campaignId'));
        }
    }

    @IsTest
    static void test_resolve_emptyCampaign_returnsEmptyList() {
        Campaign empty = new Campaign(Name = 'Empty', IsActive = true);
        insert empty;
        List<ULBC_EmailRecipientResolver.Resolved> out =
            ULBC_EmailRecipientResolver.resolve(empty.Id, null);
        System.assertEquals(0, out.size());
    }
}
