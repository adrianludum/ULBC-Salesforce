/**
 * ULBC_Phase3B_Recruitment_Test
 *
 * Verifies the recruitment pipeline (Lead) data model for Phase 3B:
 *   - Lead custom fields exist and accept values
 *   - Pipeline stages: Prospect → Emailed → Spoken To → Applied → Accepted
 *   - Lead conversion creates Contact with correct field mapping
 *   - All 6 custom fields are populated and queryable
 *
 * Run with: sf apex run test --class-names ULBC_Phase3B_Recruitment_Test --code-coverage --target-org ulbc
 */
@isTest
private class ULBC_Phase3B_Recruitment_Test {

    private static Lead createTestLead() {
        return new Lead(
            FirstName                    = 'Test',
            LastName                     = 'Prospect',
            Email                        = 'test.prospect@example.com',
            Phone                        = '07700900001',
            Company                      = '[Not Provided]',
            Status                       = 'Prospect',
            ULBC_Current_Institution__c  = 'Durham School',
            ULBC_Graduation_Year__c      = 2027,
            ULBC_Gender__c               = 'Female',
            ULBC_Current_Rowing_Event__c = 'Women\'s 4-',
            ULBC_Recruitment_Source__c   = 'BUCS Results',
            ULBC_Coach_Notes__c          = 'Strong 2k erg time. Raced at BUCS Regatta 2026.'
        );
    }

    // ── Lead creation and custom fields ─────────────────────────────────

    @isTest
    static void test_leadCreatedWithAllCustomFields() {
        Lead l = createTestLead();

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [
            SELECT ULBC_Current_Institution__c, ULBC_Graduation_Year__c,
                   ULBC_Gender__c, ULBC_Current_Rowing_Event__c,
                   ULBC_Recruitment_Source__c, ULBC_Coach_Notes__c
            FROM Lead WHERE Id = :l.Id
        ];
        System.assertEquals('Durham School',  result.ULBC_Current_Institution__c);
        System.assertEquals(2027,             result.ULBC_Graduation_Year__c);
        System.assertEquals('Female',         result.ULBC_Gender__c);
        System.assertEquals('Women\'s 4-',    result.ULBC_Current_Rowing_Event__c);
        System.assertEquals('BUCS Results',   result.ULBC_Recruitment_Source__c);
        System.assert(result.ULBC_Coach_Notes__c.contains('Strong 2k erg time'));
    }

    @isTest
    static void test_leadDefaultStatusIsProspect() {
        Lead l = createTestLead();
        insert l;

        Lead result = [SELECT Status FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Prospect', result.Status);
    }

    // ── Pipeline stage progression ──────────────────────────────────────

    @isTest
    static void test_leadProgressesThroughPipelineStages() {
        Lead l = createTestLead();
        insert l;

        List<String> stages = new List<String>{
            'Emailed', 'Spoken To', 'Applied'
        };

        for (String stage : stages) {
            l.Status = stage;
            update l;

            Lead result = [SELECT Status FROM Lead WHERE Id = :l.Id];
            System.assertEquals(stage, result.Status, 'Lead must accept status: ' + stage);
        }
    }

    // ── Gender picklist values ──────────────────────────────────────────

    @isTest
    static void test_genderMaleValue() {
        Lead l = createTestLead();
        l.ULBC_Gender__c = 'Male';
        insert l;

        Lead result = [SELECT ULBC_Gender__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Male', result.ULBC_Gender__c);
    }

    // ── Recruitment Source picklist values ───────────────────────────────

    @isTest
    static void test_allRecruitmentSourceValues() {
        List<String> sources = new List<String>{
            'BUCS Results', 'Referral', 'Direct Inquiry', 'Trials', 'Other'
        };

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < sources.size(); i++) {
            Lead l = new Lead(
                FirstName                  = 'Source',
                LastName                   = 'Test' + i,
                Company                    = '[Not Provided]',
                Status                     = 'Prospect',
                ULBC_Recruitment_Source__c  = sources[i]
            );
            leads.add(l);
        }

        Test.startTest();
        insert leads;
        Test.stopTest();

        List<Lead> results = [
            SELECT ULBC_Recruitment_Source__c FROM Lead WHERE Id IN :leads ORDER BY LastName
        ];
        for (Integer i = 0; i < sources.size(); i++) {
            System.assertEquals(sources[i], results[i].ULBC_Recruitment_Source__c,
                'Recruitment Source must accept: ' + sources[i]);
        }
    }

    // ── Lead conversion ─────────────────────────────────────────────────

    @isTest
    static void test_leadConversionCreatesContact() {
        Lead l = createTestLead();
        insert l;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus('Accepted');
        lc.setDoNotCreateOpportunity(true);

        Test.startTest();
        Database.LeadConvertResult result = Database.convertLead(lc);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Lead conversion must succeed');
        System.assertNotEquals(null, result.getContactId(), 'Contact must be created');

        Contact c = [
            SELECT FirstName, LastName, Email, Phone
            FROM Contact WHERE Id = :result.getContactId()
        ];
        System.assertEquals('Test',                      c.FirstName);
        System.assertEquals('Prospect',                  c.LastName);
        System.assertEquals('test.prospect@example.com', c.Email);
        System.assertEquals('07700900001',               c.Phone);
    }

    @isTest
    static void test_leadConversionSetsAcceptedStatus() {
        Lead l = createTestLead();
        insert l;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus('Accepted');
        lc.setDoNotCreateOpportunity(true);

        Test.startTest();
        Database.LeadConvertResult result = Database.convertLead(lc);
        Test.stopTest();

        Lead converted = [SELECT Status, IsConverted FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Accepted', converted.Status);
        System.assertEquals(true, converted.IsConverted);
    }

    @isTest
    static void test_notProgressedClosesLeadWithoutConversion() {
        Lead l = createTestLead();
        insert l;

        l.Status = 'Not Progressed';
        update l;

        Lead result = [SELECT Status, IsConverted FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Not Progressed', result.Status);
        System.assertEquals(false, result.IsConverted, 'Not Progressed must not convert the Lead');
    }

    // ── Bulk insert ─────────────────────────────────────────────────────

    @isTest
    static void test_bulkLeadInsert() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            leads.add(new Lead(
                FirstName                    = 'Bulk',
                LastName                     = 'Prospect' + i,
                Company                      = '[Not Provided]',
                Status                       = 'Prospect',
                ULBC_Current_Institution__c  = 'Test University',
                ULBC_Graduation_Year__c      = 2027,
                ULBC_Gender__c               = 'Male',
                ULBC_Current_Rowing_Event__c = 'Men\'s 8+',
                ULBC_Recruitment_Source__c   = 'Trials'
            ));
        }

        Test.startTest();
        insert leads;
        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM Lead WHERE ULBC_Current_Institution__c = 'Test University'],
            'All 200 leads must be inserted');
    }
}
