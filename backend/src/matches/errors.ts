/** A match-level operation failed (not found, wrong state, not a
 * participant...). Carries its own HTTP status — see http/respond.ts. */
export class MatchError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "MatchError";
    this.status = status;
  }
}
