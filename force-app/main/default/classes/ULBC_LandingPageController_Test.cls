@IsTest
private class ULBC_LandingPageController_Test {

    @TestSetup
    static void setup() {
        Campaign c = new Campaign(
            Name = 'Test Dinner 2025',
            Type = 'Dinner',
            Status = 'Planned',
            IsActive = true,
            StartDate = Date.newInstance(2025, 11, 15),
            ULBC_Venue__c = 'ULBC Boathouse',
            ULBC_Ticket_Price__c = 75.00,
            ULBC_Dress_Code__c = 'Black Tie',
            ULBC_Start_Time__c = Time.newInstance(19, 0, 0, 0),
            ULBC_End_Time__c = Time.newInstance(23, 0, 0, 0)
        );
        insert c;
    }

    @IsTest
    static void test_getCampaignDetails() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Dinner 2025' LIMIT 1];

        Test.startTest();
        ULBC_LandingPageController.CampaignDetails d =
            ULBC_LandingPageController.getCampaignDetails(camp.Id);
        Test.stopTest();

        System.assertEquals('Test Dinner 2025', d.name);
        System.assertEquals('ULBC Boathouse', d.venue);
        System.assertEquals(75.00, d.ticketPrice);
        System.assertEquals('Black Tie', d.dressCode);
        System.assertEquals('19:00', d.startTime);
        System.assertEquals('23:00', d.endTime);
        System.assertEquals('Dinner', d.campaignType);
    }

    @IsTest
    static void test_saveLandingPage() {
        Campaign camp = [SELECT Id FROM Campaign WHERE Name = 'Test Dinner 2025' LIMIT 1];

        Test.startTest();
        ULBC_LandingPageController.saveLandingPage(
            camp.Id,
            '<html>test</html>',
            'Starter: Soup\nMain: Beef',
            'Smart Casual',
            'Near Chiswick station',
            'price_test123',
            'A great dinner',
            85.00,
            'New Venue',
            '18:30',
            '22:30'
        );
        Test.stopTest();

        Campaign updated = [
            SELECT ULBC_Landing_Page_HTML__c, ULBC_Menu__c, ULBC_Dress_Code__c,
                   ULBC_Transport_Info__c, ULBC_Stripe_Price_ID__c, Description,
                   ULBC_Ticket_Price__c, ULBC_Venue__c, ULBC_Start_Time__c, ULBC_End_Time__c
            FROM Campaign WHERE Id = :camp.Id
        ];

        System.assertEquals('<html>test</html>', updated.ULBC_Landing_Page_HTML__c);
        System.assertEquals('Starter: Soup\nMain: Beef', updated.ULBC_Menu__c);
        System.assertEquals('Smart Casual', updated.ULBC_Dress_Code__c);
        System.assertEquals('Near Chiswick station', updated.ULBC_Transport_Info__c);
        System.assertEquals('price_test123', updated.ULBC_Stripe_Price_ID__c);
        System.assertEquals('A great dinner', updated.Description);
        System.assertEquals(85.00, updated.ULBC_Ticket_Price__c);
        System.assertEquals('New Venue', updated.ULBC_Venue__c);
        System.assertEquals(Time.newInstance(18, 30, 0, 0), updated.ULBC_Start_Time__c);
        System.assertEquals(Time.newInstance(22, 30, 0, 0), updated.ULBC_End_Time__c);
    }
}
