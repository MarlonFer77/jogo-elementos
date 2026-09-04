import { createServer as createHttpServer, type Server } from "node:http";

import { matchPath } from "./http/route.js";
import { MatchStore } from "./matches/match-store.js";
import {
  handleCreateMatch,
  handleGetMatch,
  handleJoinMatch,
  handleSubmitTurn,
  handleUnlockSkill,
} from "./routes/matches.js";
import { handleValidateTurn } from "./routes/validate-turn.js";

/**
 * Builds the HTTP server without starting it — kept separate from
 * `listen()` so tests can spin it up on an ephemeral port. Each call gets
 * its own in-memory `MatchStore`, which also keeps tests isolated from
 * each other.
 */
export function createServer(): Server {
  const matchStore = new MatchStore();

  return createHttpServer((req, res) => {
    const pathname = new URL(req.url ?? "/", "http://localhost").pathname;

    // Permissive CORS: there's no auth or per-origin concern here (see
    // DECISION-016 — identity is just a client-provided string), and the
    // Flutter web app runs on its own dev-server origin, separate from
    // this server's. See DECISION-021.
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    if (req.method === "GET" && pathname === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok" }));
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

    const joinParams =
      req.method === "POST" ? matchPath("/matches/:id/join", pathname) : null;
    if (joinParams) {
      void handleJoinMatch(req, res, matchStore, joinParams.id!);
      return;
    }

    const turnsParams =
      req.method === "POST" ? matchPath("/matches/:id/turns", pathname) : null;
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
      handleGetMatch(res, matchStore, matchParams.id!);
      return;
    }

    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "not_found" }));
  });
}
