/**
 * ULBC_EmailHtmlMutator
 *
 * Stateless rendering of an EmailTemplate's resolved HTML into the
 * "send-ready" form: links rewritten to go through the click-tracking
 * endpoint, a 1×1 open-tracking pixel injected, and a compliance footer
 * (with personalised unsubscribe URL) appended.
 *
 * Pure functions — no SOQL, no DML, no system state. All inputs supplied
 * by the caller.
 *
 * Regex-based link rewriting is intentionally simple. Real-world template
 * HTML produced by Salesforce's renderer is well-formed enough that a
 * single href-extraction pattern handles ~all cases. When it does not
 * match a link, the link is left untracked (open tracking still works);
 * the send is never aborted because of an unparseable link.
 *
 * Skip rules (links left untouched):
 *   - href starts with the tracking base URL (already tracked)
 *   - href contains "unsubscribe" (handled separately by footer template)
 *   - href starts with mailto:, tel:, or #
 */
public with sharing class ULBC_EmailHtmlMutator {

    /** Captures: group(1)=attrs before href, group(2)=URL, group(3)=attrs after. */
    @TestVisible
    private static final Pattern A_HREF = Pattern.compile(
        '(?i)<a\\b([^>]*?)href\\s*=\\s*"(https?://[^"]+)"([^>]*)>'
    );

    private static final Pattern BODY_CLOSE = Pattern.compile('(?i)</body\\s*>');

    /** Substituted with the recipient's personalised unsubscribe URL at append time. */
    @TestVisible
    private static final String UNSUB_PLACEHOLDER = '{{UNSUB_URL}}';

    /**
     * Compliance footer (UK GDPR / PECR + UK Charity Commission). Hardcoded
     * because Custom Settings don't support LongTextArea, and at ~700 chars
     * the footer doesn't fit a 255-char Text field. To update the wording,
     * change here and redeploy. Move to a Static Resource if frequent edits
     * by non-developers become a need.
     */
    private static final String FOOTER_HTML =
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"' +
        ' style="margin-top:32px;border-top:1px solid #e0e0e0;padding-top:16px;">' +
        '<tr><td style="font-family:Arial,Helvetica,sans-serif;font-size:12px;' +
        'line-height:1.5;color:#666;text-align:center;">' +
        '<p style="margin:0 0 8px 0;">' +
        'You\'re receiving this email because you\'re an alumnus of ULBC.' +
        '</p><p style="margin:0 0 8px 0;">' +
        'ULBC Trust Limited is a registered charity in England and Wales (no.&nbsp;1174721).<br />' +
        'Registered office: University of London Boathouse, 81 Hartington Road, London W4&nbsp;3TU.' +
        '</p><p style="margin:0;">' +
        '<a href="{{UNSUB_URL}}" style="color:#666;text-decoration:underline;">Unsubscribe</a>' +
        '</p></td></tr></table>';

    /**
     * Inject tracking into the rendered HTML for one recipient.
     *
     * @param html       rendered HTML from Messaging.renderStoredEmailTemplate
     * @param token      ULBC_Email_Send_Recipient__c.ULBC_Token__c
     * @param baseUrl    Public Site origin without trailing slash, e.g. https://x.my.salesforce-sites.com/donate
     * @param trackingEnabled when false, links are not rewritten and pixel is not injected (kill switch).
     *                        The footer + unsub link are appended either way (UK GDPR/PECR).
     */
    public static String inject(String html, String token, String baseUrl,
                                 Boolean trackingEnabled) {
        if (String.isBlank(html)) return html;
        if (String.isBlank(token) || String.isBlank(baseUrl)) return html;

        String working = html;

        if (trackingEnabled) {
            working = rewriteLinks(working, token, baseUrl);
        }

        working = appendFooter(working, token, baseUrl);

        if (trackingEnabled) {
            working = injectPixel(working, token, baseUrl);
        }

        return working;
    }

    // ── Link rewriting ──────────────────────────────────────────────────

    @TestVisible
    private static String rewriteLinks(String html, String token, String baseUrl) {
        Matcher m = A_HREF.matcher(html);
        List<String> parts = new List<String>();
        Integer last = 0;
        while (m.find()) {
            parts.add(html.substring(last, m.start()));
            String preAttrs = m.group(1);
            String url = m.group(2);
            String postAttrs = m.group(3);

            if (shouldSkipUrl(url, baseUrl)) {
                parts.add(m.group());
            } else {
                String tracked = clickUrl(baseUrl, token, url);
                parts.add('<a' + preAttrs + 'href="' + tracked + '"' + postAttrs + '>');
            }
            last = m.end();
        }
        parts.add(html.substring(last));
        return String.join(parts, '');
    }

    @TestVisible
    private static Boolean shouldSkipUrl(String url, String baseUrl) {
        if (String.isBlank(url)) return true;
        String lower = url.toLowerCase();
        if (lower.startsWith('mailto:')) return true;
        if (lower.startsWith('tel:')) return true;
        if (lower.startsWith('#')) return true;
        if (lower.contains('unsubscribe')) return true;
        if (String.isNotBlank(baseUrl) && lower.startsWith(baseUrl.toLowerCase())) return true;
        return false;
    }

    @TestVisible
    private static String clickUrl(String baseUrl, String token, String url) {
        return baseUrl
            + '/services/apexrest/email/click?t='
            + EncodingUtil.urlEncode(token, 'UTF-8')
            + '&u='
            + EncodingUtil.urlEncode(url, 'UTF-8');
    }

    // ── Pixel injection ─────────────────────────────────────────────────

    @TestVisible
    private static String injectPixel(String html, String token, String baseUrl) {
        String pixel = '<img src="'
            + baseUrl + '/services/apexrest/email/open?t=' + EncodingUtil.urlEncode(token, 'UTF-8')
            + '" width="1" height="1" alt="" style="display:block;border:0;" />';

        Matcher m = BODY_CLOSE.matcher(html);
        if (m.find()) {
            return html.substring(0, m.start()) + pixel + html.substring(m.start());
        }
        return html + pixel;
    }

    // ── Footer ─────────────────────────────────────────────────────────

    @TestVisible
    private static String appendFooter(String html, String token, String baseUrl) {
        String unsubUrl = baseUrl
            + '/services/apexrest/email/unsub?t='
            + EncodingUtil.urlEncode(token, 'UTF-8');
        String resolved = FOOTER_HTML.replace(UNSUB_PLACEHOLDER, unsubUrl);

        Matcher m = BODY_CLOSE.matcher(html);
        if (m.find()) {
            return html.substring(0, m.start()) + resolved + html.substring(m.start());
        }
        return html + resolved;
    }
}
