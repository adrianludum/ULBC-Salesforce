# Phase 5A.1 — Deployment Runbook

**Goal:** Add Stripe data model fields, donation link formula, custom setting, and supporting tests.
**Estimated time:** 20–30 minutes (most of it merging perm sets and layouts).
**Org:** ulbc (adrian-36nu@cassidy.uk.com)
**Prerequisite check:** None for 5A.1. OQ-027 (Stripe webhook signing secret) and OQ-028 (Site URL) are NOT prerequisites for 5A.1 — they block 5A.2/5A.4 only.

---

## Step 0 — Prep

Make sure your project is on the latest main branch and tests are green before you start:

```bash
cd ~/ULBC-salesforcce
git status                              # should be clean
sf apex run test --target-org ulbc --code-coverage --result-format human --wait 10
```

You should still see 62 tests passing from earlier phases. If anything's red, fix that first — don't pile new metadata on top of broken tests.

---

## Step 1 — Copy the new metadata files into your project

Copy from this delivery into your project's `force-app/main/default/`:

```
force-app/main/default/objects/Contact/fields/ULBC_Stripe_Customer_ID__c.field-meta.xml
force-app/main/default/objects/Contact/fields/ULBC_Donation_Link__c.field-meta.xml
force-app/main/default/objects/CampaignMember/fields/ULBC_Stripe_Payment_ID__c.field-meta.xml
force-app/main/default/objects/ULBC_Stripe_Settings__c/ULBC_Stripe_Settings__c.object-meta.xml
force-app/main/default/objects/ULBC_Stripe_Settings__c/fields/DonationBaseURL__c.field-meta.xml
force-app/main/default/classes/ULBC_StripeFields_Test.cls
force-app/main/default/classes/ULBC_StripeFields_Test.cls-meta.xml
```

CampaignMember does not have its own custom object folder under standard SFDX projects — the field-meta.xml goes in `force-app/main/default/objects/CampaignMember/fields/`. If that folder doesn't exist, create it. SFDX handles standard object custom field deployment fine.

---

## Step 2 — Merge the permission set patches

Open `permission-set-patches.md` (in this delivery). Open each of the four perm set XML files in your project and add the `<fieldPermissions>` blocks listed.

Files to edit:
- `force-app/main/default/permissionsets/ULBC_Full_Access.permissionset-meta.xml`
- `force-app/main/default/permissionsets/ULBC_Finance.permissionset-meta.xml`
- `force-app/main/default/permissionsets/ULBC_Fundraiser.permissionset-meta.xml`
- `force-app/main/default/permissionsets/ULBC_Event_Organiser.permissionset-meta.xml`

**CRITICAL:** `ULBC_Donation_Link__c` is a formula field. In every perm set, it must have `<editable>false</editable>`. If you set it to true, the deployment will fail with a confusing "field is not editable" error.

Keep `<fieldPermissions>` blocks in alphabetical order by field name — Salesforce doesn't enforce this, but it makes diffs and merges far easier.

---

## Step 3 — Patch the page layouts

Open `layout-patches.md` (in this delivery).

If `Contact-Layout.layout-meta.xml` and `CampaignMember-Layout.layout-meta.xml` are NOT in your project yet, retrieve them first:

```bash
sf org list metadata --metadata-type Layout --target-org ulbc | grep -iE 'contact|campaign'
# Note the exact layout names, then:
sf project retrieve start --metadata "Layout:Contact-Contact Layout" --target-org ulbc
sf project retrieve start --metadata "Layout:CampaignMember-CampaignMember Layout" --target-org ulbc
```

(The layout fullName format is `ObjectName-LayoutName`. The default Contact page layout is usually `Contact-Contact Layout`. Check the org listing output for the exact string.)

Once retrieved, merge in the `<layoutSections>` blocks from `layout-patches.md`.

---

## Step 4 — Deploy

```bash
sf project deploy start \
    --source-dir force-app/main/default/objects/Contact/fields/ULBC_Stripe_Customer_ID__c.field-meta.xml \
    --source-dir force-app/main/default/objects/Contact/fields/ULBC_Donation_Link__c.field-meta.xml \
    --source-dir force-app/main/default/objects/CampaignMember/fields/ULBC_Stripe_Payment_ID__c.field-meta.xml \
    --source-dir force-app/main/default/objects/ULBC_Stripe_Settings__c \
    --source-dir force-app/main/default/permissionsets \
    --source-dir force-app/main/default/layouts \
    --source-dir force-app/main/default/classes/ULBC_StripeFields_Test.cls \
    --target-org ulbc \
    --wait 10
```

Or simpler — deploy the whole project (longer, but exercises any other unsynced metadata):

```bash
sf project deploy start --source-dir force-app --target-org ulbc --wait 15
```

Watch for these errors:

| Error | Cause | Fix |
|---|---|---|
| "Field is not writeable: Contact.ULBC_Donation_Link__c" | `<editable>true</editable>` set on a formula field in a perm set | Change to `<editable>false</editable>` in all four perm sets |
| "Custom setting required" | DonationBaseURL referenced in formula before the Custom Setting deploys | Deploy Custom Setting object first, then the Contact field. The combined deploy command above orders this correctly. |
| "External ID field already in use" | An old Stripe Customer ID field exists from a previous attempt | `sf data query --query "SELECT ULBC_Stripe_Customer_ID__c FROM Contact LIMIT 1" --target-org ulbc` to confirm. If it exists, rename or drop the old one before re-deploying. |

---

## Step 5 — Set the Custom Setting org-default value

Until the Salesforce Site is created in 5A.4, set a placeholder URL so the formula doesn't render an obviously broken link in any email accidentally sent before 5A.4 lands:

```bash
sf data create record \
    --sobject ULBC_Stripe_Settings__c \
    --values "SetupOwnerId=$(sf org display --target-org ulbc --json | jq -r '.result.id') DonationBaseURL__c=https://placeholder.invalid/donate" \
    --target-org ulbc
```

Or via UI: Setup → Custom Settings → ULBC Stripe Settings → Manage → New (Default Organization Level Value) → set DonationBaseURL to `https://placeholder.invalid/donate`.

The `.invalid` TLD is reserved by RFC 2606 — this means any test email accidentally sent before 5A.4 will produce a clearly-broken link rather than something that looks real. You will UPDATE this value to the real Site URL in Step 5A.4.

---

## Step 6 — Run the tests

```bash
sf apex run test \
    --tests ULBC_StripeFields_Test \
    --target-org ulbc \
    --code-coverage \
    --result-format human \
    --wait 10
```

Expected: 6 passing, 0 failing.

If `test_donationLinkFormula_rendersCorrectly` fails with a mismatched URL, check:
1. The Custom Setting org-default value was set in Step 5
2. The formula field deployed (check via Setup → Object Manager → Contact → Fields)
3. There's no whitespace difference in the formula expression

If either uniqueness test fails, the External ID + Unique flags didn't deploy correctly. Check the field metadata in Setup → Object Manager and confirm "External ID" and "Unique" are both ticked.

---

## Step 7 — Smoke test in the UI

1. Open Jade Smith's Contact record (ULBC-0001).
2. Confirm the new "Stripe Integration" section appears with two fields.
3. `Stripe Customer ID` should be empty (no Stripe activity yet — correct).
4. `Donation Link` should display: `https://placeholder.invalid/donate?ulbc_trust_id=ULBC-0001`
5. Hover the Donation Link — it's a Text formula field, NOT a Hyperlink. (We chose Text so it works as a merge field in plain-text emails. If you want it to render as a clickable link in record detail view, we can add a separate Hyperlink-type formula field in 5A.4 for UI use only.)

---

## Step 8 — Commit and push

```bash
git add force-app/main/default/objects/Contact/fields/ULBC_Stripe_Customer_ID__c.field-meta.xml \
        force-app/main/default/objects/Contact/fields/ULBC_Donation_Link__c.field-meta.xml \
        force-app/main/default/objects/CampaignMember/fields/ULBC_Stripe_Payment_ID__c.field-meta.xml \
        force-app/main/default/objects/ULBC_Stripe_Settings__c \
        force-app/main/default/permissionsets \
        force-app/main/default/layouts \
        force-app/main/default/classes/ULBC_StripeFields_Test.cls \
        force-app/main/default/classes/ULBC_StripeFields_Test.cls-meta.xml

git commit -m "Phase 5A.1: Stripe data model — Customer ID, Payment ID, Donation Link formula, Custom Setting

Adds:
- Contact.ULBC_Stripe_Customer_ID__c (Text 255, External ID, Unique)
- Contact.ULBC_Donation_Link__c (formula referencing Custom Setting + Trust ID)
- CampaignMember.ULBC_Stripe_Payment_ID__c (Text 255, External ID, Unique)
- ULBC_Stripe_Settings__c hierarchy custom setting with DonationBaseURL__c
- Field permissions on 4 perm sets per Decision 5.10
- Page layout updates on Contact and CampaignMember
- ULBC_StripeFields_Test (6 tests covering existence, External ID flags, uniqueness, formula rendering)

Implements Decisions 5.10, 5.14, 5.15.
Closes OQ-036.

Test count: 68 passing (was 62)."

git push
```

---

## What you'll have after 5A.1

| Item | Status |
|---|---|
| Contact: Stripe Customer ID field (External ID, Unique) | ✅ Deployed |
| Contact: Donation Link formula field | ✅ Deployed |
| CampaignMember: Stripe Payment ID (External ID, Unique) | ✅ Deployed |
| ULBC_Stripe_Settings__c Custom Setting | ✅ Deployed with placeholder URL |
| Permission sets updated | ✅ Deployed |
| Page layouts updated | ✅ Deployed |
| Apex tests | ✅ 6 new tests, total org count = 68 passing |

---

## What's next — Phase 5A.2 preview

Once 5A.1 is green, the next session will be:
- Apex class `ULBC_StripeWebhookController` — public REST endpoint at `/services/apexrest/stripe/webhook`
- Stripe signature verification using `Crypto.generateMac('HmacSHA256', ...)`
- Logging only — no business logic yet (that's 5A.3)
- A `ULBC_Webhook_Log__c` custom object so you can inspect every payload Stripe has sent
- Mock-payload tests

5A.2 needs from you in the meantime:
- **OQ-027**: Once we know the Salesforce Site URL (5A.4), generate the webhook signing secret in Stripe Dashboard. We can defer this until the Site is up.
- Confirm: do you want webhook payload bodies stored in full on `ULBC_Webhook_Log__c`, or only metadata (event type, ID, timestamp)? Storing full bodies is invaluable for debugging but uses more storage. Default would be: full body for first 30 days, then a scheduled job that strips the body and keeps only the header info.

But first — get 5A.1 deployed and 6 new tests green.
