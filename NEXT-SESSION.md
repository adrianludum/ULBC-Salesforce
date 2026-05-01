# Next session — Stripe production go-live (OQ-029)

Phase 5A is **complete**. Phase 6 Xero is **live** (Decisions 6.9–6.14, daily 02:00 UTC import). Phase 6 orphan notifications **deployed 2026-04-30** (Decision 6.13) — bell live to Martin Peel, email digest built and pre-wired to `adminulbh@gmail.com` but switch OFF. **Decision 6.14 deployed 2026-05-01**: noise orphans (Xero Contact has no AccountNumber yet) are now *deferred* — no Opp, no notification, watermark held back so the next nightly run re-pulls them once Martin assigns AccountNumbers in Xero. 9 pre-existing noise orphans deleted in the same session — they'll re-import cleanly when Martin sets AccountNumbers. Three possible directions next:

1. **Resolve OQ-053 (Stripe ↔ Xero double-counting)** — **still the Stripe go-live blocker.** Decision 6.14 incidentally suppresses double-counting for Stripe payouts that arrive in Xero with no AccountNumber, but Stripe payouts that DO have AccountNumber (or any that Martin starts assigning in Xero) would still double-count. Recommended fix: extend `ULBC_XeroIncomeImporter` to skip transactions whose Xero reference matches an existing `ULBC_Stripe_Payment_ID__c` on Opportunity.
2. **Stripe production go-live (OQ-029)** — flip from test mode to live charges. **Blocked on OQ-053 above.** Otherwise fully ready.
3. **Email deliverability (OQ-039..OQ-045)** — blocked on OQ-051 (decide new email account / hosting). Resume after that decision.
4. **Verify orphan notifications + flip email switch on** — small follow-up after a real *genuine* orphan (AccountNumber present, no Salesforce match) appears in a future run. Decision 6.14 reduces orphan volume substantially, so this may now wait days/weeks rather than hours. One Custom Setting flip (`ULBC_Xero_Settings__c.OrphanNotificationsEnabled__c = true`).
5. **OQ-052** — close the orphan loop by pushing assigned Trust IDs back to Xero AccountNumber. Quick Action on Opportunity. Not blocking; complementary to Decision 6.14 (the loop becomes: import → defer → manual Xero assign → re-import; OQ-052 would automate the manual step).

The prompt below is for **option 1** (production go-live). Swap to a different prompt if you'd rather tackle email or start Phase 6 — see the alternative-prompt section at the bottom.

Paste the block below into a new Claude session to resume.

---

## Prompt to paste — Stripe production go-live (OQ-029)

> **Stripe production go-live.** Phase 5A is fully complete on test mode (last commit on `main` 2026-04-29). I need to flip Stripe to live mode end-to-end without breaking anything.
>
> **Status as of last session (2026-04-29):**
> - All of 5A.1–5A.5 deployed and committed. 208 tests passing org-wide.
> - Donate flow smoke-tested end-to-end ✅ (£25 test card → Opportunity `006Sk00000ThXUfIAN`, webhook log `WHL-00008`).
> - Events flow smoke-tested end-to-end ✅ (£75 test card on `Henley Women 2026` → Opportunity `006Sk00000TiLPpIAN`, CampaignMember Status=Purchased, webhook log `WHL-00011`).
> - Public Site live at `https://ulbctrustlimited.my.salesforce-sites.com` (legacy hostname), urlPathPrefix=donate.
> - Stripe Dashboard webhook endpoint is currently in **test mode** at `https://ulbctrustlimited.my.salesforce-sites.com/services/apexrest/stripe/webhook`.
> - Named Credential `Stripe_API` currently uses a **test-mode** restricted API key (`rk_test_…`).
> - `ULBC_Stripe_Settings__c.WebhookSigningSecret__c` currently holds the **test-mode** webhook signing secret.
>
> **Read first**: `OPEN-QUESTIONS.md` OQ-029 (the documented checklist for the test→live flip), `DECISIONS.md` Decision 5.22 (the sharing strategy that Phase 5A converged on, including the 2026-04-29 amendment for the controller).
>
> **Goals for this session, in order:**
>
> 1. **Pre-flight check.** Confirm test-mode is healthy: latest webhook log Status=Processed, the £25 + £75 Opportunities still exist, the Stripe Dashboard test-mode webhook is still receiving events successfully. If anything's degraded since 2026-04-29, fix that first before going live.
>
> 2. **Stripe Dashboard switch to live mode.** Adrian creates:
>     - A live-mode webhook endpoint pointed at the same Salesforce URL (`https://ulbctrustlimited.my.salesforce-sites.com/services/apexrest/stripe/webhook`), subscribed to `checkout.session.completed`. Capture the **live signing secret** (`whsec_live_…`).
>     - A live-mode restricted API key with the same scopes as the test key (Checkout Sessions: Write, Customers: Write). Capture the secret value once (`rk_live_…`).
>
> 3. **Salesforce config swap.** Three values to update:
>     - `ULBC_Stripe_Settings__c.WebhookSigningSecret__c` → live `whsec_live_…` (write a one-line Anonymous Apex script in `scripts/apex/set-live-signing-secret.apex`, then run it; do NOT commit the secret).
>     - Named Credential `Stripe_API` → swap the password (the API key) from `rk_test_…` to `rk_live_…` in Setup. URL stays at `https://api.stripe.com`.
>     - Decide whether to keep both webhook endpoints active in Stripe (test + live) or disable the test one. Recommendation: keep test active and pointed at the same URL — our handler dedupes by event_id, so it's safe; useful to keep test working for future debugging.
>
> 4. **Live smoke test.** Adrian makes a real **£1** donation to the unrestricted fund through `/donate?fund=<unrestricted-campaign-id>` using a real card. Watch the webhook log for `Status=Processed`. Verify the Opportunity lands. Then **refund** the £1 in Stripe Dashboard. (Refund handling itself is OQ-035 — out of scope for this session; we're just confirming the live happy path.)
>
> 5. **Document.** Create `RUNBOOK-5A-PROD-GO-LIVE.md` recording: the date of cutover, the two new Stripe IDs (webhook endpoint id, restricted-key prefix only — never the secret), the date and amount of the live smoke test, the refund event id. Close OQ-029 in `OPEN-QUESTIONS.md`.
>
> **Out of scope this session:**
> - Refund-to-Salesforce handling (OQ-035) — separate work.
> - Email deliverability (parked on OQ-051).
> - Phase 6 Xero (blocked on OQ-030).
>
> **Don't paste any Stripe secret into source control or chat.** Use scripts that read from prompts, or paste directly into Setup. The runbook records prefixes only.

---

## Alternative prompt — Email deliverability (after OQ-051 resolved)

> Resume Phase 3D email deliverability. ULBC has decided on the new email account / hosting setup (OQ-051 — fill in the answer here when known: domain, host, From addresses). Decision 5.20 was scoped against the old `ulbctrust.org` Microsoft 365 setup and is parked; the values need to be reconsidered against the new sender.
>
> Read first: `DECISIONS.md` Decision 5.20 (parked — original record preserved), `OPEN-QUESTIONS.md` OQ-039 to OQ-045 (all marked ⏸️ on hold) and OQ-051 (the gate — should now be resolved).
>
> Goals: generate a new DKIM key pair in Salesforce for the new domain → publish CNAMEs in DNS → verify with `dig` → publish SPF + DMARC TXT records (values depend on the new host) → click Activate → mail-tester end-to-end ≥ 9/10 → Decision 5.20 superseded by a new decision recording the live setup.

---

## Alternative prompt — Phase 6 Xero integration (after OQ-030 resolved)

> Start Phase 6 Xero integration. Adrian / Finance Person has provided the chart-of-accounts mapping (OQ-030).
>
> Read first: `PRD.md` §15a (Xero integration), `DECISIONS.md` Decisions 6.1 through 6.8.
>
> Goals (multi-session): Phase 6A.1 Connected App registration → 6A.2 Named Credential + OAuth flow → 6A.3 Custom Metadata Type for the account mapping → 6A.4 `ULBC_XeroInvoiceService` class → 6A.5 `ULBC_OpportunityXeroSync` trigger → 6A.6 `ULBC_Xero_Contact_ID__c` lazy creation. End-to-end smoke test: a Closed Won Opportunity in Salesforce produces a paid invoice in Xero against the right account code.

---

## What you'll need on hand

For the production go-live track (option 1):
- Stripe Dashboard access in live mode (Adrian).
- Salesforce CLI + admin in `ulbc` org.
- A real card for the £1 live smoke test (refunded immediately after).

For the email track (option 2): the new email-account setup details.

For the Xero track (option 3): the chart-of-accounts mapping from Finance Person.
