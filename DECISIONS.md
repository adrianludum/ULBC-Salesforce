# ULBC Trust Salesforce — Decision Log
*Last updated: 2026-04-28 (evening — email auth setup)*
*Current phase: Phase 5A.3 Complete — Site + LWCs next (5A.4); email deliverability (Decision 5.20) in flight*

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
- **Implementation**: Jade Smith loaded in org (Trust ID: ULBC-0001) ✅
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

### Decision 3.12 — Auto-Trust ID on Contact insert
- **What**: ULBC_ContactTriggerHandler.assignTrustId fires on before insert. Queries highest existing ULBC-XXXX and assigns next sequential number. Pre-set Trust IDs (migration) are not overwritten.
- **Why**: Removes manual Trust ID assignment step. Ensures every Contact gets a unique Trust ID automatically, including those created via Lead conversion.
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

### Decision 5.7 — Trust ID-personalised links for known alumni
- **What**: Event registration LWC accepts a `?c=ULBC-XXXX` URL parameter. When present, the page pre-fills name/email from the matching Contact and the Stripe Checkout metadata includes `trust_id` for reliable Contact matching on the webhook side. Anonymous registration (no Trust ID) still works via email-based matching.
- **Why**: Alumni clicking from an emailed event invitation get a friction-free registration. Webhook can match on Trust ID (reliable) rather than email (which may be different to what's on file). Building this in v1 because the email comms work in Phase 3D will produce these links anyway.
- **Date**: 2026-04-27

### Decision 5.8 — Contact matching priority for Stripe webhooks
- **What**: When a Stripe webhook fires (donation or event ticket), Salesforce matches the donor to a Contact in this priority order:
  1. Trust ID from Stripe metadata (if present, e.g. from personalised email link)
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

---

## Phase 5A Decisions — additions 2026-04-28

### Decision 5.16 — Site URL strategy for v1: My Domain only, custom domain deferred
- **What**: For v1, Salesforce Site URLs use the existing My Domain hostname `ulbctrustlimited.my.site.com` (org has enhanced domains; My Domain Name = `ulbctrustlimited`, confirmed in Setup 2026-04-28). Site URL Path Prefix is left blank, so URLs are `ulbctrustlimited.my.site.com/events/<campaign>` and `ulbctrustlimited.my.site.com/donate`. A custom domain (e.g. `events.ulbctrust.org`) is deferred to v2 because it requires DNS access for `ulbctrust.org`, which is out of scope for this build window.
- **Why**: The existing My Domain is already brandable and respectable for fundraising emails — no rename needed. Custom domain can be layered on top later without changing Apex or LWC code; only the Custom Setting `DonationBaseURL__c` gets updated.
- **Implication**: OQ-028 closed for v1. The Stripe webhook endpoint URL (OQ-027) will be `https://ulbctrustlimited.my.site.com/services/apexrest/stripe/webhook`; `DonationBaseURL__c` will be set to `https://ulbctrustlimited.my.site.com/donate` once the Site is deployed in 5A.4.
- **Date**: 2026-04-28

### Decision 5.17 — Charity Commission registration number recorded
- **What**: ULBC Trust Limited is registered with the Charity Commission of England & Wales, charity number **1174721**. Recorded in PRD §2 (Legal & Organisational Context). To be referenced when Gift Aid HMRC R68 submission tooling is built (post-v1, separate phase).
- **Why**: Required on every HMRC Gift Aid claim. Recording centrally so it's not chased again when the claim flow is built.
- **Implementation**: PRD §2 updated. No schema change yet — when claim tooling is built, will live in a Custom Metadata Record or a single Custom Setting field alongside the HMRC submission credentials.
- **Date**: 2026-04-28

### Decision 5.18 — Phase 5A.2 schema: ULBC_Webhook_Log__c + WebhookSigningSecret__c
- **What**: Webhook receiver writes one `ULBC_Webhook_Log__c` row per delivery. Schema:
  - `ULBC_Stripe_Event_ID__c` (Text 255, External ID, **Unique**) — DB-level idempotency; replays raise DUPLICATE_VALUE caught by the handler and logged as `Status = Duplicate`.
  - `ULBC_Stripe_Event_Type__c` (Text 100), `ULBC_Stripe_Timestamp__c` (DateTime, parsed from header `t=`), `ULBC_Processed_At__c` (DateTime, required), `ULBC_Status__c` (Picklist, required: Verified | Signature Invalid | Signature Expired | Signature Missing | Malformed | Duplicate | Error).
  - `ULBC_Raw_Payload__c` (LTA 131072), `ULBC_Payload_Truncated__c` (Checkbox), `ULBC_Signature_Header__c` (LTA 1024), `ULBC_Error_Message__c` (LTA 4096).
  - Signing secret stored on `ULBC_Stripe_Settings__c.WebhookSigningSecret__c` (Text 255, hierarchy custom setting). Hierarchy reads bypass FLS — gated only by Setup access (Customize Application).
- **Why**: Idempotency at the DB layer (Unique on event_id) means even if Apex logic in 5A.3 is buggy, duplicate Stripe deliveries cannot create duplicate Opportunities or CampaignMembers — the log insert fails first. Schema captures both Stripe's signed timestamp and Salesforce's processing time so end-to-end latency can be measured.
- **Implementation**: `ULBC_StripeWebhook` (Apex REST `/services/apexrest/stripe/webhook`) verifies HMAC-SHA256 of `t.body` against secret, enforces 5-minute tolerance window. 9 unit tests cover happy path, signature failures, stale timestamps, malformed JSON, replay handling, and rotation header (multiple `v1=` candidates). 92% class coverage. Permission set field grants on ULBC_Full_Access only — no other role needs read access.
- **Date**: 2026-04-28
- **Note on legacy webhook code**: The previous `ULBC_StripeWebhook` class (event-ticket-only logic from before Decision 5.9) is fully replaced. v0 logic remains in git history (commit b9f7ff4) for reference when Phase 5A.3 implements typed handlers.

### Decision 5.19 — Phase 5A.3 typed handlers + Decision 5.9 mapping rules
- **What**: Phase 5A.3 introduces typed handlers dispatched off `metadata.intent`:
  - `intent=donation` → `ULBC_DonationHandler` — find/create Contact, optional Gift Aid declaration capture, Closed Won Opportunity linked to fund Campaign.
  - `intent=event_ticket` → `ULBC_EventTicketHandler` — find/create Contact, CampaignMember on event Campaign with `Status=Purchased`, Closed Won Opportunity for ticket revenue, Stripe Payment ID stamped on the CampaignMember.
  - `intent=subscription` → `Status=Ignored` (per Decision 5.1, recurring giving is bank-only).
  - Missing or unknown intent → `Status=Error`, response 400.
  - Non-checkout event types (e.g. `payment_intent.succeeded`) → `Status=Ignored`. v1 only processes `checkout.session.completed`.
- **Mapping decisions** (Decision 5.9 → schema):
  - `metadata.fund` accepts a Salesforce Campaign 18-char Id only in v1. Slug→Campaign lookup deferred (the donate LWC in 5A.4 will pass the Id directly). If `fund` is missing or doesn't match a Campaign, the Opportunity is still created (so the donor's payment is captured) with a note in `Description`.
  - `gift_type="One-Off"` → `ULBC_Gift_Type__c="One-off"`; `"Recurring"` → `"Regular"`. New picklist values added: "Event Ticket" on `Opportunity.ULBC_Gift_Type__c`; "Stripe Donation" + "Stripe Event Registration" on `Contact.ULBC_Acquisition_Channel__c`. New status values "Processed" + "Ignored" on `ULBC_Webhook_Log__c.ULBC_Status__c`.
  - Currency stored as Stripe sends it (no validation — GBP in practice).
  - **No email sending yet** — donor thank-you / attendee confirmation comms deferred to a later sub-phase, scoped with the fundraiser once data flow is proven in production.
- **Gift Aid (reaffirms Decision 2.10)**: when `metadata.gift_aid="true"`:
  - `Opportunity.ULBC_Gift_Aid_Eligible__c = true` always.
  - Contact declaration fields (`ULBC_Gift_Aid_Declaration_Date__c`, `Source`, `Postcode`, `Valid_From`) populated only if the Contact had no prior declaration. Existing declarations are NOT overwritten — protects the integrity of the original declaration date for HMRC audit.
- **Stripe Customer ID linking**: when `session.customer` is present and `Contact.ULBC_Stripe_Customer_ID__c` is blank, the Customer ID is linked. Existing values are not overwritten.
- **Known limitation**: handler exceptions after signature verification log `Status=Error` with `event_id` stored. Stripe retries hit the Unique constraint and become `Status=Duplicate` — the handler is NOT re-run automatically. Failed events require manual investigation (admin reads `ULBC_Error_Message__c`, fixes root cause, manually creates records or uses Stripe Dashboard "Resend" with a fresh event_id). Acceptable for v1 given low volume; revisit if production shows churn.
- **Implementation**: 4 new Apex classes (`ULBC_ContactMatcher`, `ULBC_DonationHandler`, `ULBC_EventTicketHandler`, dispatch logic in `ULBC_StripeWebhook`). 25 new tests (8 ContactMatcher, 7 DonationHandler, 4 EventTicketHandler, 6 dispatch). Org-wide tests: 194 passing, 94% coverage.
- **Date**: 2026-04-28

### Decision 5.20 — Email authentication (SPF / DKIM / DMARC) on `ulbctrust.org` — **ON HOLD 2026-04-29**

> **Status flip 2026-04-29**: ULBC is moving to a different email account / hosting setup. Decision 5.20 is parked until that move is decided and executed; the SPF/DMARC values below would need to be reconsidered against the new sender. DKIM keys generated in Salesforce remain valid (still sign the configured domain) but Activate has not been clicked. DNS-side SPF and DMARC for `ulbctrust.org` remain at GoDaddy defaults (verified via dig 2026-04-29: `v=spf1 include:secureserver.net -all` and `p=quarantine; rua=mailto:dmarc_rua@onsecureserver.net`) — these were never updated to the values agreed below. See OQ-051 for the new email-account decision that gates resuming this work. Original record below preserved for reference.


- **What**: Authenticate all Salesforce-originated mail from `noreply@ulbctrust.org` with SPF, DKIM and DMARC, hosted at GoDaddy DNS for `ulbctrust.org`.
- **Why**: Without DKIM and SPF, Salesforce mail fails authentication at Gmail/Outlook and is spam-foldered. Critical for fundraising deliverability against ~1,500 alumni inboxes. Original symptom: bulk fundraising email landing in spam.
- **Records**:
  - **DKIM (primary)** — CNAME `salesforce._domainkey.ulbctrust.org` → `salesforce.ng72vp.custdkim.salesforce.com`. Generated in Salesforce Setup → DKIM Keys, RSA 2048, selector `salesforce`, alternate selector `salesforcealt`, domain `ulbctrust.org`, exact-domain match.
  - **DKIM (alternate)** — CNAME `salesforcealt._domainkey.ulbctrust.org` → `salesforcealt.asnhtx.custdkim.salesforce.com`. Used by Salesforce for key rotation.
  - **SPF** — TXT `@` `v=spf1 include:_spf.salesforce.com ~all`. Merged with any existing SPF (only one SPF record permitted per domain). If Google Workspace or Microsoft 365 is added later, append `include:_spf.google.com` or `include:spf.protection.outlook.com` respectively before `~all`.
  - **DMARC** — TXT `_dmarc` `v=DMARC1; p=none; rua=mailto:adrian+dmarc@cassidy.uk.com; pct=100; aspf=r; adkim=r; fo=1`. `p=none` initially (monitor mode) so nothing legitimate is rejected during ramp.
- **Status (as of 2026-04-28)**:
  - DKIM keys generated and CNAMEs added to GoDaddy ✅
  - DKIM primary CNAME verified live via MXToolbox ✅
  - DKIM alternate CNAME — not yet independently verified, expected live
  - DKIM **Activate** button in Salesforce — not yet clicked (verify alternate CNAME first)
  - SPF and DMARC — values agreed but not yet confirmed published in GoDaddy DNS
  - Mail-tester end-to-end score — pending; first test send did not arrive at mail-tester (root cause not yet diagnosed; could be List Email queue delay or the Activity-tab single-send didn't fire)
- **DMARC tightening schedule**: hold at `p=none` for 2 weeks, review aggregate reports, move to `p=quarantine; pct=25` and ramp to `pct=100`, then to `p=reject` after 4–6 weeks of clean reports. Aggregate reports go to `adrian+dmarc@cassidy.uk.com` — note `cassidy.uk.com` is a different domain from `ulbctrust.org` so some receivers may require a `_report._dmarc` opt-in record on `cassidy.uk.com`. Switch to an `@ulbctrust.org` reporting address if reports don't arrive within 7 days.
- **Choice of `noreply@`**: Acknowledged drawback — `noreply@` addresses score worse with spam filters and discourage reply-engagement. Kept as the From for system alerts (Upgrade Prospect, future automation). Fundraising bulk mail SHOULD use a friendlier address (e.g. `info@ulbctrust.org` or `fundraising@ulbctrust.org`) added as a second Org-Wide Email Address — to be addressed in next session alongside template buildout.
- **Implementation owner**: Adrian. DNS edits made via GoDaddy `dcc.godaddy.com/control/portfolio/ulbctrust.org/settings`. No Salesforce code changes — configuration only.
- **Date**: 2026-04-28

### Decision 5.21 — Phase 5A.4 implementation choices (Site, LWCs, Stripe Checkout)
- **What**: Implementation choices for the public Site + LWCs + Stripe Checkout layer.
  - **Controller shape**: two `@AuraEnabled` methods (`createDonationSession`, `createEventSession`) on `ULBC_StripeCheckoutController`, sharing private helpers for form-body construction and the Stripe POST. Not a single parameterised method — the two intents take fundamentally different inputs (donation: amount + Gift Aid + fund; event_ticket: campaign + qty), and one-method-per-intent gives type-safe `@AuraEnabled` signatures the LWCs consume directly.
  - **LWC structure**: three components — `ulbcDonate` (page-level), `ulbcEventRegister` (page-level, self-contained), and `ulbcGiftAidDeclaration` (reusable child consumed by `ulbcDonate`). Gift Aid is split out because the HMRC declaration wording is legally fixed and the same component will be reused by any future donate flow.
  - **Site mount strategy**: classic Salesforce Site (Visualforce host pages + Lightning Out + Aura wrapper apps `ULBCDonateApp` / `ULBCEventRegisterApp`). LWR (Experience Cloud) was considered and rejected for v1 because the metadata is heavier and the runbook language ("Site Guest User profile") matched classic.
  - **Site URL shape**: `/donate?ulbc_trust_id=…&fund=…` and `/events?id=<CampaignId>&ulbc_trust_id=…`. Decision 5.4 originally proposed `/events/<campaign-name-slug>`; Decision 5.19 deferred slug→Campaign lookup; this phase chose query-param symmetry with the donate page. Slug routing can be layered on later via the Site's URL rewriter without breaking these URLs.
  - **Recurring giving in UI**: not exposed in the v1 `ulbcDonate` LWC. The controller and handler still accept `gift_type=Recurring` so the contract is preserved, but the LWC always sends `One-Off`. Stripe webhooks only deliver `checkout.session.completed`, which fires once per Checkout Session — adequate for one-off donations, insufficient for subscription renewals which would need additional `invoice.paid` event handling. Defer until the fundraiser asks for it. (Reaffirms Decision 5.1's framing: recurring giving is bank-channel in v1.)
  - **Min donation**: £1. Allows £1 test-card flows in test mode. Adjust `MIN_DONATION_GBP` in the controller if the fundraiser sets a higher floor.
  - **Success / cancel pages**: the same LWC renders a banner on return (`?status=success` or `?status=cancelled`). No separate thank-you / cancelled LWCs in v1.
  - **Custom Setting addition**: new field `EventsBaseURL__c` on `ULBC_Stripe_Settings__c` alongside the existing `DonationBaseURL__c`. Two separate fields keep the URL construction explicit; the existing `Contact.ULBC_Donation_Link__c` formula is unaffected.
  - **Site itself**: NOT authored as metadata in this commit. First-time `CustomSite` deployment via metadata API tends to fail because the standard error pages it references don't exist before Site creation. Manual Setup-UI creation (≈5 min) is faster than fighting the bootstrap. Once the Site exists, retrieve it via `sf project retrieve start --metadata CustomSite:ULBC_Public` and commit; from then on it's deployable.
- **Why**: All choices documented in RUNBOOK-5A.4.md, with rationale.
- **Implementation**: 1 new Apex class + test (`ULBC_StripeCheckoutController` + 20 tests), 3 new LWCs, 2 Aura wrapper apps, 2 Visualforce host pages, 1 new Custom Setting field (`EventsBaseURL__c`), permission set update granting controller class access. Post-deploy script `scripts/apex/set-stripe-urls.apex` for Custom Setting URL values. Org-wide tests: 208 passing.
- **Date**: 2026-04-28

### Decision 5.22 — Sharing strategy for the Stripe webhook chain
- **What**: After a Stripe webhook payload has been signature-verified by `ULBC_StripeWebhook`, the entire downstream handler chain runs `without sharing`. Specifically:
  - **`with sharing`** (defence in depth at the receive boundary): `ULBC_StripeWebhook` itself — receives the HTTP, parses headers, verifies HMAC, writes the `ULBC_Webhook_Log__c` row.
  - **`without sharing`** (system-trusted post-verification work): `ULBC_DonationHandler`, `ULBC_EventTicketHandler`, `ULBC_ContactMatcher`, `ULBC_ContactTriggerHandler`, `ULBC_DonorTierEngine`.
- **Why**: Stripe webhooks deliver as the Site Guest User. Salesforce post-Spring '21 enforces "secure guest user record access" — the guest user cannot see records they just created, and cannot see records owned by other users (e.g. the site's Default Record Owner) under standard sharing rules. Forcing `with sharing` on the handler chain produced three distinct failure modes during smoke testing: (a) post-insert Contact re-query returns empty in `ULBC_ContactMatcher`; (b) max-Trust ID lookup in `ULBC_ContactTriggerHandler.assignTrustId` returns empty, breaking the sequential ID generator and tripping the unique constraint; (c) `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` when `ULBC_DonorTierEngine` tries to update Contacts whose parent Account the guest user can't see. The signature verification is the security boundary; once a payload is verified as genuinely from Stripe, the rest is a system-trusted backend that should not be subject to guest-user visibility rules.
- **Pattern**: This applies to any future system-trusted code that may be invoked from the webhook chain — including the planned Phase 6 Xero invoice creation, which will be triggered by `ULBC_OpportunityTrigger` and may therefore also run in guest-user context. New classes in this chain should declare `without sharing` explicitly with a comment explaining why.
- **What this is NOT**: this is not a blanket "all internal Apex is without sharing". Admin-driven flows (UI edits, list views, reports) still go through `with sharing` paths. The exemption is specifically for the Stripe-receive code path after HMAC verification. The CRUD/FLS settings on the Site Guest User profile remain minimal (Read on Campaign / Contact / Opportunity, no Edit / Create) — DML still works because `without sharing` Apex code gets system-context DML execution for the operations it performs.
- **Implementation**: 5 classes flipped from `with sharing` to `without sharing` in commit `dc3b819` after live smoke testing exposed the failure modes above (`ULBC_StripeWebhook` is unchanged but its receive layer stays `with sharing` for defence in depth at the boundary).
- **Date**: 2026-04-28
- **Amendment 2026-04-29**: `ULBC_StripeCheckoutController` (LWC-callable Checkout Session creator) was originally documented as staying `with sharing` because it "only does Campaign reads, no privilege-escalation needed". This was wrong — guest users running on the public Site cannot see Campaigns owned by internal users (e.g. fundraisers) under Salesforce's secure-guest-user-record-access feature, so the donate-page fund lookup AND the events-page `getEventInfo` wire both fail with "Event not found" / "Selected fund could not be found" even when the record exists. The donate smoke test on 2026-04-28 missed this because the test didn't pass a `fund` query param so no Campaign read was attempted. The events smoke test on 2026-04-29 surfaced it immediately. Resolution: `ULBC_StripeCheckoutController` flipped to `without sharing` too. The class still has a tight Apex-API surface (typed `@AuraEnabled` parameters, no SOQL injection, callout body assembled from validated values) — the security boundary is the API surface, not record-level sharing on Campaign. The pattern now reads: **the entire public Stripe entry-and-receive code path runs `without sharing`; the receive layer (`ULBC_StripeWebhook`) is `with sharing` only for defence in depth at the HTTP boundary.**

### Decision 6.13 — Orphan Opportunity notifications: dual-channel (Custom Notification + email digest)
- **What**: When the Xero daily import creates an Opportunity with no matching Trust ID (orphan), Martin Peel is notified via two independent channels:
  1. **Salesforce Custom Notification** (mobile + desktop bell) — per-orphan, fired by Flow `Xero_Orphan_Alert` on `Opportunity` insert filtered to `ULBC_Source__c = 'Xero Import'` AND `npe01__Contact_Id_for_Role__c = null`. Recipient: Martin's User Id (`005Sk00000YKEHqIAP`). Notification clicks open the orphan Opportunity directly (`targetId = $Record.Id`).
  2. **Email digest** (per import page) — sent by `ULBC_XeroIncomeImporter.sendOrphanDigestEmail` after orphan inserts. Lists each orphan with a clickable Opportunity URL plus the Xero Contact name, AccountNumber, and email so Martin can match the donor without opening Xero. Recipient list and master switch are stored on the existing `ULBC_Xero_Settings__c` Custom Setting (new fields `OrphanNotifyEmails__c`, `OrphanNotificationsEnabled__c`). The Chatter feed item per orphan is unchanged — it remains the permanent record on the Opportunity.
- **Why**: A single channel is fragile. The Custom Notification is great when Martin is in Salesforce mobile or desktop, useless when he isn't. Email is reliable wherever he reads mail and gives him the context to triage without opening Salesforce first. The two together cost nothing extra and make sure he sees orphans the same day.
- **Pattern**: Per-page email (not per-run-aggregate). Each Queueable invocation handles one page of Xero transactions; on a normal day with one page that collapses to one email per run. Multi-page backfills produce multiple emails — acceptable noise on a rare event.
- **Implementation**:
  - Apex: `ULBC_XeroIncomeImporter.sendOrphanDigestEmail` reads recipients via SOQL (not `getOrgDefaults`) so mid-transaction updates are visible. Send wrapped in try/catch — failure does not roll back the orphan Opportunities (Chatter post and Flow Custom Notification are the safety nets).
  - Flow: `Xero_Orphan_Alert` v2 active. Title: "Unmatched Xero deposit". Body: "No matching Trust ID. AccountNumber on Xero: {AccountNumberSeen}. Open the Opportunity to assign a donor."
  - Custom Setting record populated: `OrphanNotifyEmails__c = 'adminulbh@gmail.com'`, `OrphanNotificationsEnabled__c = false` (off by default — flip to true after the first end-to-end smoke test).
  - Tests: 4 new unit tests covering enabled+orphan→sent, disabled→skipped, no-orphans→skipped, blank-recipients→skipped. Outcome captured via `lastEmailOutcome` static (test-visible) because `Limits.getEmailInvocations()` resets at `Test.stopTest`.
- **Pre-existing breakage fixed in same change**: the original Flow v1 (created earlier on 2026-04-30) had `targetId` set to the literal string `{0058e0000024gEUAAY}` (curly braces around Adrian's User Id). That's invalid syntax for a record-target reference, so any orphan insert would have failed with `CANNOT_EXECUTE_FLOW_TRIGGER: Invalid parameter value for: targetId`. The Flow had been activated 16:45 UTC; the next scheduled import (02:00 UTC the following day) would have failed end-to-end. v2 fixes targetId to `$Record.Id` (an `elementReference`) and obsoletes v1.
- **Date**: 2026-04-30

