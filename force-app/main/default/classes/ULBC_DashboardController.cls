public with sharing class ULBC_DashboardController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getKPIMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();

        metrics.put('totalContacts', [SELECT COUNT() FROM Contact]);
        metrics.put('totalDonors', [SELECT COUNT() FROM Contact WHERE ULBC_Is_Donor__c = true]);

        AggregateResult[] allTimeGifts = [
            SELECT SUM(Amount) total
            FROM Opportunity
            WHERE StageName = 'Closed Won'
        ];
        metrics.put('totalGiftsAllTime', allTimeGifts[0].get('total') != null ? allTimeGifts[0].get('total') : 0);

        AggregateResult[] thisYearGifts = [
            SELECT SUM(Amount) total
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND CloseDate = THIS_YEAR
        ];
        metrics.put('giftsThisYear', thisYearGifts[0].get('total') != null ? thisYearGifts[0].get('total') : 0);

        AggregateResult[] lastYearGifts = [
            SELECT SUM(Amount) total
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND CloseDate = LAST_YEAR
        ];
        metrics.put('giftsLastYear', lastYearGifts[0].get('total') != null ? lastYearGifts[0].get('total') : 0);

        metrics.put('lapsedCount', [SELECT COUNT() FROM Contact WHERE ULBC_Donor_Tier__c = 'Lapsed']);
        metrics.put('upgradeProspectCount', [SELECT COUNT() FROM Contact WHERE ULBC_Upgrade_Prospect__c = true]);

        return metrics;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDonorsByTier() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (AggregateResult ar : [
            SELECT ULBC_Donor_Tier__c label, COUNT(Id) value
            FROM Contact
            WHERE ULBC_Donor_Tier__c != null
            GROUP BY ULBC_Donor_Tier__c
            ORDER BY COUNT(Id) DESC
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('label', ar.get('label'));
            row.put('value', ar.get('value'));
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDonationsByFund() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (AggregateResult ar : [
            SELECT Campaign.Name label, SUM(Amount) value
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            GROUP BY Campaign.Name
            ORDER BY SUM(Amount) DESC
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('label', ar.get('label'));
            row.put('value', ar.get('value'));
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getGiftsByYear() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (AggregateResult ar : [
            SELECT CALENDAR_YEAR(CloseDate) yr, SUM(Amount) total
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            GROUP BY CALENDAR_YEAR(CloseDate)
            ORDER BY CALENDAR_YEAR(CloseDate) ASC
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('year', ar.get('yr'));
            row.put('amount', ar.get('total'));
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getGiftAidStatus() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (AggregateResult ar : [
            SELECT ULBC_Gift_Aid_Eligible__c eligible, SUM(Amount) totalAmount, COUNT(Id) cnt
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            GROUP BY ULBC_Gift_Aid_Eligible__c
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            Boolean isEligible = (Boolean) ar.get('eligible');
            row.put('label', isEligible == true ? 'Gift Aid Eligible' : 'Not Eligible');
            row.put('amount', ar.get('totalAmount'));
            row.put('count', ar.get('cnt'));
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCrewsByRegatta() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (AggregateResult ar : [
            SELECT ULBC_Regatta__c label, COUNT(Id) value
            FROM ULBC_Crew_History__c
            WHERE ULBC_Regatta__c != null
            GROUP BY ULBC_Regatta__c
            ORDER BY COUNT(Id) DESC
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('label', ar.get('label'));
            row.put('value', ar.get('value'));
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEventAttendance() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Campaign c : [
            SELECT Id, Name, StartDate,
                (SELECT Id FROM CampaignMembers)
            FROM Campaign
            WHERE Type = 'Event'
            AND StartDate != null
            ORDER BY StartDate DESC
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('eventName', c.Name);
            row.put('eventId', c.Id);
            row.put('attendeeCount', c.CampaignMembers.size());
            row.put('startDate', c.StartDate);
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Campaign> getActiveCampaigns() {
        return [
            SELECT Id, Name, Type, Status, StartDate, EndDate,
                NumberOfContacts, NumberOfLeads
            FROM Campaign
            WHERE IsActive = true
            ORDER BY StartDate DESC NULLS LAST
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getUpgradeProspects() {
        return [
            SELECT Name, ULBC_Trust_ID__c, ULBC_Donor_Tier__c, ULBC_Rolling_12m_Giving__c, Email
            FROM Contact
            WHERE ULBC_Upgrade_Prospect__c = true
            ORDER BY ULBC_Rolling_12m_Giving__c DESC
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getLapsedDonors() {
        return [
            SELECT Name, ULBC_Trust_ID__c, Email, ULBC_Last_Gift_Date__c, ULBC_Rolling_12m_Giving__c
            FROM Contact
            WHERE ULBC_Donor_Tier__c = 'Lapsed'
            ORDER BY ULBC_Last_Gift_Date__c DESC NULLS LAST
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentDonations() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Opportunity opp : [
            SELECT Name, Amount, CloseDate, Campaign.Name, npsp__Primary_Contact__c, npsp__Primary_Contact__r.Name
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND CloseDate = LAST_N_DAYS:90
            ORDER BY CloseDate DESC
            LIMIT 20
        ]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('name', opp.Name);
            row.put('amount', opp.Amount);
            row.put('closeDate', opp.CloseDate);
            row.put('fundName', opp.Campaign != null ? opp.Campaign.Name : null);
            row.put('contactName', opp.npsp__Primary_Contact__r != null ? opp.npsp__Primary_Contact__r.Name : null);
            row.put('contactId', opp.npsp__Primary_Contact__c);
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Id> getReportIds() {
        Map<String, Id> reportMap = new Map<String, Id>();
        for (Report r : [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName LIKE 'ULBC_%'
        ]) {
            reportMap.put(r.DeveloperName, r.Id);
        }
        return reportMap;
    }
}
