# ULBC Trust Salesforce — Open Questions
*Last updated: 2026-04-08*

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

**OQ-008**: What is the full list of Campaigns/Funds at launch? (Unrestricted, Women's Group, Equipment/Fleet, Events, Scholarship, Bursary, Coaching confirmed — any others?)

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

**OQ-020**: Does Gift Aid need to be tracked at the individual transaction level (on each Opportunity) or at the contact level only (declaration on Contact)?
*PRD specifies both — confirm before Phase 2C build.*

**OQ-021**: What is the ULBC Trust charity registration number? Needed for Gift Aid configuration.
*Blocking: Phase 2C (Gift Aid)*
