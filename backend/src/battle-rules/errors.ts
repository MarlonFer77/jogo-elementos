/** A submitted state/action failed validation — maps to HTTP 400. */
export class TurnValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TurnValidationError";
  }
}
