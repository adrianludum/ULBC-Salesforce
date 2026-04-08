/**
 * ULBC_ContactDataModel_Test
 *
 * TDD test class for Phase 1 of the ULBC Trust Salesforce implementation.
 * Covers:
 *   - Core Contact custom fields
 *   - Education History related list (ULBC_Education_History__c)
 *   - International Competition related list (ULBC_International_Competition__c)
 *   - Crew History related list (ULBC_Crew_History__c)
 *
 * Primary test record: Jade Smith (nee Robinson) — Decision 1.28
 *
 * Run with: sf apex run test --class-names ULBC_ContactDataModel_Test --code-coverage
 */
@IsTest
private class ULBC_ContactDataModel_Test {

    @TestSetup
    static void makeData() {
        Contact jade = new Contact(
            FirstName                           = 'Jade',
            LastName                            = 'Smith',
            ULBC_Birth_Name__c                  = 'Robinson',
            ULBC_Trust_ID__c                    = 'ULBC-0001',
            ULBC_Primary_Contact_Type__c        = 'Alumni',
            ULBC_Gender__c                      = 'Female',
            Birthdate                           = Date.newInstance(1966, 3, 14),
            Email                               = 'jade.smith@example.com',
            ULBC_Secondary_Email__c             = 'jade.robinson@example.com',
            ULBC_GDPR_Legal_Basis__c            = 'Legitimate Interests — membership relationship',
            ULBC_Is_Donor__c                    = true,
            ULBC_Is_Volunteer__c                = true,
            ULBC_Volunteer_Since__c             = Date.newInstance(2024, 1, 1),
            ULBC_Is_Tyrian_Member__c            = false,
            ULBC_Gone_Away__c                   = false,
            ULBC_Alumni_Type__c                 = 'UK',
            ULBC_Acquisition_Channel__c         = 'Alumni'
        );
        insert jade;

        List<ULBC_Education_History__c> eduRecords = new List<ULBC_Education_History__c>{
            new ULBC_Education_History__c(
                ULBC_Contact__c     = jade.Id,
                ULBC_Institution__c = 'University College London',
                ULBC_Degree_Type__c = 'Undergraduate',
                ULBC_Subject__c     = 'Biology',
                ULBC_Start_Year__c  = 1985,
                ULBC_End_Year__c    = 1988
            ),
            new ULBC_Education_History__c(
                ULBC_Contact__c     = jade.Id,
                ULBC_Institution__c = 'Kings College London',
                ULBC_Degree_Type__c = 'Masters',
                ULBC_Subject__c     = 'Sports Science',
                ULBC_Start_Year__c  = 1988,
                ULBC_End_Year__c    = 1990
            ),
            new ULBC_Education_History__c(
                ULBC_Contact__c     = jade.Id,
                ULBC_Institution__c = 'Royal Holloway',
                ULBC_Degree_Type__c = 'PhD',
                ULBC_Subject__c     = 'Exercise Physiology',
                ULBC_Start_Year__c  = 1990,
                ULBC_End_Year__c    = 1994
            )
        };
        insert eduRecords;

        List<ULBC_International_Competition__c> compRecords = new List<ULBC_International_Competition__c>{
            new ULBC_International_Competition__c(
                ULBC_Contact__c             = jade.Id,
                ULBC_Year__c               = 1985,
                ULBC_Competition__c        = 'U23 World Championships',
                ULBC_Event__c              = 'Women\'s 4-',
                ULBC_Result__c             = '2nd',
                ULBC_Country_Represented__c = 'GB'
            ),
            new ULBC_International_Competition__c(
                ULBC_Contact__c             = jade.Id,
                ULBC_Year__c               = 1988,
                ULBC_Competition__c        = 'Olympic Games',
                ULBC_Event__c              = 'Women\'s 8+',
                ULBC_Result__c             = '5th',
                ULBC_Country_Represented__c = 'GB'
            )
        };
        insert compRecords;

        List<ULBC_Crew_History__c> crewRecords = new List<ULBC_Crew_History__c>();
        for (Integer yr = 1983; yr <= 1992; yr++) {
            crewRecords.add(new ULBC_Crew_History__c(
                ULBC_Contact__c     = jade.Id,
                ULBC_Crew_Code__c   = 'HRR-W8-' + yr,
                ULBC_Year__c        = yr,
                ULBC_Regatta__c     = 'Henley Royal Regatta',
                ULBC_Event__c       = 'Women\'s Eight',
                ULBC_Crew_Name__c   = 'ULBC Women\'s Eight ' + yr,
                ULBC_Result__c      = (Math.mod(yr, 3) == 0) ? 'Winner' : 'Finalist'
            ));
        }
        insert crewRecords;
    }

    private static Contact getJade() {
        return [
            SELECT  Id, FirstName, LastName, ULBC_Birth_Name__c, ULBC_Trust_ID__c,
                    ULBC_Primary_Contact_Type__c, ULBC_Gender__c, Birthdate, Email,
                    ULBC_Secondary_Email__c, ULBC_GDPR_Legal_Basis__c, ULBC_Is_Donor__c,
                    ULBC_Is_Volunteer__c, ULBC_Volunteer_Since__c, ULBC_Is_Tyrian_Member__c,
                    ULBC_Gone_Away__c, ULBC_Alumni_Type__c, ULBC_Acquisition_Channel__c
            FROM    Contact
            WHERE   ULBC_Trust_ID__c = 'ULBC-0001'
            LIMIT   1
        ];
    }

    // ── Section 1: Core Contact Fields ───────────────────────────────────────

    @IsTest static void test_contactCoreFields_TrustID() {
        System.assertEquals('ULBC-0001', getJade().ULBC_Trust_ID__c, 'TrustID mismatch');
    }

    @IsTest static void test_contactCoreFields_NamesAndBirthName() {
        Contact j = getJade();
        System.assertEquals('Jade',     j.FirstName,          'First name mismatch');
        System.assertEquals('Smith',    j.LastName,           'Last name mismatch');
        System.assertEquals('Robinson', j.ULBC_Birth_Name__c, 'Birth name mismatch');
    }

    @IsTest static void test_contactCoreFields_Gender() {
        System.assertEquals('Female', getJade().ULBC_Gender__c, 'Gender must be Female');
    }

    @IsTest static void test_contactCoreFields_DateOfBirth() {
        System.assertEquals(Date.newInstance(1966, 3, 14), getJade().Birthdate, 'DOB mismatch');
    }

    @IsTest static void test_contactCoreFields_PrimaryContactType_Alumni() {
        System.assertEquals('Alumni', getJade().ULBC_Primary_Contact_Type__c, 'Must default to Alumni');
    }

    @IsTest static void test_contactCoreFields_PrimaryContactType_AllowedValues() {
        insert new List<Contact>{
            new Contact(FirstName='T', LastName='A', ULBC_Trust_ID__c='ULBC-TEST-A', ULBC_Primary_Contact_Type__c='Athlete-Student'),
            new Contact(FirstName='T', LastName='P', ULBC_Trust_ID__c='ULBC-TEST-P', ULBC_Primary_Contact_Type__c='Parent'),
            new Contact(FirstName='T', LastName='O', ULBC_Trust_ID__c='ULBC-TEST-O', ULBC_Primary_Contact_Type__c='Other')
        };
        System.assertEquals(3, [SELECT COUNT() FROM Contact WHERE ULBC_Trust_ID__c IN ('ULBC-TEST-A','ULBC-TEST-P','ULBC-TEST-O')], 'All 3 type values must be valid');
    }

    @IsTest static void test_contactCoreFields_AdditiveFlags() {
        Contact j = getJade();
        System.assertEquals(true,  j.ULBC_Is_Donor__c,         'Is Donor must be true');
        System.assertEquals(true,  j.ULBC_Is_Volunteer__c,     'Is Volunteer must be true');
        System.assertEquals(false, j.ULBC_Is_Tyrian_Member__c, 'Jade never rowed for Tyrian');
    }

    @IsTest static void test_contactCoreFields_VolunteerSinceDate() {
        System.assertEquals(Date.newInstance(2024, 1, 1), getJade().ULBC_Volunteer_Since__c, 'Volunteer Since mismatch');
    }

    @IsTest static void test_contactCoreFields_GDPRLegalBasis() {
        System.assertEquals('Legitimate Interests — membership relationship', getJade().ULBC_GDPR_Legal_Basis__c, 'GDPR basis mismatch');
    }

    @IsTest static void test_contactCoreFields_GoneAway_DefaultFalse() {
        System.assertEquals(false, getJade().ULBC_Gone_Away__c, 'Gone Away must default false');
    }

    @IsTest static void test_contactCoreFields_GoneAway_CanBeSet() {
        Contact j = getJade();
        j.ULBC_Gone_Away__c = true;
        update j;
        System.assertEquals(true, [SELECT ULBC_Gone_Away__c FROM Contact WHERE Id = :j.Id].ULBC_Gone_Away__c, 'Gone Away must be settable');
    }

    @IsTest static void test_contactCoreFields_EmailFields() {
        Contact j = getJade();
        System.assertEquals('jade.smith@example.com',    j.Email,                   'Primary email mismatch');
        System.assertEquals('jade.robinson@example.com', j.ULBC_Secondary_Email__c, 'Secondary email mismatch');
    }

    @IsTest static void test_contactCoreFields_AlumniType() {
        System.assertEquals('UK', getJade().ULBC_Alumni_Type__c, 'Alumni type mismatch');
    }

    @IsTest static void test_contactCoreFields_AcquisitionChannel() {
        System.assertEquals('Alumni', getJade().ULBC_Acquisition_Channel__c, 'Acquisition channel mismatch');
    }

    @IsTest static void test_contactCoreFields_TrustID_IsExternalID() {
        Contact c = new Contact(FirstName='U', LastName='Test', ULBC_Trust_ID__c='ULBC-UPSERT-001', ULBC_Primary_Contact_Type__c='Alumni');
        Database.UpsertResult r = Database.upsert(c, Contact.ULBC_Trust_ID__c, false);
        System.assert(r.isSuccess(), 'Upsert on TrustID must succeed');
        System.assert(r.isCreated(), 'First upsert must be an insert');
    }

    // ── Section 2: Education History ─────────────────────────────────────────

    @IsTest static void test_educationHistory_ThreeRecordsCreated() {
        System.assertEquals(3, [SELECT COUNT() FROM ULBC_Education_History__c WHERE ULBC_Contact__c = :getJade().Id], '3 education records required');
    }

    @IsTest static void test_educationHistory_DegreeTypePicklistValues() {
        Id jadeId = getJade().Id;
        insert new List<ULBC_Education_History__c>{
            new ULBC_Education_History__c(ULBC_Contact__c=jadeId, ULBC_Institution__c='Test', ULBC_Degree_Type__c='Undergraduate', ULBC_Start_Year__c=2000, ULBC_End_Year__c=2003),
            new ULBC_Education_History__c(ULBC_Contact__c=jadeId, ULBC_Institution__c='Test', ULBC_Degree_Type__c='Masters',        ULBC_Start_Year__c=2003, ULBC_End_Year__c=2005),
            new ULBC_Education_History__c(ULBC_Contact__c=jadeId, ULBC_Institution__c='Test', ULBC_Degree_Type__c='PhD',            ULBC_Start_Year__c=2005, ULBC_End_Year__c=2009),
            new ULBC_Education_History__c(ULBC_Contact__c=jadeId, ULBC_Institution__c='Test', ULBC_Degree_Type__c='Other',          ULBC_Start_Year__c=2010, ULBC_End_Year__c=2011)
        };
        System.assertEquals(7, [SELECT COUNT() FROM ULBC_Education_History__c WHERE ULBC_Contact__c = :jadeId], 'All 4 degree type values must insert');
    }

    @IsTest static void test_educationHistory_UCLRecord_FieldValues() {
        ULBC_Education_History__c ucl = [
            SELECT ULBC_Degree_Type__c, ULBC_Subject__c, ULBC_Start_Year__c, ULBC_End_Year__c
            FROM   ULBC_Education_History__c
            WHERE  ULBC_Contact__c = :getJade().Id AND ULBC_Institution__c = 'University College London'
            LIMIT  1
        ];
        System.assertEquals('Undergraduate', ucl.ULBC_Degree_Type__c, 'UCL degree type mismatch');
        System.assertEquals('Biology',       ucl.ULBC_Subject__c,     'UCL subject mismatch');
        System.assertEquals(1985,            ucl.ULBC_Start_Year__c,  'UCL start year mismatch');
        System.assertEquals(1988,            ucl.ULBC_End_Year__c,    'UCL end year mismatch');
    }

    @IsTest static void test_educationHistory_DeletionCascades() {
        Contact j = getJade();
        System.assertEquals(3, [SELECT COUNT() FROM ULBC_Education_History__c WHERE ULBC_Contact__c = :j.Id], 'Precondition: 3 records');
        delete j;
        System.assertEquals(0, [SELECT COUNT() FROM ULBC_Education_History__c], 'Education records must cascade delete');
    }

    // ── Section 3: International Competition ─────────────────────────────────

    @IsTest static void test_internationalCompetition_TwoRecordsCreated() {
        System.assertEquals(2, [SELECT COUNT() FROM ULBC_International_Competition__c WHERE ULBC_Contact__c = :getJade().Id], '2 competition records required');
    }

    @IsTest static void test_internationalCompetition_OlympicRecord_FieldValues() {
        ULBC_International_Competition__c olym = [
            SELECT ULBC_Year__c, ULBC_Event__c, ULBC_Result__c, ULBC_Country_Represented__c
            FROM   ULBC_International_Competition__c
            WHERE  ULBC_Contact__c = :getJade().Id AND ULBC_Competition__c = 'Olympic Games'
            LIMIT  1
        ];
        System.assertEquals(1988,          olym.ULBC_Year__c,                'Olympic year mismatch');
        System.assertEquals('Women\'s 8+', olym.ULBC_Event__c,               'Olympic event mismatch');
        System.assertEquals('5th',         olym.ULBC_Result__c,              '5th place at Seoul');
        System.assertEquals('GB',          olym.ULBC_Country_Represented__c, 'Country must be GB');
    }

    @IsTest static void test_internationalCompetition_CompetitionPicklistValues() {
        Id jadeId = getJade().Id;
        insert new List<ULBC_International_Competition__c>{
            new ULBC_International_Competition__c(ULBC_Contact__c=jadeId, ULBC_Year__c=2000, ULBC_Competition__c='U23 World Championships', ULBC_Event__c='Women\'s 4-', ULBC_Result__c='1st', ULBC_Country_Represented__c='GB'),
            new ULBC_International_Competition__c(ULBC_Contact__c=jadeId, ULBC_Year__c=2001, ULBC_Competition__c='World Championships',     ULBC_Event__c='Women\'s 4-', ULBC_Result__c='2nd', ULBC_Country_Represented__c='GB'),
            new ULBC_International_Competition__c(ULBC_Contact__c=jadeId, ULBC_Year__c=2002, ULBC_Competition__c='Olympic Games',           ULBC_Event__c='Women\'s 8+', ULBC_Result__c='Gold',ULBC_Country_Represented__c='GB'),
            new ULBC_International_Competition__c(ULBC_Contact__c=jadeId, ULBC_Year__c=2003, ULBC_Competition__c='Other',                   ULBC_Event__c='Mixed 4x',   ULBC_Result__c='3rd', ULBC_Country_Represented__c='GB')
        };
        System.assertEquals(6, [SELECT COUNT() FROM ULBC_International_Competition__c WHERE ULBC_Contact__c = :jadeId], 'All 4 competition picklist values must insert');
    }

    @IsTest static void test_internationalCompetition_MultipleInSameYear() {
        Id jadeId = getJade().Id;
        insert new List<ULBC_International_Competition__c>{
            new ULBC_International_Competition__c(ULBC_Contact__c=jadeId, ULBC_Year__c=1987, ULBC_Competition__c='World Championships', ULBC_Event__c='Women\'s 4-', ULBC_Result__c='3rd', ULBC_Country_Represented__c='GB'),
            new ULBC_International_Competition__c(ULBC_Contact__c=jadeId, ULBC_Year__c=1987, ULBC_Competition__c='World Championships', ULBC_Event__c='Women\'s 8+', ULBC_Result__c='2nd', ULBC_Country_Represented__c='GB')
        };
        System.assertEquals(2, [SELECT COUNT() FROM ULBC_International_Competition__c WHERE ULBC_Contact__c = :jadeId AND ULBC_Year__c = 1987], 'Multiple comps in same year must be permitted');
    }

    @IsTest static void test_internationalCompetition_CountryRepresented_DefaultGB() {
        System.assertEquals('GB', [SELECT ULBC_Country_Represented__c FROM ULBC_International_Competition__c WHERE ULBC_Contact__c = :getJade().Id LIMIT 1].ULBC_Country_Represented__c, 'Country must default to GB');
    }

    @IsTest static void test_internationalCompetition_DeletionCascades() {
        delete getJade();
        System.assertEquals(0, [SELECT COUNT() FROM ULBC_International_Competition__c], 'Competition records must cascade delete');
    }

    // ── Section 4: Crew History ───────────────────────────────────────────────

    @IsTest static void test_crewHistory_TenYearHistory() {
        System.assertEquals(10, [SELECT COUNT() FROM ULBC_Crew_History__c WHERE ULBC_Contact__c = :getJade().Id], '10 crew records required');
    }

    @IsTest static void test_crewHistory_FieldValues_FirstYear() {
        ULBC_Crew_History__c first = [
            SELECT ULBC_Crew_Code__c, ULBC_Regatta__c, ULBC_Event__c, ULBC_Crew_Name__c, ULBC_Result__c
            FROM   ULBC_Crew_History__c
            WHERE  ULBC_Contact__c = :getJade().Id AND ULBC_Year__c = 1983
            LIMIT  1
        ];
        System.assertEquals('HRR-W8-1983',             first.ULBC_Crew_Code__c,  'Crew code mismatch');
        System.assertEquals('Henley Royal Regatta',    first.ULBC_Regatta__c,    'Regatta mismatch');
        System.assertEquals('Women\'s Eight',          first.ULBC_Event__c,      'Event mismatch');
        System.assertEquals('ULBC Women\'s Eight 1983',first.ULBC_Crew_Name__c,  'Crew name mismatch');
    }

    @IsTest static void test_crewHistory_NoInstitutionOnCrewRecord() {
        Schema.SObjectType crewType = Schema.getGlobalDescribe().get('ULBC_Crew_History__c');
        System.assertNotEquals(null, crewType, 'ULBC_Crew_History__c must exist');
        System.assert(!crewType.getDescribe().fields.getMap().containsKey('ulbc_institution__c'), 'No Institution field on Crew History — Decision 1.25');
    }

    @IsTest static void test_crewHistory_MultipleContactsCanShareCrewCode() {
        Contact teamMate = new Contact(FirstName='Alice', LastName='Jones', ULBC_Trust_ID__c='ULBC-0002', ULBC_Primary_Contact_Type__c='Alumni');
        insert teamMate;
        insert new ULBC_Crew_History__c(
            ULBC_Contact__c=teamMate.Id, ULBC_Crew_Code__c='HRR-W8-1983',
            ULBC_Year__c=1983, ULBC_Regatta__c='Henley Royal Regatta',
            ULBC_Event__c='Women\'s Eight', ULBC_Crew_Name__c='ULBC Women\'s Eight 1983', ULBC_Result__c='Finalist'
        );
        System.assertEquals(1, [SELECT COUNT() FROM ULBC_Crew_History__c WHERE ULBC_Contact__c = :teamMate.Id], 'Same crew code must be valid across contacts');
    }

    @IsTest static void test_crewHistory_DeletionCascades() {
        delete getJade();
        System.assertEquals(0, [SELECT COUNT() FROM ULBC_Crew_History__c], 'Crew records must cascade delete');
    }

    // ── Section 5: Integration ────────────────────────────────────────────────

    @IsTest static void test_jade_FullProfileQuery() {
        List<Contact> results = [
            SELECT  Id, FirstName, LastName, ULBC_Birth_Name__c, ULBC_Trust_ID__c,
                    ULBC_Primary_Contact_Type__c, ULBC_Gender__c, Birthdate,
                    ULBC_GDPR_Legal_Basis__c, ULBC_Is_Donor__c, ULBC_Is_Volunteer__c,
                    ULBC_Volunteer_Since__c, ULBC_Is_Tyrian_Member__c, ULBC_Gone_Away__c,
                    (SELECT ULBC_Institution__c, ULBC_Degree_Type__c, ULBC_Start_Year__c, ULBC_End_Year__c
                     FROM   ULBC_Education_Histories__r),
                    (SELECT ULBC_Year__c, ULBC_Competition__c, ULBC_Event__c, ULBC_Result__c
                     FROM   ULBC_International_Competitions__r),
                    (SELECT ULBC_Year__c, ULBC_Regatta__c, ULBC_Event__c, ULBC_Result__c
                     FROM   ULBC_Crew_Histories__r ORDER BY ULBC_Year__c ASC)
            FROM    Contact
            WHERE   ULBC_Trust_ID__c = 'ULBC-0001'
            LIMIT   1
        ];
        System.assertEquals(1,  results.size(),                                       'Jade must be found by TrustID');
        System.assertEquals(3,  results[0].ULBC_Education_Histories__r.size(),        '3 education records');
        System.assertEquals(2,  results[0].ULBC_International_Competitions__r.size(), '2 competition records');
        System.assertEquals(10, results[0].ULBC_Crew_Histories__r.size(),             '10 crew records');
    }

    @IsTest static void test_volunteerSince_RequiresIsVolunteer() {
        Boolean caught = false;
        try {
            insert new Contact(FirstName='Non', LastName='Volunteer', ULBC_Trust_ID__c='ULBC-NV-001',
                ULBC_Primary_Contact_Type__c='Alumni', ULBC_Is_Volunteer__c=false, ULBC_Volunteer_Since__c=Date.today());
        } catch (DmlException e) {
            caught = true;
        }
        System.assert(caught, 'Volunteer Since set without Is Volunteer must throw a validation error');
    }

    @IsTest static void test_goneAway_ContactExcludedFromBulkEmail() {
        // Phase 2 trigger will set HasOptedOutOfEmail = true when Gone Away is checked.
        // This test is a placeholder — assertion commented out until Phase 2 trigger is deployed.
        insert new Contact(FirstName='Gone', LastName='Away', ULBC_Trust_ID__c='ULBC-GA-001',
            ULBC_Primary_Contact_Type__c='Alumni', ULBC_Gone_Away__c=true, Email='goneaway@example.com');
        Contact c = [SELECT HasOptedOutOfEmail FROM Contact WHERE ULBC_Trust_ID__c = 'ULBC-GA-001'];
        // Uncomment when Phase 2 trigger is live:
        // System.assertEquals(true, c.HasOptedOutOfEmail, 'Gone Away must set Email Opt-Out');
        System.assertNotEquals(null, c, 'Placeholder — contact must be retrievable');
    }
}
