/**
 * ULBC_EmailTokenService
 *
 * Generates URL-safe opaque tokens for embedding in pixel, click, and
 * unsubscribe URLs. One token per ULBC_Email_Send_Recipient__c row.
 *
 * 24 bytes of entropy → 32 base64url characters → exactly fits the
 * 32-char ULBC_Token__c field with no padding.
 *
 * Random GUIDs (this) preferred over HMAC-signed tokens because they
 * are revocable by deleting the row, simpler to reason about, and
 * the secret-key surface area for HMAC is not justified at this volume.
 */
public with sharing class ULBC_EmailTokenService {

    /** Length of a generated token in characters. */
    public static final Integer TOKEN_LENGTH = 32;

    /**
     * Generate one URL-safe random token.
     * 24 bytes of cryptographic entropy from Crypto.generateAesKey(192),
     * base64-encoded then made URL-safe (+ → -, / → _).
     * 24 bytes is divisible by 3 so the encoding produces no = padding.
     */
    public static String generate() {
        Blob entropy = Crypto.generateAesKey(192);
        String b64 = EncodingUtil.base64Encode(entropy);
        return b64.replace('+', '-').replace('/', '_');
    }

    /**
     * Generate n distinct tokens. No collision check — at 192 bits of
     * entropy per token the probability of collision in a single send
     * (≤1k recipients) is below 1 in 2^150.
     */
    public static List<String> generate(Integer n) {
        List<String> out = new List<String>();
        for (Integer i = 0; i < n; i++) {
            out.add(generate());
        }
        return out;
    }
}
