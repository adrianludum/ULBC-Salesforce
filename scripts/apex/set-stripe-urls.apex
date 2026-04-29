// Sets the Salesforce Site URLs in the ULBC_Stripe_Settings__c custom setting.
// Run after Phase 5A.4 deploy + after the public Site is created and active.
//
//   sf apex run -f scripts/apex/set-stripe-urls.apex --target-org ulbc
//
// Update the values below if the site domain ever changes.

// Site has urlPathPrefix=donate (set in Setup during 5A.4), so:
//   /donate                (= Site root, served via indexPage=donate)
//   /donate/events         (= events.page on the Site)
// Using /events here (no /donate prefix) works only via the Site's
// 301 redirect to /donate/events; canonical form below avoids the hop.
ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
if (s == null) s = new ULBC_Stripe_Settings__c();
if (s.SetupOwnerId == null) s.SetupOwnerId = UserInfo.getOrganizationId();
s.DonationBaseURL__c = 'https://ulbctrustlimited.my.salesforce-sites.com/donate';
s.EventsBaseURL__c   = 'https://ulbctrustlimited.my.salesforce-sites.com/donate/events';
upsert s;

System.debug('DonationBaseURL__c = ' + s.DonationBaseURL__c);
System.debug('EventsBaseURL__c   = ' + s.EventsBaseURL__c);
