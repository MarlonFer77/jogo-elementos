import type { ServerResponse } from "node:http";
import { TurnValidationError } from '../battle-rules/errors.js';

interface HasStatus {
  status?: number;
}

export function sendJson(res: ServerResponse, status: number, body: unknown): void {
  if (res.destroyed || res.writableEnded) return;
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

/** Maps a thrown domain error to an HTTP error response. Errors that carry
 * a `.status` use it; known validation/JSON errors are 400. Unexpected errors
 * are generic 500 responses without implementation details. */
export function sendErrorResponse(res: ServerResponse, error: unknown): void {
  const status = (error as HasStatus)?.status ??
    (error instanceof TurnValidationError || error instanceof SyntaxError ? 400 : 500);
  const message = status >= 500
    ? 'Servidor temporariamente indisponível. Sincronize antes de repetir a ação.'
    : error instanceof Error ? error.message : 'Requisição inválida.';
  if (status === 413) res.setHeader('Connection', 'close');
  sendJson(res, status, { error: message });
}
