import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCrewCode from '@salesforce/apex/ULBC_CrewMembersController.getCrewCode';
import getCrewMembers from '@salesforce/apex/ULBC_CrewMembersController.getCrewMembers';

export default class UlbcCrewMembers extends NavigationMixin(LightningElement) {
    @api recordId;
    crewCode;
    members = [];
    error;

    @wire(getCrewCode, { recordId: '$recordId' })
    wiredCode({ data, error }) {
        if (data) {
            this.crewCode = data;
        } else if (error) {
            this.error = error;
        }
    }

    @wire(getCrewMembers, { crewCode: '$crewCode' })
    wiredMembers({ data, error }) {
        if (data) {
            this.members = data.map((m) => ({
                id: m.recordId,
                contactId: m.contactId,
                firstName: m.firstName || '',
                lastName: m.lastName || '',
                position: m.position,
                college: m.college || '',
                yearGroup: m.yearGroup || '',
                isSelf: m.recordId === this.recordId
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.members = [];
        }
    }

    get hasMembers() {
        return this.members.length > 0;
    }

    get memberCount() {
        return this.members.length;
    }

    get cardTitle() {
        return `Crew Members (${this.memberCount})`;
    }

    navigateToContact(event) {
        event.preventDefault();
        const contactId = event.currentTarget.dataset.id;
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
