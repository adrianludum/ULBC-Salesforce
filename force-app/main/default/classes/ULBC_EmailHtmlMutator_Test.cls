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

    // ── Link rewriting ──────────────────────────────────────────────────

    @IsTest
    static void test_inject_rewritesHttpLink() {
        String html = '<html><body>Hello <a href="https://example.com/page">click</a></body></html>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
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
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        System.assert(out.contains('/services/apexrest/email/click'),
            'Should rewrite https links');
    }

    @IsTest
    static void test_inject_skipsMailtoLink() {
        String html = '<body><a href="mailto:donate@ulbc.example">email us</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        System.assert(out.contains('href="mailto:donate@ulbc.example"'),
            'mailto: links must be left untouched');
    }

    @IsTest
    static void test_inject_skipsTelLink() {
        String html = '<body><a href="tel:+441234567890">call</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        System.assert(out.contains('href="tel:+441234567890"'));
    }

    @IsTest
    static void test_inject_skipsAlreadyTrackedLink() {
        String html = '<body><a href="' + BASE + '/services/apexrest/email/click?t=other">x</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        // Our TOKEN should appear exactly twice: the open pixel and the
        // hardcoded footer's unsub URL. The already-tracked click link must
        // keep its original "other" token (no re-wrapping).
        Integer countOurToken = countSubstr(out, '?t=' + TOKEN);
        System.assertEquals(2, countOurToken,
            'Pixel + footer unsub each carry our token; the existing click link must not be re-wrapped');
        System.assert(out.contains('?t=other'),
            'Original tracked link must keep its "other" token unchanged');
    }

    @IsTest
    static void test_inject_skipsUnsubscribeLink() {
        String html = '<body><a href="https://other.example/unsubscribe?u=x">opt out</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        System.assert(out.contains('href="https://other.example/unsubscribe?u=x"'),
            'Links containing "unsubscribe" must be left untouched');
    }

    @IsTest
    static void test_inject_preservesOtherAnchorAttributes() {
        String html = '<a class="btn" href="https://example.com" target="_blank" rel="noopener">click</a>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        System.assert(out.contains('class="btn"'), 'class attr preserved');
        System.assert(out.contains('target="_blank"'), 'target attr preserved');
        System.assert(out.contains('rel="noopener"'), 'rel attr preserved');
        System.assert(out.contains('/services/apexrest/email/click'), 'href rewritten');
    }

    @IsTest
    static void test_inject_doesNotDoubleEncodeUrl() {
        String original = 'https://example.com/page?q=hello%20world';
        String html = '<a href="' + original + '">x</a>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        // Once-encoded original should appear in the u= parameter.
        String onceEncoded = EncodingUtil.urlEncode(original, 'UTF-8');
        System.assert(out.contains('u=' + onceEncoded),
            'URL should be encoded exactly once: ' + out);
    }

    @IsTest
    static void test_inject_disabledTracking_leavesLinksAlone() {
        String html = '<body><a href="https://example.com">x</a></body>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, false);
        System.assert(out.contains('href="https://example.com"'),
            'When tracking disabled, links must not be rewritten');
        System.assert(!out.contains('email/open'),
            'When tracking disabled, pixel must not be injected');
    }

    // ── Pixel injection ─────────────────────────────────────────────────

    @IsTest
    static void test_inject_appendsPixelBeforeBodyClose() {
        String html = '<html><body>hi</body></html>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        Integer pixelIdx = out.indexOf('email/open?t=');
        Integer bodyIdx = out.indexOf('</body>');
        System.assert(pixelIdx > 0 && bodyIdx > 0, 'Both pixel and </body> present');
        System.assert(pixelIdx < bodyIdx, 'Pixel must precede </body>');
    }

    @IsTest
    static void test_inject_handlesHtmlWithNoBodyTag() {
        String html = '<p>hello</p>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        System.assert(out.startsWith('<p>hello</p>'), 'Original content first');
        System.assert(out.contains('email/open?t='), 'Pixel still appended at end');
    }

    @IsTest
    static void test_inject_pixelTokenIsUrlEncoded() {
        String tokenWithSlash = 'abc/def+ghi';
        String html = '<body>x</body>';
        String out = ULBC_EmailHtmlMutator.inject(html, tokenWithSlash, BASE, true);
        // Tokens generated by ULBC_EmailTokenService never contain / or +,
        // but the mutator should still URL-encode defensively.
        System.assert(out.contains('email/open?t=' + EncodingUtil.urlEncode(tokenWithSlash, 'UTF-8')),
            'Token in pixel URL must be URL-encoded');
    }

    // ── Footer ─────────────────────────────────────────────────────────

    @IsTest
    static void test_inject_appendsHardcodedFooterAndReplacesUnsubPlaceholder() {
        String html = '<html><body>content</body></html>';
        String out = ULBC_EmailHtmlMutator.inject(html, TOKEN, BASE, true);
        System.assert(out.contains('1174721'), 'Hardcoded charity number present in footer');
        System.assert(out.contains('ULBC Trust Limited'), 'Hardcoded charity name present');
        System.assert(out.contains(BASE + '/services/apexrest/email/unsub?t=' + TOKEN),
            'Unsub placeholder replaced with personalised URL');
        System.assert(!out.contains('{{UNSUB_URL}}'), 'Placeholder must not survive');
    }

    @IsTest
    static void test_inject_blankInputs_returnUnchanged() {
        System.assertEquals(null, ULBC_EmailHtmlMutator.inject(null, TOKEN, BASE, true));
        System.assertEquals('', ULBC_EmailHtmlMutator.inject('', TOKEN, BASE, true));
        String html = '<p>x</p>';
        System.assertEquals(html, ULBC_EmailHtmlMutator.inject(html, null, BASE, true),
            'Blank token short-circuits');
        System.assertEquals(html, ULBC_EmailHtmlMutator.inject(html, TOKEN, null, true),
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
