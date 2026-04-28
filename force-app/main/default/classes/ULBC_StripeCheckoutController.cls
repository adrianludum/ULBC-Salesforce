/**
 * ULBC_StripeCheckoutController
 *
 * Public-facing entry point for the donate page (ulbcDonate LWC) and the
 * event registration page (ulbcEventRegister LWC). Each @AuraEnabled
 * method validates inputs, looks up the relevant Campaign, builds a
 * Stripe Checkout Session via HTTP callout to the Stripe_API named
 * credential, and returns the Stripe-hosted Checkout URL for the LWC
 * to redirect to.
 *
 * The metadata sent on each Checkout Session must match the contract in
 * Decision 5.9 (amended 2026-04-27 — `ulbc_trust_id` not `trust_id`):
 *   donation:    intent, fund?, ulbc_trust_id?, gift_aid, gift_aid_postcode?, gift_type
 *   event_ticket: intent, campaign_id, ulbc_trust_id?
 *
 * Phase 5A.4.
 */
public with sharing class ULBC_StripeCheckoutController {

    @TestVisible
    private static final Decimal MIN_DONATION_GBP = 1.00;

    @TestVisible
    private static final String NAMED_CREDENTIAL = 'callout:Stripe_API';

    public class CheckoutException extends Exception {}

    // ── Donation ─────────────────────────────────────────────────────

    @AuraEnabled
    public static String createDonationSession(
        Decimal amount,
        Id fund,
        String ulbcTrustId,
        Boolean giftAid,
        String giftAidPostcode,
        String giftType
    ) {
        try {
            if (amount == null || amount < MIN_DONATION_GBP) {
                throw new CheckoutException('Minimum donation is £' + MIN_DONATION_GBP + '.');
            }
            Boolean ga = (giftAid == true);
            if (ga && String.isBlank(giftAidPostcode)) {
                throw new CheckoutException('Postcode is required to claim Gift Aid.');
            }

            // Resolve fund Campaign (optional in v1 per Decision 5.19;
            // when supplied it must exist and be visible to the running user).
            Id fundId = null;
            if (fund != null) {
                List<Campaign> camps = [SELECT Id FROM Campaign WHERE Id = :fund LIMIT 1];
                if (camps.isEmpty()) {
                    throw new CheckoutException('The selected fund could not be found.');
                }
                fundId = camps[0].Id;
            }

            Map<String, String> meta = new Map<String, String>{
                'intent' => 'donation',
                'gift_aid' => ga ? 'true' : 'false',
                'gift_type' => normaliseGiftType(giftType)
            };
            if (fundId != null) meta.put('fund', String.valueOf(fundId));
            if (String.isNotBlank(ulbcTrustId)) meta.put('ulbc_trust_id', ulbcTrustId);
            if (ga && String.isNotBlank(giftAidPostcode)) meta.put('gift_aid_postcode', giftAidPostcode);

            String donateBase = getDonateBaseUrl();
            String body = buildFormBody(
                Math.round(amount * 100),
                1,
                'ULBC Trust Donation',
                donateBase + '?status=success&session_id={CHECKOUT_SESSION_ID}',
                donateBase + '?status=cancelled',
                meta
            );

            return postCheckoutSession(body);
        } catch (CheckoutException ce) {
            throw makeAuraError(ce.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'createDonationSession failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw makeAuraError('Could not start payment: ' + e.getMessage());
        }
    }

    // ── Event ticket ─────────────────────────────────────────────────

    @AuraEnabled
    public static String createEventSession(
        Id campaignId,
        Integer qty,
        String ulbcTrustId
    ) {
        try {
            if (campaignId == null) {
                throw new CheckoutException('A campaign Id is required.');
            }
            if (qty == null || qty < 1) {
                throw new CheckoutException('Quantity must be at least 1.');
            }

            List<Campaign> camps = [
                SELECT Id, Name, ULBC_Ticket_Price__c
                FROM Campaign WHERE Id = :campaignId LIMIT 1
            ];
            if (camps.isEmpty()) {
                throw new CheckoutException('The event could not be found.');
            }
            Campaign camp = camps[0];
            if (camp.ULBC_Ticket_Price__c == null || camp.ULBC_Ticket_Price__c <= 0) {
                throw new CheckoutException('This event does not have a ticket price configured.');
            }

            Map<String, String> meta = new Map<String, String>{
                'intent' => 'event_ticket',
                'campaign_id' => String.valueOf(camp.Id)
            };
            if (String.isNotBlank(ulbcTrustId)) meta.put('ulbc_trust_id', ulbcTrustId);

            String eventsBase = getEventsBaseUrl();
            String body = buildFormBody(
                Math.round(camp.ULBC_Ticket_Price__c * 100),
                qty,
                camp.Name + ' — Ticket',
                eventsBase + '?id=' + camp.Id + '&status=success&session_id={CHECKOUT_SESSION_ID}',
                eventsBase + '?id=' + camp.Id + '&status=cancelled',
                meta
            );

            return postCheckoutSession(body);
        } catch (CheckoutException ce) {
            throw makeAuraError(ce.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'createEventSession failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw makeAuraError('Could not start payment: ' + e.getMessage());
        }
    }

    // ── Event info (for the LWC to render the page header) ───────────

    public class EventInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Datetime startTime;
        @AuraEnabled public Datetime endTime;
        @AuraEnabled public String venue;
        @AuraEnabled public Decimal ticketPrice;
        @AuraEnabled public String dressCode;
        @AuraEnabled public String menu;
        @AuraEnabled public String transportInfo;
    }

    @AuraEnabled(cacheable=true)
    public static EventInfo getEventInfo(Id campaignId) {
        if (campaignId == null) {
            throw makeAuraError('A campaign Id is required.');
        }
        List<Campaign> camps = [
            SELECT Id, Name, StartDate, EndDate,
                   ULBC_Start_Time__c, ULBC_End_Time__c, ULBC_Venue__c,
                   ULBC_Ticket_Price__c, ULBC_Dress_Code__c, ULBC_Menu__c, ULBC_Transport_Info__c
            FROM Campaign WHERE Id = :campaignId LIMIT 1
        ];
        if (camps.isEmpty()) {
            throw makeAuraError('Event not found.');
        }
        Campaign c = camps[0];
        EventInfo info = new EventInfo();
        info.id = c.Id;
        info.name = c.Name;
        info.startTime = composeDatetime(c.StartDate, c.ULBC_Start_Time__c);
        info.endTime = composeDatetime(c.EndDate, c.ULBC_End_Time__c);
        info.venue = c.ULBC_Venue__c;
        info.ticketPrice = c.ULBC_Ticket_Price__c;
        info.dressCode = c.ULBC_Dress_Code__c;
        info.menu = c.ULBC_Menu__c;
        info.transportInfo = c.ULBC_Transport_Info__c;
        return info;
    }

    private static Datetime composeDatetime(Date d, Time t) {
        if (d == null) return null;
        Time timeOfDay = (t == null) ? Time.newInstance(0, 0, 0, 0) : t;
        return Datetime.newInstance(d, timeOfDay);
    }

    // ── HTTP and helpers ─────────────────────────────────────────────

    @TestVisible
    private static String buildFormBody(
        Long unitAmountPence,
        Integer quantity,
        String productName,
        String successUrl,
        String cancelUrl,
        Map<String, String> metadata
    ) {
        List<String> parts = new List<String>{
            'mode=payment',
            'payment_method_types[]=card',
            'line_items[0][price_data][currency]=gbp',
            'line_items[0][price_data][unit_amount]=' + unitAmountPence,
            'line_items[0][price_data][product_data][name]=' + enc(productName),
            'line_items[0][quantity]=' + quantity,
            'success_url=' + enc(successUrl),
            'cancel_url=' + enc(cancelUrl)
        };
        // Sort metadata keys for deterministic body output (helps tests).
        List<String> mKeys = new List<String>(metadata.keySet());
        mKeys.sort();
        for (String k : mKeys) {
            parts.add('metadata[' + enc(k) + ']=' + enc(metadata.get(k)));
        }
        return String.join(parts, '&');
    }

    @TestVisible
    private static String postCheckoutSession(String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/v1/checkout/sessions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        Integer code = res.getStatusCode();
        if (code < 200 || code >= 300) {
            throw new CheckoutException(parseStripeError(res));
        }
        Map<String, Object> session = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object url = session.get('url');
        if (url == null) {
            throw new CheckoutException('Stripe response did not include a checkout URL.');
        }
        return (String) url;
    }

    private static String parseStripeError(HttpResponse res) {
        try {
            Map<String, Object> err = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (err.containsKey('error')) {
                Map<String, Object> errBody = (Map<String, Object>) err.get('error');
                if (errBody.containsKey('message')) {
                    return (String) errBody.get('message');
                }
            }
        } catch (Exception ignore) {
            // Fall through to generic message.
        }
        return 'Stripe returned HTTP ' + res.getStatusCode();
    }

    private static String enc(String s) {
        return (s == null) ? '' : EncodingUtil.urlEncode(s, 'UTF-8');
    }

    @TestVisible
    private static String getDonateBaseUrl() {
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        if (s == null || String.isBlank(s.DonationBaseURL__c)) {
            throw new CheckoutException('Donate page URL is not configured.');
        }
        return s.DonationBaseURL__c;
    }

    @TestVisible
    private static String getEventsBaseUrl() {
        ULBC_Stripe_Settings__c s = ULBC_Stripe_Settings__c.getOrgDefaults();
        if (s == null || String.isBlank(s.EventsBaseURL__c)) {
            throw new CheckoutException('Events page URL is not configured.');
        }
        return s.EventsBaseURL__c;
    }

    private static String normaliseGiftType(String requested) {
        return 'Recurring'.equalsIgnoreCase(requested) ? 'Recurring' : 'One-Off';
    }

    private static AuraHandledException makeAuraError(String message) {
        AuraHandledException ahe = new AuraHandledException(message);
        ahe.setMessage(message);
        return ahe;
    }
}
