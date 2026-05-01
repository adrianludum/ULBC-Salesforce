/**
 * ULBC_EmailSendController
 *
 * Aura-enabled facade used by the ulbcEmailSendComposer LWC. Three jobs:
 *   1. List EmailTemplates the user can pick from
 *   2. Preview the eligible/suppressed counts before committing to a send
 *   3. Render the email for one Contact so the user can sanity-check
 *      merge-field resolution before pressing Send
 *   4. Enqueue the actual send
 *
 * Runs `with sharing` — visibility on Campaigns, Contacts, and templates
 * matches what the user can see in the standard UI.
 */
public with sharing class ULBC_EmailSendController {

    /** Lightweight DTO for the template picker. */
    public class TemplateOption {
        @AuraEnabled public String developerName;
        @AuraEnabled public String name;
        @AuraEnabled public String subject;
        public TemplateOption(EmailTemplate t) {
            this.developerName = t.DeveloperName;
            this.name = t.Name;
            this.subject = t.Subject;
        }
    }

    /** Counts returned by previewRecipients for the LWC summary. */
    public class PreviewCounts {
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer eligible;
        @AuraEnabled public Integer suppressed;
        @AuraEnabled public Map<String, Integer> suppressionByReason;
        @AuraEnabled public String firstEligibleContactId;
    }

    /** Rendered HTML for a single recipient, used in the preview pane. */
    public class PreviewRender {
        @AuraEnabled public String subject;
        @AuraEnabled public String htmlBody;
        @AuraEnabled public String contactName;
    }

    /**
     * List EmailTemplates from a folder named after the supplied
     * developerName. If folderDevName is null, returns templates from
     * any folder the user has access to (filtered to active ones).
     */
    @AuraEnabled(cacheable=true)
    public static List<TemplateOption> listTemplates(String folderDevName) {
        String soql =
            'SELECT Id, DeveloperName, Name, Subject, Folder.DeveloperName ' +
            'FROM EmailTemplate ' +
            'WHERE IsActive = true AND TemplateType IN (\'html\', \'custom\')';
        if (String.isNotBlank(folderDevName)) {
            soql += ' AND Folder.DeveloperName = :folderDevName';
        }
        soql += ' ORDER BY Name ASC LIMIT 200';

        List<TemplateOption> out = new List<TemplateOption>();
        for (EmailTemplate t : (List<EmailTemplate>) Database.query(soql)) {
            out.add(new TemplateOption(t));
        }
        return out;
    }

    /**
     * Resolve recipients and return summary counts, without creating any
     * records. Used by the LWC to show a "X eligible, Y suppressed" line
     * before the user commits to sending.
     */
    @AuraEnabled
    public static PreviewCounts previewRecipients(Id campaignId, String filterJson) {
        ULBC_EmailSendService.FilterSpec spec = parseFilter(filterJson);
        ULBC_EmailRecipientResolver.RecipientFilter rf = spec.toResolverFilter();
        List<ULBC_EmailRecipientResolver.Resolved> resolved =
            ULBC_EmailRecipientResolver.resolve(campaignId, rf);

        PreviewCounts out = new PreviewCounts();
        out.total = resolved.size();
        out.eligible = 0;
        out.suppressed = 0;
        out.suppressionByReason = new Map<String, Integer>();

        for (ULBC_EmailRecipientResolver.Resolved r : resolved) {
            if (r.isEligible()) {
                out.eligible++;
                if (out.firstEligibleContactId == null && r.contact != null) {
                    out.firstEligibleContactId = r.contact.Id;
                }
            } else {
                out.suppressed++;
                Integer existing = out.suppressionByReason.containsKey(r.suppressionReason)
                    ? out.suppressionByReason.get(r.suppressionReason) : 0;
                out.suppressionByReason.put(r.suppressionReason, existing + 1);
            }
        }
        return out;
    }

    /**
     * Render the template against one Contact. Used by the LWC preview
     * pane. If contactId is null, picks the first eligible Contact from
     * the Campaign.
     */
    @AuraEnabled
    public static PreviewRender previewRender(Id campaignId, String templateDevName, Id contactId) {
        if (String.isBlank(templateDevName)) {
            throw new AuraHandledException('Template required for preview');
        }
        Id targetContactId = contactId;
        if (targetContactId == null) {
            PreviewCounts pc = previewRecipients(campaignId, null);
            targetContactId = pc.firstEligibleContactId;
        }
        if (targetContactId == null) {
            throw new AuraHandledException('No eligible Contact in Campaign for preview');
        }

        List<EmailTemplate> tpls = [
            SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateDevName LIMIT 1
        ];
        if (tpls.isEmpty()) {
            throw new AuraHandledException('Template not found: ' + templateDevName);
        }

        ULBC_Email_Settings__c settings = ULBC_Email_Settings__c.getOrgDefaults();
        String baseUrl = (settings == null) ? '' : settings.TrackingBaseURL__c;
        String footer = (settings == null) ? null : settings.FooterHtml__c;
        Boolean tracking = (settings != null) && (settings.EnableTracking__c == true);

        Messaging.SingleEmailMessage rendered =
            Messaging.renderStoredEmailTemplate(tpls[0].Id, targetContactId, null);
        String mutated = ULBC_EmailHtmlMutator.inject(
            rendered.getHtmlBody(), 'PREVIEW_TOKEN', baseUrl, footer, tracking);

        Contact c = [SELECT Name FROM Contact WHERE Id = :targetContactId LIMIT 1];

        PreviewRender out = new PreviewRender();
        out.subject = rendered.getSubject();
        out.htmlBody = mutated;
        out.contactName = c.Name;
        return out;
    }

    /**
     * Materialise a send and queue it. Returns the new Send Id.
     * Wraps ULBC_EmailSendService.enqueue and surfaces HandledException
     * back to the LWC as AuraHandledException.
     */
    @AuraEnabled
    public static Id enqueueSend(Id campaignId, String templateDevName,
                                   String subject, String filterJson) {
        try {
            ULBC_EmailSendService.FilterSpec spec = parseFilter(filterJson);
            ULBC_EmailSendService.EnqueueResult result =
                ULBC_EmailSendService.enqueue(campaignId, templateDevName, subject, spec, null);
            return result.sendId;
        } catch (ULBC_EmailSendService.HandledException he) {
            throw new AuraHandledException(he.getMessage());
        }
    }

    private static ULBC_EmailSendService.FilterSpec parseFilter(String filterJson) {
        if (String.isBlank(filterJson)) return new ULBC_EmailSendService.FilterSpec();
        try {
            return (ULBC_EmailSendService.FilterSpec)
                JSON.deserialize(filterJson, ULBC_EmailSendService.FilterSpec.class);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid filter spec: ' + e.getMessage());
        }
    }
}
