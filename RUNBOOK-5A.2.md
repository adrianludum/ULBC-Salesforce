# Phase 5A.2 — Stripe Webhook Receiver — Deployment Notes

**Status:** Deployed ✅ 2026-04-28 to org `ulbc` (`ulbctrustlimited.my.salesforce.com`).
**Test count:** 167 passing org-wide (9 new in `ULBC_StripeWebhook_Test`).
**Coverage:** `ULBC_StripeWebhook` 92%.

---

## What was deployed

| Component | Type | Notes |
|---|---|---|
| `ULBC_Webhook_Log__c` | Custom object | Audit trail, one row per webhook delivery |
| `ULBC_Stripe_Event_ID__c` | Text(255) on log | **Unique** — enforces idempotency at DB layer |
| `ULBC_Stripe_Event_Type__c` | Text(100) on log | e.g. `checkout.session.completed` |
| `ULBC_Stripe_Timestamp__c` | DateTime on log | Parsed from header `t=` |
| `ULBC_Processed_At__c` | DateTime on log (required) | Salesforce server time at receive |
| `ULBC_Status__c` | Picklist on log (required) | Verified / Signature Invalid / Signature Expired / Signature Missing / Malformed / Duplicate / Error |
| `ULBC_Raw_Payload__c` | LongTextArea(131072) on log | Full body verbatim |
| `ULBC_Payload_Truncated__c` | Checkbox on log | True if body exceeded LTA max |
| `ULBC_Signature_Header__c` | LongTextArea(1024) on log | Verbatim Stripe-Signature header |
| `ULBC_Error_Message__c` | LongTextArea(4096) on log | Failure detail |
| `WebhookSigningSecret__c` | Text(255) on `ULBC_Stripe_Settings__c` | **Set this in Step 1 below** |
| `ULBC_StripeWebhook` | Apex REST class | `/services/apexrest/stripe/webhook` |
| `ULBC_StripeWebhook_Test` | Apex test class | 9 tests, signature verify + log behavior |
| `ULBC_Full_Access` perm set | Updated | Object + field perms on Webhook Log (required fields excluded per Decision 3.15) |

---

## Endpoint

**Path:** `/services/apexrest/stripe/webhook`
**Method:** `POST`
**Auth:** None (public endpoint — security via signature verification)
**Full URL once Site deployed in 5A.4:**

```
https://ulbctrustlimited.my.site.com/services/apexrest/stripe/webhook
```

The Site itself is not deployed yet — endpoint is reachable internally via `/services/apexrest/stripe/webhook` on the Salesforce host but not publicly exposed until 5A.4.

---

## Behaviour

The receiver writes a log row for **every** delivery attempt, including failures. Status values:

| Status | Meaning | HTTP |
|---|---|---|
| `Verified` | HMAC matched, event id+type captured | 200 |
| `Signature Missing` | No `Stripe-Signature` header | 400 |
| `Signature Invalid` | Header malformed or HMAC mismatch | 400 |
| `Signature Expired` | Header timestamp outside ±300s window | 400 |
| `Malformed` | Body verified by signature but not valid JSON | 400 |
| `Duplicate` | Replay — event_id already logged (Unique violation caught) | 200 (ack so Stripe stops retrying) |
| `Error` | Any unhandled exception, or signing secret blank | 500 |

The 5-minute tolerance window matches Stripe's recommended replay-protection guidance. The `Duplicate` path means Stripe retries of an already-processed event are absorbed gracefully — Phase 5A.3 will rely on this same idempotency guarantee.

**No business logic yet.** Verified events are logged and the response is 200 — nothing else happens. Phase 5A.3 will add `intent` dispatching off `metadata.intent` per Decision 5.9.

---

## What you need to do — Step 1 — Set the signing secret

The webhook will return 500 with `Status = Error` until `WebhookSigningSecret__c` is populated. Two options:

**Option A — UI** (recommended for now, since you don't have a real secret yet):

1. Setup → Quick Find → **Custom Settings**
2. **ULBC Stripe Settings** → **Manage**
3. Click **Edit** on the existing org-default record
4. Set **Webhook Signing Secret** to a placeholder (e.g. `whsec_placeholder_will_set_in_5a4`)
5. Save

**Option B — wait until 5A.4**, when we create the actual Stripe endpoint and get the real signing secret. The webhook will return 500 to any caller in the meantime, which is the correct behaviour: an unconfigured webhook should reject everything.

---

## Smoke test

Once the secret is set, you can poke the endpoint internally to confirm the log row writes. Easiest way is via the Salesforce Developer Console → `Debug → Open Execute Anonymous`:

```apex
RestRequest req = new RestRequest();
req.requestURI = '/services/apexrest/stripe/webhook';
req.httpMethod = 'POST';
req.requestBody = Blob.valueOf('{"id":"evt_smoke_test","type":"ping","data":{}}');
req.headers.put('Stripe-Signature', 'no-real-signature');
RestContext.request = req;
RestContext.response = new RestResponse();
ULBC_StripeWebhook.handlePost();
System.debug('Status: ' + RestContext.response.statusCode);
System.debug('Body: ' + RestContext.response.responseBody.toString());
```

Expected: status 400, body `{"success":false,"message":"Signature verification failed: ...","logId":"a..."}`.

Then check via SOQL:

```sql
SELECT Id, Name, ULBC_Status__c, ULBC_Error_Message__c, ULBC_Stripe_Event_ID__c
FROM ULBC_Webhook_Log__c
ORDER BY CreatedDate DESC LIMIT 5
```

You should see a row with `Status = Signature Invalid`. The receiver is alive.

---

## What's next — Phase 5A.3

Phase 5A.3 plugs the typed handlers in:

1. After `Status = Verified`, parse `metadata.intent` (Decision 5.9 contract).
2. Dispatch:
   - `intent=event_ticket` → `ULBC_EventTicketHandler` — find/create Contact (per Decision 5.8 priority), create CampaignMember on the named campaign, create Closed Won Opportunity, set `ULBC_Stripe_Payment_ID__c`, send confirmation email.
   - `intent=donation` → `ULBC_DonationHandler` — find/create Contact, create Closed Won Opportunity with fund Campaign, capture Gift Aid metadata, send thank-you.
   - `intent=subscription` → reserved (currently bank-only per Decision 5.1).
3. Update log row: `Status = Processed` on success, `Status = Error` on handler exception.
4. Phase 5A.3 needs ~12 new tests covering each intent + matching priority + Gift Aid path.

Phase 5A.3 is independent of OQ-027 (signing secret) and OQ-028 (Site URL). Both unblock 5A.4 only.
