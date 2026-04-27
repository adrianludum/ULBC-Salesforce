public with sharing class ULBC_EventAttendeesController {

    public class Attendee {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String guests;
    }

    @AuraEnabled(cacheable=true)
    public static List<Attendee> getAttendees(Id eventId) {
        if (eventId == null) {
            return new List<Attendee>();
        }

        List<Attendee> attendees = new List<Attendee>();

        for (SObject rec : Database.query(
            'SELECT Id, TrustID__c, TrustID__r.FirstName, TrustID__r.LastName, ' +
            'No_of_guests__c, Guest_Name__c ' +
            'FROM Event_Attendance__c ' +
            'WHERE Event_ID__c = :eventId ' +
            'ORDER BY TrustID__r.LastName ASC NULLS LAST'
        )) {
            Attendee a = new Attendee();
            a.recordId = (Id) rec.get('Id');
            a.contactId = (Id) rec.get('TrustID__c');

            SObject contact = rec.getSObject('TrustID__r');
            if (contact != null) {
                a.firstName = (String) contact.get('FirstName');
                a.lastName = (String) contact.get('LastName');
            }

            a.guests = (String) rec.get('No_of_guests__c');
            attendees.add(a);
        }

        return attendees;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getAttendeeCount(Id eventId) {
        if (eventId == null) {
            return 0;
        }
        return Database.countQuery(
            'SELECT COUNT() FROM Event_Attendance__c WHERE Event_ID__c = :eventId'
        );
    }
}
