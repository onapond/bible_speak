const {
  PurchaseVerificationError,
  accountTokenForUserId,
  validateAppleTransaction,
  validateGooglePurchaseResponse,
} = require("./purchase_verification");

const monthly = "bible_speak_premium_monthly";
const now = Date.parse("2026-08-22T00:00:00.000Z");

describe("purchase verification", () => {
  test("derives a stable UUID account token", () => {
    const token = accountTokenForUserId("firebase-user-123");
    expect(token).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(accountTokenForUserId("firebase-user-123")).toBe(token);
  });

  test("accepts an active matching Google Play subscription", () => {
    const result = validateGooglePurchaseResponse({
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      latestOrderId: "GPA.1234-5678-9012-34567",
      lineItems: [{
        productId: monthly,
        expiryTime: "2026-09-22T00:00:00.000Z",
      }],
    }, monthly, "valid-purchase-token", now);

    expect(result.planId).toBe(monthly);
    expect(result.expiryDate).toBe("2026-09-22T00:00:00.000Z");
    expect(result.source).toBe("google_play");
  });

  test("rejects a Google Play response for another product", () => {
    expect(() => validateGooglePurchaseResponse({
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      lineItems: [{
        productId: "another_product",
        expiryTime: "2026-09-22T00:00:00.000Z",
      }],
    }, monthly, "valid-purchase-token", now)).toThrow(PurchaseVerificationError);
  });

  test("rejects a Google Play purchase bound to another app account", () => {
    const expected = accountTokenForUserId("current-user");
    expect(() => validateGooglePurchaseResponse({
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      externalAccountIdentifiers: {obfuscatedExternalAccountId: "another-account"},
      lineItems: [{
        productId: monthly,
        expiryTime: "2026-09-22T00:00:00.000Z",
      }],
    }, monthly, "valid-purchase-token", now, expected)).toThrow(
      expect.objectContaining({code: "account_mismatch"}),
    );
  });

  test("accepts an App Store signed transaction payload after signature verification", () => {
    const result = validateAppleTransaction({
      bundleId: "com.onapond.biblespeak",
      productId: monthly,
      type: "Auto-Renewable Subscription",
      originalTransactionId: "2000000123456789",
      expiresDate: Date.parse("2026-09-22T00:00:00.000Z"),
      environment: "Sandbox",
    }, monthly, now);

    expect(result.originalTransactionId).toBe("2000000123456789");
    expect(result.environment).toBe("Sandbox");
  });

  test("rejects a revoked App Store transaction", () => {
    expect(() => validateAppleTransaction({
      bundleId: "com.onapond.biblespeak",
      productId: monthly,
      type: "Auto-Renewable Subscription",
      originalTransactionId: "2000000123456789",
      expiresDate: Date.parse("2026-09-22T00:00:00.000Z"),
      revocationDate: Date.parse("2026-08-21T00:00:00.000Z"),
    }, monthly, now)).toThrow(PurchaseVerificationError);
  });
});
