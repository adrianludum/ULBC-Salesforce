@IsTest
private class ULBC_DashboardController_Test {

    @TestSetup
    static void setupData() {
        // Contacts: 5 donors + 3 lapsed-intended + 1 non-donor = 9 total
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Donor ' + i,
                Email = 'donor' + i + '@test.com',
                ULBC_Trust_ID__c = 'ULBC-' + String.valueOf(1000 + i),
                ULBC_Is_Donor__c = true
            ));
        }
        // Contacts intended to become Lapsed (no recent opps)
        for (Integer i = 0; i < 3; i++) {
            contacts.add(new Contact(
                FirstName = 'Lapsed',
                LastName = 'Donor ' + i,
                Email = 'lapsed' + i + '@test.com',
                ULBC_Trust_ID__c = 'ULBC-' + String.valueOf(2000 + i),
                ULBC_Is_Donor__c = true
            ));
        }
        // Non-donor contact
        contacts.add(new Contact(
            FirstName = 'Non',
            LastName = 'Donor',
            Email = 'nondonor@test.com'
        ));
        insert contacts;

        // Campaign (fund)
        Campaign fund = new Campaign(
            Name = 'Annual Fund',
            IsActive = true,
            Type = 'Fundraising'
        );
        insert fund;

        // Event campaign
        Campaign evt = new Campaign(
            Name = 'Annual Dinner',
            IsActive = true,
            Type = 'Event',
            StartDate = Date.today().addDays(-30)
        );
        insert evt;

        // CampaignMembers for event attendance
        List<CampaignMember> members = new List<CampaignMember>();
        for (Integer i = 0; i < 3; i++) {
            members.add(new CampaignMember(
                CampaignId = evt.Id,
                ContactId = contacts[i].Id,
                Status = 'Responded'
            ));
        }
        members.add(new CampaignMember(
            CampaignId = evt.Id,
            ContactId = contacts[3].Id,
            Status = 'Sent'
        ));
        insert members;

        // Opportunities
        List<Opportunity> opps = new List<Opportunity>();

        // contacts[0]: 900 this year -> Patron tier, 900/1000 = 90% -> upgrade prospect
        opps.add(new Opportunity(
            Name = 'Donation 0',
            Amount = 900,
            CloseDate = Date.today().addDays(-5),
            StageName = 'Closed Won',
            CampaignId = fund.Id,
            npsp__Primary_Contact__c = contacts[0].Id,
            ULBC_Gift_Aid_Eligible__c = true
        ));

        // contacts[1]: 850 this year -> Patron tier, 850/1000 = 85% -> upgrade prospect
        opps.add(new Opportunity(
            Name = 'Donation 1',
            Amount = 850,
            CloseDate = Date.today().addDays(-15),
            StageName = 'Closed Won',
            CampaignId = fund.Id,
            npsp__Primary_Contact__c = contacts[1].Id,
            ULBC_Gift_Aid_Eligible__c = false
        ));

        // contacts[2]: 200 this year -> Standard tier, 200/240 = 83% -> upgrade prospect
        opps.add(new Opportunity(
            Name = 'Donation 2',
            Amount = 200,
            CloseDate = Date.today().addDays(-25),
            StageName = 'Closed Won',
            CampaignId = fund.Id,
            npsp__Primary_Contact__c = contacts[2].Id,
            ULBC_Gift_Aid_Eligible__c = true
        ));

        // contacts[3]: 50 this year -> Standard tier, 50/240 = 21% -> no upgrade
        opps.add(new Opportunity(
            Name = 'Donation 3',
            Amount = 50,
            CloseDate = Date.today().addDays(-35),
            StageName = 'Closed Won',
            CampaignId = fund.Id,
            npsp__Primary_Contact__c = contacts[3].Id,
            ULBC_Gift_Aid_Eligible__c = false
        ));

        // Last year opportunity for contacts[4]
        opps.add(new Opportunity(
            Name = 'Last Year Donation',
            Amount = 1000,
            CloseDate = Date.today().addYears(-1),
            StageName = 'Closed Won',
            CampaignId = fund.Id,
            npsp__Primary_Contact__c = contacts[4].Id,
            ULBC_Gift_Aid_Eligible__c = true
        ));

        // Old opps for lapsed contacts (>24 months ago)
        for (Integer i = 0; i < 3; i++) {
            opps.add(new Opportunity(
                Name = 'Old Donation ' + i,
                Amount = 100,
                CloseDate = Date.today().addMonths(-30),
                StageName = 'Closed Won',
                CampaignId = fund.Id,
                npsp__Primary_Contact__c = contacts[5 + i].Id,
                ULBC_Gift_Aid_Eligible__c = false
            ));
        }

        insert opps;

        // Crew History
        List<ULBC_Crew_History__c> crews = new List<ULBC_Crew_History__c>();
        crews.add(new ULBC_Crew_History__c(
            ULBC_Contact__c = contacts[0].Id,
            ULBC_Regatta__c = 'Henley Royal Regatta',
            ULBC_Year__c = 2024,
            ULBC_Crew_Name__c = 'M8+'
        ));
        crews.add(new ULBC_Crew_History__c(
            ULBC_Contact__c = contacts[1].Id,
            ULBC_Regatta__c = 'Henley Royal Regatta',
            ULBC_Year__c = 2024,
            ULBC_Crew_Name__c = 'M4+'
        ));
        crews.add(new ULBC_Crew_History__c(
            ULBC_Contact__c = contacts[2].Id,
            ULBC_Regatta__c = 'Head of the River',
            ULBC_Year__c = 2024,
            ULBC_Crew_Name__c = 'M8+'
        ));
        insert crews;
    }

    @IsTest
    static void testGetKPIMetrics() {
        Test.startTest();
        Map<String, Object> metrics = ULBC_DashboardController.getKPIMetrics();
        Test.stopTest();

        System.assertNotEquals(null, metrics, 'Metrics should not be null');
        System.assertEquals(9, (Integer) metrics.get('totalContacts'), 'Should have 9 contacts');
        System.assert((Integer) metrics.get('totalDonors') > 0, 'Should have donors');
        System.assert((Decimal) metrics.get('giftsThisYear') > 0, 'Should have gifts this year');
        System.assert((Integer) metrics.get('lapsedCount') >= 0, 'Lapsed count should be non-negative');
        System.assert((Integer) metrics.get('upgradeProspectCount') >= 0, 'Upgrade count should be non-negative');
    }

    @IsTest
    static void testGetDonorsByTier() {
        Test.startTest();
        List<Map<String, Object>> results = ULBC_DashboardController.getDonorsByTier();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have tier data');
    }

    @IsTest
    static void testGetDonationsByFund() {
        Test.startTest();
        List<Map<String, Object>> results = ULBC_DashboardController.getDonationsByFund();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have fund data');
        System.assertEquals('Annual Fund', results[0].get('label'));
    }

    @IsTest
    static void testGetGiftsByYear() {
        Test.startTest();
        List<Map<String, Object>> results = ULBC_DashboardController.getGiftsByYear();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have yearly data');
    }

    @IsTest
    static void testGetGiftAidStatus() {
        Test.startTest();
        List<Map<String, Object>> results = ULBC_DashboardController.getGiftAidStatus();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have gift aid data');
    }

    @IsTest
    static void testGetCrewsByRegatta() {
        Test.startTest();
        List<Map<String, Object>> results = ULBC_DashboardController.getCrewsByRegatta();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have regatta data');
        Boolean foundHenley = false;
        for (Map<String, Object> row : results) {
            if (row.get('label') == 'Henley Royal Regatta') {
                foundHenley = true;
                System.assertEquals(2, row.get('value'));
            }
        }
        System.assert(foundHenley, 'Should have Henley Royal Regatta');
    }

    @IsTest
    static void testGetEventAttendance() {
        Test.startTest();
        List<Map<String, Object>> results = ULBC_DashboardController.getEventAttendance();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have event data');
        System.assertEquals('Annual Dinner', results[0].get('eventName'));
        System.assertEquals(4, results[0].get('attendeeCount'));
    }

    @IsTest
    static void testGetActiveCampaigns() {
        Test.startTest();
        List<Campaign> results = ULBC_DashboardController.getActiveCampaigns();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have active campaigns');
        // Both test campaigns (Annual Fund + Annual Dinner) are active
        System.assert(results.size() >= 2, 'Should have at least 2 active campaigns');
    }

    @IsTest
    static void testGetUpgradeProspects() {
        Test.startTest();
        List<Contact> results = ULBC_DashboardController.getUpgradeProspects();
        Test.stopTest();

        // Upgrade prospects are set by DonorTierEngine based on 80% of tier ceiling
        System.assert(results.size() > 0, 'Should have upgrade prospects');
        // Verify ordering: highest rolling 12m first
        if (results.size() > 1) {
            Decimal first = results[0].ULBC_Rolling_12m_Giving__c != null ? results[0].ULBC_Rolling_12m_Giving__c : 0;
            Decimal second = results[1].ULBC_Rolling_12m_Giving__c != null ? results[1].ULBC_Rolling_12m_Giving__c : 0;
            System.assert(first >= second, 'Should be ordered by rolling 12m giving DESC');
        }
    }

    @IsTest
    static void testGetLapsedDonors() {
        Test.startTest();
        List<Contact> results = ULBC_DashboardController.getLapsedDonors();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have lapsed donors');
    }

    @IsTest
    static void testGetRecentDonations() {
        Test.startTest();
        List<Map<String, Object>> results = ULBC_DashboardController.getRecentDonations();
        Test.stopTest();

        System.assert(results.size() > 0, 'Should have recent donations');
        System.assertEquals('Annual Fund', results[0].get('fundName'));
    }

    @IsTest
    static void testGetReportIds() {
        Test.startTest();
        Map<String, Id> ids = ULBC_DashboardController.getReportIds();
        Test.stopTest();
        System.assertNotEquals(null, ids, 'Report IDs map should not be null');
    }

    @IsTest
    static void testGetKPIMetricsNoData() {
        delete [SELECT Id FROM Opportunity];
        delete [SELECT Id FROM ULBC_Crew_History__c];
        delete [SELECT Id FROM CampaignMember];
        delete [SELECT Id FROM Contact];

        Test.startTest();
        Map<String, Object> metrics = ULBC_DashboardController.getKPIMetrics();
        Test.stopTest();

        System.assertEquals(0, (Integer) metrics.get('totalContacts'));
        System.assertEquals(0, (Decimal) metrics.get('totalGiftsAllTime'));
    }

    @IsTest
    static void testEmptyResults() {
        delete [SELECT Id FROM Opportunity];
        delete [SELECT Id FROM ULBC_Crew_History__c];
        delete [SELECT Id FROM CampaignMember];
        delete [SELECT Id FROM Contact];

        Test.startTest();
        List<Map<String, Object>> tiers = ULBC_DashboardController.getDonorsByTier();
        List<Map<String, Object>> funds = ULBC_DashboardController.getDonationsByFund();
        List<Map<String, Object>> years = ULBC_DashboardController.getGiftsByYear();
        List<Map<String, Object>> giftAid = ULBC_DashboardController.getGiftAidStatus();
        List<Map<String, Object>> crews = ULBC_DashboardController.getCrewsByRegatta();
        List<Map<String, Object>> events = ULBC_DashboardController.getEventAttendance();
        List<Campaign> campaigns = ULBC_DashboardController.getActiveCampaigns();
        List<Contact> prospects = ULBC_DashboardController.getUpgradeProspects();
        List<Contact> lapsed = ULBC_DashboardController.getLapsedDonors();
        List<Map<String, Object>> donations = ULBC_DashboardController.getRecentDonations();
        Test.stopTest();

        System.assertEquals(0, tiers.size());
        System.assertEquals(0, funds.size());
        System.assertEquals(0, years.size());
        System.assertEquals(0, giftAid.size());
        System.assertEquals(0, crews.size());
        System.assertEquals(0, prospects.size());
        System.assertEquals(0, lapsed.size());
        System.assertEquals(0, donations.size());
    }
}
