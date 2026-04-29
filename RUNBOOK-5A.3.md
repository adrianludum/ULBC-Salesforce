# Phase 5A.3 — Typed Handlers — Deployment Notes

> **2026-04-29 corrigendum**: this runbook refers to the Site URL as `ulbctrustlimited.my.site.com` (enhanced-domains form). The org actually serves Sites at `ulbctrustlimited.my.salesforce-sites.com` (legacy form), with `urlPathPrefix=donate` (so the events page is at `/donate/events`, not `/events` directly). The Stripe webhook endpoint URL was updated accordingly during 5A.4 smoke testing. See RUNBOOK-5A.4.md "Hostname + URL Path Prefix note" for the current state.

**Status:** Deployed ✅ 2026-04-28 to org `ulbc`.
**Test count:** 194 passing org-wide (25 new across 4 test classes).
**Coverage:** 94% org-wide.

---

## What was deployed

### New Apex classes
| Class | Purpose |
|---|---|
| `ULBC_ContactMatcher` | Implements Decision 5.8 four-tier match priority (TrustID → Stripe Customer ID → email → create). Plus helper `linkStripeCustomerId` that lazily binds a Stripe customer to a Contact on first payment. |
| `ULBC_DonationHandler` | Handles `intent=donation` — finds/creates Contact, captures Gift Aid declaration (if first-time), links Stripe Customer ID, creates Closed Won Opportunity on the fund Campaign. |
| `ULBC_EventTicketHandler` | Handles `intent=event_ticket` — finds/creates Contact, ensures Purchased CampaignMember status exists, upserts CampaignMember with the Stripe Payment ID stamped, creates Closed Won Opportunity. |
| `ULBC_StripeWebhook` (modified) | After signature verification, dispatches by `metadata.intent`. Subscription is logged Ignored; non-checkout event types are Ignored; missing/unknown intents return 400 Error. |

### Picklist additions
| Field | New values |
|---|---|
| `Contact.ULBC_Acquisition_Channel__c` | `Stripe Donation`, `Stripe Event Registration` |
| `Opportunity.ULBC_Gift_Type__c` | `Event Ticket` |
| `ULBC_Webhook_Log__c.ULBC_Status__c` | `Processed`, `Ignored` |

### Permission set
`ULBC_Full_Access` granted access to the 3 new Apex classes.

### Tests (25 new)
| Class | Count | Coverage |
|---|---|---|
| `ULBC_ContactMatcher_Test` | 8 | All four match priorities + new-contact path + Stripe Customer ID link helper |
| `ULBC_DonationHandler_Test` | 7 | TrustID match, recurring mapping, new donor, Gift Aid capture, Gift Aid no-overwrite, valid fund, invalid fund |
| `ULBC_EventTicketHandler_Test` | 4 | Happy path, missing campaign_id, invalid campaign_id, repeat purchase upsert |
| `ULBC_StripeWebhook_Test` | 6 new (15 total) | Donation dispatch, event_ticket dispatch, subscription Ignored, missing intent, unknown intent, handler exception |

---

## Behaviour reference

### Match priority (Decision 5.8) — applied by both handlers

| Step | Match key | Source on Stripe payload |
|---|---|---|
| 1 | `Contact.ULBC_Trust_ID__c` | `metadata.ulbc_trust_id` |
| 2 | `Contact.ULBC_Stripe_Customer_ID__c` | `session.customer` |
| 3 | `Contact.Email` OR `ULBC_Secondary_Email__c` | `customer_details.email` |
| 4 | (no match) | Create new Contact, `ULBC_Acquisition_Channel__c` = "Stripe Donation" or "Stripe Event Registration", `ULBC_GDPR_Legal_Basis__c` = "Consent", `ULBC_Primary_Contact_Type__c` = "Other" |

The match step is recorded in the webhook log's `ULBC_Error_Message__c` (renamed mentally to "Processing Notes" — the field stores match info on success too).

### Donation flow

```
Stripe checkout.session.completed
  metadata: { intent: "donation", fund: "<Campaign Id>",
              ulbc_trust_id?, gift_aid: "true|false",
              gift_aid_postcode?, gift_type: "One-Off|Recurring" }
  ↓
1. ContactMatcher.findOrCreate → Contact
2. linkStripeCustomerId (no-op if Contact already has one)
3. If gift_aid=true AND no prior declaration → populate Contact declaration
4. Look up fund Campaign (silently skip if Id invalid — Opp still created)
5. Insert Opportunity (Stage=Closed Won, Type=One-off/Regular, Source=Digital,
   Gift Aid Eligible from metadata, CampaignId from fund if found)
  ↓
Webhook log: Status=Processed
```

### Event ticket flow

```
Stripe checkout.session.completed
  metadata: { intent: "event_ticket", campaign_id: "<Campaign Id>",
              ulbc_trust_id? }
  ↓
1. Validate metadata.campaign_id → Campaign (HARD FAIL if missing/invalid)
2. ContactMatcher.findOrCreate → Contact
3. linkStripeCustomerId
4. Ensure Purchased CampaignMember status exists on this Campaign
5. Upsert CampaignMember (Status=Purchased, ULBC_Stripe_Payment_ID__c set)
6. Insert Opportunity (Stage=Closed Won, Type=Event Ticket, Source=Event,
   CampaignId=campaign_id)
  ↓
Webhook log: Status=Processed
```

### Status outcomes (full table)

| Webhook outcome | HTTP | `ULBC_Status__c` |
|---|---|---|
| Sig verify fails (any reason) | 400 / 500 | Signature Invalid / Expired / Missing |
| Body verifies but JSON parse fails | 400 | Malformed |
| Event type ≠ checkout.session.completed | 200 | Ignored |
| `metadata.intent = "subscription"` | 200 | Ignored |
| `metadata.intent` missing | 400 | Error |
| `metadata.intent` unknown value | 400 | Error |
| Donation handler succeeds | 200 | Processed |
| Event-ticket handler succeeds | 200 | Processed |
| Handler throws (e.g. invalid campaign_id) | 500 | Error |
| Stripe replay of already-logged event | 200 | Duplicate |
| Misconfigured (no signing secret) | 500 | Error |

---

## Verifying end-to-end (when 5A.4 lands)

After 5A.4 deploys the Salesforce Site, you can fire a real test event from Stripe:

1. Stripe Dashboard (test mode) → Developers → Webhooks → your endpoint
2. Click **Send test webhook** → choose `checkout.session.completed`
3. Stripe sends a synthetic payload — but with empty `metadata`
4. Result in Salesforce: log row with `ULBC_Status__c = Error`, message "metadata.intent is missing"

To test the happy path, you'll need to either:
- Edit the test payload in Stripe's webhook tester to inject `metadata.intent`
- Run an actual Stripe Checkout flow from the LWC (5A.4 work)

For now (5A.3 ship), the end-to-end test we've validated is via Apex test mocks — `test_dispatch_donation_marksProcessed` proves the full pipeline from raw signed payload through to Opportunity creation.

---

## Known limitation (worth knowing)

If a handler exception fires AFTER signature verification:

1. The webhook log row is inserted with `ULBC_Status__c = Error` AND the event_id stored.
2. Stripe retries the same event_id.
3. The retry hits the Unique constraint on `ULBC_Stripe_Event_ID__c` → caught → marked `Status = Duplicate`, **handler is not re-run**.
4. Manual intervention needed: admin reads the original Error log, identifies root cause, fixes the underlying issue (e.g. invalid Campaign Id sent), and either creates the records by hand or asks the donor to re-attempt.

This is intentional for v1 — auto-retrying handler errors risks duplicate Opportunities if the original error happened mid-DML. We can build a "reprocess" admin action later if production volume justifies it.

---

## Admin prep for Phase 5A.4 — completed 2026-04-28

All admin-side prerequisites are in place. No further user action needed before 5A.4 build can start.

| Item | Status | Where it lives |
|---|---|---|
| Webhook signing secret | ✅ stored | `ULBC_Stripe_Settings__c.WebhookSigningSecret__c` (Custom Setting org-default) |
| Stripe webhook endpoint | ✅ created (test/sandbox mode) | Stripe Dashboard → Developers → Webhooks. URL: `https://ulbctrustlimited.my.site.com/services/apexrest/stripe/webhook`. Subscribed to `checkout.session.completed`. Will return errors until 5A.4 deploys the Site — Stripe retries are harmless. |
| Stripe API restricted key | ✅ stored | Named Credential `Stripe_API` (legacy, Password Authentication, Generate Authorization Header ✓). Test-mode `rk_test_...` with **Checkout Sessions: Write** + **Customers: Write** scopes only. URL `https://api.stripe.com`. Smoke-tested via `POST /v1/customers` → 200. |
| My Domain | ✅ confirmed | `ulbctrustlimited.my.salesforce.com` (enhanced domains). Site URL will be `ulbctrustlimited.my.site.com`. |
| Charity registration | ✅ recorded | PRD §2 — Charity Commission no. 1174721. |

## What's next — Phase 5A.4 (build)

Pure code work. No further admin actions needed unless the Site activation step needs an admin click (will flag at deploy time).

| Component | Description |
|---|---|
| **`ULBC_StripeCheckoutController`** | Apex class. Methods: `createDonationSession(amount, fund, ulbc_trust_id?, gift_aid?, gift_aid_postcode?, gift_type)` and `createEventSession(campaignId, qty, ulbc_trust_id?)`. Each builds a Stripe Checkout Session via HTTP callout to `callout:Stripe_API/v1/checkout/sessions`, sets `metadata` per Decision 5.9 (including the amended `ulbc_trust_id` key), returns the Stripe-hosted Checkout URL. |
| **`ulbcDonate` LWC** | Public Lightning Web Component. Reads `?ulbc_trust_id=ULBC-XXXX&fund=<campaignId>` URL params. Captures amount, Gift Aid declaration (with postcode), one-off vs recurring. Calls `createDonationSession`, redirects browser to Stripe URL. |
| **`ulbcEventRegister` LWC** | Public LWC. URL `/events/<campaign-name-slug>`. Pulls Campaign metadata (name, dates, venue, ticket price). Captures quantity. Calls `createEventSession`, redirects to Stripe URL. |
| **Salesforce Site** | Create public Site at `ulbctrustlimited.my.site.com` (path prefix blank). Site Guest User profile granted: read on Campaign + Event-related custom fields, Apex class access on `ULBC_StripeCheckoutController`, Apex class access on `ULBC_StripeWebhook` (already granted to Full Access — needs guest-user grant). |
| **Update `DonationBaseURL__c`** | Custom Setting from `https://placeholder.invalid/donate` to `https://ulbctrustlimited.my.site.com/donate`. The `Contact.ULBC_Donation_Link__c` formula starts producing real URLs. |
| **End-to-end test** | Real Stripe Checkout flow in test mode → webhook delivery → Opportunity + CampaignMember land in Salesforce. The full loop. |

Estimate: one focused session, ~10–15 new tests including Apex callout mocking via `Test.setMock(HttpCalloutMock, ...)`.
