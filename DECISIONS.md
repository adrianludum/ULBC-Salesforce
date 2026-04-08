# ULBC Trust Salesforce — Decision Log
*Last updated: 2026-04-08*
*Current phase: Phase 2B Complete — Ready for Phase 2C*

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
