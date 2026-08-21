import loadWasm, {
  falconKeygen,
  falconSign,
  falconVerify,
  init as initCrypto,
} from "../pkg/rwa_vault_pq_core.js";

const result = document.querySelector("#result");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function expectCode(operation, expectedCode) {
  try {
    await operation();
  } catch (error) {
    assert(error?.code === expectedCode, `expected ${expectedCode}, received ${error?.code}`);
    return;
  }
  throw new Error(`expected ${expectedCode}, but the operation succeeded`);
}

async function readBytes(path) {
  const response = await fetch(path);
  assert(response.ok, `failed to read ${path}: ${response.status}`);
  return new Uint8Array(await response.arrayBuffer());
}

async function postBytes(name, bytes) {
  const response = await fetch(`/artifacts/${name}`, { method: "POST", body: bytes });
  assert(response.ok, `failed to write ${name}: ${response.status}`);
}

function replaceGetRandomValues(value) {
  const crypto = globalThis.crypto;
  const previous = Object.getOwnPropertyDescriptor(crypto, "getRandomValues");
  Object.defineProperty(crypto, "getRandomValues", {
    configurable: true,
    value,
    writable: true,
  });
  return () => {
    if (previous) {
      Object.defineProperty(crypto, "getRandomValues", previous);
    } else {
      delete crypto.getRandomValues;
    }
  };
}

try {
  await loadWasm();

  await expectCode(() => falconKeygen(), "NOT_INITIALISED");

  let restore = replaceGetRandomValues(undefined);
  await expectCode(() => initCrypto(), "RNG_FAILURE");
  await expectCode(() => falconKeygen(), "NOT_INITIALISED");
  restore();

  restore = replaceGetRandomValues((bytes) => {
    bytes.fill(0);
    return bytes;
  });
  await expectCode(() => initCrypto(), "RNG_FAILURE");
  await expectCode(() => falconKeygen(), "NOT_INITIALISED");
  restore();

  for (let draw = 0; draw < 1_000; draw += 1) {
    initCrypto();
  }

  const message = await readBytes("/browser-tests/artifacts/message.bin");
  const nativePublicKey = await readBytes("/browser-tests/artifacts/native-public.bin");
  const nativeSignature = await readBytes("/browser-tests/artifacts/native-signature.bin");
  assert(nativeSignature.length === 666, "native Falcon signature is not 666 bytes");
  assert(
    falconVerify(nativePublicKey, message, nativeSignature),
    "WASM rejected the native-generated Falcon signature",
  );

  const keyPair = falconKeygen();
  const wasmPublicKey = keyPair.publicKey;
  const wasmPrivateKey = keyPair.privateKey;
  const wasmSignature = falconSign(wasmPrivateKey, message);
  wasmPrivateKey.fill(0);
  keyPair.free();

  assert(wasmPublicKey instanceof Uint8Array, "public key did not cross as Uint8Array");
  assert(wasmSignature instanceof Uint8Array, "signature did not cross as Uint8Array");
  assert(wasmSignature.length === 666, "WASM Falcon signature is not 666 bytes");
  assert(falconVerify(wasmPublicKey, message, wasmSignature), "WASM self-verification failed");

  const tampered = wasmSignature.slice();
  tampered[0] ^= 1;
  assert(
    falconVerify(wasmPublicKey, message, tampered) === false,
    "tampered signature did not return false",
  );

  await postBytes("wasm-public.bin", wasmPublicKey);
  await postBytes("wasm-signature.bin", wasmSignature);

  document.body.dataset.status = "passed";
  result.textContent = "browser verified native; WASM fixture emitted";
} catch (error) {
  document.body.dataset.status = "failed";
  result.textContent = `${error?.stack ?? error}`;
}

await fetch("/complete", { method: "POST" });
