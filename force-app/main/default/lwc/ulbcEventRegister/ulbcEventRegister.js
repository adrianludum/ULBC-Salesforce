import { LightningElement, api, wire, track } from 'lwc';
import getEventInfo from '@salesforce/apex/ULBC_StripeCheckoutController.getEventInfo';
import createEventSession from '@salesforce/apex/ULBC_StripeCheckoutController.createEventSession';

export default class UlbcEventRegister extends LightningElement {
    @api campaignId;
    @api trustId;
    @api status;

    @track qty = 1;
    @track submitting = false;
    @track errorMessage;
    @track event;
    @track loadError;

    connectedCallback() {
        const params = new URLSearchParams(window.location.search);
        if (!this.campaignId) this.campaignId = params.get('id') || null;
        if (!this.trustId) this.trustId = params.get('ulbc_trust_id') || null;
        if (!this.status) this.status = params.get('status') || null;
    }

    @wire(getEventInfo, { campaignId: '$campaignId' })
    wiredEvent({ data, error }) {
        if (data) {
            this.event = data;
            this.loadError = null;
        } else if (error) {
            this.loadError = (error.body && error.body.message) || 'Could not load event.';
            this.event = null;
        }
    }

    get loading() {
        return this.campaignId && !this.event && !this.loadError;
    }

    get isSuccess() { return this.status === 'success'; }
    get isCancelled() { return this.status === 'cancelled'; }

    get total() {
        if (!this.event || !this.event.ticketPrice) return '0.00';
        return (this.event.ticketPrice * this.qty).toFixed(2);
    }

    get submitDisabled() {
        return this.submitting
            || !this.event
            || !this.event.ticketPrice
            || !this.qty
            || this.qty < 1;
    }

    handleQtyChange(event) {
        const n = parseInt(event.target.value, 10);
        this.qty = isNaN(n) ? 1 : n;
    }

    async handleSubmit() {
        this.errorMessage = null;
        if (!this.qty || this.qty < 1) {
            this.errorMessage = 'Please enter a quantity of at least 1.';
            return;
        }
        this.submitting = true;
        try {
            const url = await createEventSession({
                campaignId: this.campaignId,
                qty: this.qty,
                ulbcTrustId: this.trustId || null
            });
            window.location.assign(url);
        } catch (err) {
            this.submitting = false;
            this.errorMessage = (err && err.body && err.body.message)
                || 'Could not start payment. Please try again.';
        }
    }
}
