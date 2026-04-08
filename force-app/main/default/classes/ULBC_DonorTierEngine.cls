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
