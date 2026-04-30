/**
 * ULBC_XeroIncomeImporter_Test
 *
 * Phase 6A — covers Xero income import end-to-end using HttpCalloutMock:
 *   1. Match by Trust ID → Opportunity created with Contact
 *   2. Empty AccountNumber → orphan Opportunity + Chatter post
 *   3. Unknown AccountNumber → orphan Opportunity, AccountNumber preserved
 *   4. Multi-page response → second page processed via direct call
 *   5. Re-run idempotency → duplicate transaction IDs skipped
 *   6. Xero 401 → sync log Status=Error, no Opportunity inserted
 *   7. Xero 429 → sync log Status=Error
 *   8. Schedulable execute() enqueues the queueable (and queueable runs)
 *   9. Orphan digest email — enabled + recipients → one send per page
 *  10. Orphan digest email — disabled → no send
 *  11. Orphan digest email — no orphans on page → no send
 *  12. Orphan digest email — recipients blank → no send
 */
@IsTest
private class ULBC_XeroIncomeImporter_Test {

    @TestSetup
    static void setupSettings() {
        ULBC_Xero_Settings__c s = new ULBC_Xero_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            DefaultFundType__c = 'Unrestricted',
            OrphanChatterUserId__c = UserInfo.getUserId()
        );
        insert s;

        Contact known = new Contact(
            FirstName = 'Jade',
            LastName = 'Smith',
            Email = 'jade@example.com',
            ULBC_Trust_ID__c = 'ULBC-9001'
        );
        insert known;
    }

    private static Opportunity latestImportedOpp() {
        return [
            SELECT Id, Name, Amount, StageName, CloseDate,
                   ULBC_Xero_Transaction_ID__c, ULBC_Xero_AccountNumber_Seen__c,
                   ULBC_Source__c, ULBC_Gift_Type__c, ULBC_Fund_Type__c,
                   npe01__Contact_Id_for_Role__c
            FROM Opportunity
            WHERE ULBC_Source__c = 'Xero Import'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private static ULBC_Xero_Sync_Log__c latestLog() {
        return [
            SELECT Id, ULBC_Status__c, ULBC_Transactions_Read__c,
                   ULBC_Opportunities_Created__c, ULBC_Orphans_Created__c,
                   ULBC_Skipped_Duplicates__c, ULBC_Error_Message__c,
                   ULBC_Page_Number__c, ULBC_Watermark_Before__c,
                   ULBC_Watermark_After__c
            FROM ULBC_Xero_Sync_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    // ─── 1. Match by Trust ID ──────────────────────────────────────────

    @IsTest
    static void test_matchByTrustId_createsOpportunityWithContact() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-001', 25.00, DateTime.newInstanceGmt(2026, 4, 25, 10, 0, 0),
                'Jade Smith', 'ULBC-9001', 'jade@example.com'
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        ULBC_XeroIncomeImporter.PageResult r =
            ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('Success', r.status, 'Expected Success status');
        System.assertEquals(1, r.transactionsRead);
        System.assertEquals(1, r.opportunitiesCreated);
        System.assertEquals(0, r.orphansCreated);
        System.assertEquals(0, r.skippedDuplicates);

        Contact known = [SELECT Id FROM Contact WHERE ULBC_Trust_ID__c = 'ULBC-9001'];
        Opportunity opp = latestImportedOpp();
        System.assertEquals(known.Id, opp.npe01__Contact_Id_for_Role__c,
            'Opportunity should be linked to matched Contact');
        System.assertEquals(25.00, opp.Amount);
        System.assertEquals('Closed Won', opp.StageName);
        System.assertEquals('txn-001', opp.ULBC_Xero_Transaction_ID__c);
        System.assertEquals('ULBC-9001', opp.ULBC_Xero_AccountNumber_Seen__c);
        System.assertEquals('Xero Import', opp.ULBC_Source__c);
    }

    // ─── 2. No AccountNumber → orphan + Chatter ────────────────────────

    @IsTest
    static void test_noAccountNumber_createsOrphanWithChatter() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-002', 50.00, DateTime.newInstanceGmt(2026, 4, 26, 11, 0, 0),
                'Anonymous Bank Transfer', null, null
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        ULBC_XeroIncomeImporter.PageResult r =
            ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('Success', r.status);
        System.assertEquals(1, r.opportunitiesCreated);
        System.assertEquals(1, r.orphansCreated);

        Opportunity opp = latestImportedOpp();
        System.assertEquals(null, opp.npe01__Contact_Id_for_Role__c, 'Should be orphan');
        System.assertEquals(null, opp.ULBC_Xero_AccountNumber_Seen__c);

        List<FeedItem> posts = [SELECT Id, Body FROM FeedItem WHERE ParentId = :opp.Id];
        System.assertEquals(1, posts.size(),
            'Orphan should have exactly one Chatter feed item');
        System.assert(posts[0].Body.contains('no matching Trust ID'),
            'Chatter body should explain the orphan reason');
    }

    // ─── 3. Unknown AccountNumber → orphan ─────────────────────────────

    @IsTest
    static void test_unknownAccountNumber_createsOrphanPreservingValue() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-003', 100.00, DateTime.newInstanceGmt(2026, 4, 27, 12, 0, 0),
                'New Donor', 'ULBC-NOT-A-REAL-ID', 'new@example.com'
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        ULBC_XeroIncomeImporter.PageResult r =
            ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('Success', r.status);
        System.assertEquals(1, r.orphansCreated);

        Opportunity opp = latestImportedOpp();
        System.assertEquals(null, opp.npe01__Contact_Id_for_Role__c);
        System.assertEquals('ULBC-NOT-A-REAL-ID', opp.ULBC_Xero_AccountNumber_Seen__c,
            'Original AccountNumber should be preserved for triage');
    }

    // ─── 4. Multi-page response ─────────────────────────────────────────
    // Apex forbids HTTP callouts after DML in the same transaction, so we
    // can't call runPage twice directly. The page-2 work is dispatched via
    // a Queueable, which runs in a fresh transaction at Test.stopTest().

    @IsTest
    static void test_multiPage_chainProcessesBothPages() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        List<Map<String, Object>> page1 = new List<Map<String, Object>>();
        for (Integer i = 0; i < ULBC_XeroIncomeImporter.PAGE_SIZE; i++) {
            page1.add(ULBC_XeroHttpMock.txn(
                'txn-page1-' + i, 5.00,
                DateTime.newInstanceGmt(2026, 4, 28, 10, 0, i),
                'Donor ' + i, null, null
            ));
        }
        mock.body = ULBC_XeroHttpMock.buildResponse(page1);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        // Page 1 directly: does callout + DML in this transaction.
        ULBC_XeroIncomeImporter.PageResult r1 =
            ULBC_XeroIncomeImporter.runPage(1, null);

        // Swap mock body for page 2 (small, signals end of pagination)
        // and enqueue page 2 — the queueable runs in a fresh transaction
        // at Test.stopTest, so its callout is allowed.
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-page2-0', 7.00, DateTime.newInstanceGmt(2026, 4, 28, 10, 5, 0),
                'Last donor', null, null
            )
        });
        System.enqueueJob(new ULBC_XeroIncomeImporterQueueable(2, r1.watermarkAfter));
        Test.stopTest();

        System.assertEquals('Success', r1.status, 'r1 err=' + r1.errorMessage);
        System.assertEquals(true, r1.hasMore, 'Page 1 hit PAGE_SIZE — expect more');
        System.assertEquals(ULBC_XeroIncomeImporter.PAGE_SIZE, r1.opportunitiesCreated,
            'r1 err=' + r1.errorMessage);

        // Page 2's outcome is visible via SOQL after the queueable ran.
        Integer page2Count = [
            SELECT COUNT() FROM Opportunity
            WHERE ULBC_Xero_Transaction_ID__c = 'txn-page2-0'
        ];
        System.assertEquals(1, page2Count, 'Page 2 queueable should have inserted 1 Opp');

        // The page-2 sync log proves the queueable ran with hasMore=false.
        ULBC_Xero_Sync_Log__c page2Log = [
            SELECT ULBC_Status__c, ULBC_Page_Number__c,
                   ULBC_Opportunities_Created__c, ULBC_Transactions_Read__c
            FROM ULBC_Xero_Sync_Log__c
            WHERE ULBC_Page_Number__c = 2
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals('Success', page2Log.ULBC_Status__c);
        System.assertEquals(1, page2Log.ULBC_Opportunities_Created__c);
    }

    // ─── 5. Idempotency on re-run ──────────────────────────────────────
    // Same DML-before-callout constraint as test 4: the second run is
    // dispatched via a Queueable so it gets a fresh transaction.

    @IsTest
    static void test_rerun_skipsAlreadyImportedTransactions() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-idempotent', 30.00,
                DateTime.newInstanceGmt(2026, 4, 25, 10, 0, 0),
                'Jade Smith', 'ULBC-9001', 'jade@example.com'
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        ULBC_XeroIncomeImporter.PageResult firstRun =
            ULBC_XeroIncomeImporter.runPage(1, null);
        // Re-run via a Queueable so the second callout starts in a fresh tx.
        System.enqueueJob(new ULBC_XeroIncomeImporterQueueable(1, null));
        Test.stopTest();

        System.assertEquals('Success', firstRun.status, 'first err=' + firstRun.errorMessage);
        System.assertEquals(1, firstRun.opportunitiesCreated, 'first err=' + firstRun.errorMessage);
        System.assertEquals(0, firstRun.skippedDuplicates);

        // The queueable wrote its own Sync Log row. Find it (newer than firstRun's).
        List<ULBC_Xero_Sync_Log__c> logs = [
            SELECT ULBC_Status__c, ULBC_Opportunities_Created__c, ULBC_Skipped_Duplicates__c
            FROM ULBC_Xero_Sync_Log__c
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 2
        ];
        System.assertEquals(2, logs.size(), 'Both runs should have logged');
        ULBC_Xero_Sync_Log__c secondLog = logs[0];
        System.assertEquals('Success', secondLog.ULBC_Status__c);
        System.assertEquals(0, secondLog.ULBC_Opportunities_Created__c,
            'Second run must not create duplicate Opportunities');
        System.assertEquals(1, secondLog.ULBC_Skipped_Duplicates__c,
            'Second run should mark txn-idempotent as duplicate');

        Integer total = [
            SELECT COUNT() FROM Opportunity
            WHERE ULBC_Xero_Transaction_ID__c = 'txn-idempotent'
        ];
        System.assertEquals(1, total, 'Unique constraint enforces single Opp');
    }

    // ─── 6. Xero 401 → Error log, no DML ───────────────────────────────

    @IsTest
    static void test_xero401_writesErrorLog_noOpportunity() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.statusCode = 401;
        mock.body = '{"Type":"NoAuthError"}';
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        ULBC_XeroIncomeImporter.PageResult r =
            ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('Error', r.status);
        System.assertEquals(0, r.opportunitiesCreated);

        ULBC_Xero_Sync_Log__c log = latestLog();
        System.assertEquals('Error', log.ULBC_Status__c);
        System.assert(log.ULBC_Error_Message__c.contains('401'),
            'Error message should include the HTTP status');

        Integer importedCount = [
            SELECT COUNT() FROM Opportunity WHERE ULBC_Source__c = 'Xero Import'
        ];
        System.assertEquals(0, importedCount, 'No Opps on auth failure');
    }

    // ─── 7. Xero 429 → Error log ───────────────────────────────────────

    @IsTest
    static void test_xero429_writesErrorLog() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.statusCode = 429;
        mock.body = 'rate limit';
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        ULBC_XeroIncomeImporter.PageResult r =
            ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('Error', r.status);
        ULBC_Xero_Sync_Log__c log = latestLog();
        System.assert(log.ULBC_Error_Message__c.contains('429'));
    }

    // ─── 8. Schedulable + Queueable wire-up ────────────────────────────

    // ─── 9. Orphan digest email — enabled + recipients ─────────────────

    @IsTest
    static void test_orphanEmail_enabled_sendsOneEmail() {
        ULBC_Xero_Settings__c s = ULBC_Xero_Settings__c.getOrgDefaults();
        s.OrphanNotificationsEnabled__c = true;
        s.OrphanNotifyEmails__c = 'finance@example.com';
        update s;

        // Sanity-check: the update actually persisted at the row level.
        ULBC_Xero_Settings__c verified = [
            SELECT OrphanNotificationsEnabled__c, OrphanNotifyEmails__c, SetupOwnerId
            FROM ULBC_Xero_Settings__c LIMIT 1
        ];
        System.assertEquals(true, verified.OrphanNotificationsEnabled__c,
            'enabled flag should be true after update');
        System.assertEquals('finance@example.com', verified.OrphanNotifyEmails__c,
            'recipient list should be set after update');
        System.assertEquals(UserInfo.getOrganizationId(), verified.SetupOwnerId,
            'SetupOwnerId should match running org');

        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-email-1', 50.00, DateTime.newInstanceGmt(2026, 4, 30, 10, 0, 0),
                'Anonymous Bank Transfer', null, null
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        ULBC_XeroIncomeImporter.lastEmailOutcome = null;
        Test.startTest();
        ULBC_XeroIncomeImporter.PageResult r =
            ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('Success', r.status);
        System.assertEquals(1, r.orphansCreated);
        System.assertNotEquals(null, ULBC_XeroIncomeImporter.lastEmailOutcome,
            'sendOrphanDigestEmail should have run and recorded an outcome');
        System.assert(ULBC_XeroIncomeImporter.lastEmailOutcome.startsWith('sent'),
            'Expected outcome to start with "sent" but got: ' + ULBC_XeroIncomeImporter.lastEmailOutcome);
    }

    // ─── 10. Orphan digest email — disabled ────────────────────────────

    @IsTest
    static void test_orphanEmail_disabled_noSend() {
        // Default setupSettings() leaves OrphanNotificationsEnabled false.
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-email-2', 50.00, DateTime.newInstanceGmt(2026, 4, 30, 11, 0, 0),
                'Anonymous Bank Transfer', null, null
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        ULBC_XeroIncomeImporter.lastEmailOutcome = null;
        Test.startTest();
        ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assert(
            ULBC_XeroIncomeImporter.lastEmailOutcome != null
                && ULBC_XeroIncomeImporter.lastEmailOutcome.startsWith('disabled'),
            'Expected outcome to start with "disabled" when notifications off. Got: '
                + ULBC_XeroIncomeImporter.lastEmailOutcome);
    }

    // ─── 11. Orphan digest email — no orphans on page ──────────────────

    @IsTest
    static void test_orphanEmail_noOrphansOnPage_noSend() {
        ULBC_Xero_Settings__c s = ULBC_Xero_Settings__c.getOrgDefaults();
        s.OrphanNotificationsEnabled__c = true;
        s.OrphanNotifyEmails__c = 'finance@example.com';
        update s;

        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-email-3', 25.00, DateTime.newInstanceGmt(2026, 4, 30, 12, 0, 0),
                'Jade Smith', 'ULBC-9001', 'jade@example.com'
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        ULBC_XeroIncomeImporter.lastEmailOutcome = null;
        Test.startTest();
        ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('no-orphans', ULBC_XeroIncomeImporter.lastEmailOutcome,
            'Outcome should be "no-orphans" when nothing was orphaned on the page');
    }

    // ─── 12. Orphan digest email — recipients blank ────────────────────

    @IsTest
    static void test_orphanEmail_blankRecipients_noSend() {
        ULBC_Xero_Settings__c s = ULBC_Xero_Settings__c.getOrgDefaults();
        s.OrphanNotificationsEnabled__c = true;
        s.OrphanNotifyEmails__c = null;
        update s;

        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-email-4', 50.00, DateTime.newInstanceGmt(2026, 4, 30, 13, 0, 0),
                'Anonymous Bank Transfer', null, null
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        ULBC_XeroIncomeImporter.lastEmailOutcome = null;
        Test.startTest();
        ULBC_XeroIncomeImporter.runPage(1, null);
        Test.stopTest();

        System.assertEquals('blank-recipients', ULBC_XeroIncomeImporter.lastEmailOutcome,
            'Outcome should be "blank-recipients" when OrphanNotifyEmails is null');
    }

    // ─── 8. Schedulable + Queueable wire-up ────────────────────────────

    @IsTest
    static void test_schedulable_enqueuesQueueable_andRuns() {
        ULBC_XeroHttpMock mock = new ULBC_XeroHttpMock();
        mock.body = ULBC_XeroHttpMock.buildResponse(new List<Map<String, Object>>{
            ULBC_XeroHttpMock.txn(
                'txn-scheduled', 11.00,
                DateTime.newInstanceGmt(2026, 4, 29, 2, 0, 0),
                'Jade Smith', 'ULBC-9001', 'jade@example.com'
            )
        });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new ULBC_XeroImportSchedulable().execute(null);
        Test.stopTest();

        Integer impCount = [
            SELECT COUNT() FROM Opportunity
            WHERE ULBC_Xero_Transaction_ID__c = 'txn-scheduled'
        ];
        System.assertEquals(1, impCount,
            'Schedulable should enqueue queueable, which runs at Test.stopTest()');
    }
}