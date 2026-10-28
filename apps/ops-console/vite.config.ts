/// <reference types="vitest" />
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const repoRoot = fileURLToPath(new URL("../..", import.meta.url));

// The page bundles contracts/deployments/*.json and the custodian key at build time
// (T6.1b points 1 and 3), so the dev server may read the repo root.
export default defineConfig({
  plugins: [react()],
  server: { fs: { allow: [repoRoot] } },
  build: { outDir: "dist/web", target: "es2022" },
  optimizeDeps: { exclude: ["@rwa-vault/pq-core"] },
  test: { environment: "jsdom", include: ["src/**/*.test.{ts,tsx}"] },
});
