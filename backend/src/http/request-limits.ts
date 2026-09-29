import { createHash } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { sendJson } from './respond.js';

/** Single-process beta guard. Never trusts forwarded IP headers or stores tokens. */
export class RequestLimits {
  private readonly windows = new Map<string, {count: number; until: number}>();
  private active = 0;
  constructor(private readonly now = Date.now) {}

  private consume(key: string, limit: number, duration: number): number {
    const now = this.now();
    let window = this.windows.get(key);
    if (!window || window.until <= now) {
      if (this.windows.size >= 256) {
        for (const [id, value] of this.windows) if (value.until <= now) this.windows.delete(id);
        if (!this.windows.has(key) && this.windows.size >= 256) return 60;
      }
      window = {count: 0, until: now + duration};
      this.windows.set(key, window);
    }
    if (window.count >= limit) return Math.max(1, Math.ceil((window.until - now) / 1000));
    window.count++;
    return 0;
  }

  allow(req: IncomingMessage, res: ServerResponse, pathname: string): boolean {
    const reject = (status: number, seconds: number, message: string) => {
      res.setHeader('Retry-After', seconds);
      sendJson(res, status, {error: message});
      return false;
    };
    const globalWait = this.consume('global', 900, 60_000);
    if (globalWait) return reject(429, globalWait, 'Servidor recebeu muitas requisições. Aguarde antes de tentar novamente.');
    if (pathname.startsWith('/matches') && req.method !== 'OPTIONS') {
      const authorization = req.headers.authorization;
      if (!authorization || !/^Bearer [a-f0-9]{64}$/.test(authorization)) {
        sendJson(res, 401, {error: 'Credencial de sessão obrigatória. Atualize o aplicativo.'});
        return false;
      }
      const key = createHash('sha256').update(authorization).digest('hex');
      const wait = this.consume(`session:${key}`, 120, 60_000) ||
        (req.method === 'POST' ? this.consume(`write:${key}`, 60, 60_000) : 0) ||
        (req.method === 'POST' && pathname === '/matches'
          ? this.consume('create', 60, 600_000) || this.consume(`create:${key}`, 6, 600_000) : 0);
      if (wait) return reject(429, wait, 'Muitas tentativas. Aguarde antes de criar uma sala ou repetir a ação.');
    }
    if (this.active >= 40) return reject(503, 3, 'Servidor ocupado. Aguarde a sincronização.');
    this.active++;
    let released = false;
    const release = () => { if (!released) { released = true; this.active--; } };
    res.once('finish', release);
    res.once('close', release);
    return true;
  }
}
