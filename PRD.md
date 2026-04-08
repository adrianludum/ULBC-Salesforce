# ULBC Trust Salesforce — Product Requirements Document
*Status: Phase 2B In Progress*
*Last synthesised: 2026-04-08*

---

## 1. Overview

ULBC Trust Limited is the fundraising arm of the University of London Boat Club and a registered charity. This Salesforce implementation serves as the central CRM for managing approximately 1,500 alumni contacts, tracking donations and subscriptions, running fundraising campaigns, organising events, communicating with alumni and the active squad, and managing athlete recruitment. The platform is Salesforce Enterprise Edition with NPSP fully installed. The primary goal is fundraising — all other capabilities serve that mission.

---

## 2. Legal & Organisational Context

- **Data Controller**: ULBC Trust Limited (registered charity)
- **Gift Aid Entity**: ULBC Trust Limited (registered with HMRC)
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

### TODO: Add Phase 2B fields to Contact page layout and permission set

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

### Upgrade Prospect Email Alert — PARTIALLY BUILT ⚠️
- HTML email template built (ULBC_UpgradeProspectAlert) — deploy pending (folder error)
- ULBC crest logo deployed as Static Resource ✅
- Brand colours: #784ca8 (purple), #fbfafc (white), #040008 (black)
- Flow/email alert to fire template when Upgrade Prospect = true — NOT YET BUILT
- Recipient: ULBC Relationship Manager on the Contact record

### Required fields on every donation — NOT YET BUILT (Phase 2C)
- Amount (GBP)
- Close Date
- Gift Type (One-off / Regular / Pledge / Legacy-Pledge / Legacy-Gift / Gift-in-Kind / In Memory / Tribute Fund)
- Fund / Campaign allocation (required — lookup to Campaign)
- Fund Type (Unrestricted / Restricted)
- Source / Acquisition Channel
- Gift Aid Eligible (yes/no)
- Gift Aid Claimed Date
- Linked Contact
- Stripe Payment ID (placeholder)

---

## 8. Subscription Model (Custom Objects) — NOT YET BUILT (Phase 2C)

### ULBC Subscription (Custom Object)
- Contact (lookup)
- Amount (GBP) — launch default: £100/year
- Frequency (Monthly / Annual) — launch default: Annual
- Status (Active / Lapsed / Cancelled)
- Start Date
- Last Payment Date
- Next Payment Date
- Stripe Payment ID (placeholder)

### Tyrian Membership (Custom Object)
- Contact (lookup)
- Amount (GBP) — launch default: £75/year
- Frequency (Monthly / Annual) — launch default: Annual
- Status (Active / Lapsed / Cancelled)
- Start Date
- Last Payment Date
- Next Payment Date
- Stripe Payment ID (placeholder)

---

## 9. Campaign Model — NOT YET BUILT (Phase 3)

### Standing Campaigns (Funds)
- Unrestricted / General
- ULBC Women's Group
- Equipment / Fleet
- Event (one Campaign record per named event)
- Scholarship
- Bursary
- Coaching

---

## 10. Event Model — NOT YET BUILT (Phase 3)

- 5-6 events per year, up to 200 attendees
- Each event = one Salesforce Campaign record
- Attendance tracked as Campaign Members
- Registration flow: HTML form → Stripe → Salesforce API → Contact matched on email

---

## 11. Recruitment Pipeline — NOT YET BUILT (Phase 3)

- Coach-only visibility (+ Admin)
- ~400 prospects per year, targeting 10-20 accepted athletes
- Pipeline stages: Prospect → Emailed → Spoken To → Applied → Accepted
- On Accepted: Lead converts to Contact, Type = Athlete-Student, TrustID assigned

---

## 12. Gift Aid — NOT YET BUILT (Phase 2C)

- All Gift Aid declarations stored on Contact record
- Fields: Eligible (yes/no), Declaration Date, Declaration Source, Postcode, Valid From, Valid To
- Tax claim date recorded on Opportunity when claimed
- Registered under ULBC Trust Limited

---

## 13. Email Communications — NOT YET CONFIGURED (Phase 3)

- Salesforce native list email via Marketing User feature licences
- All bulk emails must include unsubscribe link
- Opt-outs flagged immediately on Contact record (HasOptedOutOfEmail = true)
- Gone Away trigger already handles opt-out automation ✅

---

## 14. Build Status & Sequence

### Completed
| Phase | Description | Tests | Status |
|---|---|---|---|
| Phase 1 | Contact data model, 3 related lists, page layout, Jade Smith test record | 33 | ✅ Complete |
| Phase 2A | Gone Away → HasOptedOutOfEmail trigger | 12 | ✅ Complete |
| Phase 2B | Donor tier engine, opportunity trigger, upgrade prospect fields | 17 | ✅ Complete |

### In Progress
| Item | Status |
|---|---|
| Email template deployment (ULBC_UpgradeProspectAlert) | ⚠️ Folder error — needs fix |
| Flow to fire email alert when Upgrade Prospect = true | ❌ Not built |
| Phase 2B fields added to Contact page layout | ❌ Not done |
| Permission set updated for Phase 2B fields | ❌ Not done |

### Remaining
| Phase | Description |
|---|---|
| Phase 2C | Opportunity custom fields, Gift Aid fields, ULBC Subscription object, Tyrian Membership object |
| Phase 3 | Profiles & FLS, Campaign model, Event model, Recruitment pipeline, Email comms setup |
| Phase 4 | Full 1,500 record migration from FileMaker |

### Source tables
| FileMaker Table | Salesforce Target | Notes |
|----------------|-------------------|-------|
| Members (~1,500) | Contact | Exclude Bank Account no. Map Mem Type: A=Athlete→Alumni, O=Other |
| Accounts_transactions | Opportunity | Map to donations with fund allocation |
| Crew_data | Crew History (related list) | Link via TrustID |
| Crew_names | Crew History (related list) | Regatta/event detail |
| EventID table | Campaign | Map EventID, Year, Event Name |

### Key migration rules
- All imported contacts: Primary Type = Alumni, Legal Basis = Legitimate Interests
- TrustID stored as External ID on Contact (enables upserts + Stripe linking)
- GoneAway = true → Contact flagged, excluded from bulk email
- Bank Account no → NOT migrated

---

## 15. Stripe Integration (Deferred — v2)

- Stripe Payment ID placeholder fields on Opportunity, ULBC Subscription, Tyrian Membership
- Full integration deferred until data model is built and tested

---

## 16. Technical Architecture

- **Platform**: Salesforce Enterprise Edition
- **Foundation**: NPSP
- **Build approach**: TDD with Claude
- **Builder/Maintainer**: Adrian Cassidy (Admin)
- **Salesforce username**: adrian-36nu@cassidy.uk.com
- **Org ID**: 00D8e000001DvjUEAS
- **CLI alias**: ulbc
- **Project directory**: ~/ULBC-salesforcce
- **Email**: Salesforce native Marketing User licences
- **Payments**: Stripe (v2 integration)
- **Brand colours**: #784ca8 (purple), #fbfafc (off-white), #040008 (near-black)
- **Logo**: ULBC_Logo static resource (deployed ✅)

### Deployed Apex Classes
| Class | Purpose | Coverage |
|---|---|---|
| ULBC_ContactTriggerHandler | Gone Away logic | 100% |
| ULBC_DonorTierEngine | Tier calculation engine | 100% |
| ULBC_ContactDataModel_Test | Phase 1 tests | — |
| ULBC_GoneAwayTrigger_Test | Phase 2A tests | — |
| ULBC_DonorTierEngine_Test | Phase 2B tests | — |

### Deployed Triggers
| Trigger | Object | Events | Purpose |
|---|---|---|---|
| ULBC_ContactTrigger | Contact | before insert, before update | Gone Away → HasOptedOutOfEmail |
| ULBC_OpportunityTrigger | Opportunity | after insert/update/delete/undelete | Fire donor tier recalculation |

### Total test count: 62 passing, 0 failing

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
