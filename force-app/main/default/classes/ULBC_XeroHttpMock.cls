/**
 * ULBC_XeroHttpMock
 *
 * Phase 6A — HttpCalloutMock for unit-testing ULBC_XeroIncomeImporter
 * without hitting a real Xero org. Tests configure the desired status
 * code and JSON body before calling the importer.
 */
@IsTest
public class ULBC_XeroHttpMock implements HttpCalloutMock {

    public Integer statusCode = 200;
    public String body = '{"BankTransactions":[]}';
    // Body returned for the /Contacts?IDs=... enrichment lookup. Tests that
    // care about AccountNumber set this; tests that don't care leave the
    // default (empty Contacts array, so enrichment finds nothing and
    // contactAccountNumber stays as it was on the BankTransaction summary).
    public String contactsBody = '{"Contacts":[]}';
    public Integer contactsStatusCode = 200;
    public String capturedEndpoint;
    public String capturedIfModifiedSince;
    public String capturedContactsEndpoint;

    public HttpResponse respond(HttpRequest req) {
        String endpoint = req.getEndpoint();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        if (endpoint != null && endpoint.contains('/api.xro/2.0/Contacts')) {
            this.capturedContactsEndpoint = endpoint;
            res.setStatusCode(this.contactsStatusCode);
            res.setBody(this.contactsBody);
            return res;
        }

        // Default: BankTransactions branch
        this.capturedEndpoint = endpoint;
        this.capturedIfModifiedSince = req.getHeader('If-Modified-Since');
        res.setStatusCode(this.statusCode);
        res.setBody(this.body);
        return res;
    }

    /**
     * Build a Xero /Contacts response containing the given (ContactID, AccountNumber)
     * pairs. Used by tests that exercise the enrichment path.
     */
    public static String buildContactsResponse(Map<String, String> accountNumbersByContactId) {
        List<Map<String, Object>> contacts = new List<Map<String, Object>>();
        for (String cid : accountNumbersByContactId.keySet()) {
            contacts.add(new Map<String, Object>{
                'ContactID' => cid,
                'AccountNumber' => accountNumbersByContactId.get(cid),
                'Name' => 'Mock Contact ' + cid
            });
        }
        return JSON.serialize(new Map<String, Object>{ 'Contacts' => contacts });
    }

    /**
     * Build a Xero BankTransaction-shaped JSON object for fixture use.
     * AccountNumber may be null to simulate a Xero Contact with no
     * Trust ID set.
     */
    public static String buildResponse(List<Map<String, Object>> txns) {
        Map<String, Object> root = new Map<String, Object>{ 'BankTransactions' => txns };
        return JSON.serialize(root);
    }

    public static Map<String, Object> txn(String id, Decimal amount, DateTime txnTime,
                                          String contactName, String accountNumber,
                                          String email) {
        Map<String, Object> contact = new Map<String, Object>{
            'ContactID' => 'xero-contact-' + id,
            'Name' => contactName,
            'EmailAddress' => email
        };
        if (accountNumber != null) {
            contact.put('AccountNumber', accountNumber);
        }
        Long ms = txnTime.getTime();
        return new Map<String, Object>{
            'BankTransactionID' => id,
            'Type' => 'RECEIVE',
            'Status' => 'AUTHORISED',
            'Date' => '/Date(' + ms + '+0000)/',
            'UpdatedDateUTC' => '/Date(' + ms + '+0000)/',
            'Total' => amount,
            'Reference' => 'Donation',
            'Contact' => contact
        };
    }
}