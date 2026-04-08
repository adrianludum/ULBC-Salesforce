#!/bin/bash
# ULBC Trust — Phase 2B setup script
# Run from inside your ULBC-salesforcce directory
# Creates all Phase 2B files: donor tier engine, opportunity trigger, email template, static resource

set -e
echo "Creating ULBC Trust Phase 2B files..."

# ─── Directories ─────────────────────────────────────────────────────────────
mkdir -p force-app/main/default/objects/Contact/fields
mkdir -p force-app/main/default/classes
mkdir -p force-app/main/default/triggers
mkdir -p force-app/main/default/staticresources
mkdir -p force-app/main/default/email/unfiled_public_classic_email_templates

# ─── Contact custom fields ────────────────────────────────────────────────────

cat > force-app/main/default/objects/Contact/fields/ULBC_Donor_Tier__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Donor_Tier__c</fullName>
    <label>Donor Tier</label>
    <type>Picklist</type>
    <required>false</required>
    <description>Auto-calculated donor tier based on rolling 12-month giving. Decision 1.8.</description>
    <valueSet>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>Prospect</fullName><default>true</default><label>Prospect</label></value>
            <value><fullName>Standard</fullName><default>false</default><label>Standard</label></value>
            <value><fullName>Patron</fullName><default>false</default><label>Patron</label></value>
            <value><fullName>Major</fullName><default>false</default><label>Major</label></value>
            <value><fullName>Lapsed</fullName><default>false</default><label>Lapsed</label></value>
            <value><fullName>Legacy Prospect</fullName><default>false</default><label>Legacy Prospect</label></value>
            <value><fullName>Legacy Pledger</fullName><default>false</default><label>Legacy Pledger</label></value>
            <value><fullName>Legator</fullName><default>false</default><label>Legator</label></value>
        </valueSetDefinition>
    </valueSet>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Rolling_12m_Giving__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Rolling_12m_Giving__c</fullName>
    <label>Rolling 12-Month Giving</label>
    <type>Currency</type>
    <precision>10</precision>
    <scale>2</scale>
    <required>false</required>
    <description>Sum of closed-won Opportunities in the rolling 12-month window. Updated by ULBC_DonorTierEngine.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Last_Gift_Date__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Last_Gift_Date__c</fullName>
    <label>Last Gift Date</label>
    <type>Date</type>
    <required>false</required>
    <description>Date of most recent closed-won Opportunity. Used to calculate Lapsed status (no gift in 24 months).</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Upgrade_Prospect__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Upgrade_Prospect__c</fullName>
    <label>Upgrade Prospect</label>
    <type>Checkbox</type>
    <defaultValue>false</defaultValue>
    <description>Set to true when rolling 12m giving reaches 80% of tier ceiling. Triggers upgrade email alert to fundraiser.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Next_Tier_Threshold__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Next_Tier_Threshold__c</fullName>
    <label>Next Tier Threshold</label>
    <type>Currency</type>
    <precision>10</precision>
    <scale>2</scale>
    <required>false</required>
    <description>Annual giving threshold for the next tier. Used in upgrade email template.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Gap_To_Next_Tier__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Gap_To_Next_Tier__c</fullName>
    <label>Gap to Next Tier</label>
    <type>Currency</type>
    <precision>10</precision>
    <scale>2</scale>
    <required>false</required>
    <description>How much more the donor needs to give to reach the next tier. Shown in upgrade email.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Tier_Progress_Pct__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Tier_Progress_Pct__c</fullName>
    <label>Tier Progress %</label>
    <type>Number</type>
    <precision>5</precision>
    <scale>1</scale>
    <required>false</required>
    <description>Rolling 12m giving as % of next tier threshold. Used in upgrade email progress bar.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

# ─── Donor Tier Engine ────────────────────────────────────────────────────────

cat > force-app/main/default/classes/ULBC_DonorTierEngine.cls-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>61.0</apiVersion>
    <status>Active</status>
</ApexClass>
ENDOFFILE

cat > force-app/main/default/classes/ULBC_DonorTierEngine.cls << 'ENDOFFILE'
/**
 * ULBC_DonorTierEngine
 *
 * Calculates and updates Donor Tier, Rolling 12-Month Giving, Last Gift Date,
 * Upgrade Prospect flag, and related fields on Contact.
 *
 * Called from ULBC_OpportunityTrigger after insert, update, delete, undelete.
 *
 * Tier thresholds (Decision 1.8):
 *   Prospect  — no gifts ever
 *   Standard  — has given, rolling 12m < £240
 *   Patron    — rolling 12m >= £241
 *   Major     — rolling 12m >= £1,000
 *   Lapsed    — has given before, no gift in 24 months
 *
 * Upgrade alert at 80% of tier ceiling:
 *   Standard ceiling £240  → alert at £192
 *   Patron ceiling £1,000  → alert at £800
 *   Major has no ceiling   → no alert
 */
public with sharing class ULBC_DonorTierEngine {

    private static final Decimal STANDARD_MAX = 240;
    private static final Decimal PATRON_MIN   = 241;
    private static final Decimal PATRON_MAX   = 1000;
    private static final Decimal MAJOR_MIN    = 1000;
    private static final Decimal UPGRADE_PCT  = 0.80;

    private static final Date WINDOW_12M = Date.today().addMonths(-12);
    private static final Date WINDOW_24M = Date.today().addMonths(-24);

    public static void recalculate(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) return;

        List<AggregateResult> rolling12m = [
            SELECT  npe01__Contact_Id_for_Role__c contactId,
                    SUM(Amount) total
            FROM    Opportunity
            WHERE   npe01__Contact_Id_for_Role__c IN :contactIds
            AND     StageName = 'Closed Won'
            AND     CloseDate >= :WINDOW_12M
            GROUP BY npe01__Contact_Id_for_Role__c
        ];

        List<AggregateResult> rolling24m = [
            SELECT  npe01__Contact_Id_for_Role__c contactId,
                    MAX(CloseDate) lastGiftDate
            FROM    Opportunity
            WHERE   npe01__Contact_Id_for_Role__c IN :contactIds
            AND     StageName = 'Closed Won'
            AND     CloseDate >= :WINDOW_24M
            GROUP BY npe01__Contact_Id_for_Role__c
        ];

        List<AggregateResult> everGiven = [
            SELECT  npe01__Contact_Id_for_Role__c contactId,
                    MAX(CloseDate) lastGiftDate
            FROM    Opportunity
            WHERE   npe01__Contact_Id_for_Role__c IN :contactIds
            AND     StageName = 'Closed Won'
            GROUP BY npe01__Contact_Id_for_Role__c
        ];

        Map<Id, Decimal> rolling12mByContact = new Map<Id, Decimal>();
        for (AggregateResult ar : rolling12m) {
            rolling12mByContact.put((Id) ar.get('contactId'), (Decimal) ar.get('total'));
        }

        Map<Id, Boolean> hasGivenIn24m = new Map<Id, Boolean>();
        for (AggregateResult ar : rolling24m) {
            hasGivenIn24m.put((Id) ar.get('contactId'), true);
        }

        Map<Id, Date>    everLastGift = new Map<Id, Date>();
        Map<Id, Boolean> hasEverGiven = new Map<Id, Boolean>();
        for (AggregateResult ar : everGiven) {
            Id cId = (Id) ar.get('contactId');
            everLastGift.put(cId, (Date) ar.get('lastGiftDate'));
            hasEverGiven.put(cId, true);
        }

        List<Contact> toUpdate = new List<Contact>();

        for (Id contactId : contactIds) {
            Decimal rolling12 = rolling12mByContact.containsKey(contactId)
                ? rolling12mByContact.get(contactId) : 0;
            Boolean givenIn24 = hasGivenIn24m.containsKey(contactId);
            Boolean givenEver = hasEverGiven.containsKey(contactId);
            Date    lastGift  = everLastGift.containsKey(contactId)
                ? everLastGift.get(contactId) : null;

            String  tier          = 'Prospect';
            Decimal nextThreshold = null;
            Decimal gap           = null;
            Decimal progressPct   = null;
            Boolean upgradeFlag   = false;

            if (!givenEver) {
                tier = 'Prospect';
            } else if (!givenIn24) {
                tier = 'Lapsed';
            } else if (rolling12 >= MAJOR_MIN) {
                tier = 'Major';
            } else if (rolling12 >= PATRON_MIN) {
                tier          = 'Patron';
                nextThreshold = PATRON_MAX;
                gap           = PATRON_MAX - rolling12;
                progressPct   = (rolling12 / PATRON_MAX * 100).setScale(1);
                upgradeFlag   = (rolling12 >= PATRON_MAX * UPGRADE_PCT);
            } else {
                tier          = 'Standard';
                nextThreshold = STANDARD_MAX;
                gap           = STANDARD_MAX - rolling12;
                progressPct   = (rolling12 / STANDARD_MAX * 100).setScale(1);
                upgradeFlag   = (rolling12 >= STANDARD_MAX * UPGRADE_PCT);
            }

            if (progressPct != null && progressPct > 100) progressPct = 100;

            Contact c = new Contact(Id = contactId);
            c.ULBC_Donor_Tier__c          = tier;
            c.ULBC_Rolling_12m_Giving__c  = rolling12;
            c.ULBC_Last_Gift_Date__c      = lastGift;
            c.ULBC_Upgrade_Prospect__c    = upgradeFlag;
            c.ULBC_Next_Tier_Threshold__c = nextThreshold;
            c.ULBC_Gap_To_Next_Tier__c    = gap;
            c.ULBC_Tier_Progress_Pct__c   = progressPct;
            toUpdate.add(c);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}
ENDOFFILE

# ─── Donor Tier Engine Test ───────────────────────────────────────────────────

cat > force-app/main/default/classes/ULBC_DonorTierEngine_Test.cls-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>61.0</apiVersion>
    <status>Active</status>
</ApexClass>
ENDOFFILE

cat > force-app/main/default/classes/ULBC_DonorTierEngine_Test.cls << 'ENDOFFILE'
/**
 * ULBC_DonorTierEngine_Test
 * Phase 2B — Donor Tier Engine tests
 */
@IsTest
private class ULBC_DonorTierEngine_Test {

    private static Contact makeContact(String trustId) {
        Contact c = new Contact(
            FirstName = 'Test', LastName = 'Donor',
            ULBC_Trust_ID__c = trustId,
            ULBC_Primary_Contact_Type__c = 'Alumni',
            Email = trustId + '@example.com'
        );
        insert c;
        return c;
    }

    private static Opportunity makeOpp(Id contactId, Decimal amount, Date closeDate) {
        return new Opportunity(
            Name = 'Test Gift ' + amount,
            StageName = 'Closed Won',
            CloseDate = closeDate,
            Amount = amount,
            npe01__Contact_Id_for_Role__c = contactId
        );
    }

    private static Contact reloadContact(Id contactId) {
        return [
            SELECT Id, ULBC_Donor_Tier__c, ULBC_Rolling_12m_Giving__c,
                   ULBC_Last_Gift_Date__c, ULBC_Upgrade_Prospect__c,
                   ULBC_Next_Tier_Threshold__c, ULBC_Gap_To_Next_Tier__c,
                   ULBC_Tier_Progress_Pct__c
            FROM   Contact WHERE Id = :contactId
        ];
    }

    @IsTest static void test_noGifts_tierIsProspect() {
        Contact c = makeContact('ULBC-TIER-P-001');
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Prospect', r.ULBC_Donor_Tier__c, 'No gifts = Prospect');
        System.assertEquals(0, r.ULBC_Rolling_12m_Giving__c, 'No gifts = £0');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, 'Prospect has no upgrade alert');
    }

    @IsTest static void test_giftUnder240_tierIsStandard() {
        Contact c = makeContact('ULBC-TIER-S-001');
        insert makeOpp(c.Id, 100, Date.today().addDays(-30));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c, '£100 = Standard');
        System.assertEquals(100, r.ULBC_Rolling_12m_Giving__c, 'Rolling total £100');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, '£100 below 80% threshold');
    }

    @IsTest static void test_giftAt192_triggersUpgradeAlert_Standard() {
        Contact c = makeContact('ULBC-TIER-S-002');
        insert makeOpp(c.Id, 192, Date.today().addDays(-10));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c,        '£192 = Standard');
        System.assertEquals(true,       r.ULBC_Upgrade_Prospect__c,  '£192 = 80% → upgrade alert');
        System.assertEquals(240,        r.ULBC_Next_Tier_Threshold__c,'Next threshold £240');
        System.assertEquals(48,         r.ULBC_Gap_To_Next_Tier__c,  'Gap = £48');
    }

    @IsTest static void test_giftAt239_isStandard_notPatron() {
        Contact c = makeContact('ULBC-TIER-S-003');
        insert makeOpp(c.Id, 239, Date.today().addDays(-5));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals('Standard', reloadContact(c.Id).ULBC_Donor_Tier__c, '£239 = Standard');
    }

    @IsTest static void test_giftAt241_tierIsPatron() {
        Contact c = makeContact('ULBC-TIER-PAT-001');
        insert makeOpp(c.Id, 241, Date.today().addDays(-20));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Patron', r.ULBC_Donor_Tier__c, '£241 = Patron');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, '£241 below 80% of £1,000');
    }

    @IsTest static void test_giftAt800_triggersUpgradeAlert_Patron() {
        Contact c = makeContact('ULBC-TIER-PAT-002');
        insert makeOpp(c.Id, 800, Date.today().addDays(-15));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Patron', r.ULBC_Donor_Tier__c,        '£800 = Patron');
        System.assertEquals(true,     r.ULBC_Upgrade_Prospect__c,  '£800 = 80% → upgrade alert');
        System.assertEquals(1000,     r.ULBC_Next_Tier_Threshold__c,'Next threshold £1,000');
        System.assertEquals(200,      r.ULBC_Gap_To_Next_Tier__c,  'Gap = £200');
    }

    @IsTest static void test_giftAt999_isPatron_notMajor() {
        Contact c = makeContact('ULBC-TIER-PAT-003');
        insert makeOpp(c.Id, 999, Date.today().addDays(-5));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals('Patron', reloadContact(c.Id).ULBC_Donor_Tier__c, '£999 = Patron');
    }

    @IsTest static void test_giftAt1000_tierIsMajor() {
        Contact c = makeContact('ULBC-TIER-M-001');
        insert makeOpp(c.Id, 1000, Date.today().addDays(-10));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Major', r.ULBC_Donor_Tier__c, '£1,000 = Major');
        System.assertEquals(false, r.ULBC_Upgrade_Prospect__c, 'Major has no upgrade alert');
    }

    @IsTest static void test_largeGift_15000_isMajor() {
        Contact c = makeContact('ULBC-TIER-M-002');
        insert makeOpp(c.Id, 15000, Date.today().addDays(-5));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Major', r.ULBC_Donor_Tier__c,           '£15,000 = Major');
        System.assertEquals(15000,   r.ULBC_Rolling_12m_Giving__c,   'Rolling total £15,000');
        System.assertEquals(false,   r.ULBC_Upgrade_Prospect__c,     'Major has no upgrade alert');
    }

    @IsTest static void test_giftOver24MonthsAgo_tierIsLapsed() {
        Contact c = makeContact('ULBC-TIER-L-001');
        insert makeOpp(c.Id, 500, Date.today().addMonths(-25));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Lapsed', r.ULBC_Donor_Tier__c,         'Gift 25m ago = Lapsed');
        System.assertEquals(0,        r.ULBC_Rolling_12m_Giving__c, 'Outside 12m = £0');
        System.assertEquals(false,    r.ULBC_Upgrade_Prospect__c,   'Lapsed has no upgrade alert');
    }

    @IsTest static void test_giftAt23Months_isNotLapsed() {
        Contact c = makeContact('ULBC-TIER-L-002');
        insert makeOpp(c.Id, 300, Date.today().addMonths(-23));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertNotEquals('Lapsed', reloadContact(c.Id).ULBC_Donor_Tier__c, '23m ago is not Lapsed');
    }

    @IsTest static void test_rollingWindow_excludesOldGifts() {
        Contact c = makeContact('ULBC-TIER-W-001');
        insert new List<Opportunity>{
            makeOpp(c.Id, 150, Date.today().addDays(-30)),
            makeOpp(c.Id, 200, Date.today().addMonths(-14))
        };
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals(150,      r.ULBC_Rolling_12m_Giving__c, 'Only £150 within 12m counts');
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c,       '£150 = Standard');
    }

    @IsTest static void test_rollingWindow_multipleGiftsWithin12m() {
        Contact c = makeContact('ULBC-TIER-W-002');
        insert new List<Opportunity>{
            makeOpp(c.Id, 200, Date.today().addDays(-10)),
            makeOpp(c.Id, 250, Date.today().addDays(-60)),
            makeOpp(c.Id, 200, Date.today().addDays(-200))
        };
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals(650,     r.ULBC_Rolling_12m_Giving__c, '£200+£250+£200 = £650');
        System.assertEquals('Patron', r.ULBC_Donor_Tier__c,        '£650 = Patron');
    }

    @IsTest static void test_lastGiftDate_isCorrect() {
        Contact c = makeContact('ULBC-TIER-D-001');
        Date recentDate = Date.today().addDays(-5);
        Date olderDate  = Date.today().addDays(-90);
        insert new List<Opportunity>{
            makeOpp(c.Id, 100, olderDate),
            makeOpp(c.Id, 100, recentDate)
        };
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals(recentDate, reloadContact(c.Id).ULBC_Last_Gift_Date__c, 'Last gift date must be most recent');
    }

    @IsTest static void test_tierDowngrade_whenGiftDeleted() {
        Contact c = makeContact('ULBC-TIER-DOWN-001');
        Opportunity bigGift = makeOpp(c.Id, 1200, Date.today().addDays(-30));
        insert bigGift;
        ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        System.assertEquals('Major', reloadContact(c.Id).ULBC_Donor_Tier__c, 'Precondition: Major');
        insert makeOpp(c.Id, 100, Date.today().addDays(-10));
        Test.startTest();
            delete bigGift;
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ c.Id });
        Test.stopTest();
        Contact r = reloadContact(c.Id);
        System.assertEquals('Standard', r.ULBC_Donor_Tier__c,           'After deleting £1,200 = Standard');
        System.assertEquals(100,        r.ULBC_Rolling_12m_Giving__c,   'Rolling total = £100');
    }

    @IsTest static void test_bulk_recalculate50Contacts() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 50; i++) {
            contacts.add(new Contact(
                FirstName='Bulk', LastName='Donor'+i,
                ULBC_Trust_ID__c='ULBC-BULK-TIER-'+String.valueOf(i).leftPad(3,'0'),
                ULBC_Primary_Contact_Type__c='Alumni'
            ));
        }
        insert contacts;
        List<Opportunity> opps = new List<Opportunity>();
        for (Contact c : contacts) {
            opps.add(makeOpp(c.Id, 300, Date.today().addDays(-10)));
        }
        insert opps;
        Set<Id> contactIds = new Map<Id,Contact>(contacts).keySet();
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(contactIds);
        Test.stopTest();
        System.assertEquals(50, [SELECT COUNT() FROM Contact
            WHERE ULBC_Trust_ID__c LIKE 'ULBC-BULK-TIER-%' AND ULBC_Donor_Tier__c = 'Patron'],
            'All 50 bulk contacts must be Patron');
    }

    @IsTest static void test_jade_progressionToMajor() {
        Contact jade = new Contact(
            FirstName='Jade', LastName='Smith',
            ULBC_Trust_ID__c='ULBC-JADE-TIER-001',
            ULBC_Primary_Contact_Type__c='Alumni'
        );
        insert jade;
        insert makeOpp(jade.Id, 15000, Date.today().addDays(-30));
        Test.startTest();
            ULBC_DonorTierEngine.recalculate(new Set<Id>{ jade.Id });
        Test.stopTest();
        Contact r = reloadContact(jade.Id);
        System.assertEquals('Major', r.ULBC_Donor_Tier__c,          'Jade = Major');
        System.assertEquals(15000,   r.ULBC_Rolling_12m_Giving__c,  '£15,000 rolling total');
        System.assertEquals(false,   r.ULBC_Upgrade_Prospect__c,    'Major = no upgrade alert');
        System.assertNotEquals(null,  r.ULBC_Last_Gift_Date__c,      'Last gift date populated');
    }
}
ENDOFFILE

# ─── Opportunity Trigger ──────────────────────────────────────────────────────

cat > force-app/main/default/triggers/ULBC_OpportunityTrigger.trigger-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>61.0</apiVersion>
    <status>Active</status>
</ApexTrigger>
ENDOFFILE

cat > force-app/main/default/triggers/ULBC_OpportunityTrigger.trigger << 'ENDOFFILE'
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
ENDOFFILE

# ─── Static Resource (ULBC Logo) ─────────────────────────────────────────────

cat > force-app/main/default/staticresources/ULBC_Logo.resource-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
    <cacheControl>Public</cacheControl>
    <contentType>image/jpeg</contentType>
    <description>ULBC Trust crest — used in email templates.</description>
</StaticResource>
ENDOFFILE

# ─── Email Template ───────────────────────────────────────────────────────────

cat > force-app/main/default/email/unfiled_public_classic_email_templates/ULBC_UpgradeProspectAlert.email-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<EmailTemplate xmlns="http://soap.sforce.com/2006/04/metadata">
    <available>true</available>
    <encodingKey>UTF-8</encodingKey>
    <n>ULBC Upgrade Prospect Alert</n>
    <style>none</style>
    <subject>Upgrade Opportunity: {!relatedTo.FirstName} {!relatedTo.LastName} is approaching their next giving tier</subject>
    <type>visualforce</type>
    <description>Sent to the ULBC Relationship Manager when a donor reaches 80% of their tier ceiling.</description>
</EmailTemplate>
ENDOFFILE

cat > force-app/main/default/email/unfiled_public_classic_email_templates/ULBC_UpgradeProspectAlert.email << 'ENDOFFILE'
<messaging:emailTemplate subject="Upgrade Opportunity: {!relatedTo.FirstName} {!relatedTo.LastName} is approaching their next giving tier"
    recipientType="User"
    relatedToType="Contact"
    xmlns:messaging="http://soap.sforce.com/2006/04/messaging">
<messaging:htmlEmailBody>
<html>
<head>
<meta charset="UTF-8"/>
<style>
  body { margin:0; padding:0; background-color:#f4f1f8; font-family:Georgia,'Times New Roman',serif; color:#040008; }
  .wrapper { max-width:620px; margin:40px auto; background-color:#fbfafc; border-radius:4px; overflow:hidden; box-shadow:0 2px 12px rgba(4,0,8,0.12); }
  .header { background-color:#040008; padding:36px 40px 28px; text-align:center; }
  .header img { width:90px; height:90px; border-radius:50%; border:3px solid #784ca8; }
  .header-title { color:#fbfafc; font-size:13px; letter-spacing:3px; text-transform:uppercase; margin-top:16px; margin-bottom:0; font-family:Arial,sans-serif; }
  .alert-banner { background-color:#784ca8; padding:18px 40px; text-align:center; }
  .alert-banner p { margin:0; color:#fbfafc; font-size:15px; font-family:Arial,sans-serif; letter-spacing:1px; text-transform:uppercase; font-weight:bold; }
  .body { padding:40px 40px 32px; }
  .greeting { font-size:22px; font-weight:bold; color:#040008; margin:0 0 8px; }
  .intro { font-size:15px; color:#333; line-height:1.7; margin:0 0 32px; font-family:Arial,sans-serif; }
  .donor-card { background-color:#f4f1f8; border-left:4px solid #784ca8; border-radius:3px; padding:24px 28px; margin-bottom:32px; }
  .donor-name { font-size:20px; font-weight:bold; color:#040008; margin:0 0 16px; }
  .stat-row { margin-bottom:10px; font-family:Arial,sans-serif; font-size:14px; }
  .stat-label { color:#666; display:inline-block; width:180px; }
  .stat-value { color:#040008; font-weight:bold; }
  .stat-value.highlight { color:#784ca8; }
  .progress-section { margin-bottom:32px; }
  .progress-label { font-family:Arial,sans-serif; font-size:13px; color:#666; margin-bottom:8px; }
  .progress-bar-bg { background-color:#e8e2f0; border-radius:20px; height:14px; overflow:hidden; }
  .progress-bar-fill { background-color:#784ca8; height:14px; border-radius:20px; }
  .progress-pct { font-family:Arial,sans-serif; font-size:12px; color:#784ca8; font-weight:bold; margin-top:6px; text-align:right; }
  .cta-section { text-align:center; margin-bottom:32px; }
  .cta-button { display:inline-block; background-color:#784ca8; color:#fbfafc !important; text-decoration:none; padding:14px 36px; border-radius:3px; font-family:Arial,sans-serif; font-size:14px; font-weight:bold; letter-spacing:1px; text-transform:uppercase; }
  .next-steps { background-color:#040008; border-radius:3px; padding:24px 28px; margin-bottom:32px; }
  .next-steps h3 { color:#784ca8; font-family:Arial,sans-serif; font-size:12px; letter-spacing:2px; text-transform:uppercase; margin:0 0 14px; }
  .next-steps ul { margin:0; padding-left:18px; color:#fbfafc; font-family:Arial,sans-serif; font-size:14px; line-height:1.8; }
  .footer { background-color:#040008; padding:24px 40px; text-align:center; border-top:3px solid #784ca8; }
  .footer p { color:#888; font-family:Arial,sans-serif; font-size:12px; margin:0; line-height:1.6; }
  .footer a { color:#784ca8; text-decoration:none; }
  hr.divider { border:none; border-top:1px solid #e8e2f0; margin:0 0 32px; }
</style>
</head>
<body>
<div class="wrapper">
  <div class="header">
    <img src="{!$Resource.ULBC_Logo}" alt="ULBC Trust Crest"/>
    <p class="header-title">ULBC Trust Limited &nbsp;&#183;&nbsp; Fundraising Intelligence</p>
  </div>
  <div class="alert-banner">
    <p>Upgrade Prospect Identified</p>
  </div>
  <div class="body">
    <p class="greeting">A donor is approaching their next tier.</p>
    <p class="intro">The following contact has reached the upgrade threshold. Their rolling 12&#8209;month giving is now within range of the next fundraising tier. This is the right moment to make a personalised approach.</p>
    <div class="donor-card">
      <p class="donor-name">{!relatedTo.FirstName} {!relatedTo.LastName}</p>
      <div class="stat-row"><span class="stat-label">Current Tier</span><span class="stat-value">{!relatedTo.ULBC_Donor_Tier__c}</span></div>
      <div class="stat-row"><span class="stat-label">12-Month Giving</span><span class="stat-value highlight">&#163;{!relatedTo.ULBC_Rolling_12m_Giving__c}</span></div>
      <div class="stat-row"><span class="stat-label">Next Tier Threshold</span><span class="stat-value">&#163;{!relatedTo.ULBC_Next_Tier_Threshold__c}</span></div>
      <div class="stat-row"><span class="stat-label">Gap to Next Tier</span><span class="stat-value">&#163;{!relatedTo.ULBC_Gap_To_Next_Tier__c}</span></div>
      <div class="stat-row"><span class="stat-label">Acquisition Channel</span><span class="stat-value">{!relatedTo.ULBC_Acquisition_Channel__c}</span></div>
    </div>
    <div class="progress-section">
      <p class="progress-label">Progress toward next tier threshold</p>
      <div class="progress-bar-bg">
        <div class="progress-bar-fill" style="width:{!relatedTo.ULBC_Tier_Progress_Pct__c}%;"></div>
      </div>
      <p class="progress-pct">{!relatedTo.ULBC_Tier_Progress_Pct__c}% of threshold reached</p>
    </div>
    <hr class="divider"/>
    <div class="next-steps">
      <h3>Suggested Next Steps</h3>
      <ul>
        <li>Review this donor's full giving history in Salesforce</li>
        <li>Check their crew history and international competition record &#8212; useful conversation hooks</li>
        <li>Consider a personal call or handwritten note before making the ask</li>
        <li>If they are a Henley alumni, reference the current season</li>
        <li>Log your outreach as an Activity on their contact record</li>
      </ul>
    </div>
    <div class="cta-section">
      <a class="cta-button" href="https://ulbctrustlimited.lightning.force.com/lightning/r/Contact/{!relatedTo.Id}/view">
        Open {!relatedTo.FirstName}'s Record in Salesforce
      </a>
    </div>
    <p style="font-family:Arial,sans-serif;font-size:13px;color:#888;text-align:center;margin:0;">
      This alert was generated automatically by ULBC Trust Salesforce.<br/>
      Clear the <strong>Upgrade Prospect</strong> flag on the contact record once you have acted on it.
    </p>
  </div>
  <div class="footer">
    <p>
      ULBC Trust Limited &nbsp;&#183;&nbsp; Registered Charity &nbsp;&#183;&nbsp; England &amp; Wales<br/>
      <a href="https://ulbctrustlimited.lightning.force.com">Open Salesforce</a>
      &nbsp;&#183;&nbsp;
      This email was sent because you are the ULBC Relationship Manager for this contact.
    </p>
  </div>
</div>
</body>
</html>
</messaging:htmlEmailBody>
<messaging:plainTextEmailBody>
ULBC TRUST — UPGRADE PROSPECT ALERT

Donor: {!relatedTo.FirstName} {!relatedTo.LastName}
Current Tier: {!relatedTo.ULBC_Donor_Tier__c}
12-Month Giving: £{!relatedTo.ULBC_Rolling_12m_Giving__c}
Next Tier Threshold: £{!relatedTo.ULBC_Next_Tier_Threshold__c}
Gap to Next Tier: £{!relatedTo.ULBC_Gap_To_Next_Tier__c}

This donor has reached the upgrade threshold. Now is the right time to make a personalised approach.

Open their record: https://ulbctrustlimited.lightning.force.com/lightning/r/Contact/{!relatedTo.Id}/view

Clear the Upgrade Prospect flag on the contact record once you have acted on it.

ULBC Trust Limited · Registered Charity · England and Wales
</messaging:plainTextEmailBody>
</messaging:emailTemplate>
ENDOFFILE

echo ""
echo "✅ All Phase 2B files created. Verifying..."
echo ""
find force-app/main/default/objects/Contact/fields/ULBC_Donor_Tier__c.field-meta.xml \
     force-app/main/default/objects/Contact/fields/ULBC_Rolling_12m_Giving__c.field-meta.xml \
     force-app/main/default/objects/Contact/fields/ULBC_Last_Gift_Date__c.field-meta.xml \
     force-app/main/default/objects/Contact/fields/ULBC_Upgrade_Prospect__c.field-meta.xml \
     force-app/main/default/objects/Contact/fields/ULBC_Next_Tier_Threshold__c.field-meta.xml \
     force-app/main/default/objects/Contact/fields/ULBC_Gap_To_Next_Tier__c.field-meta.xml \
     force-app/main/default/objects/Contact/fields/ULBC_Tier_Progress_Pct__c.field-meta.xml \
     force-app/main/default/classes/ULBC_DonorTierEngine.cls \
     force-app/main/default/classes/ULBC_DonorTierEngine_Test.cls \
     force-app/main/default/triggers/ULBC_OpportunityTrigger.trigger \
     force-app/main/default/staticresources/ULBC_Logo.resource-meta.xml \
     force-app/main/default/email/unfiled_public_classic_email_templates/ULBC_UpgradeProspectAlert.email \
     2>/dev/null && echo "All 12 key files present ✅" || echo "Some files missing ❌"

echo ""
echo "One manual step required:"
echo "  Copy your ULBC logo image to:"
echo "  force-app/main/default/staticresources/ULBC_Logo.resource"
echo "  (rename IMG_2008.png to ULBC_Logo.resource — no extension change needed for .resource files)"
echo ""
echo "Then deploy in this order:"
echo "  1. sf project deploy start --source-dir force-app/main/default/objects/Contact --target-org ulbc --wait 10"
echo "  2. sf project deploy start --source-dir force-app/main/default/staticresources --target-org ulbc --wait 10"
echo "  3. sf project deploy start --source-dir force-app/main/default/classes/ULBC_DonorTierEngine.cls --source-dir force-app/main/default/triggers/ULBC_OpportunityTrigger.trigger --target-org ulbc --wait 10"
echo "  4. sf project deploy start --source-dir force-app/main/default/classes/ULBC_DonorTierEngine_Test.cls --target-org ulbc --wait 10"
echo "  5. sf project deploy start --source-dir force-app/main/default/email --target-org ulbc --wait 10"
