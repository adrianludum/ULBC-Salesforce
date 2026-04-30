# ULBC Trust Salesforce — Product Requirements Document
*Status: Phase 5A Complete (Stripe donate + events flows live, test mode). Phase 6 Live (Xero → Salesforce daily import 02:00 UTC, orphan dual-channel notifications to Martin Peel — bell live, email armed-but-disabled until first natural orphan smoke test). Phase 5A go-live (test → prod) and email deliverability resumption next.*
*Last synthesised: 2026-04-28*

---

## 1. Overview

ULBC Trust Limited is the fundraising arm of the University of London Boat Club and a registered charity. This Salesforce implementation serves as the central CRM for managing approximately 1,500 alumni contacts, tracking donations and subscriptions, running fundraising campaigns, organising events, communicating with alumni and the active squad, and managing athlete recruitment. The platform is Salesforce Enterprise Edition with NPSP fully installed. The primary goal is fundraising — all other capabilities serve that mission.

---

## 2. Legal & Organisational Context

- **Data Controller**: ULBC Trust Limited (registered charity, Charity Commission no. **1174721**)
- **Gift Aid Entity**: ULBC Trust Limited (registered with HMRC, charity no. 1174721)
- **GDPR Legal Basis**: Legitimate Interests — membership relationship. Documented on every contact record. Unsubscribe link mandatory in all bulk emails.
- **Out of scope**: The ULBC limited company (operating club entity) and boathouse income — funded by the Trust but not modelled in Salesforce
- **Jurisdiction**: England & Wales, UK GDPR applies

---

## 3. Platform

- **Edition**: Salesforce Enterprise Edition
- **Org**: ULBC Trust Limited (ID: 00D8e000001DvjU, Instance: GBR82)
- **Foundation**: Nonprofit Success Pack (NPSP) — all 5 components installed
  - Contacts & Organizations (npe01)
  - Recurring Donations (npe03)
  - Households (npo02)
  - Affiliations (npe5)
  - Relationships (npe4)
- **Licences**: 10 full Salesforce licences (6 assigned, 4 spare)
- **Currency**: GBP
- **Locale**: English (United Kingdom), GMT

---

## 4. Users & Access Control

| User | Primary Type | Can See | Cannot See |
|------|-------------|---------|------------|
| Admin (x2) | System Admin | Everything | Nothing |
| Fundraiser | Standard User | All contacts, donations, Gift Aid, campaigns, events | Recruitment pipeline |
| Finance Person | Standard User | All contacts, all financial data, Gift Aid, donations | Recruitment pipeline |
| Event Organiser | Standard User | Events, contact name/email only | Gift amounts, household links, recruitment |
| Coach | Standard User | Current athletes, recruitment pipeline | Donor records, gift amounts, household links, alumni |
| Boathouse Manager | Standard User | Current athletes only | Donor records, gift amounts, household links, recruitment |

**Field-level security rules:**
- Gift amounts hidden from: Event Organiser, Coach, Boathouse Manager
- Household relationship links hidden from: Coach, Boathouse Manager
- Recruitment/Lead records visible to: Admin, Coach only

### Permission Sets — DEPLOYED ✅ (Phase 3C)
| Permission Set | API Name | Key Access |
|---|---|---|
| ULBC Full Access | ULBC_Full_Access | Admin — everything |
| ULBC Fundraiser | ULBC_Fundraiser | All contacts, donations, Gift Aid, campaigns. No Lead. |
| ULBC Finance | ULBC_Finance | All contacts, all financial data. Campaign read-only. No Lead. |
| ULBC Event Organiser | ULBC_Event_Organiser | Contact (name/email/read only), Campaign (read/write), history objects (read). No Opportunity, no Lead. |
| ULBC Coach | ULBC_Coach | Contact (read/edit/create), Lead (read/edit/create + convert), history objects (read). No Opportunity, no Campaign. |
| ULBC Boathouse Manager | ULBC_Boathouse_Manager | Contact (read only), history objects (read). No Lead, no Opportunity, no Campaign. |

### Current Athletes List View — DEPLOYED ✅ (Phase 3C)
- Contact list view filtered to `Primary Contact Type = Athlete-Student`
- Default working view for Coach and Boathouse Manager
- Graduated athletes drop off automatically when admin flips type to Alumni

---

## 5. Contact Data Model

### BUILD STATUS: ✅ PHASE 1 COMPLETE — DEPLOYED AND TESTED

### Primary Contact Type (single, evolving)
- Athlete-Student → Alumni (one-way, manual flip by admin on graduation — Decision: no automation needed at 10-20 students/year)
- Parent
- Other

### Additive Flags (independent, accumulate over time)
- Is Donor (true/false)
- Is Volunteer (true/false + Volunteer Since date)
- Is Tyrian Member (true/false — separate subscription object)

### Core Contact Fields — ALL DEPLOYED ✅
| Field | API Name | Type | Status |
|---|---|---|---|
| Trust ID | ULBC_Trust_ID__c | Text(50), External ID, Unique | ✅ Deployed |
| Birth Name | ULBC_Birth_Name__c | Text(100) | ✅ Deployed |
| Gender | ULBC_Gender__c | Picklist | ✅ Deployed |
| Primary Contact Type | ULBC_Primary_Contact_Type__c | Picklist (required) | ✅ Deployed |
| Is Donor | ULBC_Is_Donor__c | Checkbox | ✅ Deployed |
| Is Volunteer | ULBC_Is_Volunteer__c | Checkbox | ✅ Deployed |
| Volunteer Since | ULBC_Volunteer_Since__c | Date | ✅ Deployed |
| Is Tyrian Member | ULBC_Is_Tyrian_Member__c | Checkbox | ✅ Deployed |
| GDPR Legal Basis | ULBC_GDPR_Legal_Basis__c | Picklist | ✅ Deployed |
| Secondary Email | ULBC_Secondary_Email__c | Email | ✅ Deployed |
| Gone Away | ULBC_Gone_Away__c | Checkbox | ✅ Deployed |
| Alumni Type | ULBC_Alumni_Type__c | Picklist (UK/Global) | ✅ Deployed |
| Acquisition Channel | ULBC_Acquisition_Channel__c | Picklist | ✅ Deployed |

### Donor Tier Fields — ALL DEPLOYED ✅ (Phase 2B)
| Field | API Name | Type | Status |
|---|---|---|---|
| Donor Tier | ULBC_Donor_Tier__c | Picklist | ✅ Deployed |
| Rolling 12-Month Giving | ULBC_Rolling_12m_Giving__c | Currency | ✅ Deployed |
| Last Gift Date | ULBC_Last_Gift_Date__c | Date | ✅ Deployed |
| Upgrade Prospect | ULBC_Upgrade_Prospect__c | Checkbox | ✅ Deployed |
| Next Tier Threshold | ULBC_Next_Tier_Threshold__c | Currency | ✅ Deployed |
| Gap to Next Tier | ULBC_Gap_To_Next_Tier__c | Currency | ✅ Deployed |
| Tier Progress % | ULBC_Tier_Progress_Pct__c | Number | ✅ Deployed |

### Phase 2B fields added to Contact page layout ✅ and permission set ✅

### Auto-TrustID Assignment — DEPLOYED ✅ (Phase 3C)
- On Contact insert, if ULBC_Trust_ID__c is blank, auto-assigns next sequential ULBC-XXXX
- Queries highest existing TrustID and increments
- Pre-set TrustIDs (migration) are NOT overwritten
- Handles bulk inserts (200+ contacts)

### Validation Rules — DEPLOYED ✅
- ULBC_VolunteerSince_RequiresIsVolunteer: Volunteer Since cannot be set unless Is Volunteer = true

### Education History (Related List) — DEPLOYED ✅
One record per institution:
- Institution (Text — will become picklist when OQ-006 resolved)
- Degree Type (Undergraduate / Masters / PhD / Other)
- Subject
- Start Year
- End Year
- Relationship: Master-Detail to Contact (cascade delete)

### Crew History (Related List) — DEPLOYED ✅
- Crew Code
- Year
- Regatta
- Event
- Crew Name
- Result
- No Institution field (Decision 1.25 — all attributed to ULBC)
- Relationship: Master-Detail to Contact (cascade delete)

### International Competition History (Related List) — DEPLOYED ✅
- Year
- Competition (U23 World Championships / World Championships / Olympic Games / Other)
- Event (e.g. Women's 4-, Women's 8+)
- Result
- Country Represented (default: GB)
- Relationship: Master-Detail to Contact (cascade delete)

---

## 6. Account Model (NPSP Households)

- **Household Account**: Auto-created by NPSP for every individual contact.
- **Organisational Account**: Employer / corporate connections.
- Household links hidden from Coach and Boathouse Manager profiles.

---

## 7. Donation Model (NPSP Opportunities)

### Donor Tier Engine — DEPLOYED ✅ (Phase 2B)

Tier thresholds (auto-calculated on Contact from rolling 12-month cumulative giving):

| Tier | Threshold | Upgrade Alert | Status |
|------|-----------|---------------|--------|
| Prospect | No gifts yet | — | ✅ Live |
| Standard | < £240/yr | At £192 (80%) | ✅ Live |
| Patron | ≥ £241/yr | At £800 (80%) | ✅ Live |
| Major | ≥ £1,000/yr | None (no ceiling) | ✅ Live |
| Lapsed | No gift in 24 months | — | ✅ Live |
| Legacy Prospect | Manually assigned | — | Picklist value only |
| Legacy Pledger | Confirmed pledge | — | Picklist value only |
| Legator | Deceased + legacy received | — | Picklist value only |

### Automation Rules — DEPLOYED ✅
- Donor tier auto-calculated from rolling 12-month cumulative total (ULBC_DonorTierEngine)
- Upgrade Prospect flag set when donor reaches 80% of tier ceiling
- Lapsed flag when no donation in 24 months
- ULBC_OpportunityTrigger fires recalculation on every Opportunity insert/update/delete/undelete

### Upgrade Prospect Email Alert — TEMPLATE DEPLOYED ✅, FLOW NOT YET BUILT ⚠️
- HTML email template deployed (ULBC_UpgradeProspectAlert) ✅
- ULBC crest logo deployed as Static Resource ✅
- Brand colours: #784ca8 (purple), #fbfafc (white), #040008 (black)
- Recipient: info@innovatefundraising.com (single default — Decision 2.8)
- From address: noreply@ulbctrust.org (Org-Wide Email Address — needs verification in Setup — Decision 2.9)
- Upgrade Prospect flag manually cleared by fundraiser after acting (Decision 2.7)
- **REMAINING**: Record-Triggered Flow on Contact (when ULBC_Upgrade_Prospect__c changes false→true) to send Email Alert. Blocked on Org-Wide Email Address verification.

### Required fields on every donation — DEPLOYED ✅ (Phase 2C)
| Field | API Name | Type | Status |
|---|---|---|---|
| Gift Type | ULBC_Gift_Type__c | Picklist (8 values) | ✅ Deployed |
| Fund Type | ULBC_Fund_Type__c | Picklist (Unrestricted/Restricted) | ✅ Deployed |
| Gift Aid Eligible | ULBC_Gift_Aid_Eligible__c | Checkbox | ✅ Deployed |
| Gift Aid Claimed Date | ULBC_Gift_Aid_Claimed_Date__c | Date | ✅ Deployed |
| Gift Source | ULBC_Gift_Source__c | Picklist | ✅ Deployed |
| Stripe Payment ID | ULBC_Stripe_Payment_ID__c | Text(255) placeholder | ✅ Deployed |
| Amount (GBP) | Amount | Standard NPSP field | ✅ Live |
| Close Date | CloseDate | Standard field | ✅ Live |
| Fund / Campaign | CampaignId | Standard NPSP field | ✅ Live |

---

## 8. Subscription Model (Custom Objects) — DEPLOYED ✅ (Phase 2C)

### ULBC Subscription (Custom Object) — DEPLOYED ✅
Auto-number: SUB-{0000}. Sharing: ReadWrite.
| Field | API Name | Type | Notes |
|---|---|---|---|
| Contact | ULBC_Contact__c | Lookup(Contact) | Optional + SetNull on delete. Decision 2.11 |
| Amount | ULBC_Amount__c | Currency | Default £100. Decision 2.5 |
| Frequency | ULBC_Frequency__c | Picklist | Monthly / Annual. Default Annual |
| Status | ULBC_Status__c | Picklist | Active / Lapsed / Cancelled |
| Start Date | ULBC_Start_Date__c | Date | Required |
| Last Payment Date | ULBC_Last_Payment_Date__c | Date | Optional |
| Next Payment Date | ULBC_Next_Payment_Date__c | Date | Optional |
| Stripe Payment ID | ULBC_Stripe_Payment_ID__c | Text(255) | Placeholder. Decision 1.7 |

### Tyrian Membership (Custom Object) — DEPLOYED ✅
Auto-number: TYR-{0000}. Sharing: ReadWrite.
| Field | API Name | Type | Notes |
|---|---|---|---|
| Contact | ULBC_Contact__c | Lookup(Contact) | Optional + SetNull on delete. Decision 2.11 |
| Amount | ULBC_Amount__c | Currency | Default £75. Decision 2.5 |
| Frequency | ULBC_Frequency__c | Picklist | Monthly / Annual. Default Annual |
| Status | ULBC_Status__c | Picklist | Active / Lapsed / Cancelled |
| Start Date | ULBC_Start_Date__c | Date | Required |
| Last Payment Date | ULBC_Last_Payment_Date__c | Date | Optional |
| Next Payment Date | ULBC_Next_Payment_Date__c | Date | Optional |
| Stripe Payment ID | ULBC_Stripe_Payment_ID__c | Text(255) | Placeholder. Decision 1.7 |

---

## 9. Campaign Model — DEPLOYED ✅ (Phase 3A)

### BUILD STATUS: ✅ PHASE 3A COMPLETE — 7 STANDING FUND CAMPAIGNS LIVE

### Standing Campaigns (Funds) — ALL DEPLOYED ✅
| Campaign Name | Type | Status | Salesforce ID |
|---|---|---|---|
| Unrestricted / General | Fund | In Progress | 701Sk00000z6KAeIAM |
| ULBC Women's Group | Fund | In Progress | 701Sk00000z6KAfIAM |
| Equipment / Fleet | Fund | In Progress | 701Sk00000z6KAgIAM |
| Event | Fund | In Progress | 701Sk00000z6KAhIAM |
| Scholarship | Fund | In Progress | 701Sk00000z6KAiIAM |
| Bursary | Fund | In Progress | 701Sk00000z6KAjIAM |
| Coaching | Fund | In Progress | 701Sk00000z6KAkIAM |

- Campaign object added to ULBC_Full_Access permission set ✅
- Opportunities can be linked to Campaigns via CampaignId (donation → fund allocation) ✅
- Campaign Members supported for future event attendance tracking ✅
- Additional funds can be added as new Campaign records at any time

---

## 10. Event Model — DEPLOYED ✅ (Phase 3D)

### BUILD STATUS: ✅ PHASE 3D COMPLETE — EVENT MODEL LIVE

- 5-6 events per year, up to 200 attendees
- Each event = one Salesforce Campaign record (Type = 'Event')
- Attendance tracked as Campaign Members
- Registration flow: HTML form → Stripe → Salesforce API → Contact matched on email (deferred — OQ-015)

### Campaign Custom Fields (Event) — ALL DEPLOYED ✅
| Field | API Name | Type | Notes |
|---|---|---|---|
| Start Time | ULBC_Start_Time__c | Time | Pairs with standard StartDate |
| End Time | ULBC_End_Time__c | Time | Pairs with standard EndDate |
| Venue | ULBC_Venue__c | Text(255) | Event location |
| Ticket Price | ULBC_Ticket_Price__c | Currency(8,2) | Price per attendee |

Standard Campaign fields also used: Name, Description, StartDate, EndDate.

### CampaignMember Statuses (per event campaign — manual setup)
| Status | HasResponded | Notes |
|---|---|---|
| Invited | false | Initial status when attendee is added |
| Registered | true | Attendee has confirmed/paid |
| Attended | true | Post-event confirmation |
| No-Show | false | Registered but did not attend |

Statuses are created per-campaign (not deployable metadata). Set up manually when creating each event campaign. Decision 3.20.

---

## 11. Recruitment Pipeline — DEPLOYED ✅ (Phase 3B)

### BUILD STATUS: ✅ PHASE 3B COMPLETE — LEAD DATA MODEL AND PIPELINE LIVE

- Coach-only visibility (+ Admin) — enforcement deferred to Phase 3C (permission sets)
- ~400 prospects per year, targeting 10-20 accepted athletes
- Pipeline stages: Prospect → Emailed → Spoken To → Applied → Accepted → Not Progressed
- On Accepted: Lead converts to Contact (standard fields map automatically)
- Post-conversion: Admin manually sets Primary Contact Type = Athlete-Student and assigns TrustID

### Lead Custom Fields — ALL DEPLOYED ✅
| Field | API Name | Type | Notes |
|---|---|---|---|
| Current School / University | ULBC_Current_Institution__c | Text(100) | Where they are now, pre-ULBC |
| Graduation Year | ULBC_Graduation_Year__c | Number(4,0) | Expected graduation from current institution |
| Gender | ULBC_Gender__c | Picklist (Male/Female) | |
| Current Rowing Event | ULBC_Current_Rowing_Event__c | Text(100) | What they row now, pre-ULBC |
| Recruitment Source | ULBC_Recruitment_Source__c | Picklist | BUCS Results / Referral / Direct Inquiry / Trials / Other |
| Coach Notes | ULBC_Coach_Notes__c | Long Text Area(5000) | Free-text notes |

### Lead Status (Pipeline Stages) — DEPLOYED ✅
| Status | Closed | Converted | Notes |
|---|---|---|---|
| Prospect | No | No | Default for new leads |
| Emailed | No | No | |
| Spoken To | No | No | |
| Applied | No | No | |
| Accepted | Yes | Yes | Triggers Lead conversion |
| Not Progressed | Yes | No | Closed without conversion |

### Lead Conversion Mapping — MANUAL SETUP REQUIRED ⚠️
Standard fields (Name, Email, Phone) map automatically. Custom field mapping must be configured in Setup → Object Manager → Lead → Fields & Relationships → Map Lead Fields:
- Lead.ULBC_Gender__c → Contact.ULBC_Gender__c
- After conversion: manually set Contact.ULBC_Primary_Contact_Type__c = 'Athlete-Student' and assign ULBC_Trust_ID__c

### Permission Set — UPDATED ✅
- Lead object added to ULBC_Full_Access (read/write, no delete)
- All 6 Lead custom fields added to ULBC_Full_Access FLS

---

## 12. Gift Aid — DEPLOYED ✅ (Phase 2C)

Tracked at two levels (Decision 2.10):

**Contact level — declaration record:**
| Field | API Name | Type |
|---|---|---|
| Gift Aid Eligible | ULBC_Gift_Aid_Eligible__c | Checkbox |
| Declaration Date | ULBC_Gift_Aid_Declaration_Date__c | Date |
| Declaration Source | ULBC_Gift_Aid_Declaration_Source__c | Picklist |
| Gift Aid Postcode | ULBC_Gift_Aid_Postcode__c | Text(10) |
| Valid From | ULBC_Gift_Aid_Valid_From__c | Date |
| Valid To | ULBC_Gift_Aid_Valid_To__c | Date (blank = open-ended) |

**Opportunity level — per-gift tracking:**
- Gift Aid Eligible: ULBC_Gift_Aid_Eligible__c (Checkbox) — set manually per donation
- Gift Aid Claimed Date: ULBC_Gift_Aid_Claimed_Date__c (Date) — date HMRC claim submitted

Registered under ULBC Trust Limited.

---

## 13. Email Communications — PARTIALLY CONFIGURED (Phase 3D / ongoing)

- Salesforce native list email via Marketing User feature licences
- All bulk emails must include unsubscribe link (`{{{Sender.UnsubscribeLink}}}`)
- All bulk emails must include charity number (1174721) and registered address in footer
- Opt-outs flagged immediately on Contact record (HasOptedOutOfEmail = true)
- Gone Away trigger already handles opt-out automation ✅

### Email authentication (deliverability) — DEPLOYED ✅ (2026-04-28)

Sending domain `ulbctrust.org` is authenticated via SPF, DKIM and DMARC. Decision 5.20.

| Mechanism | Record | Status |
|---|---|---|
| DKIM key (primary) | CNAME `salesforce._domainkey.ulbctrust.org` → `salesforce.ng72vp.custdkim.salesforce.com` | ✅ Published, verified via MXToolbox |
| DKIM key (alternate) | CNAME `salesforcealt._domainkey.ulbctrust.org` → `salesforcealt.asnhtx.custdkim.salesforce.com` | ✅ Published |
| Salesforce DKIM activation | Setup → DKIM Keys → `salesforce` selector → Active | ⚠️ Pending — flip to Active once both CNAMEs verified |
| SPF | TXT `@` `v=spf1 include:_spf.salesforce.com ~all` (merged with any existing SPF) | ⚠️ Pending GoDaddy publish + verify |
| DMARC | TXT `_dmarc` `v=DMARC1; p=none; rua=mailto:adrian+dmarc@cassidy.uk.com; pct=100; aspf=r; adkim=r; fo=1` | ⚠️ Pending GoDaddy publish + verify |
| End-to-end mail-tester score | Target 9+/10 | ⚠️ Pending — first send did not arrive at mail-tester |

DMARC tightening schedule (post-verification):
- Week 0–2: `p=none` (monitor mode, current)
- Week 2–6: `p=quarantine; pct=25` then ramp to `pct=100`
- Week 6+: `p=reject` once aggregate reports show clean SPF/DKIM alignment

### Email templates

- **Lightning Email Templates** are the supported template system (Classic templates deprecated for new work).
- Branded HTML templates use inline CSS (Salesforce strips `<style>` blocks in some contexts).
- Brand colours: `#784ca8` (purple), `#fbfafc` (off-white), `#040008` (near-black).
- Logo (`ULBC_Logo` static resource) is exposed via Salesforce Files public link or via the Salesforce Site `/resource/ULBC_Logo` path for inclusion in HTML emails.

### Attachments

- **List Email does NOT support file attachments** (Salesforce platform limitation). Use a Salesforce Files public link in the email body instead.
- Single-recipient email from a Contact's Activity tab supports attachments up to 25 MB total message size.
- Files attached via the composer should be uploaded to Salesforce Files first, then inserted via "Insert File" — drag-drop into the body inlines them.

---

## 14. Build Status & Sequence

### Completed
| Phase | Description | Tests | Status |
|---|---|---|---|
| Phase 1 | Contact data model, 3 related lists, page layout, Jade Smith test record | 33 | ✅ Complete |
| Phase 2A | Gone Away → HasOptedOutOfEmail trigger | 12 | ✅ Complete |
| Phase 2B | Donor tier engine, opportunity trigger, upgrade prospect fields, email template | 18 | ✅ Complete |
| Phase 2C | Opportunity fields, Gift Aid fields, ULBC Subscription object, Tyrian Membership object | 8 | ✅ Complete |
| Phase 3A | Campaign model — 7 standing fund campaigns, permission set update | 5 | ✅ Complete |
| Phase 3B | Recruitment pipeline — Lead custom fields, pipeline stages, conversion, permission set | 9 | ✅ Complete |
| Phase 3C | Profiles & FLS — 5 permission sets, auto-TrustID trigger, Current Athletes list view | 15 | ✅ Complete |
| Phase 3D | Event model — 4 Campaign custom fields, CampaignMember statuses, permission set updates | 8 | ✅ Complete |
| Phase 4A | Migration metadata — 4 Contact fields, Rowing Position on Crew History, permission sets | 4 | ✅ Complete |
| Phase 4B | FileMaker migration — 1,345 Contacts, 24,940 Opportunities, 2,050 Crew History, 1,270 Education History, 26 Events, 2,038 Attendance, 399 Notes, 17 Partner Relationships | — | ✅ Complete |

### In Progress
| Item | Status |
|---|---|
| Org-Wide Email Address (noreply@ulbctrust.org) verification | ❌ Manual step needed in Setup |
| Flow to fire email alert when Upgrade Prospect = true | ❌ Not built — blocked on Org-Wide Email Address |

### Remaining
| Phase | Description |
|---|---|
| Phase 3B | ~~Recruitment pipeline~~ | ✅ Complete |
| Phase 3B (manual) | Lead conversion field mapping in Setup UI | ✅ Complete |
| Phase 3C | ~~Profiles & FLS~~ | ✅ Complete |
| Phase 3D | ~~Event model~~ | ✅ Complete |
| Phase 3D | Email comms setup (Marketing User licences — manual Setup step) |
| Phase 3D | Upgrade Alert Flow — blocked on OQ-023 |
| Phase 4 | ~~Full 1,500 record migration from FileMaker~~ | ✅ Complete |
| **Phase 5A** | **Stripe webhook receiver + event ticketing flow (Salesforce Site + LWC). ~3 sessions.** |
| **Phase 5B** | **Donation flow on Stripe webhook — deferred until website rebuild decided (OQ-026)** |
| ~~Phase 6A (original)~~ | ~~Salesforce → Xero invoice push~~ — **direction reversed 2026-04-29 (Decision 6.9). See Phase 6 (revised) below.** |
| **Phase 6 (revised)** | **Xero → Salesforce daily import (Closed Won Opportunities mirrored from Xero RECEIVE bank transactions). Decisions 6.9–6.13.** | ✅ **Live 2026-04-29**, orphan dual-channel notifications to Martin Peel deployed 2026-04-30. |

### Source tables
| FileMaker Table | Salesforce Target | Notes |
|----------------|-------------------|-------|
| Members (~1,500) | Contact | ✅ 1,345 migrated. 9 failed (data quality). Mem Type: A→Alumni, S/O/P/D→Other. |
| Accounts_transactions | Opportunity | ✅ 24,940 migrated. 2,040 skipped (no TrustId). |
| Crew_data + Crew_names | Crew History (related list) | ✅ 2,050 migrated. Joined on Crew Code. |
| EventID table | Campaign | ✅ 26 events migrated. 2,038 attendance records. |

### Key migration rules
- All imported contacts: Primary Type = Alumni, Legal Basis = Legitimate Interests
- TrustID stored as External ID on Contact (enables upserts + Stripe linking)
- GoneAway = true → Contact flagged, excluded from bulk email
- Bank Account no → NOT migrated

---

## 15. Stripe Integration — Phase 5 (Planned 2026-04-27)

### Scope
Stripe handles **website donations** and **event ticketing** (dinners, BBQs, etc.). Recurring subscriptions (Tyrian, ULBC) come through bank account, ingested via Xero — NOT Stripe. See Decision 5.1.

### Architecture
- **Public Apex REST endpoint** on Salesforce Site receives Stripe webhooks
- **Stripe signature verification** on every payload (Decision 5.11)
- **Event handler** dispatches by `metadata.intent` to typed handlers:
  - `donation` → creates Opportunity, matches/creates Contact, populates Gift Aid fields
  - `event_ticket` → creates CampaignMember on the Event Campaign
  - `subscription` → reserved for future use (currently bank-only)
- **Salesforce Site + LWC** for public event registration pages at `ulbctrust.my.site.com/events/<campaign>` (Decision 5.4)

### Sub-phases
| Sub-phase | Scope | Status |
|---|---|---|
| 5A.1 | Data model — `ULBC_Stripe_Customer_ID__c` on Contact, `ULBC_Donation_Link__c` formula on Contact, `ULBC_Stripe_Payment_ID__c` on CampaignMember, `ULBC_Stripe_Settings__c` Custom Setting, permission set + layout updates | **Deployed ✅ 2026-04-27** |
| 5A.2 | Apex webhook receiver: HMAC-SHA256 signature verify, `ULBC_Webhook_Log__c` audit object (Unique event_id for DB-level idempotency), `WebhookSigningSecret__c` on Custom Setting, 9 tests | **Deployed ✅ 2026-04-28** |
| 5A.3 | Typed handlers: `ULBC_ContactMatcher` (Decision 5.8 priority), `ULBC_DonationHandler` (with Gift Aid capture per Decision 2.10), `ULBC_EventTicketHandler` (Campaign + CampaignMember + Opportunity), intent dispatch in webhook, 25 new tests | **Deployed ✅ 2026-04-28** |
| 5A.4 | Salesforce Site + LWCs: `ulbcEventRegister` (event ticketing) AND `ulbcDonate` (personalised donations), per Decisions 5.4 + 5.15 | **Deployed ✅ 2026-04-28**, donate flow smoke-tested end-to-end (real £25 test card → Closed Won Opportunity in Salesforce). |
| 5A.5 | Wrap-up: events smoke test (OQ-046 ✅), webhook log layout + list view diagnostics (OQ-047 ✅), `CustomSite:ULBC_Public` retrieved into source control (OQ-048 ✅), orphan smoke-test Contact deleted (OQ-049 ✅), runbook hostname corrigenda (OQ-050 ✅). Sixth `with sharing` fix applied to `ULBC_StripeCheckoutController` — Decision 5.22 amended. | **Deployed ✅ 2026-04-29**, both donate and events flows smoke-tested end-to-end. |
| ~~5B~~ | ~~Donation flow~~ | **Closed — merged into 5A.3 + 5A.4 by Decision 5.15** |

### Stripe metadata contract (Decision 5.9, amended 2026-04-27)
Every Stripe Checkout Session must pass:
- `intent`: "donation" | "event_ticket" | "subscription"
- `fund`: Campaign ID or fund slug (donations only)
- `ulbc_trust_id`: ULBC-XXXX (if known) — **renamed from `trust_id` for clarity in Stripe Dashboard**
- `gift_aid`: "true" | "false" (donations only)
- `gift_aid_postcode`: postcode string (if gift_aid=true)
- `gift_type`: "One-Off" | "Recurring" (donations only)
- `campaign_id`: Salesforce Campaign 18-char ID (event tickets only)

### Contact matching priority (Decision 5.8) + Identity bridging (Decision 5.14)
**How an anonymous Stripe payment is linked to the right Contact:**

The donor never sees or types their TrustID. Two mechanisms get the TrustID into the Stripe payload:

1. **Personalised URL** (primary): every fundraising email sent from Salesforce contains a link with `?ulbc_trust_id=ULBC-XXXX` baked in. The donate / event page reads the URL parameter and passes it as Stripe metadata.
2. **Email match** (secondary): for cold web donors with no personalised link, Stripe Checkout collects email by default; webhook handler matches by Contact.Email.

**Match priority used by webhook handler:**
1. `metadata.ulbc_trust_id` from Stripe (personalised URL hit)
2. Stripe Customer ID match (`Contact.ULBC_Stripe_Customer_ID__c`)
3. Email match (`Contact.Email` or `Contact.ULBC_Secondary_Email__c`)
4. Create new Contact with Acquisition Channel = "Stripe Donation" or "Stripe Event Registration", flagged for manual review by Fundraiser.

### Existing Stripe footprint (as of April 2026)
- Stripe account registered to ULBC Trust Limited ✅
- 1 active legacy subscription (Bethany Welch, £80/yr from 2014) — grandfathered (Decision 5.12)
- 3 payments in last 12 months (£200 donation, £5 donation, £80 subscription renewal)
- Existing donate page: WordPress + WP Simple Pay (managed by third party) — fixed £25, no Gift Aid capture, no fund selection. To be rebuilt at later date (OQ-026).

---

## 15a. Xero Integration — Phase 6

> **Direction reversed 2026-04-29 (Decision 6.9).** The original "Salesforce → Xero invoices" plan below (§15a planned-state, Decisions 6.1–6.8) is preserved as historical context but **does not reflect what was built**. The deployed Phase 6 mirrors income inbound from Xero into Salesforce — see "§15a deployed state" immediately below for the live architecture.

### Deployed state (2026-04-29 → 2026-04-30) — Decisions 6.9–6.13

**Direction**: Xero → Salesforce (Xero is the source of truth for received income; Salesforce mirrors it as Closed Won Opportunities).

**Trigger**: Daily scheduled Apex (`ULBC Xero Daily Income Import`, 02:00 UTC, cron `0 0 2 * * ?`).

**Flow**:
1. `ULBC_XeroImportSchedulable` → `ULBC_XeroIncomeImporterQueueable` chains pages.
2. Each page: `GET /api.xro/2.0/BankTransactions?where=Type=="RECEIVE"` with `If-Modified-Since: <watermark>` (page size 100).
3. Per-page enrichment: `GET /api.xro/2.0/Contacts?IDs=<csv>` to fetch AccountNumber + EmailAddress (Xero's BankTransactions endpoint omits AccountNumber).
4. Per transaction → one Opportunity: Stage = Closed Won, Amount + Date from Xero, `ULBC_Source__c = 'Xero Import'`.
5. Donor link: `Trust ID = Xero Contact AccountNumber`. Match on `Contact.ULBC_Trust_ID__c`.
6. No match → orphan Opportunity (no Primary Contact). Surfaced via list view + Chatter feed item + dual-channel notification to Martin Peel (Decision 6.13):
   - **Bell** (Custom Notification, mobile + desktop) — Flow `Xero_Orphan_Alert` v2, fires per orphan on insert.
   - **Email digest** (per import page) — `ULBC_XeroIncomeImporter.sendOrphanDigestEmail`. Off by default; recipient list and master switch on `ULBC_Xero_Settings__c`.
7. Idempotency: `ULBC_Xero_Transaction_ID__c` is External ID + Unique on Opportunity. Re-runs skip duplicates.
8. Donor-tier engine fires automatically on Opp insert via existing `ULBC_OpportunityTrigger` — no extra wiring.

**Auth**: Web-app OAuth 2.0 via Named Credential `ULBC_Xero` (Salesforce Auth Provider type "Open ID Connect"). Scopes: `openid offline_access accounting.banktransactions.read accounting.contacts.read`. Tenant ID set as Custom Header `Xero-tenant-id` on the Named Credential.

**Audit**: Every page-run writes a `ULBC_Xero_Sync_Log__c` row (transactions read, opportunities created, orphans created, skipped duplicates, watermark before/after, status, error message).

**Code in source** (committed as of `a7b433d`): `ULBC_XeroIncomeImporter`, `ULBC_XeroIncomeImporterQueueable`, `ULBC_XeroImportSchedulable`, `ULBC_XeroHttpMock`, `ULBC_XeroIncomeImporter_Test` (12 tests). Custom objects: `ULBC_Xero_Settings__c`, `ULBC_Xero_Sync_Log__c`. Flow: `Xero_Orphan_Alert` v2 active.

**Out of scope**: Refunds (handled in Xero, not mirrored). Stripe-paid donations create both a webhook Opportunity AND a Xero-import Opportunity — see OQ-053. Backfilling AccountNumbers onto historical Xero Contacts — see OQ-052.

---

### §15a planned state (NOT BUILT — superseded by Decisions 6.9–6.13)

### Scope
Bridge the workflow boundary between Fundraiser/Admin (Salesforce) and Finance Person (Xero). Two flows:
1. **Salesforce → Xero invoices**: Closed Won Opportunity creates a paid invoice in Xero (custom Apex)
2. **Stripe → Xero bank deposits**: native Xero Stripe feed, configured by Finance Person (NOT in Salesforce — Decision 6.4)

### Architecture
- **Trigger**: Opportunity after-insert/update on StageName change to Closed Won (Decision 6.5)
- **Auth**: OAuth 2.0 via Named Credential `ULBC_Xero` (Decision 6.6)
- **Account mapping**: Custom Metadata Records (`ULBC_Xero_Account_Mapping__mdt`) — Finance Person specifies, Adrian encodes (Decision 6.7)
- **Contact sync**: Lazy creation — `ULBC_Xero_Contact_ID__c` on Salesforce Contact, populated on first invoice (Decision 6.8)

### Sub-phases
| Sub-phase | Scope | Status |
|---|---|---|
| 6A.1 | Xero Connected App registration (one-time, Adrian) | ~~OQ-033~~ Superseded — actual auth is Web-App OAuth via Named Credential, not a Connected App |
| 6A.2 | Named Credential setup, OAuth 2.0 flow tested | ~~Superseded~~ — replaced by the deployed `ULBC_Xero` Named Credential (Open ID Connect provider) used by the Xero → Salesforce import |
| 6A.3 | Custom Metadata Type for account mapping | ~~OQ-030 / Decision 6.7~~ Superseded — no chart-of-accounts mapping needed (no invoices created) |
| 6A.4 | ULBC_XeroInvoiceService Apex class — create invoice from Opportunity | ~~Superseded~~ — no invoices created |
| 6A.5 | ULBC_OpportunityXeroSync trigger | ~~Superseded~~ — direction reversed; no Salesforce → Xero push |
| 6A.6 | ULBC_Xero_Contact_ID__c field + Contact sync logic | ~~Superseded~~ — match-only via Trust ID = AccountNumber |
| 6B | Refund handling via Credit Notes | ~~OQ-035~~ Superseded — refunds handled in Xero, not mirrored |
| 6C | Finance Person configures native Xero Stripe feed | Not started — manual, in Xero |

### Out of scope (v1)
- Backfilling historical Opportunities into Xero (OQ-034 — recommendation: do not backfill)
- Two-way sync from Xero back to Salesforce (one-way only: Salesforce → Xero)
- Gift Aid reclaims as Xero line items (OQ-032 — recommendation: handle separately on HMRC payout)

---

## 16. Technical Architecture

- **Platform**: Salesforce Enterprise Edition
- **Foundation**: NPSP
- **Build approach**: TDD with Claude
- **Builder/Maintainer**: Adrian Cassidy (Admin)
- **Salesforce username**: adrian-36nu@cassidy.uk.com
- **Org ID**: 00D8e000001DvjUEAS
- **CLI alias**: ulbc
- **Project directory**: ~/Projects/ULBC-salesforce
- **GitHub**: https://github.com/adrianludum/ULBC-Salesforce
- **Email**: Salesforce native Marketing User licences
- **Payments**: Stripe (v2 integration)
- **Brand colours**: #784ca8 (purple), #fbfafc (off-white), #040008 (near-black)
- **Logo**: ULBC_Logo static resource (deployed ✅)

### Deployed Apex Classes
| Class | Purpose | Coverage |
|---|---|---|
| ULBC_ContactTriggerHandler | Gone Away logic + auto-TrustID | 100% |
| ULBC_DonorTierEngine | Tier calculation engine | 100% |
| ULBC_ContactDataModel_Test | Phase 1 tests | — |
| ULBC_GoneAwayTrigger_Test | Phase 2A tests | — |
| ULBC_DonorTierEngine_Test | Phase 2B tests | — |
| ULBC_Phase2C_DataModel_Test | Phase 2C tests | — |
| ULBC_Phase3A_Campaign_Test | Phase 3A tests | — |
| ULBC_Phase3B_Recruitment_Test | Phase 3B tests | — |
| ULBC_Phase3C_Access_Test | Phase 3C tests | — |

### Deployed Triggers
| Trigger | Object | Events | Purpose |
|---|---|---|---|
| ULBC_ContactTrigger | Contact | before insert, before update | Gone Away → HasOptedOutOfEmail + auto-TrustID on insert |
| ULBC_OpportunityTrigger | Opportunity | after insert/update/delete/undelete | Fire donor tier recalculation |

### Total test count: 99 passing, 0 failing

---

## 17. Out of Scope (v1)

- Boathouse income and student bill payments (limited company)
- Bank account number storage
- Stripe integration (structure only in v1)
- Login/portal for alumni self-service
- Salesforce Marketing Cloud / external email platform
- The ULBC limited company entity

---

## 18. Open Questions
See OPEN-QUESTIONS.md

---

## 19. Primary Test Record — Jade Smith

Jade Smith (nee Robinson) — TrustID ULBC-0001 — is loaded in the org ✅

Her record exercises every Phase 1 data model feature and is the canonical test contact for all future phases.
