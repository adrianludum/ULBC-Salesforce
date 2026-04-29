# Next session — Email deliverability finish + Phase 5A.5 wrap-up

Two threads, both partial. Do thread 1 first (small, ~30 min — finishing what was started 2026-04-28 evening), then thread 2 (5A.5 wrap-up, ~1 focused session).

Paste the block below into a new Claude session to resume.

---

## Prompt to paste

> Two threads to finish off — start with thread 1 (small), then move to thread 2.
>
> **Status as of last session (2026-04-29):**
> - All of 5A.1, 5A.2, 5A.3, 5A.4 deployed and committed.
> - 208 tests passing org-wide.
> - Public Salesforce Site `ULBC Public` is created and active at `https://ulbctrustlimited.my.salesforce-sites.com` (legacy `.my.salesforce-sites.com` hostname, NOT `.my.site.com`).
> - Stripe Dashboard webhook endpoint is in test mode, pointed at `https://ulbctrustlimited.my.salesforce-sites.com/services/apexrest/stripe/webhook`, signing secret stored in Custom Setting.
> - **Donate flow: smoke-tested end-to-end ✅** — real £25 test-card payment via `/donate` produced a Closed Won Opportunity (`006Sk00000ThXUfIAN`) and webhook log `WHL-00008` Status=Processed.
> - Email auth (Decision 5.20) is half-set-up: DKIM key generated and CNAMEs added to GoDaddy, primary CNAME verified live, but Activate not clicked, alternate not verified, SPF/DMARC not yet confirmed live, mail-tester not yet succeeded.
>
> **Read first** (in this order):
> 1. `RUNBOOK-5A.4.md` end-to-end — especially "Smoke-test fixes applied" and "Hostname note".
> 2. `DECISIONS.md` Decisions 5.20 (email auth), 5.21 (5A.4 implementation), 5.22 (sharing strategy).
> 3. `OPEN-QUESTIONS.md` OQ-039 to OQ-050 — the explicit backlog for both threads.
> 4. `PRD.md` §13 (email config) and §15 (Stripe phase plan).
>
> ## Thread 1 — Finish email deliverability (Decision 5.20, OQ-039 to OQ-045)
>
> **Status as of last session (2026-04-28 evening):**
> - DKIM key generated in Salesforce (selectors `salesforce` / `salesforcealt`, RSA 2048, exact-domain match `ulbctrust.org`).
> - Both DKIM CNAMEs added to GoDaddy DNS.
> - Primary CNAME `salesforce._domainkey.ulbctrust.org` verified live via MXToolbox ✅.
> - SPF and DMARC values agreed (Decision 5.20) but not confirmed live in GoDaddy.
> - DKIM **Activate** button in Salesforce — NOT yet clicked.
> - First mail-tester send did not arrive — root cause not diagnosed.
>
> **Goals (in order):**
> 1. Verify alternate DKIM CNAME at MXToolbox (`salesforcealt._domainkey.ulbctrust.org`) → expect `salesforcealt.asnhtx.custdkim.salesforce.com`.
> 2. Verify SPF and DMARC at MXToolbox SPF Record Lookup and DMARC Lookup against `ulbctrust.org`. If missing or wrong, walk Adrian through the GoDaddy fix.
> 3. Click **Activate** on the DKIM key in Salesforce Setup → DKIM Keys.
> 4. Send a fresh test from a Contact's Activity tab — From `noreply@ulbctrust.org`, To `adrian+salesforce@cassidy.uk.com`. Use the branded HTML template (purple banner, ULBC logo, charity number footer).
> 5. Inspect raw headers in the received email. Confirm `spf=pass`, `dkim=pass d=ulbctrust.org`, `dmarc=pass`.
> 6. Run a mail-tester send and target 9+/10. Diagnose any deductions.
> 7. Close OQ-039, OQ-040, OQ-041 in `OPEN-QUESTIONS.md` once each step passes.
> 8. Discuss OQ-042 (whether to add `info@ulbctrust.org` as a friendlier From for bulk fundraising) — make a recommendation.
> 9. Set calendar reminders for the OQ-045 DMARC tightening dates (2026-05-12 → quarantine, 2026-06-09 → reject).
>
> ## Thread 2 — Phase 5A.5 wrap-up (OQ-046 to OQ-050)
>
> Once thread 1 is closed, wrap up Phase 5A so it's fully done before production go-live (OQ-029) or Phase 6 (Xero).
>
> **Goals (in order):**
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
> ## Out of scope this session
>
> - **Production go-live** (OQ-029) — separate deliberate session. Requires live-mode Stripe webhook + live signing secret + live restricted API key in Named Credential `Stripe_API` + a real £1 charge-and-refund test.
> - **Phase 6 Xero** — the next significant chunk after 5A.5 closes and production goes live. Blocked anyway on OQ-030 (chart of accounts mapping from Finance Person).

---

## What you'll need on hand

For thread 1 (email): GoDaddy DNS access (`dcc.godaddy.com/control/portfolio/ulbctrust.org/settings`), Salesforce Setup access, mail-tester.com, MXToolbox.

For thread 2 (5A.5): Salesforce CLI authenticated to org `ulbc` (already done — `sf org list` should show it). A Campaign with `ULBC_Ticket_Price__c` set, OR be ready to create one in Setup before the events smoke test. (The `Test Event` Campaign created during 5A.4 unit tests is wiped after each test run — you'll need a real persistent one.)

When the session finishes:
- Email is fully authenticated and verified clean (mail-tester 9+/10, DKIM/SPF/DMARC all `pass` in headers), AND
- 5A is functionally complete with the events flow proven and the Site in source control.
- The next milestones are (a) production cutover (OQ-029) and (b) Phase 6 Xero integration build.
