# ULBC Trust Salesforce — Decision Log
*Last updated: 2026-04-15*
*Current phase: Phase 4 Complete — Migration Done*

---

## Decisions

### Decision 1.1 — Primary use case is fundraising
- **What**: Fundraising is the core purpose of the Salesforce implementation.
- **Why**: User confirmed this explicitly.
- **Date**: 2026-03-27

### Decision 1.2 — Audience is 1,500 ULBC alumni
- **What**: Primary contact universe is approximately 1,500 alumni of ULBC — all former rowers.
- **Date**: 2026-03-27

### Decision 1.3 — Legal entity is ULBC Trust Limited
- **What**: ULBC Trust Limited is the data controller, registered charity, and Gift Aid entity.
- **Date**: 2026-03-27

### Decision 1.4 — Tyrian is the alumni rowing club with a separate subscription
- **What**: Tyrian has its own subscription fee, tracked separately on the same contact record.
- **Date**: 2026-03-27

### Decision 1.5 — Bank account numbers will NOT be migrated
- **What**: FileMaker Bank Account no field excluded from migration. PCI-DSS / GDPR compliance.
- **Date**: 2026-03-27

### Decision 1.6 — Salesforce Enterprise Edition, no additional email platform
- **What**: Marketing User licences used for bulk email. No Mailchimp/Dotdigital/MCAE.
- **Date**: 2026-03-27

### Decision 1.7 — Stripe integration planned, not in scope for v1
- **What**: Structure placeholder (Stripe Payment ID fields) in place. Integration deferred.
- **Date**: 2026-03-27

### Decision 1.8 — Donor segmentation tiers with automatic upgrade prompts
- **What**: Three cumulative annual giving tiers:
  - Standard: < £240/yr
  - Patron (Mid-value): ≥ £241/yr
  - Major: ≥ £1,000/yr
  - Upgrade alert fires at 80% of tier ceiling (Standard: £192, Patron: £800)
- **Implementation**: ULBC_DonorTierEngine Apex class + ULBC_OpportunityTrigger. Deployed ✅
- **Date**: 2026-03-27

### Decision 1.9 — Two separate subscription tracks on a single contact record
- **What**: ULBC alumni subscription (£100/year) and Tyrian membership (£75/year) tracked separately.
- **Subscription amounts**: ULBC £100/year, Tyrian £75/year — both stored on record, not hardcoded.
- **Date**: 2026-03-27

### Decision 1.10 — Gift Aid registered under ULBC Trust Limited
- **Date**: 2026-03-27

### Decision 1.11 — Contact Type is a single primary classification with additive flags
- **What**: One primary type (evolves). Boolean flags on top: Is Donor, Is Volunteer, Is Tyrian Member.
- **Date**: 2026-03-27

### Decision 1.12 — Contact lifecycle is one-way and automatic
- **What**: Athlete-Student → Alumni transition is MANUAL (admin flips picklist). No automation needed at 10-20 students/year (Decision 2.1).
- **Date**: 2026-03-27

### Decision 1.13 — GDPR legal basis is Legitimate Interests
- **What**: All imported contacts: Legal Basis = "Legitimate Interests — membership relationship".
- **Date**: 2026-03-27

### Decision 1.14 — Events managed via HTML form + Stripe + Salesforce API
- **Date**: 2026-03-27

### Decision 1.15 — Email-based contact matching for event registrations
- **Date**: 2026-03-27

### Decision 1.16 — 5-6 events per year, up to 200 attendees
- **Date**: 2026-03-27

### Decision 1.17 — Boathouse income is out of scope
- **Date**: 2026-03-27

### Decision 1.18 — Recruitment pipeline modelled as Salesforce Leads
- **Date**: 2026-03-27

### Decision 1.19 — Recruitment pipeline is coach-only
- **Date**: 2026-03-27

### Decision 1.20 — Six named users, defined access model
- **Date**: 2026-03-27

### Decision 1.21 — Gift amounts restricted to Admin, Fundraiser, Finance only
- **Date**: 2026-03-27

### Decision 1.22 — Household relationships hidden from Coach and Boathouse Manager
- **Date**: 2026-03-27

### Decision 1.23 — NPSP fully installed, Lite Pae and Sales Insights removed
- **Date**: 2026-03-27

### Decision 1.24 — Education history is a related list, not a single field
- **Implementation**: ULBC_Education_History__c custom object deployed ✅
- **Date**: 2026-03-27

### Decision 1.25 — Institution attended is biographical only, not crew attribution
- **Implementation**: No Institution field on ULBC_Crew_History__c — confirmed in tests ✅
- **Date**: 2026-03-27

### Decision 1.26 — International competition history is a related list on Contact
- **Implementation**: ULBC_International_Competition__c custom object deployed ✅
- **Date**: 2026-03-27

### Decision 1.27 — TDD build sequence: model first, migration last
- **Implementation**: In progress. Phase 1 and 2A/2B complete. Migration in Phase 4.
- **Date**: 2026-03-27

### Decision 1.28 — Jade Smith is the primary test record
- **Implementation**: Jade Smith loaded in org (TrustID: ULBC-0001) ✅
- **Date**: 2026-03-27

---

## Phase 2 Decisions

### Decision 2.1 — Athlete-Student → Alumni transition is manual
- **What**: Admin manually flips Primary Contact Type picklist from Athlete-Student to Alumni on graduation. No trigger or automation needed.
- **Why**: 10-20 students per year. Manual is the right level of complexity.
- **Date**: 2026-04-08

### Decision 2.2 — Is Donor flag is set manually
- **What**: Is Donor checkbox is set manually by admin or fundraiser when first donation is recorded. Not automated by trigger.
- **Why**: The flag is biographical context; the Donor Tier engine handles the financial calculation automatically.
- **Date**: 2026-04-08

### Decision 2.3 — Gone Away drives email opt-out, one-way only
- **What**: Gone Away = true → HasOptedOutOfEmail = true. Gone Away = false → HasOptedOutOfEmail = false. Manual opt-out does NOT set Gone Away.
- **Implementation**: ULBC_ContactTrigger + ULBC_ContactTriggerHandler deployed ✅
- **Date**: 2026-04-08

### Decision 2.4 — Upgrade prospect notification is email to fundraiser
- **What**: When Upgrade Prospect flag is set on Contact, an HTML email is sent to the ULBC Relationship Manager. No in-app notification or Task.
- **Why**: Fundraiser may not be in Salesforce daily. Email works outside the platform. At 5-10 prospects/year, noise is not an issue.
- **Implementation**: Email template deployed (ULBC_UpgradeProspectAlert) ✅. Flow to fire it NOT YET BUILT — blocked on Org-Wide Email Address verification.
- **Date**: 2026-04-08

### Decision 2.5 — ULBC subscription is £100/year, Tyrian is £75/year at launch
- **What**: Launch defaults only. Amounts stored on subscription records, not hardcoded anywhere.
- **Why**: Both will change over time.
- **Date**: 2026-04-08

### Decision 2.6 — Donor tier thresholds are constants in Apex, not custom metadata
- **What**: Standard ceiling (£240), Patron ceiling (£1,000), and upgrade percentage (80%) are defined as constants in ULBC_DonorTierEngine.
- **Why**: These thresholds are stable business rules. If they change, a code change + deployment is appropriate.
- **Future**: Could be moved to Custom Metadata Types if the fundraiser needs to adjust them without a deployment.
- **Date**: 2026-04-08

### Decision 2.7 — Upgrade Prospect flag is manually cleared by fundraiser
- **What**: After the upgrade prospect email alert fires, the fundraiser manually clears the Upgrade Prospect checkbox on the Contact record once they have acted on it. No auto-clear after email send.
- **Why**: At 5-10 prospects/year, manual confirmation is appropriate. The fundraiser needs to confirm they have engaged with the prospect.
- **Date**: 2026-04-08

### Decision 2.8 — Upgrade prospect email goes to a single default recipient
- **What**: Upgrade prospect email alerts are sent to the fundraising manager at info@innovatefundraising.com. Single default recipient for now — not a per-contact Relationship Manager lookup.
- **Why**: Only one fundraiser at launch. Per-contact assignment can be added later if the team grows.
- **Date**: 2026-04-08

### Decision 2.9 — Upgrade prospect email sent from noreply@ulbctrust.org
- **What**: Org-Wide Email Address configured as noreply@ulbctrust.org. Used as the "from" address on the upgrade prospect email alert.
- **Why**: Professional sender identity. Salesforce sends the email — no Gmail routing needed. The address just needs to be verified in Setup → Organization-Wide Email Addresses.
- **Date**: 2026-04-08

---

## Phase 2C Decisions

### Decision 2.10 — Gift Aid tracked at both Contact and Opportunity level
- **What**: Gift Aid declaration data (eligible flag, declaration date, source, postcode, valid from/to) stored on Contact. Per-donation tracking (gift aid eligible checkbox, claimed date) stored on Opportunity.
- **Why**: HMRC compliance requires both the declaration audit trail (Contact) and a record of which specific donations were claimed and when (Opportunity). Resolves OQ-020.
- **Date**: 2026-04-09

### Decision 2.11 — Contact lookup on Subscription and Tyrian Membership is optional (not required) at metadata level
- **What**: ULBC_Contact__c on both ULBC_Subscription__c and ULBC_Tyrian_Membership__c is defined as required=false with deleteConstraint=SetNull.
- **Why**: Salesforce metadata API does not permit a required Lookup field with deleteConstraint=SetNull. The alternatives — Restrict (blocks contact deletion) or Cascade (deletes subscriptions on contact delete) — are both worse for a charity CRM. In practice, the Contact field is always populated; this is a metadata-level constraint only.
- **Date**: 2026-04-09

### Decision 2.12 — Required custom object fields are excluded from permission set FLS entries
- **What**: Fields defined as required=true on custom objects (Amount, Frequency, Status, Start Date on both subscription objects) are not listed in ULBC_Full_Access fieldPermissions.
- **Why**: Salesforce platform rule — required fields and master-detail relationship fields are always readable and editable by anyone with object access. The metadata API rejects permission set deployments that include FLS entries for required fields.
- **Implementation note**: Only optional fields (Contact lookup, Last/Next Payment Date, Stripe Payment ID) need FLS entries in the permission set.
- **Date**: 2026-04-09

---

## Phase 3A Decisions

### Decision 3.1 — Standing funds modelled as standard Campaign records
- **What**: 7 standing funds (Unrestricted/General, Women's Group, Equipment/Fleet, Event, Scholarship, Bursary, Coaching) are standard Salesforce Campaign records with Type=Fund.
- **Why**: Campaign is the standard NPSP mechanism for fund allocation. Donations link to Campaigns via CampaignId. No custom object needed.
- **Date**: 2026-04-15

### Decision 3.2 — Fund list is initial 7, extensible at any time
- **What**: The 7 funds are the launch set. Additional funds can be created as new Campaign records without any code changes.
- **Why**: User confirmed these 7 are sufficient for launch. Resolves OQ-008.
- **Date**: 2026-04-15

### Decision 3.3 — Campaign records are data, not deployable metadata
- **What**: Campaign records created directly in org via Apex anonymous execution. They are not part of the metadata deployment package.
- **Why**: Salesforce Campaign records are data, not metadata — they cannot be deployed via sf project deploy. Test class creates its own records in test context.
- **Date**: 2026-04-15

---

## Phase 3B Decisions

### Decision 3.4 — Recruitment pipeline uses standard Lead object
- **What**: Recruitment prospects are modelled as Salesforce Leads with 6 custom fields. No custom object needed.
- **Why**: Lead object provides built-in conversion to Contact, status tracking, and is the standard Salesforce pattern for prospect pipelines. Decisions 1.18, 1.19.
- **Date**: 2026-04-15

### Decision 3.5 — Lead Gender picklist is Male / Female only
- **What**: ULBC_Gender__c on Lead has two values: Male, Female. Simpler than Contact's 4-value picklist.
- **Why**: Rowing events are gender-binary (Men's / Women's). Coach needs to know which squad the prospect fits. User confirmed.
- **Date**: 2026-04-15

### Decision 3.6 — Current Institution covers schools and universities
- **What**: ULBC_Current_Institution__c is a free-text field labelled "Current School / University".
- **Why**: Prospects may be at school or university before joining ULBC. User confirmed both should be covered.
- **Date**: 2026-04-15

### Decision 3.7 — Pre-ULBC rowing context on Lead record
- **What**: Graduation Year and Current Rowing Event both describe the prospect's situation before joining ULBC, not after.
- **Why**: The coach needs to know when they'd be available (graduation year from current institution) and what events they currently compete in (pre-ULBC). User confirmed.
- **Date**: 2026-04-15

### Decision 3.8 — Not Progressed status for closed-without-conversion leads
- **What**: "Not Progressed" is a closed, non-converted Lead Status for prospects who drop out of the pipeline.
- **Why**: Standard Salesforce requires at least one closed-not-converted status. "Not Progressed" is friendlier than "Closed - Not Converted" for a sports recruitment context.
- **Date**: 2026-04-15

### Decision 3.9 — Lead conversion field mapping is a manual Setup step
- **What**: Custom field mapping (Lead.ULBC_Gender__c → Contact.ULBC_Gender__c) must be configured in Setup → Object Manager → Lead → Map Lead Fields. Post-conversion, admin manually sets Contact.ULBC_Primary_Contact_Type__c = 'Athlete-Student' and assigns ULBC_Trust_ID__c.
- **Why**: Salesforce Lead conversion field mapping is UI-only configuration — it cannot be deployed via metadata API.
- **Date**: 2026-04-15

### Decision 3.10 — Coach-only Lead visibility implemented via permission sets
- **What**: Lead object only granted to ULBC_Coach permission set. Other role permission sets (Fundraiser, Finance, Event Organiser, Boathouse Manager) have no Lead access.
- **Why**: Only Coach + Admin need recruitment pipeline visibility. Permission sets are additive — no Lead grant = no Lead access.
- **Implementation**: ULBC_Coach permission set includes Lead object + all Lead custom fields + ConvertLeads + EditTask permissions. ✅
- **Date**: 2026-04-15

---

## Phase 3C Decisions

### Decision 3.11 — 5 role-specific permission sets replace ULBC_Full_Access for non-admin users
- **What**: Each non-admin user gets their role-specific permission set only. ULBC_Full_Access remains for admin use.
- **Why**: Additive permission model — each role sees only what's granted. FLS on custom fields controls field visibility per role.
- **Date**: 2026-04-15

### Decision 3.12 — Auto-TrustID on Contact insert
- **What**: ULBC_ContactTriggerHandler.assignTrustId fires on before insert. Queries highest existing ULBC-XXXX and assigns next sequential number. Pre-set TrustIDs (migration) are not overwritten.
- **Why**: Removes manual TrustID assignment step. Ensures every Contact gets a unique TrustID automatically, including those created via Lead conversion.
- **Date**: 2026-04-15

### Decision 3.13 — Current Athletes list view for Coach/Boathouse Manager
- **What**: Contact list view filtered to Primary Contact Type = Athlete-Student. Soft boundary — coach can still search for alumni by name if needed (useful for recruitment referrals).
- **Why**: Coach's working view should show only current athletes. Hard sharing rules would block useful alumni access and add complexity not warranted at this scale.
- **Date**: 2026-04-15

### Decision 3.14 — Coach needs Account + Contact + Lead + ConvertLeads + EditTask
- **What**: Coach permission set includes Account (create/read/edit), Contact (create/read/edit), Lead (create/read/edit), plus ConvertLeads and EditTask system permissions.
- **Why**: Lead conversion creates a Household Account (NPSP) and Contact. ConvertLeads requires EditTask as a dependency. Coach must be able to create and edit athlete Contact records.
- **Date**: 2026-04-15

### Decision 3.15 — Required fields excluded from permission set FLS (platform rule)
- **What**: ULBC_Primary_Contact_Type__c (required=true) is not listed in any permission set FLS entries.
- **Why**: Salesforce rejects permission set deployments that include FLS entries for required fields. Required fields are always readable/editable by anyone with object access. Same as Decision 2.12.
- **Date**: 2026-04-15

### Decision 3.16 — Event Organiser can read Education History, Crew History, International Competition
- **What**: Event Organiser permission set includes read-only access to the three history related list objects.
- **Why**: User confirmed Event Organiser needs visibility into attendee backgrounds for event context.
- **Date**: 2026-04-15

### Decision 3.17 — Events modelled as Campaign records with Type = 'Event'
- **What**: Each event is a Campaign record with Type = 'Event', distinguishing them from standing fund Campaigns (Type = 'Fund').
- **Why**: Reuses standard Campaign + CampaignMember infrastructure. No custom objects needed for 5-6 events/year.
- **Date**: 2026-04-15

### Decision 3.18 — Event times stored as custom Time fields on Campaign
- **What**: ULBC_Start_Time__c and ULBC_End_Time__c (Time type) pair with standard StartDate/EndDate fields.
- **Why**: Standard Campaign date fields are date-only (no time component). Custom Time fields give full date-time coverage.
- **Date**: 2026-04-15

### Decision 3.19 — Venue and Ticket Price as custom Campaign fields
- **What**: ULBC_Venue__c (Text 255) and ULBC_Ticket_Price__c (Currency 8,2) added to Campaign.
- **Why**: User confirmed these are needed for event records. Max Capacity excluded — not needed at this stage.
- **Date**: 2026-04-15

### Decision 3.20 — CampaignMember statuses set up manually per event campaign
- **What**: Four custom statuses (Invited, Registered, Attended, No-Show) are created manually per event Campaign — not deployable metadata.
- **Why**: CampaignMemberStatus is per-campaign data, not org-wide metadata. With 5-6 events/year, manual setup is low burden. Consistent with Decision 3.1 (standing funds as data, not metadata).
- **Date**: 2026-04-15

### Decision 4.1 — Migration tool: Python script with simple_salesforce
- **What**: Phase 4 migration uses a Python script (`data/migrate.py`) with simple_salesforce bulk API for all data import.
- **Why**: Complex field mapping, data cleaning (encoding artefacts, date parsing), and cross-table joins (Crew Code ↔ Crew Name) make Python the best fit. Batch upsert on ULBC_Trust_ID__c for Contacts.
- **Date**: 2026-04-15

### Decision 4.2 — Mem Type mapping: A→Alumni, S/O/P/D→Other
- **What**: FileMaker Mem Type mapped to Primary Contact Type. A=Alumni, all others=Other. D=Deceased sets npsp__Deceased__c flag. Original Mem Type + Sub Code stored in Contact Description.
- **Why**: Only Alumni is a meaningful contact type. S (Subscription), O (Other), P (Partner) don't warrant separate types. Deceased is a status flag, not a type.
- **Date**: 2026-04-15

### Decision 4.3 — All Accounts.csv rows imported as Opportunities
- **What**: All 26,980 transaction rows imported as Opportunity records (Closed Won). Account code S → Gift Type Regular, DM → One-off, DN → Fund Type Restricted. Original account code stored in Description.
- **Why**: User wants full payment history tracked. Subscription payments (S, 24k rows) are individual payment records linked to the member Contact.
- **Date**: 2026-04-15

### Decision 4.4 — Notes imported as standard Note object
- **What**: 407 FileMaker notes imported as standard Salesforce Note records linked to Contact via ParentId.
- **Why**: ContentNote API not available via REST. Standard Note object achieves the same result.
- **Date**: 2026-04-15

### Decision 4.5 — New Contact fields for migration data
- **What**: Four new Contact fields added: ULBC_Profession__c (Text), ULBC_Other_Interests__c (LTA), ULBC_Special_Skills__c (LTA), ULBC_Follow_Up_Notes__c (LTA). Plus ULBC_Rowing_Position__c (Number) on Crew History.
- **Why**: Source data has populated values (60–56 records for interests/skills, 55 for follow-up notes, many for profession). User confirmed all should be preserved.
- **Date**: 2026-04-15

---

## Phase 5 Decisions — Stripe Integration (Added 2026-04-27)

### Decision 5.1 — Stripe handles website donations and event ticketing only
- **What**: Stripe is the payment rail for (a) one-off website donations and (b) event ticketing for dinners, BBQs, and similar paid events. Recurring subscriptions (Tyrian, ULBC) continue to come through bank account (Direct Debit / standing order) and will be ingested via Xero, NOT Stripe.
- **Why**: Stripe usage analysis (April 2026) showed extremely low subscription volume — one active legacy subscription (Bethany Welch, £80/yr Student plan from 2014) and three payments in the last 12 months. The bank account is the real source of recurring giving. There is no business case for migrating bank subscriptions to Stripe.
- **Implication**: ULBC_Subscription__c and ULBC_Tyrian_Membership__c objects will NOT have Stripe integration in v1. Their Stripe Payment ID fields remain placeholders.
- **Date**: 2026-04-27

### Decision 5.2 — Build path: custom Apex + webhooks (no AppExchange package)
- **What**: Stripe integration built as custom Apex REST endpoint receiving Stripe webhooks. No AppExchange package (Chargent, Blackthorn etc.) and no middleware (Zapier, Make).
- **Why**: Free, full control over data model mapping, version-controlled in metadata. Existing data model fits cleanly. AppExchange packages add £30-100/user/month recurring cost for a low-volume use case.
- **Date**: 2026-04-27

### Decision 5.3 — Salesforce-side first; donate page rebuild deferred
- **What**: Build the Salesforce-side webhook receiver and event ticketing flow first. The website donate page rebuild (currently a basic WP Simple Pay form on WordPress at fixed £25) is deferred — depends on broader website rebuild discussion that is out of scope for now. Salesforce-side build is independent: same webhook handler will accept donations from any Stripe source when the page is eventually rebuilt.
- **Why**: Stripe is the integration boundary, not WordPress. Building to that boundary first means we're not blocked on someone else's calendar (the WordPress site is managed by a third party). Event ticketing is the immediate use case.
- **Date**: 2026-04-27

### Decision 5.4 — Event registration via Salesforce Site + LWC
- **What**: Public event registration pages built as a Salesforce Site (free, hosted on the org) with a Lightning Web Component that renders event details from the Campaign record and handles Stripe Checkout. URL pattern: `ulbctrust.my.site.com/events/<campaign-name>`.
- **Why**: Each Event Campaign IS the page — Campaign Name, Start Time, End Time, Venue, Ticket Price fields (deployed in Phase 3D) populate the page. No separate "build a website" step per event. Adding a new dinner = creating a new Campaign record. Salesforce Sites are free and metadata-deployed.
- **Date**: 2026-04-27

### Decision 5.5 — Single ticket price per event in v1
- **What**: Each event has one ticket price (existing ULBC_Ticket_Price__c field on Campaign). Multi-tier ticketing (alumni / student / guest at different prices) deferred to v2.
- **Why**: Ship the working core first. Multi-tier requires a child Event_Ticket_Type__c object with name/price/capacity/Stripe Price ID — about a day's extra build work. Most events can be single-price; tiered events can be handled by listing two events for now.
- **Date**: 2026-04-27

### Decision 5.6 — Soft cap on event capacity
- **What**: Event registration form shows "limited availability" warnings as capacity approaches but does not refuse to sell beyond the capacity number. Allows overbooking.
- **Why**: For dinners and BBQs, the registrar (fundraiser/event organiser) can manage edge cases manually. Hard cap creates failure modes when there's a queue at capacity. Soft cap matches how the events run in practice.
- **Date**: 2026-04-27

### Decision 5.7 — TrustID-personalised links for known alumni
- **What**: Event registration LWC accepts a `?c=ULBC-XXXX` URL parameter. When present, the page pre-fills name/email from the matching Contact and the Stripe Checkout metadata includes `trust_id` for reliable Contact matching on the webhook side. Anonymous registration (no TrustID) still works via email-based matching.
- **Why**: Alumni clicking from an emailed event invitation get a friction-free registration. Webhook can match on TrustID (reliable) rather than email (which may be different to what's on file). Building this in v1 because the email comms work in Phase 3D will produce these links anyway.
- **Date**: 2026-04-27

### Decision 5.8 — Contact matching priority for Stripe webhooks
- **What**: When a Stripe webhook fires (donation or event ticket), Salesforce matches the donor to a Contact in this priority order:
  1. TrustID from Stripe metadata (if present, e.g. from personalised email link)
  2. Stripe Customer ID match (existing ULBC_Stripe_Customer_ID__c on Contact)
  3. Email match (Contact.Email or ULBC_Secondary_Email__c)
  4. Create new Contact: Primary Contact Type = "Other", Acquisition Channel = "Stripe Donation" or "Stripe Event Registration"
- **Why**: Avoids duplicate Contacts where possible. New Contact creation on no-match means we never lose a donor's data. Acquisition Channel field already exists from Phase 1.
- **Date**: 2026-04-27

### Decision 5.9 — Stripe metadata contract
- **What**: Every Stripe Checkout Session created (whether by the future donate page or the event ticketing LWC) MUST include the following metadata keys for Salesforce to process correctly:
  - `intent`: "donation" | "event_ticket" | "subscription"
  - `fund`: Campaign ID or fund slug (donations only)
  - `trust_id`: ULBC-XXXX (if known)
  - `gift_aid`: "true" | "false" (donations only)
  - `gift_aid_postcode`: postcode string (donations with gift_aid=true)
  - `gift_type`: "One-Off" | "Recurring" (donations only)
  - `campaign_id`: Salesforce Campaign 18-char ID (event tickets only)
- **Why**: Webhook handler is a switch on `intent`. Without consistent metadata, the handler can't route correctly. This contract is the formal interface between any front-end and Salesforce.
- **Date**: 2026-04-27

### Decision 5.10 — New Salesforce fields for Stripe integration
- **What**: Three new fields added in Phase 5A:
  - Contact: `ULBC_Stripe_Customer_ID__c` — Text(255), External ID, Unique
  - CampaignMember: `ULBC_Stripe_Payment_ID__c` — Text(255), External ID, Unique
  - Permission set updates: ULBC_Full_Access (R/W), ULBC_Finance (R/W), ULBC_Fundraiser (R/W), ULBC_Event_Organiser (R/W on CampaignMember field only)
- **Why**: Stripe Customer ID on Contact enables Stripe→Salesforce matching for repeat donors. Payment ID on CampaignMember provides audit trail for paid event attendees and prevents duplicate processing.
- **Note**: Subscription ID fields on ULBC_Subscription__c / ULBC_Tyrian_Membership__c NOT added — see Decision 5.1.
- **Date**: 2026-04-27

### Decision 5.11 — Public Apex REST endpoint via Salesforce Site
- **What**: Webhook receiver exposed as a public Apex REST endpoint (e.g. `/services/apexrest/stripe/webhook`) on a Salesforce Site. No authentication header required (Stripe doesn't send one), but every payload is validated using Stripe's webhook signing secret before any processing happens.
- **Why**: Stripe webhooks come from Stripe's servers — they need an unauthenticated endpoint. Signature verification is the security boundary. Salesforce Sites are free.
- **Implementation**: Apex class `ULBC_StripeWebhookController` with `@HttpPost` method that verifies signature, parses event, dispatches to typed handler classes per event type.
- **Date**: 2026-04-27

### Decision 5.12 — Bethany Welch legacy subscription grandfathered for now
- **What**: The one active legacy Stripe subscription (Bethany Welch, £80/yr Student plan, started 2014-10-12) remains active at £80/yr. No automatic migration to the new £100/yr ULBC Subscription model.
- **Why**: One person. Manual decision belongs to the fundraiser, not to automation. Logged as OQ-025 for follow-up.
- **Date**: 2026-04-27

### Decision 5.13 — Gift Aid capture must happen at point of donation in any rebuild
- **What**: When the website donate page is rebuilt (timing TBD, separate decision), the new page MUST capture Gift Aid declarations inline. Until then, the existing manual paper/email Gift Aid process remains.
- **Why**: Gift Aid uplift is 25% per eligible donation — the single highest-value capture in the entire fundraising stack. Industry data: integrated donate page Gift Aid capture rates are 60-80%; separate-form processes 20-40%. Locking this as a requirement now prevents the rebuild from shipping without it.
- **Implementation note**: Stripe Checkout's standard fields don't capture Gift Aid; whatever front-end is built (GiveWP, custom, etc.) must collect it and pass via metadata per Decision 5.9.
- **Date**: 2026-04-27

---

## Phase 6 Decisions — Xero Integration (Added 2026-04-27)

### Decision 5.14 — Identity bridging strategy (Stripe → Contact)
- **What**: Two-mechanism approach for linking anonymous Stripe payments back to the right Salesforce Contact.
  1. **Personalised URL parameter** (primary): every fundraising email and event invite sent from Salesforce includes a unique link with `?ulbc_trust_id=ULBC-XXXX` embedded. The donate/event page reads the parameter and passes it to Stripe Checkout as `metadata.ulbc_trust_id`. Webhook handler matches Contact by `ULBC_Trust_ID__c`.
  2. **Email match at checkout** (secondary): for donors arriving without a personalised link (cold web traffic), Stripe Checkout collects email by default; webhook handler matches by `Contact.Email` or `ULBC_Secondary_Email__c`.
  3. **No-match fallback**: webhook creates a new Contact with Acquisition Channel = "Stripe Donation" or "Stripe Event Registration", flagged for manual review by Fundraiser.
- **Why**: Personalised links handle the bulk of identified income (email-driven fundraising). Email match catches repeat web donors. Manual review handles genuinely new donors. Considered and rejected: a public dropdown / search of all Contact names — GDPR violation (publishing 1,500 alumni names without consent has no lawful basis under UK GDPR Art. 6); also a safeguarding risk for estranged or "Gone Away" individuals.
- **Implementation**: New formula field `Contact.ULBC_Donation_Link__c` constructs the personalised URL by concatenating a base URL (from Custom Setting `ULBC_Stripe_Settings__c.DonationBaseURL__c`) with the Trust ID. Used as merge field `{!Contact.ULBC_Donation_Link__c}` in any Salesforce email template.
- **Date**: 2026-04-27

### Decision 5.15 — Salesforce-hosted donate page for personalised giving
- **What**: Build a public donate page on the same Salesforce Site as event ticketing (per Decision 5.4). Personalised donation links from Salesforce email go to this page; cold web traffic continues to use the existing WordPress donate page until WordPress is rebuilt (OQ-026).
- **Why**: Eliminates the third-party WordPress dependency for identified donations. Reuses the Site/LWC/Stripe infrastructure already being built for events. Collapses Phase 5B (donation flow) into Phase 5A — no separate sub-phase needed.
- **Implementation**: New LWC `ulbcDonate` reads `ulbc_trust_id` and `fund` from URL parameters, calls Apex method `ULBC_StripeCheckoutController.createDonationSession()`, redirects to Stripe Checkout. Webhook handler routes by `metadata.intent = "donation"` per Decision 5.9.
- **Implication**: Phase 5B is now closed and merged into 5A.3 (donation handler) + 5A.4 (donate LWC alongside event LWC). PRD section 15 updated accordingly.
- **Date**: 2026-04-27

### Decision 5.9 — Stripe metadata contract — AMENDED 2026-04-27
- **Amendment**: The metadata key `trust_id` is renamed to `ulbc_trust_id` for clarity in the Stripe Dashboard. Field name on Salesforce Contact (`ULBC_Trust_ID__c`) is unchanged.
- **Why**: Anyone reading a Stripe payload metadata block now sees `ulbc_trust_id: ULBC-0042` and the link to the Salesforce field is unambiguous. Free change — no code yet written against the old name.
- **Original decision text below remains otherwise valid.**


### Decision 6.1 — Xero is the source of truth for finance; Salesforce is the source of truth for fundraising
- **What**: ULBC Trust uses Xero for statutory accounts, bank reconciliation, charity accounts (SORP), and audit. Salesforce holds the fundraising and donor relationship data. The two systems are integrated: every donation that creates an Opportunity in Salesforce also creates a paid invoice in Xero. Bank deposits from Stripe are reconciled in Xero against those invoices.
- **Why**: Finance Person works exclusively in Xero. Fundraiser/Admin work in Salesforce. The integration bridges the workflow boundary so that both can do their jobs without manual transcription.
- **Date**: 2026-04-27

### Decision 6.2 — Xero goal: invoices in Xero AND Stripe reconciliation
- **What**: Both flows are in scope:
  - **Salesforce Opportunity → Xero Invoice**: every Closed Won Opportunity creates a paid invoice in Xero (custom Apex build).
  - **Stripe → Xero bank deposit feed**: native Xero feature, enabled by Finance Person. Imports Stripe payouts as bank transactions in Xero, reconciled against the invoices created above.
- **Why**: Together they give complete audit trail from donor → invoice → bank deposit. Each donation traceable end-to-end without spreadsheets.
- **Date**: 2026-04-27

### Decision 6.3 — Build path: custom Apex + Xero REST API (not Breadwinner)
- **What**: Xero integration built as custom Apex extending the existing webhook layer. When the Stripe webhook creates an Opportunity, the same handler also calls Xero's REST API to create the matching invoice. NO AppExchange package (Breadwinner, Workato).
- **Why**: Reuses the Apex infrastructure already being built for Stripe. Marginal cost is small relative to standalone Breadwinner (~£150-200/month = £1,800-2,400/yr). Custom code maps directly to ULBC's data model (funds → account codes, gift types → tracking categories).
- **Trade-off**: Requires developer time for any future schema changes. Acceptable given the controlled scope.
- **Date**: 2026-04-27

### Decision 6.4 — Stripe-Xero bank reconciliation handled in Xero, not Salesforce
- **What**: The Stripe→Xero bank deposit import is a NATIVE Xero feature (Xero Stripe feed, included in standard Xero subscription). Configured once in Xero by the Finance Person — not built in Salesforce.
- **Why**: Xero's built-in Stripe feed is mature, free, and handles fees, refunds, currency, and timing correctly. Replicating it in Salesforce would be redundant engineering.
- **Implementation**: Finance Person enables the Stripe feed in Xero (Banking → Add Bank Account → Stripe). 30-minute config. Out of scope for the Salesforce build.
- **Date**: 2026-04-27

### Decision 6.5 — Xero invoice creation triggered by Opportunity Closed Won, not Stripe webhook
- **What**: The Xero invoice is created when an Opportunity moves to Closed Won, regardless of whether it came from Stripe, bank transfer, or manual entry. This is implemented as an Opportunity trigger (after insert/update), not directly off the Stripe webhook.
- **Why**: Decouples Xero from Stripe. Bank-collected donations (Direct Debit, standing orders) entered manually into Salesforce also need Xero invoices. Tying invoice creation to the Stripe webhook would miss these. Closed Won is the financial event of record.
- **Implementation**: New trigger `ULBC_OpportunityXeroSync` (after insert/update on StageName change to Closed Won). Handler class `ULBC_XeroInvoiceService.createInvoiceForOpportunity(oppId)`.
- **Date**: 2026-04-27

### Decision 6.6 — Xero connection via OAuth 2.0 stored in Named Credentials
- **What**: Salesforce → Xero authentication uses OAuth 2.0 with refresh token stored in a Named Credential. Initial auth done once by Admin during setup. Refresh handled automatically by Apex on token expiry.
- **Why**: Xero requires OAuth 2.0 (no legacy API key auth). Named Credentials are Salesforce's standard pattern for this — credentials never appear in Apex code, fully managed in Setup.
- **Implementation**: Connected App registered in Xero developer portal (one-time, by Adrian). Named Credential `ULBC_Xero` created in Salesforce. Custom metadata for Xero org ID, default account codes.
- **Date**: 2026-04-27

### Decision 6.7 — Chart of accounts mapping owned by Finance Person
- **What**: The mapping from Salesforce fund/gift type to Xero account codes and tracking categories is a finance decision, not a developer decision. The Finance Person specifies the mapping; Adrian encodes it in Custom Metadata Records (one record per fund Campaign + gift type combination).
- **Why**: Account code structure is a charity accounting decision affected by SORP, restricted/unrestricted fund rules, and HMRC reporting. Belongs to whoever signs off the accounts.
- **Implementation**: Custom Metadata Type `ULBC_Xero_Account_Mapping__mdt` with fields: Fund Campaign, Gift Type, Xero Account Code, Xero Tracking Category, Notes. Apex reads this at runtime when building the invoice.
- **Date**: 2026-04-27
- **Blocked on**: OQ-026 (Finance Person to provide mapping).

### Decision 6.8 — Xero Contact creation strategy: match-or-create per Salesforce Contact
- **What**: Each Salesforce Contact that has a donation gets a corresponding Xero Contact. Match priority: Xero Contact ID stored on Salesforce Contact > email match > create new. Xero Contact ID stored on Salesforce Contact in new field.
- **Why**: Xero invoices need a Customer (Contact). Per-donor invoices give the Finance Person full visibility — donor name on every invoice. Creating one Xero Contact per Salesforce Contact keeps the model clean.
- **Implementation**: New Contact field `ULBC_Xero_Contact_ID__c` (Text 255, External ID, Unique). Created lazily — only when a Contact has a donation that needs invoicing.
- **Date**: 2026-04-27

