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
  handleSurrender,
} from "./routes/matches.js";
import { handleValidateTurn } from "./routes/validate-turn.js";
import { RequestLimits } from './http/request-limits.js';
import { sendJson } from './http/respond.js';
import {sendErrorResponse} from './http/respond.js';
import {readJsonBody} from './http/json-body.js';
import {MatchError} from './matches/errors.js';
import type {Accounts} from './auth/accounts.js';

/**
 * Builds the HTTP server without starting it — kept separate from
 * `listen()` so tests can spin it up on an ephemeral port. Each call gets
 * its own in-memory `MatchStore`, which also keeps tests isolated from
 * each other.
 */
export function createServer(matchStore = new MatchStore({filePath: process.env.MATCH_STORE_FILE}), accounts?: Accounts): Server {
  const limits = new RequestLimits();
  const server = createHttpServer(async (req, res) => {
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

    try {
      if (pathname === '/account') {
        if (!accounts) throw new MatchError('Login ainda não configurado no servidor.', 503);
        if (req.method === 'GET') sendJson(res, 200, await accounts.read(req));
        else if (req.method === 'POST') sendJson(res, 200, await accounts.link(req, await readJsonBody(req)));
        else sendJson(res, 405, {error:'Método não permitido.'});
        return;
      }
      if (pathname.startsWith('/matches')) {
        if (accounts) await accounts.authenticate(req);
        else if (!/^Bearer [a-f0-9]{64}$/.test(req.headers.authorization ?? '')) throw new MatchError('Login indisponível neste servidor.', 503);
      }
    } catch (error) { sendErrorResponse(res, error instanceof MatchError ? error : new MatchError('Identidade indisponível. Tente novamente.', 503)); return; }

    if (req.method === "GET" && pathname === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", protocol: 2, accounts: !!accounts, persistence: process.env.MATCH_STORE === 'firestore' ? 'firestore' : 'local' }));
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
    const surrenderParams = req.method === 'POST' ? matchPath('/matches/:id/surrender', pathname) : null;
    if (surrenderParams) {
      void handleSurrender(req, res, matchStore, surrenderParams.id!);
      return;
    }
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
