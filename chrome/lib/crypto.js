const CRYPTO_KEY_ALIAS = "lifelogCryptoKey";
const ALGORITHM = "AES-GCM";
const KEY_LENGTH = 256;
const IV_LENGTH = 12;

async function exportKey(key) {
  const raw = await crypto.subtle.exportKey("raw", key);
  return Array.from(new Uint8Array(raw));
}

async function importKey(rawArray) {
  const raw = new Uint8Array(rawArray).buffer;
  return crypto.subtle.importKey("raw", raw, { name: ALGORITHM }, true, ["encrypt", "decrypt"]);
}

export async function getOrCreateKey() {
  const stored = await chrome.storage.local.get(CRYPTO_KEY_ALIAS);
  if (stored[CRYPTO_KEY_ALIAS]) {
    return importKey(stored[CRYPTO_KEY_ALIAS]);
  }

  const key = await crypto.subtle.generateKey(
    { name: ALGORITHM, length: KEY_LENGTH },
    true,
    ["encrypt", "decrypt"]
  );
  const exported = await exportKey(key);
  await chrome.storage.local.set({ [CRYPTO_KEY_ALIAS]: exported });
  return key;
}

export async function encrypt(key, plaintext) {
  const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
  const encoded = new TextEncoder().encode(plaintext);
  const cipherBuffer = await crypto.subtle.encrypt(
    { name: ALGORITHM, iv },
    key,
    encoded
  );
  return {
    iv: Array.from(iv),
    ciphertext: Array.from(new Uint8Array(cipherBuffer))
  };
}

export async function decrypt(key, { iv, ciphertext }) {
  const ivBytes = new Uint8Array(iv);
  const cipherBytes = new Uint8Array(ciphertext).buffer;
  const plainBuffer = await crypto.subtle.decrypt(
    { name: ALGORITHM, iv: ivBytes },
    key,
    cipherBytes
  );
  return new TextDecoder().decode(plainBuffer);
}
