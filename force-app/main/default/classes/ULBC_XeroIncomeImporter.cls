/**
 * ULBC_XeroIncomeImporter
 *
 * Phase 6A — pulls income transactions from Xero and mirrors them into
 * Salesforce as Opportunities. One Xero BankTransaction (Type=RECEIVE) →
 * one Opportunity (Stage=Closed Won), keyed by BankTransactionID for
 * idempotency. Donor identity links via Trust ID = Xero Contact AccountNumber.
 *
 * Entry point: runPage(pageNumber, watermarkOverride). Pagination handled
 * by ULBC_XeroIncomeImporterQueueable, which chains itself per page.
 *
 * Decisions: 6.9 (direction reversed — Xero is source of truth for income),
 * 6.10 (Trust ID = Xero AccountNumber), 6.11 (one transaction → one
 * Opportunity), 6.12 (orphan UX via Chatter + dashboard).
 */
// without sharing: invoked from Schedulable / Queueable contexts that
// run as the scheduling user but should write across the org regardless
// of CRUD/FLS gaps. Same Decision 5.22 reasoning as ULBC_DonationHandler.
public without sharing class ULBC_XeroIncomeImporter {

    @TestVisible private static final Integer PAGE_SIZE = 100;
    @TestVisible private static final String NAMED_CRED = 'callout:ULBC_Xero';
    public static final String SOURCE_VALUE = 'Xero Import';
    public static final String STAGE_CLOSED_WON = 'Closed Won';
    public static final String DEFAULT_GIFT_TYPE = 'One-off';

    public class XeroException extends Exception {}

    public class PageResult {
        public Integer pageNumber;
        public Integer transactionsRead = 0;
        public Integer opportunitiesCreated = 0;
        public Integer orphansCreated = 0;
        public Integer skippedDuplicates = 0;
        public Integer deferredNoAccountNumber = 0;
        public Boolean hasMore = false;
        public String status = 'Error';
        public String errorMessage;
        public DateTime watermarkBefore;
        public DateTime watermarkAfter;
    }

    public class XeroBankTransaction {
        public String bankTransactionId;
        public DateTime txnDate;
        public DateTime updatedDateUtc;
        public Decimal total;
        public String reference;
        public String contactId;            // Xero ContactID (GUID), used to fetch AccountNumber
        public String contactName;
        public String contactAccountNumber; // populated by enrichContactsWithAccountNumbers()
        public String contactEmail;
    }

    /**
     * Process one page of Xero BankTransactions. Returns a PageResult
     * describing what happened (and whether more pages remain). Always
     * writes a ULBC_Xero_Sync_Log__c row, even on failure.
     */
    public static PageResult runPage(Integer pageNumber, DateTime watermarkOverride) {
        PageResult result = new PageResult();
        result.pageNumber = pageNumber;
        DateTime runStarted = System.now();

        try {
            DateTime watermark = (watermarkOverride != null)
                ? watermarkOverride
                : getWatermark();
            result.watermarkBefore = watermark;

            HttpResponse res = fetchPage(pageNumber, watermark);
            Integer code = res.getStatusCode();
            if (code < 200 || code >= 300) {
                throw new XeroException('Xero returned HTTP ' + code + ': ' + truncate(res.getBody(), 1000));
            }

            List<XeroBankTransaction> txns = parseTransactions(res.getBody());
            result.transactionsRead = txns.size();

            // Enrich Contact summaries with AccountNumber (= Trust ID).
            // Xero's /BankTransactions endpoint omits AccountNumber from its
            // embedded Contact, so we fetch the full Contact records in bulk.
            enrichContactsWithAccountNumbers(txns);

            // Index by BankTransactionID so the orphan email can quote
            // donor name / AccountNumber / email per orphan.
            Map<String, XeroBankTransaction> txnsByBankTxnId = new Map<String, XeroBankTransaction>();
            for (XeroBankTransaction t : txns) {
                if (String.isNotBlank(t.bankTransactionId)) txnsByBankTxnId.put(t.bankTransactionId, t);
            }

            // Already-imported guard (idempotency)
            Set<String> incomingIds = new Set<String>();
            for (XeroBankTransaction t : txns) {
                if (String.isNotBlank(t.bankTransactionId)) incomingIds.add(t.bankTransactionId);
            }
            Set<String> existingIds = new Set<String>();
            if (!incomingIds.isEmpty()) {
                for (Opportunity o : [
                    SELECT ULBC_Xero_Transaction_ID__c
                    FROM Opportunity
                    WHERE ULBC_Xero_Transaction_ID__c IN :incomingIds
                ]) {
                    existingIds.add(o.ULBC_Xero_Transaction_ID__c);
                }
            }

            // Trust ID → SF Contact lookup
            Set<String> trustIds = new Set<String>();
            for (XeroBankTransaction t : txns) {
                if (existingIds.contains(t.bankTransactionId)) continue;
                if (String.isNotBlank(t.contactAccountNumber)) trustIds.add(t.contactAccountNumber);
            }
            Map<String, Id> contactByTrustId = new Map<String, Id>();
            if (!trustIds.isEmpty()) {
                for (Contact c : [
                    SELECT Id, ULBC_Trust_ID__c
                    FROM Contact
                    WHERE ULBC_Trust_ID__c IN :trustIds
                ]) {
                    contactByTrustId.put(c.ULBC_Trust_ID__c, c.Id);
                }
            }

            List<Opportunity> toInsert = new List<Opportunity>();
            DateTime maxUpdated = (watermark != null) ? watermark : null;
            // Decision 6.14: track the earliest UpdatedDateUTC among txns deferred
            // because their Xero Contact has no AccountNumber. Used to hold the
            // watermark back so the next run re-pulls them once Martin sets the
            // AccountNumber on the Xero side.
            DateTime minDeferredUpdated = null;
            for (XeroBankTransaction t : txns) {
                if (t.updatedDateUtc != null && (maxUpdated == null || t.updatedDateUtc > maxUpdated)) {
                    maxUpdated = t.updatedDateUtc;
                }
                if (existingIds.contains(t.bankTransactionId)) {
                    result.skippedDuplicates++;
                    continue;
                }
                if (String.isBlank(t.contactAccountNumber)) {
                    result.deferredNoAccountNumber++;
                    if (t.updatedDateUtc != null
                        && (minDeferredUpdated == null || t.updatedDateUtc < minDeferredUpdated)) {
                        minDeferredUpdated = t.updatedDateUtc;
                    }
                    continue;
                }
                Id contactId = contactByTrustId.get(t.contactAccountNumber);
                Opportunity opp = buildOpportunity(t, contactId);
                toInsert.add(opp);
                if (contactId == null) result.orphansCreated++;
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
                result.opportunitiesCreated = toInsert.size();
                postChatterOnOrphans(toInsert);
                sendOrphanDigestEmail(toInsert, txnsByBankTxnId);
            }

            // Hold the watermark back to just before the earliest deferred txn so
            // the next If-Modified-Since query re-pulls it. Imported txns advance
            // freely; idempotency on ULBC_Xero_Transaction_ID__c prevents dupes.
            // Subtract 1 second (not 1ms): If-Modified-Since is RFC 1123 GMT with
            // second precision, so a sub-second offset would format identically
            // and exclude the deferred txn from the next run's response.
            DateTime effectiveNewWatermark = maxUpdated;
            if (minDeferredUpdated != null && maxUpdated != null
                && minDeferredUpdated <= maxUpdated) {
                effectiveNewWatermark = minDeferredUpdated.addSeconds(-1);
            }
            result.watermarkAfter = effectiveNewWatermark;
            updateWatermark(effectiveNewWatermark);

            result.status = 'Success';
            result.hasMore = (txns.size() == PAGE_SIZE);

        } catch (Exception e) {
            result.status = 'Error';
            result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
        }

        writeSyncLog(result, runStarted);
        return result;
    }

    @TestVisible
    private static HttpResponse fetchPage(Integer pageNumber, DateTime watermark) {
        HttpRequest req = new HttpRequest();
        String endpoint = NAMED_CRED + '/api.xro/2.0/BankTransactions'
            + '?page=' + pageNumber
            + '&where=' + EncodingUtil.urlEncode('Type=="RECEIVE"', 'UTF-8');
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        if (watermark != null) {
            // Xero supports If-Modified-Since (RFC 1123 GMT) for incremental sync.
            req.setHeader('If-Modified-Since', watermark.formatGmt('EEE, d MMM yyyy HH:mm:ss \'GMT\''));
        }
        req.setTimeout(60000);
        return new Http().send(req);
    }

    /**
     * Fetches AccountNumber + EmailAddress for each unique ContactID in the
     * given transactions and writes them onto the matching XeroBankTransaction
     * objects. Necessary because Xero's /BankTransactions endpoint returns
     * only a summarised Contact (no AccountNumber).
     *
     * Chunks IDs into batches of 50 (Xero's documented limit for the IDs
     * query parameter on /Contacts).
     */
    @TestVisible
    private static void enrichContactsWithAccountNumbers(List<XeroBankTransaction> txns) {
        if (txns == null || txns.isEmpty()) return;
        Set<String> uniqueIds = new Set<String>();
        for (XeroBankTransaction t : txns) {
            if (String.isNotBlank(t.contactId) && String.isBlank(t.contactAccountNumber)) {
                uniqueIds.add(t.contactId);
            }
        }
        if (uniqueIds.isEmpty()) return;

        Map<String, String> accountNumberById = new Map<String, String>();
        Map<String, String> emailById = new Map<String, String>();

        List<String> idList = new List<String>(uniqueIds);
        Integer batchSize = 50;
        for (Integer start = 0; start < idList.size(); start += batchSize) {
            Integer endIdx = Math.min(start + batchSize, idList.size());
            List<String> batch = new List<String>();
            for (Integer i = start; i < endIdx; i++) batch.add(idList[i]);
            String idsParam = String.join(batch, ',');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CRED + '/api.xro/2.0/Contacts?IDs=' + EncodingUtil.urlEncode(idsParam, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(60000);

            HttpResponse res = new Http().send(req);
            Integer code = res.getStatusCode();
            if (code < 200 || code >= 300) {
                throw new XeroException('Xero /Contacts returned HTTP ' + code + ': ' + truncate(res.getBody(), 1000));
            }

            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> contacts = (List<Object>) root.get('Contacts');
            if (contacts == null) continue;
            for (Object o : contacts) {
                Map<String, Object> c = (Map<String, Object>) o;
                String cid = (String) c.get('ContactID');
                if (String.isBlank(cid)) continue;
                String accNum = (String) c.get('AccountNumber');
                String email = (String) c.get('EmailAddress');
                if (String.isNotBlank(accNum)) accountNumberById.put(cid, accNum);
                if (String.isNotBlank(email)) emailById.put(cid, email);
            }
        }

        for (XeroBankTransaction t : txns) {
            if (String.isBlank(t.contactId)) continue;
            if (String.isBlank(t.contactAccountNumber) && accountNumberById.containsKey(t.contactId)) {
                t.contactAccountNumber = accountNumberById.get(t.contactId);
            }
            if (String.isBlank(t.contactEmail) && emailById.containsKey(t.contactId)) {
                t.contactEmail = emailById.get(t.contactId);
            }
        }
    }

    @TestVisible
    private static List<XeroBankTransaction> parseTransactions(String body) {
        List<XeroBankTransaction> out = new List<XeroBankTransaction>();
        if (String.isBlank(body)) return out;
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> txns = (List<Object>) root.get('BankTransactions');
        if (txns == null) return out;
        for (Object o : txns) {
            Map<String, Object> m = (Map<String, Object>) o;
            XeroBankTransaction t = new XeroBankTransaction();
            t.bankTransactionId = (String) m.get('BankTransactionID');
            t.txnDate = parseXeroDate(stringValue(m.get('Date')));
            t.updatedDateUtc = parseXeroDate(stringValue(m.get('UpdatedDateUTC')));
            Object totalObj = m.get('Total');
            if (totalObj != null) {
                try { t.total = Decimal.valueOf(String.valueOf(totalObj)); }
                catch (Exception ex) { t.total = 0; }
            }
            t.reference = (String) m.get('Reference');
            Map<String, Object> contact = (Map<String, Object>) m.get('Contact');
            if (contact != null) {
                t.contactId = (String) contact.get('ContactID');
                t.contactName = (String) contact.get('Name');
                // The /BankTransactions endpoint returns only a Contact summary
                // (Name, ContactID, Phones, Addresses, ContactGroups). AccountNumber
                // and EmailAddress are NOT included. enrichContactsWithAccountNumbers()
                // fills these in via a follow-up GET /Contacts?IDs=... call.
                t.contactAccountNumber = (String) contact.get('AccountNumber');
                t.contactEmail = (String) contact.get('EmailAddress');
            }
            out.add(t);
        }
        return out;
    }

    @TestVisible
    private static Opportunity buildOpportunity(XeroBankTransaction t, Id contactId) {
        ULBC_Xero_Settings__c s = ULBC_Xero_Settings__c.getOrgDefaults();
        String defaultFundType = (s != null && String.isNotBlank(s.DefaultFundType__c))
            ? s.DefaultFundType__c
            : 'Unrestricted';

        Date closeDate = (t.txnDate != null)
            ? Date.newInstance(t.txnDate.yearGmt(), t.txnDate.monthGmt(), t.txnDate.dayGmt())
            : Date.today();

        Decimal amount = (t.total != null) ? t.total : 0;
        String amountStr = '£' + amount.setScale(2);
        String dateStr = closeDate.year() + '-'
            + String.valueOf(closeDate.month()).leftPad(2, '0') + '-'
            + String.valueOf(closeDate.day()).leftPad(2, '0');

        String name;
        if (contactId != null) {
            String donor = (String.isNotBlank(t.contactName)) ? t.contactName : 'Donor';
            name = donor + ' — ' + amountStr + ' — ' + dateStr;
        } else {
            String tail = String.isNotBlank(t.contactAccountNumber)
                ? ' — ' + t.contactAccountNumber
                : '';
            name = 'Xero unmatched — ' + amountStr + ' — ' + dateStr + tail;
        }
        if (name.length() > 120) name = name.substring(0, 120);

        return new Opportunity(
            Name = name,
            Amount = amount,
            CloseDate = closeDate,
            StageName = STAGE_CLOSED_WON,
            ULBC_Xero_Transaction_ID__c = t.bankTransactionId,
            ULBC_Xero_AccountNumber_Seen__c = t.contactAccountNumber,
            ULBC_Source__c = SOURCE_VALUE,
            ULBC_Gift_Type__c = DEFAULT_GIFT_TYPE,
            ULBC_Fund_Type__c = defaultFundType,
            npe01__Contact_Id_for_Role__c = contactId
        );
    }

    private static DateTime parseXeroDate(String s) {
        if (String.isBlank(s)) return null;
        if (s.startsWith('/Date(')) {
            Integer plusIdx = s.indexOf('+');
            if (plusIdx < 0) plusIdx = s.indexOf('-', 6);
            Integer endIdx = (plusIdx > 0) ? plusIdx : s.indexOf(')');
            try { return DateTime.newInstance(Long.valueOf(s.substring(6, endIdx))); }
            catch (Exception e) { return null; }
        }
        try { return (DateTime) JSON.deserialize('"' + s + '"', DateTime.class); }
        catch (Exception e) { return null; }
    }

    private static String stringValue(Object o) {
        return (o == null) ? null : String.valueOf(o);
    }

    private static String truncate(String s, Integer max) {
        if (s == null) return '';
        return (s.length() <= max) ? s : s.substring(0, max);
    }

    private static DateTime getWatermark() {
        ULBC_Xero_Settings__c s = ULBC_Xero_Settings__c.getOrgDefaults();
        return (s != null) ? s.LastSyncedAt__c : null;
    }

    private static void updateWatermark(DateTime newValue) {
        if (newValue == null) return;
        ULBC_Xero_Settings__c s = ULBC_Xero_Settings__c.getOrgDefaults();
        if (s == null || s.Id == null) {
            s = new ULBC_Xero_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        // Only advance, never go backwards.
        if (s.LastSyncedAt__c == null || newValue > s.LastSyncedAt__c) {
            s.LastSyncedAt__c = newValue;
            upsert s;
        }
    }

    private static void postChatterOnOrphans(List<Opportunity> opps) {
        ULBC_Xero_Settings__c s = ULBC_Xero_Settings__c.getOrgDefaults();
        Id mentionUser;
        if (s != null && String.isNotBlank(s.OrphanChatterUserId__c)) {
            try { mentionUser = Id.valueOf(s.OrphanChatterUserId__c); }
            catch (Exception e) { mentionUser = null; }
        }
        List<FeedItem> posts = new List<FeedItem>();
        for (Opportunity o : opps) {
            if (o.npe01__Contact_Id_for_Role__c != null) continue;
            String shown = String.isNotBlank(o.ULBC_Xero_AccountNumber_Seen__c)
                ? o.ULBC_Xero_AccountNumber_Seen__c
                : '(none on Xero transaction)';
            String body = 'Imported from Xero with no matching Trust ID. AccountNumber: '
                + shown
                + '. Reassign by setting the Primary Contact.';
            FeedItem fi = new FeedItem(ParentId = o.Id, Body = body);
            posts.add(fi);
        }
        if (!posts.isEmpty()) {
            // Best-effort: don't fail the import if Chatter is disabled or a post is rejected.
            Database.insert(posts, false);
        }
    }

    /**
     * Email the Finance Person (Martin) — and anyone else listed in the
     * Custom Setting — a digest of orphan Opportunities created on this
     * page. Off unless OrphanNotificationsEnabled is true AND
     * OrphanNotifyEmails is non-blank. Send failures are swallowed: the
     * orphan Opps and Chatter post are the safety net.
     */
    @TestVisible private static String lastEmailOutcome;

    @TestVisible
    private static void sendOrphanDigestEmail(List<Opportunity> opps, Map<String, XeroBankTransaction> txnsByBankTxnId) {
        // SOQL (not getOrgDefaults) so we always see the current values — the
        // Custom Setting cache otherwise holds the @TestSetup snapshot across
        // mid-transaction updates in test contexts.
        List<ULBC_Xero_Settings__c> rows = [
            SELECT OrphanNotificationsEnabled__c, OrphanNotifyEmails__c
            FROM ULBC_Xero_Settings__c
            WHERE SetupOwnerId = :UserInfo.getOrganizationId()
            LIMIT 1
        ];
        if (rows.isEmpty()) { lastEmailOutcome = 'no-settings-row'; return; }
        ULBC_Xero_Settings__c s = rows[0];
        if (s.OrphanNotificationsEnabled__c != true) { lastEmailOutcome = 'disabled (' + s.OrphanNotificationsEnabled__c + ')'; return; }
        if (String.isBlank(s.OrphanNotifyEmails__c)) { lastEmailOutcome = 'blank-recipients'; return; }

        List<Opportunity> orphans = new List<Opportunity>();
        for (Opportunity o : opps) {
            if (o.npe01__Contact_Id_for_Role__c == null) orphans.add(o);
        }
        if (orphans.isEmpty()) { lastEmailOutcome = 'no-orphans'; return; }

        List<String> recipients = new List<String>();
        for (String raw : s.OrphanNotifyEmails__c.split('[,;\\s]+')) {
            String trimmed = raw.trim();
            if (String.isNotBlank(trimmed)) recipients.add(trimmed);
        }
        if (recipients.isEmpty()) { lastEmailOutcome = 'no-parsed-recipients'; return; }

        String orgUrl = '';
        try { orgUrl = URL.getOrgDomainUrl().toExternalForm(); }
        catch (Exception e) { orgUrl = ''; }

        Integer n = orphans.size();
        String subject = 'Xero import: ' + n + ' orphan donation' + (n == 1 ? '' : 's') + ' need a Contact';

        String body = 'The Xero daily import created the following Opportunities with no matching Trust ID. ';
        body += 'Open each one in Salesforce and set the Primary Contact:\n\n';
        for (Opportunity o : orphans) {
            body += '* ' + o.Name + '\n';
            if (String.isNotBlank(orgUrl)) body += '  ' + orgUrl + '/' + o.Id + '\n';
            XeroBankTransaction t = (txnsByBankTxnId != null) ? txnsByBankTxnId.get(o.ULBC_Xero_Transaction_ID__c) : null;
            if (t != null) {
                String donorLine = '  Xero Contact: ' + (String.isNotBlank(t.contactName) ? t.contactName : '(unnamed)');
                if (String.isNotBlank(t.contactAccountNumber)) donorLine += ' (AccountNumber ' + t.contactAccountNumber + ')';
                body += donorLine + '\n';
                if (String.isNotBlank(t.contactEmail)) body += '  Email: ' + t.contactEmail + '\n';
            }
            body += '\n';
        }
        body += 'If you don\'t recognise the donor, leave the Opportunity unassigned and add a Chatter comment for the fundraiser to investigate.\n';

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipients);
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setSaveAsActivity(false);

        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            lastEmailOutcome = 'sent (' + recipients.size() + ' recipients, ' + n + ' orphans)';
        } catch (Exception e) {
            lastEmailOutcome = 'send-failed: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'Orphan digest email failed: ' + e.getMessage());
        }
    }

    private static void writeSyncLog(PageResult r, DateTime runStarted) {
        ULBC_Xero_Sync_Log__c log = new ULBC_Xero_Sync_Log__c(
            ULBC_Run_Started__c = runStarted,
            ULBC_Run_Finished__c = System.now(),
            ULBC_Status__c = r.status,
            ULBC_Transactions_Read__c = r.transactionsRead,
            ULBC_Opportunities_Created__c = r.opportunitiesCreated,
            ULBC_Orphans_Created__c = r.orphansCreated,
            ULBC_Skipped_Duplicates__c = r.skippedDuplicates,
            ULBC_Deferred_No_AccountNumber__c = r.deferredNoAccountNumber,
            ULBC_Error_Message__c = r.errorMessage,
            ULBC_Watermark_Before__c = r.watermarkBefore,
            ULBC_Watermark_After__c = r.watermarkAfter,
            ULBC_Page_Number__c = r.pageNumber
        );
        insert log;
    }
}