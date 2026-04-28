# Next session — Email deliverability finish + Phase 5A.4 kick-off

Two threads to pick up. Do thread 1 first (small, ~30 min), then thread 2 (the big build).

Paste the block below into a new Claude session to resume.

---

## Prompt to paste

> Two threads to finish off — start with thread 1 (small), then move to thread 2.
>
> ## Thread 1 — Finish email deliverability setup (Decision 5.20)
>
> **Status as of last session (2026-04-28 evening):**
> - DKIM key generated in Salesforce (selector `salesforce`, alternate `salesforcealt`, RSA 2048, exact-domain match `ulbctrust.org`).
> - Both DKIM CNAMEs added to GoDaddy DNS.
> - Primary CNAME `salesforce._domainkey.ulbctrust.org` verified live via MXToolbox ✅.
> - SPF and DMARC values agreed (see Decision 5.20) but not yet confirmed live in GoDaddy.
> - DKIM Activate button in Salesforce — NOT yet clicked.
> - First mail-tester send did not arrive — root cause not diagnosed.
>
> **What to do:**
> 1. Verify alternate DKIM CNAME at MXToolbox (`salesforcealt._domainkey.ulbctrust.org`) → expect `salesforcealt.asnhtx.custdkim.salesforce.com`.
> 2. Verify SPF and DMARC at MXToolbox SPF Record Lookup and DMARC Lookup against `ulbctrust.org`. If missing or wrong, walk Adrian through the GoDaddy fix.
> 3. Click **Activate** on the DKIM key in Salesforce Setup → DKIM Keys.
> 4. Send a fresh test from a Contact's Activity tab — From `noreply@ulbctrust.org`, To `adrian+salesforce@cassidy.uk.com`. Use the branded HTML template (purple banner, ULBC logo, charity number footer).
> 5. Inspect raw headers in the received email. Confirm `spf=pass`, `dkim=pass d=ulbctrust.org`, `dmarc=pass`.
> 6. Run a mail-tester send and target 9+/10. Diagnose any deductions.
> 7. Resolve OQ-039, OQ-040, OQ-041 in `OPEN-QUESTIONS.md` once each step passes.
> 8. Discuss OQ-042 (whether to add `info@ulbctrust.org` as a friendlier From for bulk fundraising) — this is a fundraiser decision but make a recommendation.
>
> **Read first:**
> - `PRD.md` §13 — current email config and deliverability status table
> - `DECISIONS.md` Decision 5.20 — full record set and DMARC tightening schedule
> - `OPEN-QUESTIONS.md` OQ-039 through OQ-045
>
> ---
>
> ## Thread 2 — Phase 5A.4 build (Stripe Site + LWCs)
>
> Once thread 1 is closed, move to Phase 5A.4 — build the Salesforce Site + LWCs + Stripe Checkout integration to complete the donation and event-ticket flow end-to-end.
>
> **Status as of last session (2026-04-28):**
> - Phases 5A.1, 5A.2, 5A.3 are deployed and committed (last code commit `295deb7`).
> - Webhook receiver is verifying signatures and dispatching by `metadata.intent` to typed handlers (`ULBC_DonationHandler`, `ULBC_EventTicketHandler`).
> - 194 org-wide tests passing, 94% coverage.
> - **All admin prerequisites for 5A.4 are complete** — Stripe webhook endpoint created (test mode), signing secret in Custom Setting, restricted API key in Named Credential `Stripe_API` with Checkout Sessions Write + Customers Write scopes, smoke-tested 200 OK.
>
> **Read first** (in this order):
> 1. The "Admin prep for Phase 5A.4 — completed 2026-04-28" and "What's next — Phase 5A.4 (build)" sections at the bottom of `RUNBOOK-5A.3.md` — these are the source of truth for what's done and what's needed.
> 2. `DECISIONS.md` Decisions 5.4, 5.7, 5.9 (with 2026-04-27 amendment), 5.10, 5.14, 5.15, 5.16, 5.18, 5.19 — these define the Stripe metadata contract, Site URL strategy, contact match priority, and current data model.
> 3. `PRD.md` §15 — phase plan for Stripe integration.
>
> **Then propose your plan** for the build before coding. I want to push back on it before you start. In particular:
> - How you'll structure `ULBC_StripeCheckoutController` (one method per intent, or one parameterised method?)
> - LWC structure — do you handle Gift Aid as a single component or break it out?
> - Salesforce Site — deployable via metadata or admin-clicks-only? (I think metadata for the Site object + permission set + guest-user-FLS, but the Site **activation** may need a click.)
> - Test strategy for the Apex callout (`HttpCalloutMock` for the Checkout Session creation; full webhook flow already tested in 5A.3).
>
> Don't start coding until I've reviewed your plan.

---

## What you'll need on hand

For thread 1: GoDaddy DNS access (`dcc.godaddy.com/control/portfolio/ulbctrust.org/settings`), Salesforce Setup access, mail-tester.com, MXToolbox.

For thread 2: Nothing further from Stripe Dashboard or Salesforce Setup unless we hit something unexpected during Site activation. The build is code-and-deploy from here.

When the 5A.4 build finishes:
- You'll do an end-to-end test by going to `https://ulbctrustlimited.my.site.com/donate?ulbc_trust_id=ULBC-0001&fund=<a Campaign Id>` in an incognito browser, completing a £1 test-mode card payment (Stripe test card `4242 4242 4242 4242`, any future expiry, any CVC, any postcode), and watching the Opportunity appear in Salesforce within seconds.
- Test mode only. Production go-live is a separate later step (OQ-029).
