/**
 * ULBC_EmailTokenService_Test
 *
 * Verifies token shape (length, character set), uniqueness across many
 * iterations, and bulk generation.
 */
@IsTest
private class ULBC_EmailTokenService_Test {

    @IsTest
    static void test_generate_returnsTokenOfExpectedLength() {
        String t = ULBC_EmailTokenService.generate();
        System.assertEquals(ULBC_EmailTokenService.TOKEN_LENGTH, t.length(),
            'Token length must equal TOKEN_LENGTH constant');
    }

    @IsTest
    static void test_generate_returnsOnlyUrlSafeCharacters() {
        // Run a few iterations to catch occasional + or / from base64.
        for (Integer i = 0; i < 50; i++) {
            String t = ULBC_EmailTokenService.generate();
            System.assert(Pattern.matches('^[A-Za-z0-9_\\-]+$', t),
                'Token contains a non-URL-safe character: ' + t);
            System.assert(!t.contains('='),
                'Token must not contain base64 padding: ' + t);
        }
    }

    @IsTest
    static void test_generate_returnsUniqueTokensAcrossManyCalls() {
        Integer n = 5000;
        Set<String> seen = new Set<String>();
        for (Integer i = 0; i < n; i++) {
            seen.add(ULBC_EmailTokenService.generate());
        }
        System.assertEquals(n, seen.size(),
            'All ' + n + ' tokens should be unique');
    }

    @IsTest
    static void test_generateBulk_returnsRequestedCount() {
        List<String> tokens = ULBC_EmailTokenService.generate(100);
        System.assertEquals(100, tokens.size());
        System.assertEquals(100, new Set<String>(tokens).size(),
            'Bulk-generated tokens should all be distinct');
    }
}
