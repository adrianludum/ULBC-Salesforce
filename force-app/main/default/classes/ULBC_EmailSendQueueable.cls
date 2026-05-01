/**
 * ULBC_EmailSendQueueable
 *
 * Async send pipeline. One Queueable execution = one batch of recipients
 * rendered, mutated, sent, marked. Self-chains until no Pending rows remain.
 *
 * Batch size 50 — tuned for SOQL governor headroom because
 * Messaging.renderStoredEmailTemplate burns one query per call internally.
 * 50 renders ≈ 50 SOQL + our own ~5 ≈ 55, well under the 100 limit.
 *
 * Send batch sizing: a single Messaging.sendEmail call accepts up to 100
 * SingleEmailMessage instances; 50 fits in one call.
 *
 * Failure handling: every per-recipient error is caught and the recipient
 * is marked Failed/SendException — never aborts the chain. The Send only
 * transitions to Status=Failed if ZERO recipients were sent successfully.
 *
 * Status lifecycle managed here:
 *   Queued → Sending (first execution)
 *   Sending → Sent (final execution, ≥1 recipient sent successfully)
 *   Sending → Failed (final execution, zero successes)
 *   * → no-op when Status is Cancelled (user aborted)
 */
public with sharing class ULBC_EmailSendQueueable implements Queueable {

    @TestVisible
    private static final Integer BATCH_SIZE = 50;

    private final Id sendId;

    public ULBC_EmailSendQueueable(Id sendId) {
        this.sendId = sendId;
    }

    public void execute(QueueableContext qc) {
        ULBC_Email_Send__c send = loadSend();
        if (send == null) return;

        // Honour cancellation
        if (send.ULBC_Status__c == 'Cancelled') return;
        if (send.ULBC_Status__c == 'Sent' || send.ULBC_Status__c == 'Failed') return;

        // First-time transition Queued → Sending
        if (send.ULBC_Status__c == 'Queued') {
            send.ULBC_Status__c = 'Sending';
            update send;
        }

        // Settings
        ULBC_Email_Settings__c settings = ULBC_Email_Settings__c.getOrgDefaults();
        String oweId = (settings == null) ? null : settings.OrgWideEmailAddressId__c;
        String baseUrl = (settings == null) ? null : settings.TrackingBaseURL__c;
        String footer = (settings == null) ? null : settings.FooterHtml__c;
        Boolean tracking = (settings != null) && (settings.EnableTracking__c == true);
        String replyTo = (settings == null) ? null : settings.DefaultReplyTo__c;

        // Resolve template (errors fail the entire send)
        Id templateId = resolveTemplate(send.ULBC_Email_Template_DevName__c);
        if (templateId == null) {
            failSend(send, 'EmailTemplate not found: ' + send.ULBC_Email_Template_DevName__c);
            return;
        }

        // Load batch
        List<ULBC_Email_Send_Recipient__c> batch = [
            SELECT Id, ULBC_Contact__c, ULBC_Email_Address__c, ULBC_Token__c, ULBC_Status__c
            FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :sendId
              AND ULBC_Status__c = 'Pending'
            LIMIT :BATCH_SIZE
        ];

        if (batch.isEmpty()) {
            finaliseSend(send);
            return;
        }

        // Render + mutate
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<ULBC_Email_Send_Recipient__c> indexToRecipient =
            new List<ULBC_Email_Send_Recipient__c>();

        for (ULBC_Email_Send_Recipient__c rcpt : batch) {
            try {
                Messaging.SingleEmailMessage rendered =
                    Messaging.renderStoredEmailTemplate(templateId, rcpt.ULBC_Contact__c, null);

                String mutated = ULBC_EmailHtmlMutator.inject(
                    rendered.getHtmlBody(), rcpt.ULBC_Token__c, baseUrl, footer, tracking);

                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setHtmlBody(mutated);
                msg.setSubject(rendered.getSubject());
                msg.setToAddresses(new String[]{ rcpt.ULBC_Email_Address__c });
                if (String.isNotBlank(oweId)) msg.setOrgWideEmailAddressId(oweId);
                if (String.isNotBlank(replyTo)) msg.setReplyTo(replyTo);
                msg.setSaveAsActivity(false);
                msg.setUseSignature(false);
                msg.setTreatTargetObjectAsRecipient(false);

                messages.add(msg);
                indexToRecipient.add(rcpt);

                // Snapshot subject onto Send on first successful render
                if (String.isBlank(send.ULBC_Subject__c)) {
                    send.ULBC_Subject__c = rendered.getSubject();
                }
            } catch (Exception e) {
                rcpt.ULBC_Status__c = 'Failed';
                rcpt.ULBC_Suppression_Reason__c = 'SendException';
            }
        }

        // Send
        if (!messages.isEmpty()) {
            try {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(messages, false);
                for (Integer i = 0; i < results.size(); i++) {
                    ULBC_Email_Send_Recipient__c rcpt = indexToRecipient[i];
                    if (results[i].isSuccess()) {
                        rcpt.ULBC_Status__c = 'Sent';
                    } else {
                        rcpt.ULBC_Status__c = 'Failed';
                        rcpt.ULBC_Suppression_Reason__c = 'SendException';
                    }
                }
            } catch (Exception batchErr) {
                // Whole-batch failure — don't abort the chain.
                for (ULBC_Email_Send_Recipient__c rcpt : indexToRecipient) {
                    if (rcpt.ULBC_Status__c == 'Pending') {
                        rcpt.ULBC_Status__c = 'Failed';
                        rcpt.ULBC_Suppression_Reason__c = 'SendException';
                    }
                }
            }
        }

        update batch;
        update send;

        // Chain or finalise
        Integer remaining = [
            SELECT COUNT()
            FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :sendId
              AND ULBC_Status__c = 'Pending'
        ];
        if (remaining > 0) {
            if (!Test.isRunningTest()) {
                System.enqueueJob(new ULBC_EmailSendQueueable(sendId));
            }
        } else {
            finaliseSend(send);
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────

    private ULBC_Email_Send__c loadSend() {
        List<ULBC_Email_Send__c> rows = [
            SELECT Id, ULBC_Status__c, ULBC_Email_Template_DevName__c, ULBC_Subject__c
            FROM ULBC_Email_Send__c
            WHERE Id = :sendId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    @TestVisible
    private static Id resolveTemplate(String devName) {
        if (String.isBlank(devName)) return null;
        List<EmailTemplate> tpls = [
            SELECT Id FROM EmailTemplate WHERE DeveloperName = :devName LIMIT 1
        ];
        return tpls.isEmpty() ? null : tpls[0].Id;
    }

    private void finaliseSend(ULBC_Email_Send__c send) {
        Integer sent = [
            SELECT COUNT()
            FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :sendId
              AND ULBC_Status__c = 'Sent'
        ];
        send.ULBC_Status__c = (sent > 0) ? 'Sent' : 'Failed';
        send.ULBC_Sent_At__c = System.now();
        update send;
    }

    private void failSend(ULBC_Email_Send__c send, String reason) {
        // Mark all pending recipients failed too
        List<ULBC_Email_Send_Recipient__c> pending = [
            SELECT Id, ULBC_Status__c, ULBC_Suppression_Reason__c
            FROM ULBC_Email_Send_Recipient__c
            WHERE ULBC_Email_Send__c = :sendId
              AND ULBC_Status__c = 'Pending'
        ];
        for (ULBC_Email_Send_Recipient__c r : pending) {
            r.ULBC_Status__c = 'Failed';
            r.ULBC_Suppression_Reason__c = 'SendException';
        }
        if (!pending.isEmpty()) update pending;
        send.ULBC_Status__c = 'Failed';
        send.ULBC_Sent_At__c = System.now();
        update send;
        System.debug(LoggingLevel.ERROR, 'ULBC_EmailSendQueueable failed send '
            + sendId + ': ' + reason);
    }
}
