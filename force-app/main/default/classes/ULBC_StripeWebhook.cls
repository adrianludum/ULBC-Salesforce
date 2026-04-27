/**
 * ULBC_StripeWebhook
 * REST endpoint for Stripe checkout.session.completed webhooks.
 * Creates or finds Contacts for buyer + guests, adds CampaignMembers,
 * and creates a Closed Won Opportunity for the ticket purchase.
 *
 * Guest metadata format: guest_1_name, guest_1_email, guest_2_name, guest_2_email, etc.
 *
 * Endpoint: /services/apexrest/stripe/webhook
 */
@RestResource(urlMapping='/stripe/webhook')
global with sharing class ULBC_StripeWebhook {

    global class WebhookResult {
        global Boolean success;
        global String message;
        global String contactId;
        global String opportunityId;
        global Integer guestsRegistered;
    }

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        WebhookResult result = new WebhookResult();
        result.guestsRegistered = 0;

        try {
            String body = req.requestBody.toString();
            Map<String, Object> event = (Map<String, Object>) JSON.deserializeUntyped(body);

            String eventType = (String) event.get('type');

            if (eventType != 'checkout.session.completed') {
                result.success = true;
                result.message = 'Event type ' + eventType + ' ignored';
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(result));
                return;
            }

            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> session = (Map<String, Object>) data.get('object');

            // Extract customer details
            Map<String, Object> customerDetails = (Map<String, Object>) session.get('customer_details');
            String email = (String) customerDetails.get('email');
            String fullName = (String) customerDetails.get('name');

            // Extract payment details
            Integer amountTotal = (Integer) session.get('amount_total');
            Decimal amount = (amountTotal != null) ? Decimal.valueOf(amountTotal) / 100 : 0;
            String currencyCode = (String) session.get('currency');
            String paymentIntentId = (String) session.get('payment_intent');
            String sessionId = (String) session.get('id');

            // Extract metadata
            Map<String, Object> metadata = (Map<String, Object>) session.get('metadata');
            String campaignId = (metadata != null) ? (String) metadata.get('campaign_id') : null;
            String ticketQty = (metadata != null) ? (String) metadata.get('quantity') : '1';
            Integer qty = (ticketQty != null) ? Integer.valueOf(ticketQty) : 1;

            if (String.isBlank(email)) {
                result.success = false;
                result.message = 'No email in checkout session';
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(result));
                return;
            }

            // Parse buyer name
            String firstName = '';
            String lastName = fullName;
            if (String.isNotBlank(fullName) && fullName.contains(' ')) {
                Integer spaceIdx = fullName.lastIndexOf(' ');
                firstName = fullName.substring(0, spaceIdx).trim();
                lastName = fullName.substring(spaceIdx + 1).trim();
            }

            // Find or create buyer Contact
            Contact contact = findOrCreateContact(email, firstName, lastName, 'Event');
            result.contactId = contact.Id;

            // Create Opportunity (ticket purchase)
            Opportunity opp = new Opportunity(
                AccountId = contact.AccountId,
                npsp__Primary_Contact__c = contact.Id,
                Name = fullName + ' — Event Ticket',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                Amount = amount,
                ULBC_Gift_Type__c = 'Event Ticket',
                ULBC_Gift_Source__c = 'Online',
                ULBC_Stripe_Payment_ID__c = paymentIntentId,
                Description = 'Stripe Session: ' + sessionId +
                              ' | Qty: ' + qty +
                              ' | Currency: ' + (currencyCode != null ? currencyCode.toUpperCase() : 'GBP')
            );
            insert opp;
            result.opportunityId = opp.Id;

            // Add buyer as CampaignMember
            if (String.isNotBlank(campaignId)) {
                ensureCampaignMemberStatus(campaignId);
                addCampaignMember(contact.Id, campaignId, 'Purchased');

                // Process guests from metadata
                if (metadata != null) {
                    result.guestsRegistered = processGuests(metadata, campaignId);
                }
            }

            // Send notification emails
            try {
                if (String.isNotBlank(campaignId)) {
                    String campaignName = [SELECT Name FROM Campaign WHERE Id = :campaignId LIMIT 1].Name;
                    List<Contact> guestContacts = getGuestContacts(metadata);

                    // Email buyer with confirmation + guest list
                    if (String.isNotBlank(email)) {
                        sendBuyerConfirmation(contact, campaignName, guestContacts, qty);
                    }

                    // Email each guest who has an email
                    for (Contact g : guestContacts) {
                        if (String.isNotBlank(g.Email)) {
                            sendGuestTicket(g, contact, campaignName);
                        }
                    }

                    flushEmails();
                }
            } catch (Exception emailErr) {
                System.debug(LoggingLevel.ERROR, 'Email notification failed: ' + emailErr.getMessage());
            }

            result.success = true;
            result.message = 'Ticket purchase recorded — ' + qty + ' ticket(s), ' +
                             result.guestsRegistered + ' guest(s) registered';
            res.statusCode = 200;

        } catch (Exception e) {
            result.success = false;
            result.message = e.getMessage();
            res.statusCode = 500;
        }

        res.responseBody = Blob.valueOf(JSON.serialize(result));
    }

    private static Integer processGuests(Map<String, Object> metadata, String campaignId) {
        Integer guestCount = 0;

        for (Integer i = 1; i <= 9; i++) {
            String guestName = (String) metadata.get('guest_' + i + '_name');
            String guestEmail = (String) metadata.get('guest_' + i + '_email');

            if (String.isBlank(guestName) && String.isBlank(guestEmail)) {
                break;
            }

            // Parse guest name
            String gFirstName = '';
            String gLastName = guestName;
            if (String.isNotBlank(guestName) && guestName.contains(' ')) {
                Integer spaceIdx = guestName.lastIndexOf(' ');
                gFirstName = guestName.substring(0, spaceIdx).trim();
                gLastName = guestName.substring(spaceIdx + 1).trim();
            }

            // Find or create guest Contact
            Contact guest;
            if (String.isNotBlank(guestEmail)) {
                guest = findOrCreateContact(guestEmail, gFirstName, gLastName, 'Event Guest');
            } else if (String.isNotBlank(guestName)) {
                // No email — create Contact with name only
                guest = createGuestContact(gFirstName, gLastName);
            } else {
                continue;
            }

            addCampaignMember(guest.Id, campaignId, 'Registered');
            guestCount++;
        }

        return guestCount;
    }

    private static Contact findOrCreateContact(String email, String firstName, String lastName, String channel) {
        List<Contact> existing = [
            SELECT Id, AccountId, FirstName, LastName
            FROM Contact
            WHERE Email = :email
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        Contact c = new Contact(
            FirstName = firstName,
            LastName = String.isBlank(lastName) ? email : lastName,
            Email = email,
            ULBC_Acquisition_Channel__c = channel,
            ULBC_GDPR_Legal_Basis__c = 'Consent'
        );
        insert c;

        return [SELECT Id, AccountId, FirstName, LastName FROM Contact WHERE Id = :c.Id];
    }

    private static Contact createGuestContact(String firstName, String lastName) {
        Contact c = new Contact(
            FirstName = firstName,
            LastName = String.isBlank(lastName) ? 'Guest' : lastName,
            ULBC_Acquisition_Channel__c = 'Event Guest',
            ULBC_GDPR_Legal_Basis__c = 'Consent'
        );
        insert c;
        return [SELECT Id, AccountId, FirstName, LastName FROM Contact WHERE Id = :c.Id];
    }

    private static void addCampaignMember(Id contactId, String campaignId, String status) {
        List<CampaignMember> existing = [
            SELECT Id FROM CampaignMember
            WHERE ContactId = :contactId AND CampaignId = :campaignId
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            insert new CampaignMember(
                CampaignId = campaignId,
                ContactId = contactId,
                Status = status
            );
        }
    }

    private static void ensureCampaignMemberStatus(String campaignId) {
        List<CampaignMemberStatus> existing = [
            SELECT Label FROM CampaignMemberStatus
            WHERE CampaignId = :campaignId AND Label IN ('Purchased', 'Registered')
        ];

        Set<String> existingLabels = new Set<String>();
        for (CampaignMemberStatus s : existing) {
            existingLabels.add(s.Label);
        }

        List<CampaignMemberStatus> toInsert = new List<CampaignMemberStatus>();
        if (!existingLabels.contains('Purchased')) {
            toInsert.add(new CampaignMemberStatus(
                CampaignId = campaignId, Label = 'Purchased',
                SortOrder = 4, IsDefault = false, HasResponded = true
            ));
        }
        if (!existingLabels.contains('Registered')) {
            toInsert.add(new CampaignMemberStatus(
                CampaignId = campaignId, Label = 'Registered',
                SortOrder = 5, IsDefault = false, HasResponded = true
            ));
        }

        if (!toInsert.isEmpty()) {
            try {
                insert toInsert;
            } catch (DmlException e) {
                // Statuses may already exist from another thread
            }
        }
    }

    // ── Email notifications ──────────────────────────────────────────

    private static List<Contact> getGuestContacts(Map<String, Object> metadata) {
        List<String> guestEmails = new List<String>();
        List<String> guestNames = new List<String>();

        for (Integer i = 1; i <= 9; i++) {
            String gName = (String) metadata.get('guest_' + i + '_name');
            String gEmail = (String) metadata.get('guest_' + i + '_email');
            if (String.isBlank(gName) && String.isBlank(gEmail)) break;
            if (String.isNotBlank(gEmail)) guestEmails.add(gEmail);
            if (String.isNotBlank(gName)) guestNames.add(gName);
        }

        if (guestEmails.isEmpty() && guestNames.isEmpty()) {
            return new List<Contact>();
        }

        List<Contact> guests = new List<Contact>();
        if (!guestEmails.isEmpty()) {
            guests = [SELECT Id, FirstName, LastName, Email
                      FROM Contact WHERE Email IN :guestEmails];
        }

        // Also find name-only guests (created moments ago)
        if (!guestNames.isEmpty()) {
            for (String fullName : guestNames) {
                String lastName = fullName;
                String firstName = '';
                if (fullName.contains(' ')) {
                    Integer idx = fullName.lastIndexOf(' ');
                    firstName = fullName.substring(0, idx).trim();
                    lastName = fullName.substring(idx + 1).trim();
                }
                // Check if already in the list by email
                Boolean found = false;
                for (Contact c : guests) {
                    if (c.FirstName == firstName && c.LastName == lastName) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    List<Contact> nameMatch = [SELECT Id, FirstName, LastName, Email
                                               FROM Contact
                                               WHERE FirstName = :firstName AND LastName = :lastName
                                               ORDER BY CreatedDate DESC LIMIT 1];
                    if (!nameMatch.isEmpty()) guests.add(nameMatch[0]);
                }
            }
        }

        return guests;
    }

    private static void sendBuyerConfirmation(Contact buyer, String eventName,
                                               List<Contact> guests, Integer qty) {
        String guestListHtml = '';
        if (!guests.isEmpty()) {
            guestListHtml = '<div style="background:#f4f1f8;border-left:4px solid #784ca8;border-radius:3px;padding:16px 20px;margin:20px 0;">' +
                '<p style="font-family:Arial,sans-serif;font-size:13px;color:#666;text-transform:uppercase;letter-spacing:1px;margin:0 0 8px;">Guests registered</p>';
            for (Contact g : guests) {
                String name = (String.isNotBlank(g.FirstName) ? g.FirstName + ' ' : '') + g.LastName;
                String emailNote = String.isNotBlank(g.Email) ? ' — ticket sent to ' + g.Email : ' — no email on file';
                guestListHtml += '<p style="font-family:Arial,sans-serif;font-size:14px;margin:4px 0;color:#040008;">' +
                    name + '<span style="color:#888;">' + emailNote + '</span></p>';
            }
            guestListHtml += '</div>';
        }

        String html = buildEmailWrapper(
            'Booking Confirmed',
            '<p style="font-size:22px;font-weight:bold;color:#040008;margin:0 0 8px;">Thank you, ' +
                String.valueOf(buyer.FirstName) + '!</p>' +
            '<p style="font-size:15px;color:#333;line-height:1.7;font-family:Arial,sans-serif;">Your ' +
                qty + ' ticket(s) for <strong>' + eventName + '</strong> have been confirmed.</p>' +
            guestListHtml +
            '<p style="font-size:14px;color:#333;line-height:1.7;font-family:Arial,sans-serif;">Your digital ticket will be sent separately. If you have any questions, please contact <a href="mailto:boathouse@ulbc.co.uk" style="color:#784ca8;">boathouse@ulbc.co.uk</a>.</p>'
        );

        sendEmail(buyer.Email, 'Booking Confirmed — ' + eventName, html);
    }

    private static void sendGuestTicket(Contact guest, Contact buyer, String eventName) {
        String buyerName = (String.isNotBlank(buyer.FirstName) ? buyer.FirstName + ' ' : '') + buyer.LastName;

        String html = buildEmailWrapper(
            'Your Ticket',
            '<p style="font-size:22px;font-weight:bold;color:#040008;margin:0 0 8px;">You\'re invited!</p>' +
            '<p style="font-size:15px;color:#333;line-height:1.7;font-family:Arial,sans-serif;">' +
                buyerName + ' has purchased a ticket for you to attend <strong>' + eventName + '</strong>.</p>' +
            '<div style="background:#f4f1f8;border-left:4px solid #784ca8;border-radius:3px;padding:16px 20px;margin:20px 0;">' +
                '<p style="font-family:Arial,sans-serif;font-size:14px;margin:0;color:#040008;">' +
                '<strong>Event:</strong> ' + eventName + '<br>' +
                '<strong>Purchased by:</strong> ' + buyerName + '</p>' +
            '</div>' +
            '<p style="font-size:14px;color:#333;line-height:1.7;font-family:Arial,sans-serif;">Your digital ticket will follow shortly. If you have any questions, contact <a href="mailto:boathouse@ulbc.co.uk" style="color:#784ca8;">boathouse@ulbc.co.uk</a>.</p>'
        );

        sendEmail(guest.Email, 'Your Ticket — ' + eventName, html);
    }

    private static String buildEmailWrapper(String bannerText, String bodyContent) {
        return '<html><head><meta charset="UTF-8"/></head><body style="margin:0;padding:0;background-color:#f4f1f8;font-family:Georgia,serif;color:#040008;">' +
            '<div style="max-width:620px;margin:40px auto;background-color:#fbfafc;border-radius:4px;overflow:hidden;box-shadow:0 2px 12px rgba(4,0,8,0.12);">' +
            '<div style="background-color:#040008;padding:36px 40px 28px;text-align:center;">' +
                '<p style="color:#fbfafc;font-size:13px;letter-spacing:3px;text-transform:uppercase;margin:0;font-family:Arial,sans-serif;">University of London Boat Club</p>' +
            '</div>' +
            '<div style="background-color:#784ca8;padding:18px 40px;text-align:center;">' +
                '<p style="margin:0;color:#fbfafc;font-size:15px;font-family:Arial,sans-serif;letter-spacing:1px;text-transform:uppercase;font-weight:bold;">' + bannerText + '</p>' +
            '</div>' +
            '<div style="padding:40px 40px 32px;">' + bodyContent + '</div>' +
            '<div style="background-color:#040008;padding:24px 40px;text-align:center;border-top:3px solid #784ca8;">' +
                '<p style="color:#888;font-family:Arial,sans-serif;font-size:12px;margin:0;line-height:1.6;">ULBC Trust — Registered Charity No. 1174721<br><a href="https://ulbc.co.uk" style="color:#784ca8;text-decoration:none;">ulbc.co.uk</a></p>' +
            '</div>' +
            '</div></body></html>';
    }

    @TestVisible
    private static List<Messaging.SingleEmailMessage> pendingEmails = new List<Messaging.SingleEmailMessage>();

    private static void sendEmail(String toAddress, String subject, String htmlBody) {
        if (String.isBlank(toAddress)) return;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toAddress });
        mail.setSubject(subject);
        mail.setHtmlBody(htmlBody);
        mail.setSaveAsActivity(false);

        pendingEmails.add(mail);
    }

    private static void flushEmails() {
        if (!pendingEmails.isEmpty()) {
            try {
                Messaging.sendEmail(pendingEmails);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Email send failed: ' + e.getMessage());
            }
            pendingEmails.clear();
        }
    }
}
