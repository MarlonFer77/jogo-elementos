import { test } from "node:test";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";

import { createServer } from "../src/server.js";

test("GET /health responds 200 with status ok", async () => {
  const server = createServer().listen(0);
  const { port } = server.address() as AddressInfo;

  try {
    const response = await fetch(`http://localhost:${port}/health`);
    const body = await response.json() as {
      status: string; protocol: number; accounts: boolean;
      persistence: string; revision: string;
    };

    assert.equal(response.status, 200);
    assert.equal(body.status, "ok");
    assert.equal(body.protocol, 2);
    assert.equal(typeof body.accounts, "boolean");
    assert.match(body.persistence, /^(local|firestore)$/);
    assert.match(body.revision, /^(local|[a-f0-9]{12})$/i);
  } finally {
    server.close();
  }
});

test("unknown routes respond 404", async () => {
  const server = createServer().listen(0);
  const { port } = server.address() as AddressInfo;

  try {
    const response = await fetch(`http://localhost:${port}/ghost`);
    assert.equal(response.status, 404);
  } finally {
    server.close();
  }
});

test("responses carry a permissive CORS header, for the Flutter web app", async () => {
  const server = createServer().listen(0);
  const { port } = server.address() as AddressInfo;

  try {
    const response = await fetch(`http://localhost:${port}/health`);
    assert.equal(response.headers.get("access-control-allow-origin"), "*");
  } finally {
    server.close();
  }
});

test("an OPTIONS preflight request is answered without hitting any route", async () => {
  const server = createServer().listen(0);
  const { port } = server.address() as AddressInfo;

  try {
    const response = await fetch(`http://localhost:${port}/matches/ABC123/turns`, {
      method: "OPTIONS",
    });
    assert.equal(response.status, 204);
    assert.equal(response.headers.get("access-control-allow-origin"), "*");
    assert.match(
      response.headers.get("access-control-allow-methods") ?? "",
      /POST/,
    );
  } finally {
    server.close();
  }
});
