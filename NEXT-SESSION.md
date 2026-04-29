# Next session — Phase 5A.5 wrap-up

Email deliverability work (Decision 5.20, OQ-039 to OQ-045) is **parked** as of 2026-04-29 — ULBC is moving to a different email account / hosting setup, so the SPF/DMARC values would need to be reconsidered against the new sender. See OQ-051 for the gating decision. Don't touch email this session.

Paste the block below into a new Claude session to resume.

---

## Prompt to paste

> Phase 5A.5 — wrap up the donate + event ticketing build. Donate flow is live and end-to-end verified; events flow is deployed but unverified; a few polish items are outstanding before we either flip 5A to production or move on to Phase 6 (Xero).
>
> **Status as of last session (2026-04-29):**
> - All of 5A.1, 5A.2, 5A.3, 5A.4 deployed and committed.
> - 208 tests passing org-wide.
> - Public Salesforce Site `ULBC Public` is created and active at `https://ulbctrustlimited.my.salesforce-sites.com` (legacy `.my.salesforce-sites.com` hostname, NOT `.my.site.com`).
> - Stripe Dashboard webhook endpoint is in test mode, pointed at `https://ulbctrustlimited.my.salesforce-sites.com/services/apexrest/stripe/webhook`, signing secret stored in Custom Setting.
> - **Donate flow: smoke-tested end-to-end ✅** — real £25 test-card payment via `/donate` produced a Closed Won Opportunity (`006Sk00000ThXUfIAN`) and webhook log `WHL-00008` Status=Processed.
> - **Email deliverability is parked** (OQ-051). Don't restart it this session. The DNS still has GoDaddy stock SPF/DMARC defaults — Salesforce mail is currently spam-foldered, but fixing it properly waits on the email-account-move decision.
>
> **Read first** (in this order):
> 1. `RUNBOOK-5A.4.md` end-to-end — especially "Smoke-test fixes applied" and "Hostname note".
> 2. `DECISIONS.md` Decision 5.21 (5A.4 implementation choices), Decision 5.22 (sharing strategy). Skip 5.20 (parked).
> 3. `OPEN-QUESTIONS.md` items OQ-046 to OQ-050 — the explicit 5A.5 backlog. (OQ-039 to OQ-045 are all marked ⏸️ on hold and OQ-051 is the gate that has to clear before they reopen.)
>
> **Goals for this session, in order:**
>
> 1. **Smoke-test the event ticketing flow (OQ-046).** Find or create a test Campaign with `ULBC_Ticket_Price__c` set (e.g. £10). Open `https://ulbctrustlimited.my.salesforce-sites.com/events?id=<CampaignId>` in incognito, complete a test-card flow, and verify the resulting `CampaignMember` (Status=Purchased, Stripe Payment ID stamped) and Closed Won `Opportunity` (Type=Event Ticket, linked to the Campaign). Diagnose any failures the same way we did the donation flow — most likely failure mode is another `with sharing` class somewhere in the trigger chain that wasn't caught.
>
> 2. **Surface webhook log diagnostic fields (OQ-047).** Edit `ULBC_Webhook_Log__c`'s Compact Layout AND Detail Layout to expose `ULBC_Status__c`, `ULBC_Stripe_Event_Type__c`, `ULBC_Stripe_Event_ID__c`, `ULBC_Error_Message__c`, `ULBC_Stripe_Timestamp__c`, and `ULBC_Processed_At__c`. Also update the default list view columns so the at-a-glance triage works without CLI SOQL. Deploy as metadata so it's reproducible.
>
> 3. **Pull the Site into source control (OQ-048).** Run `sf project retrieve start --metadata CustomSite:ULBC_Public --target-org ulbc` and commit the resulting `force-app/main/default/sites/ULBC_Public.site-meta.xml` so the Site is reproducible in a scratch org from now on.
>
> 4. **Optional: clean up the two orphan Contacts (OQ-049)** — `003Sk00000wKzp8IAC` and `003Sk00000vmACiIAM` were created during the failed-smoke-test attempts. If they're still around and have no related Opportunities/CampaignMembers, delete them via SOQL or Setup. Skip if you want to keep them as a record.
>
> 5. **Optional: tidy up runbooks 5A.2 / 5A.3 to reflect the correct `.my.salesforce-sites.com` hostname (OQ-050).** Or accept the runbooks as a historical record and add a single corrigendum line.
>
> **Out of scope this session:**
>
> - **Email deliverability** (Decision 5.20, OQ-039..045). Parked until OQ-051 (new email account/hosting decision) is resolved. Will be picked up in its own focused session once the new setup is decided.
> - **Production go-live** (OQ-029) — separate deliberate session. Requires live-mode Stripe webhook + live signing secret + live restricted API key in Named Credential `Stripe_API` + a real £1 charge-and-refund test.
> - **Phase 6 Xero** — the next significant chunk after 5A.5 closes and production goes live. Blocked anyway on OQ-030 (chart of accounts mapping from Finance Person).

---

## What you'll need on hand

- Salesforce CLI authenticated to org `ulbc` (already done — `sf org list` should show it).
- Stripe Dashboard test-mode access (for any further webhook config if needed).
- A Campaign with `ULBC_Ticket_Price__c` set, OR be ready to create one in Setup before the events smoke test. (The `Test Event` Campaign created during 5A.4 unit tests is wiped after each test run — you'll need a real persistent one.)

When the session finishes:
- 5A is functionally complete with the events flow proven and the Site in source control.
- The next milestones are (a) decide the email-account move (OQ-051) so deliverability work can resume, (b) production cutover (OQ-029), and (c) Phase 6 Xero integration build.
