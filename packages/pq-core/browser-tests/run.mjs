import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const browserTests = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(browserTests, "..");
const artifacts = join(browserTests, "artifacts");

const chromeCandidates = [
  process.env.CHROME_BIN,
  process.platform === "win32"
    ? "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
    : null,
  process.platform === "win32"
    ? "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
    : null,
  "google-chrome",
  "chromium",
  "chromium-browser",
].filter(Boolean);

const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".wasm", "application/wasm"],
  [".bin", "application/octet-stream"],
]);

function resolveStaticPath(urlPath) {
  const decoded = decodeURIComponent(urlPath === "/" ? "/browser-tests/index.html" : urlPath);
  const candidate = resolve(packageRoot, `.${normalize(decoded)}`);
  return candidate.startsWith(`${packageRoot}${process.platform === "win32" ? "\\" : "/"}`)
    ? candidate
    : null;
}

async function collect(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 4_096) throw new Error("artifact body exceeds 4 KiB");
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

function startServer() {
  let completed = false;
  const waiters = [];
  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url, "http://127.0.0.1");
      if (process.env.PQ_BROWSER_TEST_DEBUG) {
        console.log(`${request.method} ${url.pathname}`);
      }
      if (request.method === "GET" && url.pathname === "/wait") {
        if (completed) response.writeHead(204).end();
        else waiters.push(response);
        return;
      }
      if (request.method === "POST" && url.pathname === "/complete") {
        completed = true;
        for (const waiter of waiters.splice(0)) waiter.writeHead(204).end();
        response.writeHead(204).end();
        return;
      }
      const upload = /^\/artifacts\/(wasm-public|wasm-signature)\.bin$/.exec(url.pathname);
      if (request.method === "POST" && upload) {
        await writeFile(join(artifacts, `${upload[1]}.bin`), await collect(request));
        response.writeHead(204).end();
        return;
      }

      if (request.method !== "GET") {
        response.writeHead(405).end();
        return;
      }

      const path = resolveStaticPath(url.pathname);
      if (!path) {
        response.writeHead(403).end();
        return;
      }
      const bytes = await readFile(path);
      response.writeHead(200, {
        "Content-Type": mimeTypes.get(extname(path)) ?? "application/octet-stream",
      });
      response.end(bytes);
    } catch (error) {
      response.writeHead(error?.code === "ENOENT" ? 404 : 500).end(String(error));
    }
  });

  return new Promise((resolvePromise, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => resolvePromise(server));
  });
}

function runChrome(executable, url, profile) {
  const arguments_ = [
    "--headless=new",
    "--disable-gpu",
    "--disable-extensions",
    "--disable-background-networking",
    "--no-first-run",
    "--no-default-browser-check",
    "--no-sandbox",
    `--user-data-dir=${profile}`,
    "--dump-dom",
    url,
  ];

  return new Promise((resolvePromise, reject) => {
    const child = spawn(executable, arguments_, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8").on("data", (chunk) => (stdout += chunk));
    child.stderr.setEncoding("utf8").on("data", (chunk) => (stderr += chunk));
    const timeout = setTimeout(() => {
      child.kill();
      reject(new Error("headless Chromium timed out"));
    }, 240_000);
    child.once("error", reject);
    child.once("exit", (code) => {
      clearTimeout(timeout);
      if (code !== 0) reject(new Error(`Chromium exited ${code}: ${stderr}`));
      else resolvePromise({ stdout, stderr });
    });
  });
}

async function findChrome() {
  for (const candidate of chromeCandidates) {
    try {
      const probe = await new Promise((resolvePromise, reject) => {
        const child = spawn(candidate, ["--version"], { stdio: "ignore" });
        child.once("error", reject);
        child.once("exit", (code) => resolvePromise(code === 0));
      });
      if (probe) return candidate;
    } catch {
      // Try the next supported executable name.
    }
  }
  throw new Error("Chrome or Chromium was not found; set CHROME_BIN");
}

const declarations = await readFile(join(packageRoot, "pkg", "rwa_vault_pq_core.d.ts"), "utf8");
for (const api of ["publicKey", "privateKey", "falconSign", "falconVerify"]) {
  const declaration = declarations.split("\n").find((line) => line.includes(api));
  if (!declaration || !declaration.includes("Uint8Array") || declaration.includes("string")) {
    throw new Error(`${api} is not a Uint8Array-only binding: ${declaration ?? "missing"}`);
  }
}

await stat(join(artifacts, "message.bin"));
await stat(join(artifacts, "native-public.bin"));
await stat(join(artifacts, "native-signature.bin"));

const server = await startServer();
const profile = await mkdtemp(join(tmpdir(), "rwa-pq-chromium-"));
try {
  const address = server.address();
  const chrome = await findChrome();
  const { stdout } = await runChrome(chrome, `http://127.0.0.1:${address.port}/`, profile);
  if (!stdout.includes('data-status="passed"')) {
    throw new Error(`browser acceptance failed:\n${stdout}`);
  }
  await stat(join(artifacts, "wasm-public.bin"));
  await stat(join(artifacts, "wasm-signature.bin"));
  console.log("browser verified native and emitted a WASM Falcon fixture");
} finally {
  await new Promise((resolvePromise) => server.close(resolvePromise));
  await rm(profile, { force: true, recursive: true });
}
