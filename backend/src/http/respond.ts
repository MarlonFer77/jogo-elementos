import type { ServerResponse } from "node:http";

interface HasStatus {
  status?: number;
}

export function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

/** Maps a thrown domain error to an HTTP error response. Errors that carry
 * a `.status` (e.g. MatchError) use it; everything else (e.g.
 * TurnValidationError, a raw JSON.parse SyntaxError) is a 400. */
export function sendErrorResponse(res: ServerResponse, error: unknown): void {
  const status = (error as HasStatus)?.status ?? 400;
  const message = error instanceof Error ? error.message : "invalid request";
  sendJson(res, status, { error: message });
}
