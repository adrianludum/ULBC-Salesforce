# Next session — Phase 5A.5 wrap-up + production go-live prep

Paste the block below into a new Claude session to resume.

---

## Prompt to paste

> Phase 5A.5 — wrap up the donate + event ticketing build. Donate flow is live and end-to-end verified; events flow is deployed but unverified; a few polish items are outstanding before we either flip 5A to production or move on to Phase 6 (Xero).
>
> **Status as of last session (2026-04-28):**
> - All of 5A.1, 5A.2, 5A.3, 5A.4 deployed and committed (last commit `dc3b819`).
> - 208 tests passing org-wide.
> - Public Salesforce Site `ULBC Public` is created and active at `https://ulbctrustlimited.my.salesforce-sites.com` (the legacy `.my.salesforce-sites.com` hostname, NOT `.my.site.com`).
> - Stripe Dashboard webhook endpoint is in test mode, pointed at `https://ulbctrustlimited.my.salesforce-sites.com/services/apexrest/stripe/webhook`, signing secret stored in Custom Setting.
> - **Donate flow: smoke-tested end-to-end ✅** — real £25 test-card payment via `/donate` produced a Closed Won Opportunity in Salesforce with Stripe Payment ID stamped (webhook log `WHL-00008` Status=Processed, Opportunity `006Sk00000ThXUfIAN`).
> - Decision 5.21 logged: post-signature-verification Stripe webhook chain runs `without sharing` because the signature verification is the security boundary and the guest user's restricted view would otherwise block legitimate system operations.
>
> **Read first** (in this order):
> 1. `RUNBOOK-5A.4.md` end-to-end — especially the "Smoke-test fixes applied" and "Hostname note" sections.
> 2. `OPEN-QUESTIONS.md` items OQ-039 through OQ-043 — the explicit 5A.5 backlog.
> 3. `DECISIONS.md` Decisions 5.20 and 5.21 — the implementation choices and the sharing-strategy rule.
>
> **Goals for this session, in order:**
>
> 1. **Smoke-test the event ticketing flow (OQ-039).** Find or create a test Campaign with `ULBC_Ticket_Price__c` set (e.g. £10). Open `https://ulbctrustlimited.my.salesforce-sites.com/events?id=<CampaignId>` in incognito, complete a test-card flow, and verify the resulting `CampaignMember` (Status=Purchased, Stripe Payment ID stamped) and Closed Won `Opportunity` (Type=Event Ticket, linked to the Campaign). Diagnose any failures the same way we did the donation flow — most likely failure mode is another `with sharing` class somewhere in the trigger chain that I missed.
>
> 2. **Surface webhook log diagnostic fields (OQ-040).** Edit `ULBC_Webhook_Log__c`'s Compact Layout AND Detail Layout to expose `ULBC_Status__c`, `ULBC_Stripe_Event_Type__c`, `ULBC_Stripe_Event_ID__c`, `ULBC_Error_Message__c`, `ULBC_Stripe_Timestamp__c`, and `ULBC_Processed_At__c`. Also update the default list view columns so the at-a-glance triage works without CLI SOQL. Deploy as metadata so it's reproducible.
>
> 3. **Pull the Site into source control (OQ-041).** Run `sf project retrieve start --metadata CustomSite:ULBC_Public --target-org ulbc` and commit the resulting `force-app/main/default/sites/ULBC_Public.site-meta.xml` so the Site is reproducible in a scratch org from now on.
>
> 4. **Optional: clean up the two orphan Contacts (OQ-042)** — `003Sk00000wKzp8IAC` and `003Sk00000vmACiIAM` were created during the failed-smoke-test attempts. If they're still around and have no related Opportunities/CampaignMembers, delete them via SOQL or Setup. Skip if you want to keep them as a record.
>
> 5. **Optional: tidy up runbooks 5A.2 / 5A.3 to reflect the correct `.my.salesforce-sites.com` hostname (OQ-043).** Or accept the runbooks as a historical record and add a single corrigendum line.
>
> **Do NOT flip Stripe to live mode in this session.** Production go-live is OQ-029 — a separate, deliberate step that requires: new live-mode webhook endpoint + live signing secret + live restricted API key in Named Credential `Stripe_API` + a real £1 charge-and-refund test. Schedule that for a focused production-cutover session, not bundled with polish.
>
> **What's NOT in scope:** Phase 6 Xero integration is the next significant chunk of work after 5A.5 closes and production go-live happens. Don't touch Xero this session.

---

## What you'll need on hand

- Salesforce CLI authenticated to org `ulbc` (already done — `sf org list` should show it).
- Stripe Dashboard test-mode access (for any further webhook config if needed).
- Optional: a Campaign with `ULBC_Ticket_Price__c` set, OR be ready to create one in Setup before the events smoke test. The `Test Event` Campaign created during 5A.4 unit tests is wiped after each test run — you'll need a real persistent one.

When the session finishes:
- 5A is functionally complete and metadata-tracked.
- The next milestones are (a) production cutover (OQ-029) and (b) Phase 6 Xero integration build.
