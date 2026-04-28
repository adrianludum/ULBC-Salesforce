import { LightningElement, api } from 'lwc';

export default class UlbcGiftAidDeclaration extends LightningElement {
    @api giftAid = false;
    @api postcode = '';

    handleToggle(event) {
        this.giftAid = event.target.checked;
        this.dispatchChange();
    }

    handlePostcode(event) {
        this.postcode = event.target.value;
        this.dispatchChange();
    }

    dispatchChange() {
        this.dispatchEvent(new CustomEvent('change', {
            detail: { giftAid: this.giftAid, postcode: this.postcode }
        }));
    }

    @api
    isValid() {
        if (!this.giftAid) return true;
        return !!(this.postcode && this.postcode.trim().length > 0);
    }
}
