# Phase 5A.4 — Site + LWCs + Stripe Checkout — Deployment Notes

**Status:** Code deployed ✅ 2026-04-28 to org `ulbc`. Manual Site creation pending.
**Test count:** 203 passing org-wide (20 new in `ULBC_StripeCheckoutController_Test`).
**Deploy ID:** `0AfSk000001AXOjKAO`.

---

## What was deployed

### New Apex
| Class | Purpose |
|---|---|
| `ULBC_StripeCheckoutController` | Two `@AuraEnabled` methods (`createDonationSession`, `createEventSession`) that build Stripe Checkout Sessions via HTTP callout to `callout:Stripe_API/v1/checkout/sessions` and return the hosted Checkout URL. Plus `getEventInfo` (cacheable) for the event LWC to render Campaign details. |
| `ULBC_StripeCheckoutController_Test` | 20 tests. HttpCalloutMock captures the form-encoded body sent to Stripe and asserts the metadata contract (Decision 5.9 amended) on every variation. Covers happy path, Gift Aid w/ postcode, TrustID flow, recurring pass-through, validation rejections (below-min, missing postcode, invalid fund, zero qty, no ticket price), Stripe 4xx/5xx handling, missing URL fields, and the EventInfo wire. |

### New LWCs
| Component | Purpose |
|---|---|
| `ulbcGiftAidDeclaration` | Reusable child component. Toggle + HMRC-compliant declaration text + postcode input. Exposes `isValid()` for parent validation. |
| `ulbcDonate` | Public donate page. Reads `?ulbc_trust_id=…&fund=…&status=…` from URL, captures amount (5 presets + custom) + Gift Aid, calls `createDonationSession`, redirects to Stripe. Shows success/cancel banners on return. |
| `ulbcEventRegister` | Public event registration page. Reads `?id=<CampaignId>&ulbc_trust_id=…&status=…` from URL. Pulls Campaign metadata (name, dates, venue, ticket price, dress code, menu, transport) via `getEventInfo` wire. Captures qty (1–20), calls `createEventSession`, redirects to Stripe. |

### New Aura wrapper apps (Lightning Out for Sites)
| App | Purpose |
|---|---|
| `ULBCDonateApp` | `extends="ltng:outApp"` `implements="ltng:allowGuestAccess"`. Declares `c:ulbcDonate` + `c:ulbcGiftAidDeclaration` as dependencies so the LWC can be mounted from Visualforce via `$Lightning.createComponent`. |
| `ULBCEventRegisterApp` | Same pattern for `c:ulbcEventRegister`. |

### New Visualforce host pages
| Page | URL on Site | Purpose |
|---|---|---|
| `donate.page` | `/donate` | Mounts `c:ulbcDonate` via Lightning Out. Reads URL query params and passes them as LWC `@api` properties. |
| `events.page` | `/events` | Mounts `c:ulbcEventRegister`. |

### Schema additions
| Object | Field | Type | Purpose |
|---|---|---|---|
| `ULBC_Stripe_Settings__c` | `EventsBaseURL__c` | Text(255) | Base URL for the events page. Read by the controller to construct Stripe success/cancel URLs. Set post-deploy via `scripts/apex/set-stripe-urls.apex`. |

### Permission set updates
`ULBC_Full_Access` granted Apex class access on `ULBC_StripeCheckoutController`.

### Post-deploy script
`scripts/apex/set-stripe-urls.apex` — sets `DonationBaseURL__c` to `https://ulbctrustlimited.my.site.com/donate` and `EventsBaseURL__c` to `https://ulbctrustlimited.my.site.com/events`. Run once after the public Site exists in Setup.

---

## Manual steps remaining

The Site itself was deliberately not authored as metadata in this phase — first-time `CustomSite` creation via metadata API tends to fail because the standard error pages it references don't yet exist. Creating it via Setup is faster than fighting the metadata bootstrap.

### 1. Create the public Site (~5 min)

Setup → User Interface → **Sites and Domains → Sites** → **New**.

| Field | Value |
|---|---|
| Site Label | `ULBC Public` |
| Site Name | `ULBC_Public` |
| Site Description | Public donate + event ticketing |
| Default Web Address | leave blank (path prefix) — uses `ulbctrustlimited.my.site.com` directly |
| Active | ✅ |
| Active Site Home Page | `donate` |
| Inactive Site Home Page | leave default (`InMaintenance`) |
| Site Robots.txt | leave default |
| Site Favicon | leave default |
| Clickjack Protection Level | Allow framing by the same origin only (default) |

Save.

### 2. Add the Visualforce pages to the Site

On the Site detail page → **Site Visualforce Pages** → Edit → add `donate` and `events` to the enabled list.

### 3. Configure Site Guest User profile

On the Site detail page → **Public Access Settings** → opens the `ULBC_Public Profile`.

**Apex Class Access — enable:**
- `ULBC_StripeCheckoutController`
- `ULBC_StripeWebhook`
- `ULBC_DonationHandler`
- `ULBC_EventTicketHandler`
- `ULBC_ContactMatcher`

**Visualforce Page Access — enable:**
- `donate`
- `events`

**Object Permissions — enable Read** on:
- `Campaign`
- `Contact`
- `Opportunity`

**Field-Level Security — enable Read** on Campaign:
- `Name`, `StartDate`, `EndDate`
- `ULBC_Start_Time__c`, `ULBC_End_Time__c`
- `ULBC_Venue__c`, `ULBC_Ticket_Price__c`
- `ULBC_Dress_Code__c`, `ULBC_Menu__c`, `ULBC_Transport_Info__c`

(The webhook handlers need broader CRUD on Contact / Opportunity / CampaignMember — those are already covered by the running user when the webhook executes via Site Guest User. If end-to-end test fails with FLS errors, grant the additional Edit/Create perms on Contact, Opportunity, CampaignMember, ULBC_Webhook_Log__c.)

### 4. Run the post-deploy script

```
sf apex run -f scripts/apex/set-stripe-urls.apex --target-org ulbc
```

This sets `DonationBaseURL__c` and `EventsBaseURL__c` in `ULBC_Stripe_Settings__c` so the controller can build success/cancel URLs and the `Contact.ULBC_Donation_Link__c` formula starts producing real personalised URLs.

### 5. Smoke-test

1. Open `https://ulbctrustlimited.my.site.com/donate` in incognito. The donate LWC should load with £25 preset selected and Gift Aid toggle unchecked.
2. Click "Continue to secure checkout". You should land on a real Stripe Checkout page (test mode).
3. Pay with card `4242 4242 4242 4242`, any future expiry, any CVC, any postcode.
4. Browser redirects to `…/donate?status=success&session_id=cs_test_…` and shows the green banner.
5. Within seconds, check Salesforce: a new Contact (if not matched) and a Closed Won Opportunity for £25 with `ULBC_Gift_Source__c = Digital`. A `ULBC_Webhook_Log__c` row with `Status = Processed`.

For the event flow, repeat with `https://ulbctrustlimited.my.site.com/events?id=<CampaignId>` where the Campaign has `ULBC_Ticket_Price__c` set.

---

## Behaviour reference

### Stripe Checkout Session metadata sent (Decision 5.9 amended 2026-04-27)

**Donation:**
```
intent=donation
fund=<CampaignId>           (omitted when no fund chosen)
ulbc_trust_id=ULBC-XXXX     (omitted when not supplied)
gift_aid=true|false
gift_aid_postcode=…         (only when gift_aid=true)
gift_type=One-Off|Recurring (v1 LWC only sends One-Off)
```

**Event ticket:**
```
intent=event_ticket
campaign_id=<CampaignId>
ulbc_trust_id=ULBC-XXXX     (omitted when not supplied)
```

The webhook receivers in 5A.3 (`ULBC_DonationHandler`, `ULBC_EventTicketHandler`) consume exactly this contract.

### Validation rules enforced before callout
| Rule | Where | Error message |
|---|---|---|
| `amount >= £1` | `createDonationSession` | "Minimum donation is £1.00." |
| Gift Aid requires postcode | `createDonationSession` | "Postcode is required to claim Gift Aid." |
| `fund` Id, if supplied, must exist | `createDonationSession` | "The selected fund could not be found." |
| `campaignId` is required | `createEventSession` | "A campaign Id is required." |
| `qty >= 1` | `createEventSession` | "Quantity must be at least 1." |
| Campaign must exist + have ticket price | `createEventSession` | "This event does not have a ticket price configured." |
| `DonationBaseURL__c` populated | both | "Donate page URL is not configured." |
| `EventsBaseURL__c` populated | event flow | "Events page URL is not configured." |
| Stripe HTTP 4xx/5xx | `postCheckoutSession` | Stripe's `error.message` if available, else `"Stripe returned HTTP <code>"` |

All errors surface to the LWC as `AuraHandledException` with the message above; the LWC renders them in a `slds-text-color_error` block.

### Stripe success/cancel URLs
- Donation: `<DonationBaseURL>?status=success&session_id={CHECKOUT_SESSION_ID}` / `<DonationBaseURL>?status=cancelled`
- Event: `<EventsBaseURL>?id=<campaignId>&status=success&session_id={CHECKOUT_SESSION_ID}` / `<EventsBaseURL>?id=<campaignId>&status=cancelled`

The same LWC renders the post-payment banner when it sees `status=success` or `status=cancelled` in the URL — no separate thank-you LWC.

---

## Known limitations / deferred

1. **Recurring donations not exposed in v1 UI.** The `gift_type=Recurring` value flows through the controller and handler unchanged, but the `ulbcDonate` LWC currently only sends `One-Off`. Adding a "monthly" option would require switching the Stripe Checkout `mode` to `subscription` and processing `invoice.paid` webhook events for renewals — out of scope for this phase. (Decision 5.1 also reserves recurring giving for the bank channel.)

2. **Event URL shape uses `?id=<CampaignId>` not `/events/<slug>`.** Decision 5.4 originally proposed `/events/<campaign-name>`; Decision 5.19 deferred slug→Campaign lookup. This phase chose query-param style for symmetry with the donate page (`/donate?ulbc_trust_id=…&fund=…`). When slug routing is added later, the URL rewriter on the Site can map `/events/<slug>` → `events.page?id=<resolved-id>` without breaking the existing query-param URLs. Logged as Decision 5.20.

3. **Min donation = £1.** PRD didn't specify; chosen for v1 to allow £1 test-card flows. Adjust `MIN_DONATION_GBP` in the controller if the fundraiser wants a higher floor.

4. **Site metadata not in source control yet.** First-time creation needs the Setup-UI path. Once the Site exists, run `sf project retrieve start --metadata CustomSite:ULBC_Public` to pull it into `force-app/main/default/sites/` and commit. From that point it's metadata-deployable.

5. **No standalone thank-you / cancelled pages.** Banners on the same LWC. Sufficient for v1; can split out if marketing wants tracking pixels or different copy.

6. **End-to-end smoke test deferred until manual Site setup is done.** All 20 unit tests + the 174 prior org tests + the LWC framework checks pass. The full webhook→Opportunity loop was already proven in 5A.3 with mocked signed payloads. The remaining unproven leg is Site → Stripe redirect → return — verifiable in 5–10 min once the Site is up.
