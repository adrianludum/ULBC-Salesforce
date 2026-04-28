# Next session — Phase 5A.4 kick-off prompt

Paste the block below into a new Claude session to resume.

---

## Prompt to paste

> Phase 5A.4 — build the Salesforce Site + LWCs + Stripe Checkout integration to complete the donation and event-ticket flow end-to-end.
>
> **Status as of last session (2026-04-28):**
> - Phases 5A.1, 5A.2, 5A.3 are deployed and committed (last commit `295deb7`).
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

Nothing further from Stripe Dashboard or Salesforce Setup unless we hit something unexpected during Site activation. The build is code-and-deploy from here.

When the build finishes:
- You'll do an end-to-end test by going to `https://ulbctrustlimited.my.site.com/donate?ulbc_trust_id=ULBC-0001&fund=<a Campaign Id>` in an incognito browser, completing a £1 test-mode card payment (Stripe test card `4242 4242 4242 4242`, any future expiry, any CVC, any postcode), and watching the Opportunity appear in Salesforce within seconds.
- Test mode only. Production go-live is a separate later step (OQ-029).
