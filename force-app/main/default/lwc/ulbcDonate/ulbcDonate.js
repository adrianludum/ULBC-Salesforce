import { LightningElement, api, track } from 'lwc';
import createDonationSession from '@salesforce/apex/ULBC_StripeCheckoutController.createDonationSession';

const PRESET_AMOUNTS = [10, 25, 50, 100, 250];

export default class UlbcDonate extends LightningElement {
    @api trustId;
    @api fund;
    @api status;

    @track amount = 25;
    @track customAmount = '';
    @track useCustom = false;
    @track giftAid = false;
    @track giftAidPostcode = '';
    @track submitting = false;
    @track errorMessage;

    connectedCallback() {
        const params = new URLSearchParams(window.location.search);
        if (!this.trustId) this.trustId = params.get('ulbc_trust_id') || null;
        if (!this.fund) this.fund = params.get('fund') || null;
        if (!this.status) this.status = params.get('status') || null;
    }

    get isSuccess() { return this.status === 'success'; }
    get isCancelled() { return this.status === 'cancelled'; }

    get presetButtons() {
        return PRESET_AMOUNTS.map(a => ({
            value: a,
            label: '£' + a,
            variant: (!this.useCustom && this.amount === a) ? 'brand' : 'neutral'
        }));
    }

    get effectiveAmount() {
        if (this.useCustom) {
            const n = parseFloat(this.customAmount);
            return isNaN(n) ? 0 : n;
        }
        return this.amount;
    }

    get totalLabel() {
        return '£' + this.effectiveAmount.toFixed(2);
    }

    get submitDisabled() {
        return this.submitting || this.effectiveAmount < 1;
    }

    handlePreset(event) {
        this.useCustom = false;
        this.amount = parseFloat(event.currentTarget.dataset.amount);
        this.errorMessage = null;
    }

    handleCustomFocus() {
        this.useCustom = true;
    }

    handleCustom(event) {
        this.useCustom = true;
        this.customAmount = event.target.value;
    }

    handleGiftAidChange(event) {
        this.giftAid = event.detail.giftAid;
        this.giftAidPostcode = event.detail.postcode;
    }

    async handleSubmit() {
        this.errorMessage = null;
        const ga = this.template.querySelector('c-ulbc-gift-aid-declaration');
        if (ga && !ga.isValid()) {
            this.errorMessage = 'Please enter your postcode for Gift Aid.';
            return;
        }
        if (this.effectiveAmount < 1) {
            this.errorMessage = 'Minimum donation is £1.';
            return;
        }
        this.submitting = true;
        try {
            const url = await createDonationSession({
                amount: this.effectiveAmount,
                fund: this.fund || null,
                ulbcTrustId: this.trustId || null,
                giftAid: this.giftAid,
                giftAidPostcode: this.giftAid ? this.giftAidPostcode : null,
                giftType: 'One-Off'
            });
            window.location.assign(url);
        } catch (err) {
            this.submitting = false;
            this.errorMessage = (err && err.body && err.body.message)
                || 'Could not start payment. Please try again.';
        }
    }
}
