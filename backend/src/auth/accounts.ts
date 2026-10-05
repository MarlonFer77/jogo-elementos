import {randomBytes} from 'node:crypto';
import type {IncomingMessage} from 'node:http';
import type {Firestore} from 'firebase-admin/firestore';
import {MatchError} from '../matches/errors.js';
import {setIdentity, sha256, type AccountIdentity} from './identity.js';

interface VerifiedUser {uid: string; email_verified?: boolean; firebase?: {sign_in_provider?: string}}
export type VerifyToken = (token: string) => Promise<VerifiedUser>;
export class Accounts {
  private readonly cache = new Map<string, {until: number; identity: AccountIdentity}>();
  constructor(private readonly db: Firestore, private readonly verify: VerifyToken) {}

  private async user(req: IncomingMessage): Promise<VerifiedUser> {
    const token = req.headers.authorization?.replace(/^Bearer /, '') ?? '';
    if (!/^[\w-]+\.[\w-]+\.[\w-]+$/.test(token) || token.length > 8192) throw new MatchError('Entre na sua conta.', 401);
    let user: VerifiedUser;
    try { user = await this.verify(token); }
    catch { throw new MatchError('Sessão inválida ou expirada. Entre novamente.', 401); }
    if (!user.email_verified || user.firebase?.sign_in_provider !== 'password') {
      throw new MatchError('Confirme seu e-mail antes de vincular ou acessar o perfil.', 403);
    }
    return user;
  }

  private async account(uid: string): Promise<AccountIdentity> {
    const cached = this.cache.get(uid);
    if (cached && cached.until > Date.now()) return cached.identity;
    const saved = await this.db.collection('elementosAccounts').doc(uid).get();
    if (!saved.exists) throw new MatchError('Crie ou vincule seu perfil para continuar.', 404);
    const identity = saved.data() as AccountIdentity;
    if (this.cache.size >= 100) this.cache.clear();
    this.cache.set(uid, {identity, until:Date.now() + 30_000});
    return identity;
  }

  async authenticate(req: IncomingMessage): Promise<void> {
    const bearer = req.headers.authorization?.replace(/^Bearer /, '') ?? '';
    if (/^[a-f0-9]{64}$/.test(bearer)) {
      // Once linked, possession of the old installation token no longer logs in.
      const claimed = await this.db.collection('elementosIdentityClaims').doc(sha256(bearer)).get();
      if (claimed.exists) throw new MatchError('Este perfil já tem conta. Entre com e-mail e senha.', 401);
      return; // Unlinked legacy clients remain supported during migration.
    }
    const user = await this.user(req);
    setIdentity(req, await this.account(user.uid));
  }

  async read(req: IncomingMessage): Promise<{playerId: string}> {
    const user = await this.user(req);
    return {playerId:(await this.account(user.uid)).playerId};
  }

  async link(req: IncomingMessage, body: unknown): Promise<{playerId: string}> {
    const user = await this.user(req);
    const data = body as Record<string, unknown> | null;
    const playerId = data?.playerId;
    const legacyToken = data?.legacyToken;
    const matchId = data?.matchId;
    const validName = typeof playerId === 'string' && playerId === playerId.trim() &&
      (legacyToken ? playerId.length > 0 && playerId.length <= 64 && !/[\x00-\x1f]/.test(playerId) : /^[\p{L}\p{N} ._-]{1,24}$/u.test(playerId));
    if (!validName || ['__proto__', 'prototype', 'constructor'].includes(playerId as string)) {
      throw new MatchError('Use um nome de 1 a 24 letras, números, espaços, _ ou -.', 400);
    }
    if (legacyToken !== undefined && (typeof legacyToken !== 'string' || !/^[a-f0-9]{64}$/.test(legacyToken))) throw new MatchError('Sessão antiga inválida.', 400);
    const hash = sha256(typeof legacyToken === 'string' ? legacyToken : randomBytes(32).toString('hex'));
    const accountRef = this.db.collection('elementosAccounts').doc(user.uid);
    const claimRef = this.db.collection('elementosIdentityClaims').doc(hash);
    await this.db.runTransaction(async tx => {
      const existing = await tx.get(accountRef);
      if (existing.exists) {
        const account = existing.data() as AccountIdentity;
        if (account.playerId !== playerId || legacyToken && account.credentialHash !== hash) throw new MatchError('A conta já possui outro perfil. Nenhum progresso foi substituído.', 409);
        return;
      }
      const claim = await tx.get(claimRef);
      if (claim.exists) throw new MatchError('Esta sessão já está vinculada a outra conta.', 409);
      if (legacyToken) {
        const key = sha256(JSON.stringify([playerId, hash]));
        const profile = await tx.get(this.db.collection('elementosProfiles').doc(key));
        if (!profile.exists) {
          if (typeof matchId !== 'string' || !/^[A-F0-9]{6}$/.test(matchId)) throw new MatchError('Informe a última sala para comprovar o perfil antigo.', 400);
          const match = await tx.get(this.db.collection('elementosMatches').doc(matchId));
          if (!match.exists || match.data()?.credentials?.[playerId] !== hash) throw new MatchError('Não foi possível comprovar a sessão antiga. Nenhum dado foi alterado.', 403);
        }
      }
      tx.create(accountRef, {playerId, credentialHash:hash, createdAt:Date.now()});
      tx.create(claimRef, {uid:user.uid});
    });
    this.cache.delete(user.uid);
    return {playerId: playerId as string};
  }
}
