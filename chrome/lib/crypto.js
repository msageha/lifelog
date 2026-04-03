const CRYPTO_KEY_NAME = "lifelogCryptoKey";

async function getOrCreateKey() {
  const stored = await chrome.storage.local.get(CRYPTO_KEY_NAME);
  if (stored[CRYPTO_KEY_NAME]) {
    const rawKey = new Uint8Array(stored[CRYPTO_KEY_NAME]);
    return crypto.subtle.importKey("raw", rawKey, "AES-GCM", true, ["encrypt", "decrypt"]);
  }

  const key = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, ["encrypt", "decrypt"]);
  const exported = await crypto.subtle.exportKey("raw", key);
  await chrome.storage.local.set({ [CRYPTO_KEY_NAME]: Array.from(new Uint8Array(exported)) });
  return key;
}

let cachedKey = null;

async function getCryptoKey() {
  if (!cachedKey) {
    cachedKey = await getOrCreateKey();
  }
  return cachedKey;
}

export async function encrypt(plaintext) {
  if (!plaintext && plaintext !== "") return null;
  const key = await getCryptoKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(JSON.stringify(plaintext));
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoded);
  return {
    _encrypted: true,
    iv: Array.from(iv),
    data: Array.from(new Uint8Array(ciphertext))
  };
}

export async function decrypt(envelope) {
  if (!envelope || !envelope._encrypted) return envelope;
  const key = await getCryptoKey();
  const iv = new Uint8Array(envelope.iv);
  const data = new Uint8Array(envelope.data);
  const decrypted = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, data);
  return JSON.parse(new TextDecoder().decode(decrypted));
}
