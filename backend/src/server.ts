import { createServer as createHttpServer, type Server } from "node:http";

import { matchPath } from "./http/route.js";
import { MatchStore } from "./matches/match-store.js";
import {
  handleCreateMatch,
  handleConfigure,
  handleGetMatch,
  handleJoinMatch,
  handleSubmitTurn,
  handleUnlockSkill,
  handleSeal,
} from "./routes/matches.js";
import { handleValidateTurn } from "./routes/validate-turn.js";
import { RequestLimits } from './http/request-limits.js';
import { sendJson } from './http/respond.js';

/**
 * Builds the HTTP server without starting it — kept separate from
 * `listen()` so tests can spin it up on an ephemeral port. Each call gets
 * its own in-memory `MatchStore`, which also keeps tests isolated from
 * each other.
 */
export function createServer(matchStore = new MatchStore({filePath: process.env.MATCH_STORE_FILE})): Server {
  const limits = new RequestLimits();
  const server = createHttpServer((req, res) => {
    let pathname: string;
    try { pathname = new URL(req.url ?? '/', 'http://localhost').pathname; }
    catch { sendJson(res, 400, {error: 'Endereço inválido.'}); return; }

    // CORS is not authentication: rooms require a per-installation bearer token.
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.setHeader('Access-Control-Expose-Headers', 'Retry-After');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    if (!limits.allow(req, res, pathname)) return;

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    if (req.method === "GET" && pathname === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", protocol: 2, persistence: process.env.MATCH_STORE === 'firestore' ? 'firestore' : 'local' }));
      return;
    }

    if (req.method === "POST" && pathname === "/battles/validate-turn") {
      void handleValidateTurn(req, res);
      return;
    }

    if (req.method === "POST" && pathname === "/matches") {
      void handleCreateMatch(req, res, matchStore);
      return;
    }

    const configureParams = req.method === 'POST' ? matchPath('/matches/:id/configure', pathname) : null;
    for (const stage of ['start', 'finish']) {
      const params = req.method === 'POST' ? matchPath(`/matches/:id/seal/${stage}`, pathname) : null;
      if (params) {
        void handleSeal(req, res, matchStore, params.id!, stage === 'finish');
        return;
      }
    }
    if (configureParams) {
      void handleConfigure(req, res, matchStore, configureParams.id!);
      return;
    }
    const joinParams =
      req.method === "POST" ? matchPath("/matches/:id/join", pathname) : null;
    if (joinParams) {
      void handleJoinMatch(req, res, matchStore, joinParams.id!);
      return;
    }

    const turnsParams =
      req.method === "POST" ? matchPath("/matches/:id/turns", pathname) : null;
    const previewParams = req.method === 'POST' ? matchPath('/matches/:id/preview', pathname) : null;
    if (previewParams) {
      void handleSubmitTurn(req, res, matchStore, previewParams.id!, true);
      return;
    }
    if (turnsParams) {
      void handleSubmitTurn(req, res, matchStore, turnsParams.id!);
      return;
    }

    const unlockParams =
      req.method === "POST" ? matchPath("/matches/:id/skills/unlock", pathname) : null;
    if (unlockParams) {
      void handleUnlockSkill(req, res, matchStore, unlockParams.id!);
      return;
    }

    const matchParams =
      req.method === "GET" ? matchPath("/matches/:id", pathname) : null;
    if (matchParams) {
      handleGetMatch(req, res, matchStore, matchParams.id!);
      return;
    }

    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "not_found" }));
  });
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  server.keepAliveTimeout = 5_000;
  server.maxHeadersCount = 32;
  return server;
}
