# Custom Mass Email Send + Tracking — Deployment Runbook

**Status:** Built, not yet deployed.
**Plan:** [`/Users/adriancassidy/.claude/plans/mass-emails-in-salesforce-glimmering-book.md`](/Users/adriancassidy/.claude/plans/mass-emails-in-salesforce-glimmering-book.md)

---

## What was built

### Schema (`force-app/main/default/objects/`)
| Object | Purpose |
|---|---|
| `ULBC_Email_Settings__c` | Hierarchy custom setting: tracking base URL, OWE Id, footer HTML, IP hash salt, tracking kill switch |
| `ULBC_Email_Send__c` | One per send. Roll-up summaries for Sent/Open/Click counts, formula Open Rate / Click Rate %. Lookup to Campaign |
| `ULBC_Email_Send_Recipient__c` | One per recipient. Master-detail to Send. Trust ID denormalised. Token, status, per-recipient open/click counters |
| `ULBC_Email_Event__c` | Forensic write-only log. Lookup (not master-detail) to Recipient so blind inserts never lock the parent rollup |

### Apex (`force-app/main/default/classes/`)
| Class | Role |
|---|---|
| `ULBC_EmailTokenService` | URL-safe random tokens (32 chars, 192 bits entropy) |
| `ULBC_EmailHtmlMutator` | Pure function: rewrite links, inject pixel, append footer with personalised unsub URL |
| `ULBC_EmailRecipientResolver` | Resolve Campaign members → eligible/suppressed list. Filter rules drop entirely; suppression rules keep with reason |
| `ULBC_EmailSendService` | Orchestration: validate, resolve, materialise records, enqueue Queueable |
| `ULBC_EmailSendQueueable` | Async send: 50/batch, render via `Messaging.renderStoredEmailTemplate`, mutate, send via `Messaging.sendEmail`, chain |
| `ULBC_EmailTrackingResource` | Public REST `/email/open|click|unsub` — returns 1×1 GIF / 302 / confirmation HTML; blind-inserts events |
| `ULBC_EmailEventAggregator` | Self-rescheduling Schedulable, every 5 min. Folds events onto Recipient counters; rollups propagate to Send |
| `ULBC_EmailSendController` | `@AuraEnabled` facade for the LWC (templates, preview, enqueue) |

Each class has a `_Test.cls` with happy + sad paths. Coverage target ≥85%.

### UI
| Component | Where |
|---|---|
| `ulbcEmailSendComposer` LWC | Quick Action on Campaign — template picker, audience filters, live counts, preview iframe, Send button |
| Quick Action `Campaign.ULBC_Send_Email` | Surfaces the LWC on Campaign record pages |

### Reports
- CRT `ULBC_Campaign_Email_Performance` — Campaign → Sends → Recipients
- CRT `ULBC_Email_Send_Recipient_Detail` — Send → Recipients → Contact (forensic)
- Starter report `ULBC_Email_Performance_By_Campaign` — grouped by Campaign with Total Sent + Total Clicks

### Permissions
- `ULBC_Email_Sender` — for staff who compose/send
- `ULBC_Email_Tracking_Guest` — for the Site Guest User (must be assigned manually, see below)

---

## Pre-deploy admin checklist

**1. Verify an OrgWideEmailAddress.**
Setup → Email → Organization-Wide Addresses → New. Enter the from address (e.g. `info@ulbctrust.org`) and display name. Verify via the email Salesforce sends. Once verified, copy the 18-character record Id.

**2. Configure DKIM Keys for the sending domain.**
Setup → Email → DKIM Keys → Create New Key. Apply the published TXT records to your DNS. Without DKIM, mail goes from `*.salesforce.com` and deliverability suffers.

**3. Create the EmailTemplate folder.**
Setup → Lightning Email Templates → All Folders → New Folder. DeveloperName: `ULBC_Bulk`. The LWC composer scopes its picker to this folder. Authors create templates with merge fields against Contact.

**4. Author the footer HTML in `ULBC_Email_Settings__c`.**
Must contain: registered charity name + number, postal address, "You're receiving this because you're a Trust supporter", and the literal token `{{UNSUB_URL}}` which the mutator replaces per-recipient.

---

## Deploy

```bash
sf project deploy start --source-dir force-app/main/default \
  --test-level RunSpecifiedTests \
  --tests ULBC_EmailTokenService_Test ULBC_EmailHtmlMutator_Test \
          ULBC_EmailRecipientResolver_Test ULBC_EmailSendService_Test \
          ULBC_EmailSendQueueable_Test ULBC_EmailTrackingResource_Test \
          ULBC_EmailEventAggregator_Test ULBC_EmailSendController_Test
```

Expected: ~50 new tests pass, no metadata validation errors.

---

## Post-deploy steps

**1. Populate `ULBC_Email_Settings__c` org default.**
Setup → Custom Settings → ULBC Email Settings → Manage → New. Fill in:
- Tracking Base URL: `https://ulbctrustlimited.my.salesforce-sites.com/donate` (same Site as Stripe webhook)
- Default From Address: as verified in step 1 of pre-deploy
- Default From Name: `ULBC Trust`
- Default Reply-To: monitored mailbox
- OrgWideEmailAddress Id: from step 1
- Footer HTML: see step 4
- IP Hash Salt: generate a random 32+ char string (this is a secret; rotate quarterly)
- Enable Tracking: ✓

**2. Assign permission sets.**
- `ULBC_Email_Sender` → staff who run sends
- `ULBC_Email_Tracking_Guest` → ULBC Public Site Guest User (Setup → Sites → ULBC_Public → Public Access Settings → Permission Set Assignments)

**3. Bootstrap the aggregator.**
Anonymous Apex:
```apex
ULBC_EmailEventAggregator.start();
```
This schedules the first run; subsequent runs reschedule themselves every 5 minutes. To cancel:
```apex
for (CronTrigger ct : [SELECT Id FROM CronTrigger
                        WHERE CronJobDetail.Name LIKE 'ULBC_EmailEventAggregator%']) {
    System.abortJob(ct.Id);
}
```

**4. Add the Quick Action to the Campaign page layout.**
Setup → Object Manager → Campaign → Page Layouts → (each layout) → drag "Send Email" Quick Action onto the layout's mobile/Lightning actions section.

**5. Smoke test.**
- Create an EmailTemplate in folder `ULBC_Bulk` with one merge field, e.g. `Hello {!Contact.FirstName}`.
- Create a test Campaign with 3 Contacts (one healthy, one with `HasOptedOutOfEmail = true`, one with no email).
- Open the Campaign → Send Email → pick the template → Refresh count (should show 1 eligible, 2 suppressed) → Preview → Send.
- Confirm 1 email arrives. Open it in Gmail/Apple Mail and click the link.
- After ~5 min, confirm `ULBC_Email_Send_Recipient__c` shows `Open_Count >= 1`, `Click_Count >= 1`, `First_Open_At` populated.
- Confirm `ULBC_Email_Send__c.Open_Rate__c` reflects 100%, `Click_Rate__c` reflects 100%.
- Click the unsubscribe link in the footer — confirm Contact.HasOptedOutOfEmail flips and the confirmation page renders.

---

## Risks (per the plan, briefly)

1. **Open rates inflated** by Apple MPP and Gmail proxying — anchor reports on click rate.
2. **Site Guest User permission drift** — schedule a smoke-test job in CI.
3. **`renderStoredEmailTemplate` SOQL** — batch size 50 keeps headroom; drop to 25 if templates use complex relationships.
4. **Regex link rewriting** — falls back gracefully when an `<a>` doesn't match the pattern (link stays untracked, send continues).
5. **No bounce handling in v1** — hard bounces re-targeted next send. v2 adds `EmailMessage.Status` parsing.

---

## v2 backlog

- IP salt rotation as scheduled job + retention purger for events >18 months
- Bounce handling
- Send-cancellation UI (Queued → Cancelled)
- Real `List-Unsubscribe` + `List-Unsubscribe-Post` headers (RFC 8058 single-click)
