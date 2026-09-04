import type { IncomingMessage } from "node:http";

// A battle state/action payload is tiny; this is just a sane guard against
// a client streaming an unbounded body.
const MAX_BODY_BYTES = 1_000_000;

export class BodyTooLargeError extends Error {}

export async function readJsonBody(req: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let totalBytes = 0;

  for await (const chunk of req as AsyncIterable<Buffer>) {
    totalBytes += chunk.length;
    if (totalBytes > MAX_BODY_BYTES) {
      throw new BodyTooLargeError("request body too large");
    }
    chunks.push(chunk);
  }

  const raw = Buffer.concat(chunks).toString("utf-8");
  return raw.length === 0 ? undefined : JSON.parse(raw);
}
