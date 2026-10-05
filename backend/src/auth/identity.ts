import {createHash} from 'node:crypto';
import type {IncomingMessage} from 'node:http';
import {MatchError} from '../matches/errors.js';

export interface AccountIdentity {playerId: string; credentialHash: string}
const identities = new WeakMap<IncomingMessage, AccountIdentity>();
export const setIdentity = (req: IncomingMessage, identity: AccountIdentity) => identities.set(req, identity);
export const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

// The digest marker is internal only. No HTTP endpoint accepts it as a bearer.
export const credentialDigest = (token: string): string =>
  /^digest:[a-f0-9]{64}$/.test(token) ? token.slice(7) : sha256(token);

export function sessionToken(req: IncomingMessage, playerId?: string): string {
  const identity = identities.get(req);
  if (identity) {
    if (playerId && playerId !== identity.playerId) throw new MatchError('Use o nome vinculado à sua conta.', 403);
    return `digest:${identity.credentialHash}`;
  }
  const value = req.headers.authorization?.replace(/^Bearer /, '');
  if (!value || !/^[a-f0-9]{64}$/.test(value)) throw new MatchError('Entre novamente na sua conta.', 401);
  return value;
}
