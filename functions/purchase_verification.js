const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const {
  AppStoreServerAPIClient,
  Environment,
  ReceiptUtility,
  SignedDataVerifier,
  Type,
} = require("@apple/app-store-server-library");
const {GoogleAuth} = require("google-auth-library");

const ANDROID_PACKAGE_NAME = "com.onapond.biblespeak";
const APPLE_BUNDLE_ID = "com.onapond.biblespeak";
const SUPPORTED_PRODUCT_IDS = new Set([
  "bible_speak_premium_monthly",
  "bible_speak_premium_yearly",
]);
const GOOGLE_PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher";

class PurchaseVerificationError extends Error {
  constructor(code, message, httpStatus = 400) {
    super(message);
    this.name = "PurchaseVerificationError";
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

function assertSupportedProduct(productId) {
  if (typeof productId !== "string" || !SUPPORTED_PRODUCT_IDS.has(productId)) {
    throw new PurchaseVerificationError("unsupported_product", "Unsupported product");
  }
}

function hashClaim(source, value) {
  return crypto.createHash("sha256").update(`${source}:${value}`).digest("hex");
}

function accountTokenForUserId(userId) {
  const bytes = Buffer.from(
    crypto.createHash("sha256").update(`bible-speak:iap:${userId}`).digest().subarray(0, 16),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function validateGooglePurchaseResponse(
  data,
  productId,
  purchaseToken,
  now = Date.now(),
  expectedAccountToken,
) {
  assertSupportedProduct(productId);
  const entitledStates = new Set([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]);
  if (!data || !entitledStates.has(data.subscriptionState)) {
    throw new PurchaseVerificationError("inactive_purchase", "Subscription is not active");
  }

  const matchingItems = (data.lineItems || []).filter(
    (item) => item && item.productId === productId,
  );
  const expiryTimes = matchingItems
    .map((item) => Date.parse(item.expiryTime || ""))
    .filter(Number.isFinite);
  const expiryMillis = expiryTimes.length > 0 ? Math.max(...expiryTimes) : NaN;
  if (!Number.isFinite(expiryMillis) || expiryMillis <= now) {
    throw new PurchaseVerificationError("expired_purchase", "Subscription has expired");
  }

  const storeAccountToken = data.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  if (storeAccountToken && expectedAccountToken && storeAccountToken !== expectedAccountToken) {
    throw new PurchaseVerificationError(
      "account_mismatch",
      "Purchase belongs to another account",
      409,
    );
  }

  const claimKey = hashClaim("google_play", purchaseToken);
  return {
    planId: productId,
    expiryDate: new Date(expiryMillis).toISOString(),
    originalTransactionId: data.latestOrderId || data.latestSuccessfulOrderId || claimKey,
    claimKey,
    source: "google_play",
    environment: data.testPurchase ? "Sandbox" : "Production",
  };
}

function validateAppleTransaction(
  transaction,
  productId,
  now = Date.now(),
  expectedAccountToken,
) {
  assertSupportedProduct(productId);
  if (!transaction || transaction.bundleId !== APPLE_BUNDLE_ID) {
    throw new PurchaseVerificationError("invalid_app", "Purchase belongs to another app");
  }
  if (transaction.productId !== productId) {
    throw new PurchaseVerificationError("product_mismatch", "Product does not match");
  }
  if (transaction.type !== Type.AUTO_RENEWABLE_SUBSCRIPTION) {
    throw new PurchaseVerificationError("invalid_product_type", "Purchase is not a subscription");
  }
  if (transaction.revocationDate || transaction.isUpgraded === true) {
    throw new PurchaseVerificationError("revoked_purchase", "Subscription was revoked or upgraded");
  }
  if (!Number.isFinite(transaction.expiresDate) || transaction.expiresDate <= now) {
    throw new PurchaseVerificationError("expired_purchase", "Subscription has expired");
  }
  if (transaction.appAccountToken && expectedAccountToken &&
      transaction.appAccountToken.toLowerCase() !== expectedAccountToken.toLowerCase()) {
    throw new PurchaseVerificationError(
      "account_mismatch",
      "Purchase belongs to another account",
      409,
    );
  }

  const originalTransactionId = transaction.originalTransactionId || transaction.transactionId;
  if (!originalTransactionId) {
    throw new PurchaseVerificationError("missing_transaction", "Transaction identifier is missing");
  }
  return {
    planId: productId,
    expiryDate: new Date(transaction.expiresDate).toISOString(),
    originalTransactionId,
    claimKey: hashClaim("app_store", originalTransactionId),
    source: "app_store",
    environment: transaction.environment || "Unknown",
  };
}

async function verifyGooglePlayPurchase({productId, verificationData, userId}) {
  if (typeof verificationData !== "string" ||
      verificationData.length < 10 || verificationData.length > 8192) {
    throw new PurchaseVerificationError("invalid_token", "Invalid purchase token");
  }

  const auth = new GoogleAuth({scopes: [GOOGLE_PLAY_SCOPE]});
  const client = await auth.getClient();
  const url = "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    `applications/${ANDROID_PACKAGE_NAME}/purchases/subscriptionsv2/tokens/` +
    encodeURIComponent(verificationData);
  const response = await client.request({url, method: "GET"});
  return validateGooglePurchaseResponse(
    response.data,
    productId,
    verificationData,
    Date.now(),
    accountTokenForUserId(userId),
  );
}

let appleRootCertificates;
function loadAppleRootCertificates() {
  if (appleRootCertificates) return appleRootCertificates;
  const certificateDirectory = path.join(__dirname, "certs");
  appleRootCertificates = [
    "AppleIncRootCertificate.cer",
    "AppleRootCA-G2.cer",
    "AppleRootCA-G3.cer",
  ].map((name) => fs.readFileSync(path.join(certificateDirectory, name)));
  return appleRootCertificates;
}

function getAppleAppId() {
  const appAppleId = Number.parseInt(process.env.APPLE_APP_ID || "", 10);
  if (!Number.isSafeInteger(appAppleId) || appAppleId <= 0) {
    throw new PurchaseVerificationError(
      "apple_not_configured",
      "Apple purchase verification is not configured",
      503,
    );
  }
  return appAppleId;
}

function createAppleVerifier(environment) {
  const appAppleId = environment === Environment.PRODUCTION ? getAppleAppId() : undefined;
  return new SignedDataVerifier(
    loadAppleRootCertificates(),
    true,
    environment,
    APPLE_BUNDLE_ID,
    appAppleId,
  );
}

async function verifyAppleJws(signedTransaction, productId, environment, userId) {
  const verifier = createAppleVerifier(environment);
  const transaction = await verifier.verifyAndDecodeTransaction(signedTransaction);
  return validateAppleTransaction(
    transaction,
    productId,
    Date.now(),
    accountTokenForUserId(userId),
  );
}

function getAppleApiCredentials() {
  const keyId = process.env.APPLE_IAP_KEY_ID;
  const issuerId = process.env.APPLE_IAP_ISSUER_ID;
  const privateKey = process.env.APPLE_IAP_PRIVATE_KEY?.replace(/\\n/g, "\n");
  if (!keyId || !issuerId || !privateKey) {
    throw new PurchaseVerificationError(
      "apple_not_configured",
      "Apple purchase verification is not configured",
      503,
    );
  }
  return {keyId, issuerId, privateKey};
}

async function verifyAppleLegacyReceipt({productId, verificationData, purchaseId, userId}) {
  const {keyId, issuerId, privateKey} = getAppleApiCredentials();
  let transactionId = purchaseId;
  if (!transactionId) {
    try {
      transactionId = new ReceiptUtility().extractTransactionIdFromAppReceipt(verificationData);
    } catch (error) {
      throw new PurchaseVerificationError("invalid_receipt", "Invalid App Store receipt");
    }
  }
  if (typeof transactionId !== "string" || !/^\d{6,30}$/.test(transactionId)) {
    throw new PurchaseVerificationError("invalid_transaction", "Invalid transaction identifier");
  }

  let lastError;
  for (const environment of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const client = new AppStoreServerAPIClient(
        privateKey,
        keyId,
        issuerId,
        APPLE_BUNDLE_ID,
        environment,
      );
      const status = await client.getAllSubscriptionStatuses(transactionId);
      const signedTransactions = (status.data || []).flatMap((group) =>
        (group.lastTransactions || [])
          .map((item) => item.signedTransactionInfo)
          .filter(Boolean),
      );
      const verified = [];
      for (const signedTransaction of signedTransactions) {
        try {
          verified.push(await verifyAppleJws(
            signedTransaction,
            productId,
            environment,
            userId,
          ));
        } catch (error) {
          lastError = error;
        }
      }
      if (verified.length > 0) {
        return verified.reduce((latest, item) =>
          Date.parse(item.expiryDate) > Date.parse(latest.expiryDate) ? item : latest,
        );
      }
    } catch (error) {
      lastError = error;
    }
  }
  if (lastError instanceof PurchaseVerificationError) throw lastError;
  throw new PurchaseVerificationError("invalid_receipt", "App Store receipt could not be verified");
}

async function verifyAppStorePurchase({productId, verificationData, purchaseId, userId}) {
  if (typeof verificationData !== "string" ||
      verificationData.length < 10 || verificationData.length > 2 * 1024 * 1024) {
    throw new PurchaseVerificationError("invalid_receipt", "Invalid App Store purchase data");
  }
  if (purchaseId != null &&
      (typeof purchaseId !== "string" || purchaseId.length > 100)) {
    throw new PurchaseVerificationError("invalid_transaction", "Invalid transaction identifier");
  }

  // StoreKit 2 supplies a signed transaction JWS. Try both App Store
  // environments because review and TestFlight transactions use Sandbox.
  if (verificationData.split(".").length === 3) {
    let lastError;
    for (const environment of [Environment.PRODUCTION, Environment.SANDBOX]) {
      try {
        return await verifyAppleJws(verificationData, productId, environment, userId);
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError instanceof PurchaseVerificationError) throw lastError;
    throw new PurchaseVerificationError("invalid_jws", "App Store signature is invalid");
  }

  // StoreKit 1 supplies the base64 app receipt. Extracting an ID performs no
  // validation; the ID is used only to query Apple's authenticated server API.
  return verifyAppleLegacyReceipt({productId, verificationData, purchaseId, userId});
}

async function verifyStorePurchase(payload, userId) {
  if (!payload || typeof payload !== "object") {
    throw new PurchaseVerificationError("invalid_request", "Invalid request");
  }
  if (typeof userId !== "string" || userId.length === 0) {
    throw new PurchaseVerificationError("invalid_user", "Invalid user");
  }
  const {source, productId, verificationData, purchaseId} = payload;
  assertSupportedProduct(productId);
  if (source === "google_play") {
    return verifyGooglePlayPurchase({productId, verificationData, userId});
  }
  if (source === "app_store") {
    return verifyAppStorePurchase({productId, verificationData, purchaseId, userId});
  }
  throw new PurchaseVerificationError("unsupported_store", "Unsupported store");
}

module.exports = {
  PurchaseVerificationError,
  accountTokenForUserId,
  validateAppleTransaction,
  validateGooglePurchaseResponse,
  verifyStorePurchase,
};
