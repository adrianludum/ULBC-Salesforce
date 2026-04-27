@IsTest
private class ULBC_EventAttendeesController_Test {

    @IsTest
    static void test_getAttendees_returnsEmptyForNull() {
        List<ULBC_EventAttendeesController.Attendee> result =
            ULBC_EventAttendeesController.getAttendees(null);
        System.assertEquals(0, result.size(), 'Null ID should return empty list');
    }

    @IsTest
    static void test_getAttendeeCount_returnsZeroForNull() {
        Integer result = ULBC_EventAttendeesController.getAttendeeCount(null);
        System.assertEquals(0, result, 'Null ID should return 0');
    }
}
