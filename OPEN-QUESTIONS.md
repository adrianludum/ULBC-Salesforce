# ULBC Trust Salesforce — Open Questions
*Last updated: 2026-04-28*

---

## Resolved Questions

**OQ-001** ✅ — Tyrian subscription: ~£75/year (will change — stored on record). Decision 2.5.
**OQ-002** ✅ — ULBC alumni subscription: £100/year (will change — stored on record). Decision 2.5.
**OQ-003** ✅ — Users defined: Admin x2, Fundraiser, Finance, Event Organiser, Coach, Boathouse Manager. Decision 1.20.

---

## Tier 1 — Blocks configuration (must resolve before relevant phase)

**OQ-004**: The org has Action Plans, Actionable Relationship Center, and Advanced Program Management showing -1 remaining licences. Does this need to be resolved with Salesforce before go-live?
*Blocking: Phase 3 (profiles/access)*

**OQ-005**: What does "Mem Type" field in FileMaker map to in the new system? Values seen include "A" — full decode list needed.
*Blocking: Phase 4 (migration)*

**OQ-006**: What is the complete list of College IDs / Member Institutions for the Education History Institution field? Currently Text — will become a picklist once this list is confirmed.
*Blocking: Phase 4 (migration)*

---

## Tier 2 — Can decide during build

**OQ-007**: What interests will be tracked beyond rowing? (cycling, skiing, theatre mentioned — full list needed for Interests multi-select picklist on Contact). Not yet built.

**OQ-008** ✅ — Launch funds confirmed: Unrestricted/General, ULBC Women's Group, Equipment/Fleet, Event, Scholarship, Bursary, Coaching. 7 Campaign records deployed. Decision 3.2.

**OQ-009**: What is the protocol for creating a new restricted fund? Who can authorise it?

**OQ-010**: What schools should be included in the School drop-down? Export from FileMaker needed.

**OQ-011**: How should "GoneAway" contacts (in FileMaker) be handled in Salesforce?
*Partial answer: Gone Away flag exists on Contact, trigger sets HasOptedOutOfEmail = true. Migration rule: import with Gone Away = true and let trigger handle opt-out.*

---

## Tier 3 — Can wait until beta

**OQ-012**: What does the Stripe integration need to capture per transaction?

**OQ-013**: Will there be a donor-facing portal or online giving page?

**OQ-014**: What reports does the fundraiser need on day one?

**OQ-015**: Who will build the HTML form + Stripe + Salesforce API integration for events?

**OQ-016**: How technical is the day-to-day Salesforce administrator?

---

## Phase 2 Open Questions — Added 2026-04-08

**OQ-017** ✅ — Upgrade prospect emails go to fundraising manager (info@innovatefundraising.com). Single default recipient, not per-contact lookup. Decision 2.8.

**OQ-018** ✅ — From address is noreply@ulbctrust.org. Org-Wide Email Address to be verified in Setup. Decision 2.9.

**OQ-019** ✅ — Upgrade Prospect flag manually cleared by fundraiser after acting. Decision 2.7.

**OQ-020** ✅ — Gift Aid tracked at both levels. Declaration data on Contact; per-donation eligibility + claimed date on Opportunity. Decision 2.10.

**OQ-021** ✅ [CLOSED 2026-04-28] — ULBC Trust Charity Commission no. **1174721** (England & Wales). Recorded in PRD §2 and Decision 5.17. Will be referenced when Gift Aid HMRC R68 submission tooling is built (separate phase, not v1).

---

## Phase 2C Open Questions — Added 2026-04-09

**OQ-022**: Should the Contact lookup on ULBC_Subscription__c and ULBC_Tyrian_Membership__c be enforced as required via a Validation Rule (since the metadata-level required=true conflicts with Salesforce's deleteConstraint rules)?
*Recommendation: Yes — add a Validation Rule to both objects: ISBLANK(ULBC_Contact__c) → error "A contact must be selected". Low priority — add in Phase 3 alongside other validation rules.*

**OQ-023** ✅ [CLOSED 2026-04-28] — `noreply@ulbctrust.org` verified as an Organization-Wide Email Address. Phase 2B Upgrade Prospect Record-Triggered Flow is now unblocked and can be built (still scheduled under Phase 3D email comms).

---

## Phase 3B Open Questions — Added 2026-04-15

**OQ-024** ✅ — Lead conversion field mapping configured in Setup. Lead.ULBC_Gender__c → Contact.ULBC_Gender__c. TrustID now auto-assigned on Contact insert (Phase 3C trigger). Admin still manually sets Primary Contact Type = 'Athlete-Student' post-conversion.

---

## Phase 5 Open Questions — Stripe Integration (Added 2026-04-27)

**OQ-025**: Bethany Welch (cus_4wkmnY5jxHjbK1) is on a £80/yr legacy Student subscription from 2014, currently active and renewing. Should she be (a) grandfathered at £80/yr indefinitely, (b) gently migrated to the new £100/yr ULBC Subscription model (with her consent), or (c) cancelled and reissued as Tyrian £75/yr?
*Recommendation: Option (a) — grandfather. One person, not worth automation. Revisit if she lapses.*
*Decision needed by: Fundraiser*

**OQ-026**: WordPress site is managed by a third party (per Adrian, 2026-04-27). Need to:
(a) Confirm whether they will continue to host the donate page or whether the website is being rebuilt elsewhere.
(b) If staying with WordPress: agree on plugin choice (WP Simple Pay vs GiveWP vs custom) and confirm they can pass the metadata contract from Decision 5.9.
(c) If rebuilding the site: agree on platform and timing.
*Decision needed by: Adrian + WordPress admin. Does NOT block Phase 5 build (Salesforce-side independent of front-end).*

**OQ-027**: Stripe webhook signing secret. Adrian needs to generate a new endpoint in Stripe Dashboard (Developers → Webhooks → Add endpoint) once the Salesforce Site URL is known, and store the signing secret as a Custom Metadata Record or Protected Custom Setting.
*Blocking: Phase 5A.2 (webhook receiver deployment).*

**OQ-028** ✅ [CLOSED 2026-04-28] — Decision 5.16: v1 uses existing My Domain `ulbctrustlimited.my.site.com` (confirmed in Setup, enhanced domains enabled), Site URL Path Prefix blank. Custom domain (`events.ulbctrust.org`) deferred to v2 — requires DNS access. `DonationBaseURL__c` will be updated from the placeholder to `https://ulbctrustlimited.my.site.com/donate` once the Site is deployed in 5A.4.

**OQ-029**: Stripe test mode vs live mode flip. Build entirely in Stripe test mode. Production go-live requires:
(a) New Stripe webhook endpoint pointed at the same Salesforce Site URL but with the LIVE signing secret.
(b) Custom Metadata Record updated to swap test secret for live secret.
(c) End-to-end test with a real £1 donation, then refund.
*Standard practice — flagged so it's not forgotten on launch day.*

---

## Phase 6 Open Questions — Xero Integration (Added 2026-04-27)

**OQ-030**: Chart of accounts mapping. For each combination of Salesforce Fund (Campaign) × Gift Type, what is the corresponding Xero Account Code and Tracking Category? Need full mapping table from Finance Person before Phase 6 build. Example rows needed:
| Fund | Gift Type | Xero Account Code | Xero Tracking Category |
|---|---|---|---|
| Unrestricted / General | One-Off | ??? | ??? |
| Unrestricted / General | Recurring | ??? | ??? |
| Scholarship | One-Off | ??? | ??? |
| ...etc for all 7 funds × all gift types | | | |
*Blocking: Phase 6 build (cannot create accurate Xero invoices without this).*
*Decision needed by: Finance Person.*

**OQ-031**: Xero invoice numbering. Should Salesforce-generated invoices use Xero's auto-numbering, or follow a Salesforce pattern (e.g. SF-OPP-12345)? Affects how Finance Person searches/reconciles in Xero.
*Recommendation: Use Xero auto-numbering. Salesforce Opportunity ID stored in Xero Reference field for cross-reference.*
*Decision needed by: Finance Person.*

**OQ-032**: Gift Aid in Xero — separate line item, separate invoice, or tracking-only? When a £100 donation is Gift Aid eligible, how should the £25 reclaim appear in Xero?
*Options: (a) £100 invoice with Gift Aid as a tracking flag only; reclaim entered manually as separate income when HMRC pays out. (b) £125 invoice with £25 line as "Gift Aid receivable". (c) Two invoices.*
*Recommendation: (a) — keep Gift Aid out of donation invoices, log as separate income on HMRC payout. Charity accounting standard.*
*Decision needed by: Finance Person + auditor.*

**OQ-033**: Xero Connected App registration. Adrian needs to register a Salesforce Connected App in the Xero developer portal (https://developer.xero.com/) to obtain OAuth 2.0 client ID and secret. One-time setup.
*Blocking: Phase 6 build.*

**OQ-034**: Historical opportunities — should Xero invoices be created retroactively for the 24,940 migrated Opportunities, or only for new Opportunities created after Xero integration go-live?
*Recommendation: New only. Backfilling 24,940 invoices into Xero would create accounting chaos in periods that are already closed and audited. Historical donations remain in Salesforce only.*
*Decision needed by: Finance Person + Adrian.*

**OQ-035**: Refunds in Xero. When a donation is refunded in Stripe, how does Xero handle it? Options: (a) Credit Note created automatically by Salesforce → Xero handler. (b) Manual handling by Finance Person.
*Recommendation: (a) Automated Credit Note. Build alongside the main invoice creation.*
*Decision needed by: Finance Person.*


---

## Resolved Phase 5 Open Questions (Closed 2026-04-27)

**OQ-036** [CLOSED 2026-04-27]: Bulk donation-link export tool — how should the Fundraiser produce personalised donation URLs at scale (e.g. 800 alumni in a Christmas appeal)?
*Resolution: Closed by confirmation that all fundraising email is sent from Salesforce (Marketing User licences in Phase 1). The merge field `{!Contact.ULBC_Donation_Link__c}` on the new formula field is sufficient — no separate export tool needed. If Fundraiser ever needs CSV export, a List View "Export" action covers it natively.*

**OQ-037** [CLOSED 2026-04-27]: How should the donate page accept and forward the `ulbc_trust_id` URL parameter to Stripe Checkout, given the WordPress page is managed by a third party?
*Resolution: Closed by Decision 5.15. Personalised donations go to a new Salesforce-hosted donate page (`ulbcDonate` LWC on the same Salesforce Site as event ticketing). The third-party WordPress page handles only cold/anonymous traffic. No third-party cooperation required.*

---

## Phase 5/3 Tidy-up

**OQ-038**: Broken legacy report `ULBC_Crews_By_Regatta` fails to deploy with "invalid report type" despite the referenced Custom Report Type `ULBC_Crew_Histories` existing in the org. Currently excluded from project deploys (file moved to `~/ulbc-crews-report-broken.xml.bak`) and the `ULBC_Dashboard.dashboard-meta.xml` that references it is also excluded (`*.broken` rename). Pre-existing from Phase 2C/3.
*Investigate during a Phase 2C/3 tidy-up sprint. Either rebuild the Custom Report Type, or delete the report (and remove its reference from the dashboard).*
*Not blocking any phase.*

