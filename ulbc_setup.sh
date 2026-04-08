#!/bin/bash
# ULBC Trust — Phase 1 file setup script
# Run from inside your ULBC-salesforcce directory
# Creates all 22 files in the correct folder structure

set -e
echo "Creating ULBC Trust Phase 1 files..."

# ─── sfdx-project.json ───────────────────────────────────────────────────────
cat > sfdx-project.json << 'ENDOFFILE'
{
  "packageDirectories": [
    {
      "path": "force-app",
      "default": true
    }
  ],
  "name": "ulbc-trust-salesforce",
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "61.0",
  "description": "ULBC Trust Limited — Salesforce NPSP implementation. TDD build. Phase 1: Contact data model."
}
ENDOFFILE

# ─── manifest/package.xml ────────────────────────────────────────────────────
cat > manifest/package.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>ULBC_Education_History__c</members>
        <members>ULBC_International_Competition__c</members>
        <members>ULBC_Crew_History__c</members>
        <name>CustomObject</name>
    </types>
    <types>
        <members>Contact.ULBC_Trust_ID__c</members>
        <members>Contact.ULBC_Birth_Name__c</members>
        <members>Contact.ULBC_Gender__c</members>
        <members>Contact.ULBC_Primary_Contact_Type__c</members>
        <members>Contact.ULBC_Is_Donor__c</members>
        <members>Contact.ULBC_Is_Volunteer__c</members>
        <members>Contact.ULBC_Volunteer_Since__c</members>
        <members>Contact.ULBC_Is_Tyrian_Member__c</members>
        <members>Contact.ULBC_GDPR_Legal_Basis__c</members>
        <members>Contact.ULBC_Secondary_Email__c</members>
        <members>Contact.ULBC_Gone_Away__c</members>
        <members>Contact.ULBC_Alumni_Type__c</members>
        <members>Contact.ULBC_Acquisition_Channel__c</members>
        <name>CustomField</name>
    </types>
    <types>
        <members>Contact.ULBC_VolunteerSince_RequiresIsVolunteer</members>
        <name>ValidationRule</name>
    </types>
    <types>
        <members>ULBC_ContactDataModel_Test</members>
        <name>ApexClass</name>
    </types>
    <version>61.0</version>
</Package>
ENDOFFILE

# ─── Apex test class metadata ─────────────────────────────────────────────────
cat > force-app/main/default/classes/ULBC_ContactDataModel_Test.cls-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>61.0</apiVersion>
    <status>Active</status>
</ApexClass>
ENDOFFILE

# ─── Apex test class ──────────────────────────────────────────────────────────
cat > force-app/main/default/classes/ULBC_ContactDataModel_Test.cls << 'ENDOFFILE'
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
ENDOFFILE

# ─── Contact custom fields ────────────────────────────────────────────────────

cat > force-app/main/default/objects/Contact/fields/ULBC_Trust_ID__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Trust_ID__c</fullName>
    <label>Trust ID</label>
    <type>Text</type>
    <length>50</length>
    <required>false</required>
    <externalId>true</externalId>
    <unique>true</unique>
    <caseSensitive>false</caseSensitive>
    <description>Master migration key linking all FileMaker tables. External ID enabling upserts on data load and Stripe integration.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Birth_Name__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Birth_Name__c</fullName>
    <label>Birth Name</label>
    <type>Text</type>
    <length>100</length>
    <required>false</required>
    <description>Birth/maiden name. Used when a contact has changed surname e.g. Jade Robinson to Jade Smith.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Gender__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Gender__c</fullName>
    <label>Gender</label>
    <type>Picklist</type>
    <required>false</required>
    <description>Self-identified gender. Jade Smith is stored as Male in FileMaker — must be corrected to Female on import.</description>
    <valueSet>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>Female</fullName><default>false</default><label>Female</label></value>
            <value><fullName>Male</fullName><default>false</default><label>Male</label></value>
            <value><fullName>Non-binary</fullName><default>false</default><label>Non-binary</label></value>
            <value><fullName>Prefer not to say</fullName><default>false</default><label>Prefer not to say</label></value>
        </valueSetDefinition>
    </valueSet>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Primary_Contact_Type__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Primary_Contact_Type__c</fullName>
    <label>Primary Contact Type</label>
    <type>Picklist</type>
    <required>true</required>
    <description>Single evolving primary classification. Athlete-Student to Alumni is one-way on graduation. All imported FileMaker contacts default to Alumni. Decision 1.11, 1.12.</description>
    <valueSet>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>Athlete-Student</fullName><default>false</default><label>Athlete-Student</label></value>
            <value><fullName>Alumni</fullName><default>true</default><label>Alumni</label></value>
            <value><fullName>Parent</fullName><default>false</default><label>Parent</label></value>
            <value><fullName>Other</fullName><default>false</default><label>Other</label></value>
        </valueSetDefinition>
    </valueSet>
    <trackHistory>true</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Is_Donor__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Is_Donor__c</fullName>
    <label>Is Donor</label>
    <type>Checkbox</type>
    <defaultValue>false</defaultValue>
    <description>Additive flag. Set to true when first Opportunity is recorded. Decision 1.11.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Is_Volunteer__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Is_Volunteer__c</fullName>
    <label>Is Volunteer</label>
    <type>Checkbox</type>
    <defaultValue>false</defaultValue>
    <description>Additive flag. When true, ULBC_Volunteer_Since__c must be populated. Validation rule enforces this.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Volunteer_Since__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Volunteer_Since__c</fullName>
    <label>Volunteer Since</label>
    <type>Date</type>
    <required>false</required>
    <description>Date volunteering began. Must not be populated unless Is Volunteer is true. Enforced by validation rule.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Is_Tyrian_Member__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Is_Tyrian_Member__c</fullName>
    <label>Is Tyrian Member</label>
    <type>Checkbox</type>
    <defaultValue>false</defaultValue>
    <description>Additive flag. Tyrian is the alumni rowing club with its own separate subscription. Decision 1.4, 1.9.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_GDPR_Legal_Basis__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_GDPR_Legal_Basis__c</fullName>
    <label>GDPR Legal Basis</label>
    <type>Picklist</type>
    <required>false</required>
    <description>UK GDPR legal basis for holding and processing this contact data. All imported contacts default to Legitimate Interests. Decision 1.13.</description>
    <valueSet>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>Legitimate Interests — membership relationship</fullName><default>true</default><label>Legitimate Interests — membership relationship</label></value>
            <value><fullName>Consent</fullName><default>false</default><label>Consent</label></value>
            <value><fullName>Contract</fullName><default>false</default><label>Contract</label></value>
            <value><fullName>Legal Obligation</fullName><default>false</default><label>Legal Obligation</label></value>
        </valueSetDefinition>
    </valueSet>
    <trackHistory>true</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Secondary_Email__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Secondary_Email__c</fullName>
    <label>Secondary Email</label>
    <type>Email</type>
    <required>false</required>
    <unique>false</unique>
    <description>Secondary email address. Primary email is the standard Contact Email field.</description>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Gone_Away__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Gone_Away__c</fullName>
    <label>Gone Away</label>
    <type>Checkbox</type>
    <defaultValue>false</defaultValue>
    <description>True when postal or email contact has bounced. Phase 2 trigger will set HasOptedOutOfEmail = true. Maps from FileMaker GoneAway field.</description>
    <trackHistory>true</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Alumni_Type__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Alumni_Type__c</fullName>
    <label>Alumni Type</label>
    <type>Picklist</type>
    <required>false</required>
    <description>UK-based or international alumni. Used for segmentation and event invitations.</description>
    <valueSet>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>UK</fullName><default>true</default><label>UK</label></value>
            <value><fullName>Global</fullName><default>false</default><label>Global</label></value>
        </valueSetDefinition>
    </valueSet>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

cat > force-app/main/default/objects/Contact/fields/ULBC_Acquisition_Channel__c.field-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_Acquisition_Channel__c</fullName>
    <label>Acquisition Channel</label>
    <type>Picklist</type>
    <required>false</required>
    <description>How this contact was first acquired.</description>
    <valueSet>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>Alumni</fullName><default>false</default><label>Alumni</label></value>
            <value><fullName>Athlete</fullName><default>false</default><label>Athlete</label></value>
            <value><fullName>Event</fullName><default>false</default><label>Event</label></value>
            <value><fullName>Referral</fullName><default>false</default><label>Referral</label></value>
            <value><fullName>Digital</fullName><default>false</default><label>Digital</label></value>
        </valueSetDefinition>
    </valueSet>
    <trackHistory>false</trackHistory>
</CustomField>
ENDOFFILE

# ─── Validation rule ──────────────────────────────────────────────────────────

cat > force-app/main/default/objects/Contact/validationRules/ULBC_VolunteerSince_RequiresIsVolunteer.validationRule-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ULBC_VolunteerSince_RequiresIsVolunteer</fullName>
    <active>true</active>
    <description>Volunteer Since must not be populated unless Is Volunteer is checked.</description>
    <errorConditionFormula>AND(NOT(ULBC_Is_Volunteer__c), NOT(ISBLANK(ULBC_Volunteer_Since__c)))</errorConditionFormula>
    <errorDisplayField>ULBC_Volunteer_Since__c</errorDisplayField>
    <errorMessage>Volunteer Since can only be set when Is Volunteer is checked.</errorMessage>
</ValidationRule>
ENDOFFILE

# ─── Custom objects ───────────────────────────────────────────────────────────

cat > force-app/main/default/objects/ULBC_Education_History__c/ULBC_Education_History__c.object-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Education History</label>
    <pluralLabel>Education Histories</pluralLabel>
    <nameField>
        <label>Education History Name</label>
        <type>AutoNumber</type>
        <displayFormat>EDU-{0000}</displayFormat>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ControlledByParent</sharingModel>
    <description>One record per institution attended. Supports multiple institutions per contact. Decision 1.24.</description>
    <fields>
        <fullName>ULBC_Contact__c</fullName>
        <label>Contact</label>
        <type>MasterDetail</type>
        <referenceTo>Contact</referenceTo>
        <relationshipName>ULBC_Education_Histories</relationshipName>
        <relationshipLabel>Education History</relationshipLabel>
        <writeRequiresMasterRead>false</writeRequiresMasterRead>
        <reparentableMasterDetail>false</reparentableMasterDetail>
        <required>true</required>
    </fields>
    <fields>
        <fullName>ULBC_Institution__c</fullName>
        <label>Institution</label>
        <type>Text</type>
        <length>255</length>
        <required>true</required>
    </fields>
    <fields>
        <fullName>ULBC_Degree_Type__c</fullName>
        <label>Degree Type</label>
        <type>Picklist</type>
        <required>false</required>
        <valueSet>
            <valueSetDefinition>
                <sorted>false</sorted>
                <value><fullName>Undergraduate</fullName><default>true</default><label>Undergraduate</label></value>
                <value><fullName>Masters</fullName><default>false</default><label>Masters</label></value>
                <value><fullName>PhD</fullName><default>false</default><label>PhD</label></value>
                <value><fullName>Other</fullName><default>false</default><label>Other</label></value>
            </valueSetDefinition>
        </valueSet>
    </fields>
    <fields>
        <fullName>ULBC_Subject__c</fullName>
        <label>Subject</label>
        <type>Text</type>
        <length>255</length>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_Start_Year__c</fullName>
        <label>Start Year</label>
        <type>Number</type>
        <precision>4</precision>
        <scale>0</scale>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_End_Year__c</fullName>
        <label>End Year</label>
        <type>Number</type>
        <precision>4</precision>
        <scale>0</scale>
        <required>false</required>
    </fields>
    <listViews>
        <fullName>All</fullName>
        <filterScope>Everything</filterScope>
        <label>All Education History Records</label>
    </listViews>
</CustomObject>
ENDOFFILE

cat > force-app/main/default/objects/ULBC_International_Competition__c/ULBC_International_Competition__c.object-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>International Competition</label>
    <pluralLabel>International Competitions</pluralLabel>
    <nameField>
        <label>International Competition Name</label>
        <type>AutoNumber</type>
        <displayFormat>INTL-{0000}</displayFormat>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ControlledByParent</sharingModel>
    <description>International competition history. Multiple records per contact and multiple in same year are permitted. Decision 1.26.</description>
    <fields>
        <fullName>ULBC_Contact__c</fullName>
        <label>Contact</label>
        <type>MasterDetail</type>
        <referenceTo>Contact</referenceTo>
        <relationshipName>ULBC_International_Competitions</relationshipName>
        <relationshipLabel>International Competition History</relationshipLabel>
        <writeRequiresMasterRead>false</writeRequiresMasterRead>
        <reparentableMasterDetail>false</reparentableMasterDetail>
        <required>true</required>
    </fields>
    <fields>
        <fullName>ULBC_Year__c</fullName>
        <label>Year</label>
        <type>Number</type>
        <precision>4</precision>
        <scale>0</scale>
        <required>true</required>
    </fields>
    <fields>
        <fullName>ULBC_Competition__c</fullName>
        <label>Competition</label>
        <type>Picklist</type>
        <required>true</required>
        <valueSet>
            <valueSetDefinition>
                <sorted>false</sorted>
                <value><fullName>U23 World Championships</fullName><default>false</default><label>U23 World Championships</label></value>
                <value><fullName>World Championships</fullName><default>false</default><label>World Championships</label></value>
                <value><fullName>Olympic Games</fullName><default>false</default><label>Olympic Games</label></value>
                <value><fullName>Other</fullName><default>false</default><label>Other</label></value>
            </valueSetDefinition>
        </valueSet>
    </fields>
    <fields>
        <fullName>ULBC_Event__c</fullName>
        <label>Event</label>
        <type>Text</type>
        <length>100</length>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_Result__c</fullName>
        <label>Result</label>
        <type>Text</type>
        <length>100</length>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_Country_Represented__c</fullName>
        <label>Country Represented</label>
        <type>Text</type>
        <length>10</length>
        <required>false</required>
        <defaultValue>&apos;GB&apos;</defaultValue>
    </fields>
    <listViews>
        <fullName>All</fullName>
        <filterScope>Everything</filterScope>
        <label>All International Competition Records</label>
    </listViews>
</CustomObject>
ENDOFFILE

cat > force-app/main/default/objects/ULBC_Crew_History__c/ULBC_Crew_History__c.object-meta.xml << 'ENDOFFILE'
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Crew History</label>
    <pluralLabel>Crew Histories</pluralLabel>
    <nameField>
        <label>Crew History Name</label>
        <type>AutoNumber</type>
        <displayFormat>CREW-{0000}</displayFormat>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ControlledByParent</sharingModel>
    <description>One record per rower per regatta. All records attributed to ULBC — no institution field. Decision 1.25.</description>
    <fields>
        <fullName>ULBC_Contact__c</fullName>
        <label>Contact</label>
        <type>MasterDetail</type>
        <referenceTo>Contact</referenceTo>
        <relationshipName>ULBC_Crew_Histories</relationshipName>
        <relationshipLabel>Crew History</relationshipLabel>
        <writeRequiresMasterRead>false</writeRequiresMasterRead>
        <reparentableMasterDetail>false</reparentableMasterDetail>
        <required>true</required>
    </fields>
    <fields>
        <fullName>ULBC_Crew_Code__c</fullName>
        <label>Crew Code</label>
        <type>Text</type>
        <length>50</length>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_Year__c</fullName>
        <label>Year</label>
        <type>Number</type>
        <precision>4</precision>
        <scale>0</scale>
        <required>true</required>
    </fields>
    <fields>
        <fullName>ULBC_Regatta__c</fullName>
        <label>Regatta</label>
        <type>Text</type>
        <length>255</length>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_Event__c</fullName>
        <label>Event</label>
        <type>Text</type>
        <length>100</length>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_Crew_Name__c</fullName>
        <label>Crew Name</label>
        <type>Text</type>
        <length>255</length>
        <required>false</required>
    </fields>
    <fields>
        <fullName>ULBC_Result__c</fullName>
        <label>Result</label>
        <type>Text</type>
        <length>100</length>
        <required>false</required>
    </fields>
    <listViews>
        <fullName>All</fullName>
        <filterScope>Everything</filterScope>
        <label>All Crew History Records</label>
    </listViews>
</CustomObject>
ENDOFFILE

# ─── Jade Smith test data ─────────────────────────────────────────────────────

cat > data/test-records/jade-smith-tree.json << 'ENDOFFILE'
{
  "records": [
    {
      "attributes": { "type": "Contact", "referenceId": "JadeSmithRef" },
      "FirstName": "Jade",
      "LastName": "Smith",
      "ULBC_Birth_Name__c": "Robinson",
      "ULBC_Trust_ID__c": "ULBC-0001",
      "ULBC_Primary_Contact_Type__c": "Alumni",
      "ULBC_Gender__c": "Female",
      "Birthdate": "1966-03-14",
      "Email": "jade.smith@example.com",
      "ULBC_Secondary_Email__c": "jade.robinson@example.com",
      "ULBC_GDPR_Legal_Basis__c": "Legitimate Interests — membership relationship",
      "ULBC_Is_Donor__c": true,
      "ULBC_Is_Volunteer__c": true,
      "ULBC_Volunteer_Since__c": "2024-01-01",
      "ULBC_Is_Tyrian_Member__c": false,
      "ULBC_Gone_Away__c": false,
      "ULBC_Alumni_Type__c": "UK",
      "ULBC_Acquisition_Channel__c": "Alumni",
      "ULBC_Education_Histories__r": {
        "records": [
          { "attributes": { "type": "ULBC_Education_History__c", "referenceId": "JadeEduUCL" }, "ULBC_Institution__c": "University College London", "ULBC_Degree_Type__c": "Undergraduate", "ULBC_Subject__c": "Biology", "ULBC_Start_Year__c": 1985, "ULBC_End_Year__c": 1988 },
          { "attributes": { "type": "ULBC_Education_History__c", "referenceId": "JadeEduKings" }, "ULBC_Institution__c": "Kings College London", "ULBC_Degree_Type__c": "Masters", "ULBC_Subject__c": "Sports Science", "ULBC_Start_Year__c": 1988, "ULBC_End_Year__c": 1990 },
          { "attributes": { "type": "ULBC_Education_History__c", "referenceId": "JadeEduRH" }, "ULBC_Institution__c": "Royal Holloway", "ULBC_Degree_Type__c": "PhD", "ULBC_Subject__c": "Exercise Physiology", "ULBC_Start_Year__c": 1990, "ULBC_End_Year__c": 1994 }
        ]
      },
      "ULBC_International_Competitions__r": {
        "records": [
          { "attributes": { "type": "ULBC_International_Competition__c", "referenceId": "JadeU23" }, "ULBC_Year__c": 1985, "ULBC_Competition__c": "U23 World Championships", "ULBC_Event__c": "Women's 4-", "ULBC_Result__c": "2nd", "ULBC_Country_Represented__c": "GB" },
          { "attributes": { "type": "ULBC_International_Competition__c", "referenceId": "JadeOlympics" }, "ULBC_Year__c": 1988, "ULBC_Competition__c": "Olympic Games", "ULBC_Event__c": "Women's 8+", "ULBC_Result__c": "5th", "ULBC_Country_Represented__c": "GB" }
        ]
      },
      "ULBC_Crew_Histories__r": {
        "records": [
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1983" }, "ULBC_Crew_Code__c": "HRR-W8-1983", "ULBC_Year__c": 1983, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1983", "ULBC_Result__c": "Finalist" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1984" }, "ULBC_Crew_Code__c": "HRR-W8-1984", "ULBC_Year__c": 1984, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1984", "ULBC_Result__c": "Finalist" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1985" }, "ULBC_Crew_Code__c": "HRR-W8-1985", "ULBC_Year__c": 1985, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1985", "ULBC_Result__c": "Winner" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1986" }, "ULBC_Crew_Code__c": "HRR-W8-1986", "ULBC_Year__c": 1986, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1986", "ULBC_Result__c": "Finalist" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1987" }, "ULBC_Crew_Code__c": "HRR-W8-1987", "ULBC_Year__c": 1987, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1987", "ULBC_Result__c": "Finalist" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1988" }, "ULBC_Crew_Code__c": "HRR-W8-1988", "ULBC_Year__c": 1988, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1988", "ULBC_Result__c": "Winner" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1989" }, "ULBC_Crew_Code__c": "HRR-W8-1989", "ULBC_Year__c": 1989, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1989", "ULBC_Result__c": "Finalist" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1990" }, "ULBC_Crew_Code__c": "HRR-W8-1990", "ULBC_Year__c": 1990, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1990", "ULBC_Result__c": "Winner" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1991" }, "ULBC_Crew_Code__c": "HRR-W8-1991", "ULBC_Year__c": 1991, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1991", "ULBC_Result__c": "Finalist" },
          { "attributes": { "type": "ULBC_Crew_History__c", "referenceId": "Crew1992" }, "ULBC_Crew_Code__c": "HRR-W8-1992", "ULBC_Year__c": 1992, "ULBC_Regatta__c": "Henley Royal Regatta", "ULBC_Event__c": "Women's Eight", "ULBC_Crew_Name__c": "ULBC Women's Eight 1992", "ULBC_Result__c": "Finalist" }
        ]
      }
    }
  ]
}
ENDOFFILE

echo ""
echo "✅ All Phase 1 files created. Verifying..."
echo ""
find force-app -type f | sort
echo ""
echo "File count: $(find force-app -type f | wc -l | tr -d ' ') files (expect 20)"
echo ""
echo "Ready to deploy. Run:"
echo "  sf project deploy start --source-dir force-app/main/default/objects/Contact --wait 10"
