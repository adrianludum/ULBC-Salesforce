import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import listTemplates from '@salesforce/apex/ULBC_EmailSendController.listTemplates';
import previewRecipients from '@salesforce/apex/ULBC_EmailSendController.previewRecipients';
import previewRender from '@salesforce/apex/ULBC_EmailSendController.previewRender';
import enqueueSend from '@salesforce/apex/ULBC_EmailSendController.enqueueSend';

const TEMPLATE_FOLDER = 'ULBC_Bulk';

export default class UlbcEmailSendComposer extends NavigationMixin(LightningElement) {
    @api recordId; // Campaign Id

    @track templateOptions = [];
    @track selectedTemplate;
    @track subjectOverride = '';
    @track requireTrustId = false;
    @track statusesText = '';
    @track counts;
    @track preview;
    @track loading = false;

    @wire(listTemplates, { folderDevName: TEMPLATE_FOLDER })
    wiredTemplates({ data, error }) {
        if (data) {
            this.templateOptions = data.map(t => ({
                label: `${t.name} — ${t.subject || '(no subject)'}`,
                value: t.developerName
            }));
        } else if (error) {
            this.toast('Could not load templates', this.formatError(error), 'error');
        }
    }

    connectedCallback() {
        this.refreshCounts();
    }

    // ── Filter / counts ────────────────────────────────────────────────

    buildFilter() {
        const statuses = this.statusesText
            .split(',')
            .map(s => s.trim())
            .filter(s => s.length > 0);
        return {
            campaignMemberStatuses: statuses.length ? statuses : null,
            requireTrustId: this.requireTrustId
        };
    }

    refreshCounts = () => {
        if (!this.recordId) return;
        this.loading = true;
        previewRecipients({
            campaignId: this.recordId,
            filterJson: JSON.stringify(this.buildFilter())
        })
            .then(result => { this.counts = result; })
            .catch(err => { this.toast('Could not preview recipients', this.formatError(err), 'error'); })
            .finally(() => { this.loading = false; });
    };

    // ── Preview render ─────────────────────────────────────────────────

    handlePreview = () => {
        if (!this.selectedTemplate) return;
        this.loading = true;
        previewRender({
            campaignId: this.recordId,
            templateDevName: this.selectedTemplate,
            contactId: null
        })
            .then(result => { this.preview = result; })
            .catch(err => { this.toast('Preview failed', this.formatError(err), 'error'); })
            .finally(() => { this.loading = false; });
    };

    // ── Send ──────────────────────────────────────────────────────────

    handleSend = () => {
        if (!this.canSend) return;
        // eslint-disable-next-line no-alert
        if (!confirm(`Queue email to ${this.counts.eligible} recipients? This cannot be undone after sending starts.`)) {
            return;
        }
        this.loading = true;
        enqueueSend({
            campaignId: this.recordId,
            templateDevName: this.selectedTemplate,
            subject: this.subjectOverride || null,
            filterJson: JSON.stringify(this.buildFilter())
        })
            .then(sendId => {
                this.toast('Email queued', 'Send record created and queued.', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: sendId, objectApiName: 'ULBC_Email_Send__c', actionName: 'view' }
                });
            })
            .catch(err => { this.toast('Send failed', this.formatError(err), 'error'); })
            .finally(() => { this.loading = false; });
    };

    // ── Event handlers ─────────────────────────────────────────────────

    handleTemplateChange = (e) => { this.selectedTemplate = e.detail.value; };
    handleSubjectChange = (e) => { this.subjectOverride = e.detail.value; };
    handleRequireTrustIdChange = (e) => { this.requireTrustId = e.target.checked; this.refreshCounts(); };
    handleStatusesChange = (e) => { this.statusesText = e.detail.value; };

    // ── Getters ───────────────────────────────────────────────────────

    get hasCounts() { return this.counts != null; }

    get hasSuppressionBreakdown() {
        return this.counts && this.counts.suppressionByReason
            && Object.keys(this.counts.suppressionByReason).length > 0;
    }

    get suppressionSummary() {
        if (!this.hasSuppressionBreakdown) return '';
        return Object.entries(this.counts.suppressionByReason)
            .map(([reason, count]) => `${count} ${reason}`)
            .join(', ');
    }

    get canSend() {
        return this.selectedTemplate
            && this.counts
            && this.counts.eligible > 0
            && !this.loading;
    }

    get sendDisabled() { return !this.canSend; }

    // ── Helpers ────────────────────────────────────────────────────────

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatError(err) {
        if (!err) return 'Unknown error';
        if (typeof err === 'string') return err;
        if (err.body && err.body.message) return err.body.message;
        return err.message || JSON.stringify(err);
    }
}
