// Sets the Salesforce Site URLs in the ULBC_Stripe_Settings__c custom setting.
// Run after Phase 5A.4 deploy + after the public Site is created and active.
//
//   sf apex run -f scripts/apex/set-stripe-urls.apex --target-org ulbc
//
// Update the values below if the site domain ever changes.

ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
if (s == null) s = new ULBC_Stripe_Settings__c();
if (s.SetupOwnerId == null) s.SetupOwnerId = UserInfo.getOrganizationId();
s.DonationBaseURL__c = 'https://ulbctrustlimited.my.salesforce-sites.com/donate';
s.EventsBaseURL__c   = 'https://ulbctrustlimited.my.salesforce-sites.com/events';
upsert s;

System.debug('DonationBaseURL__c = ' + s.DonationBaseURL__c);
System.debug('EventsBaseURL__c   = ' + s.EventsBaseURL__c);
