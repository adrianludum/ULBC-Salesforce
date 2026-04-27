public with sharing class ULBC_LandingPageController {

    public class CampaignDetails {
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String venue;
        @AuraEnabled public Decimal ticketPrice;
        @AuraEnabled public String dressCode;
        @AuraEnabled public String menu;
        @AuraEnabled public String transportInfo;
        @AuraEnabled public String stripePriceId;
        @AuraEnabled public String landingPageHtml;
        @AuraEnabled public String campaignType;
    }

    @AuraEnabled(cacheable=true)
    public static CampaignDetails getCampaignDetails(Id campaignId) {
        Campaign c = [
            SELECT Name, Description, StartDate, EndDate, Type,
                   ULBC_Start_Time__c, ULBC_End_Time__c, ULBC_Venue__c,
                   ULBC_Ticket_Price__c, ULBC_Dress_Code__c, ULBC_Menu__c,
                   ULBC_Transport_Info__c, ULBC_Stripe_Price_ID__c,
                   ULBC_Landing_Page_HTML__c
            FROM Campaign
            WHERE Id = :campaignId
            LIMIT 1
        ];

        CampaignDetails d = new CampaignDetails();
        d.name = c.Name;
        d.description = c.Description;
        d.startDate = c.StartDate;
        d.endDate = c.EndDate;
        d.startTime = c.ULBC_Start_Time__c != null ? formatTime(c.ULBC_Start_Time__c) : '';
        d.endTime = c.ULBC_End_Time__c != null ? formatTime(c.ULBC_End_Time__c) : '';
        d.venue = c.ULBC_Venue__c;
        d.ticketPrice = c.ULBC_Ticket_Price__c;
        d.dressCode = c.ULBC_Dress_Code__c;
        d.menu = c.ULBC_Menu__c;
        d.transportInfo = c.ULBC_Transport_Info__c;
        d.stripePriceId = c.ULBC_Stripe_Price_ID__c;
        d.landingPageHtml = c.ULBC_Landing_Page_HTML__c;
        d.campaignType = c.Type;
        return d;
    }

    @AuraEnabled
    public static void saveLandingPage(Id campaignId, String html,
                                        String menu, String dressCode,
                                        String transportInfo, String stripePriceId,
                                        String description, Decimal ticketPrice,
                                        String venue, String startTime, String endTime) {
        Campaign c = new Campaign(Id = campaignId);
        c.ULBC_Landing_Page_HTML__c = html;
        if (menu != null) c.ULBC_Menu__c = menu;
        if (dressCode != null) c.ULBC_Dress_Code__c = dressCode;
        if (transportInfo != null) c.ULBC_Transport_Info__c = transportInfo;
        if (stripePriceId != null) c.ULBC_Stripe_Price_ID__c = stripePriceId;
        if (description != null) c.Description = description;
        if (ticketPrice != null) c.ULBC_Ticket_Price__c = ticketPrice;
        if (venue != null) c.ULBC_Venue__c = venue;
        if (startTime != null) c.ULBC_Start_Time__c = parseTime(startTime);
        if (endTime != null) c.ULBC_End_Time__c = parseTime(endTime);
        update c;
    }

    private static String formatTime(Time t) {
        Integer h = t.hour();
        Integer m = t.minute();
        return String.valueOf(h).leftPad(2, '0') + ':' + String.valueOf(m).leftPad(2, '0');
    }

    private static Time parseTime(String s) {
        if (String.isBlank(s)) return null;
        List<String> parts = s.split(':');
        if (parts.size() < 2) return null;
        return Time.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 0, 0);
    }
}
