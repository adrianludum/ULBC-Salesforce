import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAttendees from '@salesforce/apex/ULBC_EventAttendeesController.getAttendees';

export default class UlbcEventAttendees extends NavigationMixin(LightningElement) {
    @api recordId;
    attendees = [];
    error;

    @wire(getAttendees, { eventId: '$recordId' })
    wiredAttendees({ data, error }) {
        if (data) {
            this.attendees = data.map((a) => ({
                id: a.recordId,
                contactId: a.contactId,
                firstName: a.firstName || '',
                lastName: a.lastName || '',
                guests: a.guests || ''
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.attendees = [];
        }
    }

    get hasAttendees() {
        return this.attendees.length > 0;
    }

    get attendeeCount() {
        return this.attendees.length;
    }

    get cardTitle() {
        return `Attendees (${this.attendeeCount})`;
    }

    navigateToContact(event) {
        event.preventDefault();
        const contactId = event.currentTarget.dataset.id;
        if (contactId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: contactId,
                    objectApiName: 'Contact',
                    actionName: 'view'
                }
            });
        }
    }
}
