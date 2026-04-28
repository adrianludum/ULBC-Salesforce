# Phase 5A.3 — Typed Handlers — Deployment Notes

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

## What's next — Phase 5A.4

| Component | Description |
|---|---|
| **Salesforce Site** | Create a public Site at `ulbctrustlimited.my.site.com` with no path prefix. Guest user profile, FLS minimal — only what the LWCs need. |
| **`ulbcEventRegister` LWC** | Public page at `/events/<campaign-name>` reading the Event Campaign by URL slug, calling `ULBC_StripeCheckoutController.createEventSession(campaignId, qty, ulbc_trust_id?)` to get a Stripe Checkout URL, redirecting. |
| **`ulbcDonate` LWC** | Public page at `/donate` reading `?ulbc_trust_id=ULBC-XXXX&fund=<campaignId>` from URL, pre-filling Contact data if TrustID matches, calling `createDonationSession(...)` for Checkout. |
| **`ULBC_StripeCheckoutController`** | Apex class wrapping Stripe Checkout Session creation via HTTP callout (Named Credential `Stripe`). Sets metadata per Decision 5.9. |
| **Stripe API key** | Test-mode `sk_test_...` API key in a Named Credential — admin sets up, never appears in code. |
| **Update donation base URL** | Custom Setting `DonationBaseURL__c` from placeholder to `https://ulbctrustlimited.my.site.com/donate`. |
| **End-to-end test** | Real Stripe Checkout in test mode → real webhook delivery → Opportunity + CampaignMember in Salesforce. |

5A.4 needs OQ-027 fully resolved (signing secret already configured ✅) and a Stripe **API key** (not signing secret — different thing) in a Named Credential. The API key is what Salesforce uses to CALL Stripe to create Checkout Sessions; the signing secret is what Stripe uses to PROVE webhook payloads to Salesforce.
