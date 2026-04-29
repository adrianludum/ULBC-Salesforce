# ULBC Trust Salesforce — Open Questions
*Last updated: 2026-04-29 (post-5A.4 smoke test, email work parked pending new-account decision)*

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

**OQ-027** ✅ [CLOSED 2026-04-28] — Stripe webhook endpoint created in test mode (sandbox), pointed at `https://ulbctrustlimited.my.site.com/services/apexrest/stripe/webhook`. Subscribed to `checkout.session.completed`. Signing secret (`whsec_...`) stored in `ULBC_Stripe_Settings__c.WebhookSigningSecret__c`. The endpoint will return errors until 5A.4 deploys the Site — Stripe retries are harmless.

**OQ-028** ✅ [CLOSED 2026-04-28] — Decision 5.16: v1 uses existing My Domain `ulbctrustlimited.my.site.com` (confirmed in Setup, enhanced domains enabled), Site URL Path Prefix blank. Custom domain (`events.ulbctrust.org`) deferred to v2 — requires DNS access. `DonationBaseURL__c` will be updated from the placeholder to `https://ulbctrustlimited.my.site.com/donate` once the Site is deployed in 5A.4.

**OQ-029**: Stripe test mode vs live mode flip. Build entirely in Stripe test mode (sandbox). Production go-live requires:
(a) New Stripe webhook endpoint in **live mode** pointed at the same Salesforce Site URL, with the LIVE signing secret.
(b) New restricted API key in **live mode** with the same scopes (Checkout Sessions: Write, Customers: Write); update the Named Credential `Stripe_API` to use it.
(c) `ULBC_Stripe_Settings__c.WebhookSigningSecret__c` updated to the live `whsec_...`.
(d) End-to-end test with a real £1 donation, then refund.
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

---

## Phase 3D Email Deliverability — Added 2026-04-28 (Decision 5.20) — **ALL ON HOLD 2026-04-29**

> Parked: ULBC is moving to a different email account / hosting setup. Resume after OQ-051 is resolved. The questions below describe the state-as-of-2026-04-29 against the current `ulbctrust.org` setup, but the answers will change once the email account move happens. Verified via dig 2026-04-29: SPF and DMARC are still GoDaddy defaults — they were never actually updated despite earlier session notes saying otherwise. DKIM CNAMEs are correct and live.

**OQ-039** ⏸️: DKIM **Activate** button in Salesforce Setup → DKIM Keys not yet clicked. Primary CNAME `salesforce._domainkey.ulbctrust.org` is verified live via MXToolbox. Alternate CNAME `salesforcealt._domainkey.ulbctrust.org` not yet independently verified.
*Action: verify alternate CNAME via MXToolbox CNAME Lookup, then click Activate. Confirm `Active = true` on the key record.*
*Owner: Adrian. Blocking: clean DKIM signatures on all outbound Salesforce mail.*

**OQ-040** ⏸️: SPF and DMARC TXT records on `ulbctrust.org` — verified 2026-04-29 still at GoDaddy stock defaults (`v=spf1 include:secureserver.net -all` and `p=quarantine; rua=mailto:dmarc_rua@onsecureserver.net`), NOT the Decision 5.20 values. Active SPF excludes Salesforce, so Salesforce mail fails SPF. Active DMARC quarantines failures. Combined effect: Salesforce-sent mail goes to spam.
*Action: confirm both records resolve, then run a fresh mail-tester send and target 9+/10.*
*Owner: Adrian. Blocking: deliverability sign-off.*

**OQ-041** ⏸️: First mail-tester end-to-end send did not arrive at the test inbox `test-qtqqugfh9@srv1.mail-tester.com` (countdown reset repeatedly). Root cause not diagnosed in this session.
*Possibilities: (a) sent via List Email and queued, (b) Activity-tab single send not fired, (c) Org-Wide Email Address profile restriction, (d) recipient address typed incorrectly.*
*Action next session: send a fresh test from a Contact's Activity tab (From = `noreply@ulbctrust.org`, To = `adrian+salesforce@cassidy.uk.com`) and inspect headers + Setup → Email Logs.*
*Owner: Adrian. Blocking: confirmation that authentication actually works end-to-end.*

**OQ-042** ⏸️: Should bulk fundraising mail use `noreply@ulbctrust.org` (current) or be migrated to a friendlier From such as `info@ulbctrust.org` or `fundraising@ulbctrust.org`?
*Recommendation: Add a second Org-Wide Email Address (e.g. `info@ulbctrust.org`), keep `noreply@` only for system alerts (Upgrade Prospect, future automation). `noreply@` addresses score worse with spam filters and reduce reply-engagement, both of which hurt deliverability for a fundraising charity.*
*Decision needed by: Fundraiser + Adrian.*

**OQ-043** ⏸️: DMARC `rua` reporting address is `adrian+dmarc@cassidy.uk.com` — a different domain from `ulbctrust.org`. Some receivers (per RFC 7489) require a verification record at `ulbctrust.org._report._dmarc.cassidy.uk.com` on the receiving domain. Most receivers don't enforce this, but if reports don't arrive within 7 days of DMARC publish, this is the likely cause.
*Action: monitor inbox for 7 days. If no aggregate reports arrive, either add the verification record on `cassidy.uk.com` or switch `rua` to an `@ulbctrust.org` mailbox.*
*Owner: Adrian. Not blocking — deliverability still works without aggregate reports, we just lose visibility.*

**OQ-044** ⏸️: Bulk-email attachment policy. Salesforce List Email does NOT support file attachments (platform limitation). The agreed pattern is to upload to Salesforce Files, generate a Public Link, and paste the URL into the email body. No formal policy yet on file size, link expiry, or whether public links should be reviewed before sending.
*Recommendation: standard pattern documented in PRD §13. Treat any attachment >5 MB as link-only. Public links should expire after 90 days for sensitive documents.*
*Decision needed by: Fundraiser.*

**OQ-045** ⏸️: DMARC tightening — Decision 5.20 schedules a move from `p=none` → `p=quarantine` at week 2 and `p=reject` at week 6. Calendar reminder needed.
*Action: schedule a calendar reminder for 2026-05-12 (week 2) and 2026-06-09 (week 6) to revisit DMARC policy. Cannot tighten until aggregate reports show no legitimate sender failing alignment.*
*Owner: Adrian.*

---

## Phase 5A.4 follow-ups — Added 2026-04-29 (post-smoke-test)

**OQ-046**: Event registration flow (`/events?id=<CampaignId>`) is built and deployed but not yet smoke-tested end-to-end with a real test card. Needs a Campaign with `ULBC_Ticket_Price__c` set + a £1 test-card flow + verification that `CampaignMember.Status = Purchased` and the corresponding Closed Won `Opportunity` (Type `Event Ticket`) land. **Slated for Phase 5A.5.**

**OQ-047**: `ULBC_Webhook_Log__c` standard page layout doesn't expose the diagnostic fields (`ULBC_Status__c`, `ULBC_Stripe_Event_Type__c`, `ULBC_Stripe_Event_ID__c`, `ULBC_Error_Message__c`, `ULBC_Stripe_Timestamp__c`, `ULBC_Raw_Payload__c`). Investigation during 5A.4 smoke test required CLI SOQL to read the error message — admins shouldn't need that. **Add to 5A.5: edit the Compact Layout + Detail Layout to surface these fields, ideally with a list view showing Status + Stripe Event Type + Processed At as the default columns.**

**OQ-048**: Site metadata (`CustomSite:ULBC_Public`) was created via Setup UI rather than authored in source. Once the Site is stable, run `sf project retrieve start --metadata CustomSite:ULBC_Public --target-org ulbc` to pull it into `force-app/main/default/sites/` and commit. From that point the Site is metadata-tracked and reproducible in scratch orgs. **Slated for Phase 5A.5.**

**OQ-049** ✅ [CLOSED 2026-04-29]: Of the two suspected smoke-test orphans, only one was actually an orphan. Investigation:
- `003Sk00000wKzp8IAC` ("err werwer", TrustID `ULBC-0001`, 0 Opps, 0 CMs, created 2026-04-28 16:21) — true orphan from WHL-00001's broken-trigger-state attempt. **Deleted via `sf data delete record`.**
- `003Sk00000vmACiIAM` (Adrian Cassidy's real Contact, TrustID `54`, 237 Opps + 13 CMs, created 2026-04-15) — NOT an orphan. The WHL-00007 error message named this id as the "cross-reference" target because the donation handler matched the donor's identity to Adrian's Contact and tried to update it; the trigger chain (DonorTierEngine) failed under guest-user sharing. The Contact itself was untouched. WHL-00008's successful donation also linked to this Contact (the £25 Opportunity `006Sk00000ThXUfIAN` is on Adrian Cassidy's Contact).

**OQ-050**: Hostname mismatch between runbooks. RUNBOOK-5A.2 and 5A.3 documented Site URL as `ulbctrustlimited.my.site.com` (enhanced-domains form). The org actually serves at `ulbctrustlimited.my.salesforce-sites.com` (legacy form). Updated in `DonationBaseURL__c`, `EventsBaseURL__c`, and Stripe Dashboard webhook endpoint. The runbooks 5A.2 / 5A.3 still mention the wrong hostname — minor doc tidy in 5A.5 to update them retroactively (or accept as historical record).

---

## Email account migration — Added 2026-04-29

**OQ-051**: Decide on the new email account / hosting setup before resuming Decision 5.20.
*Context: as of 2026-04-29 ULBC is moving away from the `ulbctrust.org` Microsoft 365 / GoDaddy setup that Decision 5.20 was scoped against. The decision drives downstream: which mailbox Salesforce sends FROM, which `include:` lines belong in SPF, what DKIM key Salesforce should generate for the new domain, what DMARC policy makes sense, and what the Org-Wide Email Address in Salesforce should be.*
*Sub-questions to answer before resuming:*
- *Is the domain itself changing (e.g. `ulbctrust.org` → something else), or just the mailbox / hosting service?*
- *New host (Google Workspace, Microsoft 365 on a different tenant, Fastmail, self-hosted, …)?*
- *New From address(es) — bulk fundraising vs system alerts (Upgrade Prospect notifications) — same or different?*
- *Migration plan for in-flight things that hardcode `noreply@ulbctrust.org`: the Org-Wide Email Address record in Salesforce, the Upgrade Prospect alert recipient, future donor-receipt automation.*
*Action: when the email account move is decided, raise a fresh decision (5.23 or later) with the new SPF / DKIM / DMARC values for the new domain, supersede or amend Decision 5.20, and reopen OQ-039 to OQ-045 against the new setup.*
*Decision needed by: Adrian.*
*Status: open. Blocks resuming all of OQ-039 to OQ-045.*

