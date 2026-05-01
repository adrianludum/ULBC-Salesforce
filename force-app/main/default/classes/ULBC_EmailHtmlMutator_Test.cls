/**
 * ULBC_EmailHtmlMutator_Test
 *
 * Pure-function tests for link rewriting, pixel injection, footer
 * substitution, and skip rules. No DML, no SOQL.
 */
@IsTest
private class ULBC_EmailHtmlMutator_Test {

    private static final String TOKEN = 'abc-token-1234567890_AB';
    private static final String BASE = 'https://ulbc.example/donate';
    private static final String FOOTER =
        '<p>ULBC Trust, Reg. Charity 123456. <a href="{{UNSUB_URL}}">Unsubscribe</a>.</p>';

    // ── Link rewriting ──────────────────────────────────────────────────

    @IsTest
    static void test_inject_rewritesHttpLink() {
        String html = '<html><body>Hello <a href="https://example.com/page">click</a></body></html>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(out.contains('/services/apexrest/email/click?t=' + TOKEN),
            'Click endpoint with token should appear: ' + out);
        System.assert(out.contains(EncodingUtil.urlEncode('https://example.com/page', 'UTF-8')),
            'Original URL should appear URL-encoded: ' + out);
        System.assert(!out.contains('href="https://example.com/page"'),
            'Original href should be replaced: ' + out);
    }

    @IsTest
    static void test_inject_rewritesHttpsLink() {
        String html = '<a href="https://example.com">x</a>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(out.contains('/services/apexrest/email/click'),
            'Should rewrite https links');
    }

    @IsTest
    static void test_inject_skipsMailtoLink() {
        String html = '<body><a href="mailto:donate@ulbc.example">email us</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(out.contains('href="mailto:donate@ulbc.example"'),
            'mailto: links must be left untouched');
    }

    @IsTest
    static void test_inject_skipsTelLink() {
        String html = '<body><a href="tel:+441234567890">call</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(out.contains('href="tel:+441234567890"'));
    }

    @IsTest
    static void test_inject_skipsAlreadyTrackedLink() {
        String html = '<body><a href="' + BASE + '/services/apexrest/email/click?t=other">x</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        // Token in the link should be the original "other", not our TOKEN.
        Integer countOurToken = countSubstr(out, '?t=' + TOKEN);
        System.assertEquals(1, countOurToken,
            'Only the pixel should reference our token, not a re-wrapped already-tracked link');
    }

    @IsTest
    static void test_inject_skipsUnsubscribeLink() {
        String html = '<body><a href="https://other.example/unsubscribe?u=x">opt out</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(out.contains('href="https://other.example/unsubscribe?u=x"'),
            'Links containing "unsubscribe" must be left untouched');
    }

    @IsTest
    static void test_inject_preservesOtherAnchorAttributes() {
        String html = '<a class="btn" href="https://example.com" target="_blank" rel="noopener">click</a>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(out.contains('class="btn"'), 'class attr preserved');
        System.assert(out.contains('target="_blank"'), 'target attr preserved');
        System.assert(out.contains('rel="noopener"'), 'rel attr preserved');
        System.assert(out.contains('/services/apexrest/email/click'), 'href rewritten');
    }

    @IsTest
    static void test_inject_doesNotDoubleEncodeUrl() {
        String original = 'https://example.com/page?q=hello%20world';
        String html = '<a href="' + original + '">x</a>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        // Once-encoded original should appear in the u= parameter.
        String onceEncoded = EncodingUtil.urlEncode(original, 'UTF-8');
        System.assert(out.contains('u=' + onceEncoded),
            'URL should be encoded exactly once: ' + out);
    }

    @IsTest
    static void test_inject_disabledTracking_leavesLinksAlone() {
        String html = '<body><a href="https://example.com">x</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, false);
        System.assert(out.contains('href="https://example.com"'),
            'When tracking disabled, links must not be rewritten');
        System.assert(!out.contains('email/open'),
            'When tracking disabled, pixel must not be injected');
    }

    // ── Pixel injection ─────────────────────────────────────────────────

    @IsTest
    static void test_inject_appendsPixelBeforeBodyClose() {
        String html = '<html><body>hi</body></html>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        Integer pixelIdx = out.indexOf('email/open?t=');
        Integer bodyIdx = out.indexOf('</body>');
        System.assert(pixelIdx > 0 && bodyIdx > 0, 'Both pixel and </body> present');
        System.assert(pixelIdx < bodyIdx, 'Pixel must precede </body>');
    }

    @IsTest
    static void test_inject_handlesHtmlWithNoBodyTag() {
        String html = '<p>hello</p>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(out.startsWith('<p>hello</p>'), 'Original content first');
        System.assert(out.contains('email/open?t='), 'Pixel still appended at end');
    }

    @IsTest
    static void test_inject_pixelTokenIsUrlEncoded() {
        String tokenWithSlash = 'abc/def+ghi';
        String html = '<body>x</body>';
        String out = ULBC_EmailHtmlMutator.inject(html, tokenWithSlash, BASE, null, true);
        // Tokens generated by ULBC_EmailTokenService never contain / or +,
        // but the mutator should still URL-encode defensively.
        System.assert(out.contains('email/open?t=' + EncodingUtil.urlEncode(tokenWithSlash, 'UTF-8')),
            'Token in pixel URL must be URL-encoded');
    }

    // ── Footer ─────────────────────────────────────────────────────────

    @IsTest
    static void test_inject_appendsFooterAndReplacesUnsubPlaceholder() {
        String html = '<html><body>content</body></html>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, FOOTER, true);
        System.assert(out.contains('Reg. Charity 123456'), 'Footer copy present');
        System.assert(out.contains(BASE + '/services/apexrest/email/unsub?t=' + TOKEN),
            'Unsub placeholder replaced with personalised URL');
        System.assert(!out.contains('{{UNSUB_URL}}'), 'Placeholder must not survive');
    }

    @IsTest
    static void test_inject_nullFooter_skipsFooter() {
        String html = '<body>x</body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, null, true);
        System.assert(!out.contains('Reg. Charity'), 'Null footer means no footer content');
        System.assert(!out.contains('email/unsub'), 'Null footer means no unsub link');
    }

    @IsTest
    static void test_inject_blankInputs_returnUnchanged() {
        System.assertEquals(null, ULBC_EmailHtmlMutator.inject(null, TOKEN, BASE, FOOTER, true));
        System.assertEquals('', ULBC_EmailHtmlMutator.inject('', TOKEN, BASE, FOOTER, true));
        String html = '<p>x</p>';
        System.assertEquals(html, ULBC_EmailHtmlMutator.inject(html, null, BASE, FOOTER, true),
            'Blank token short-circuits');
        System.assertEquals(html, ULBC_EmailHtmlMutator.inject(html, TOKEN, null, FOOTER, true),
            'Blank baseUrl short-circuits');
    }

    // ── Helpers ────────────────────────────────────────────────────────

    private static Integer countSubstr(String haystack, String needle) {
        Integer count = 0;
        Integer idx = 0;
        while ((idx = haystack.indexOf(needle, idx)) != -1) {
            count++;
            idx += needle.length();
        }
        return count;
    }
}
