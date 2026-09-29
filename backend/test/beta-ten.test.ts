import {test} from 'node:test';
import assert from 'node:assert/strict';
import type {AddressInfo} from 'node:net';
import {createServer} from '../src/server.js';
import {MatchStore} from '../src/matches/match-store.js';

test('five rooms / ten sessions can prepare, poll and play without crossing limits', async () => {
  const server = createServer(new MatchStore()).listen(0);
  const base = `http://localhost:${(server.address() as AddressInfo).port}`;
  const call = async (player: number, path: string, body?: object) => {
    const response = await fetch(base + path, {method: body ? 'POST' : 'GET',
      headers:{Authorization:`Bearer ${player.toString(16).padStart(64,'0')}`,'Content-Type':'application/json'},
      ...(body ? {body:JSON.stringify(body)} : {})});
    assert.ok(response.ok, `${path}: ${response.status}`);
    return await response.json() as any;
  };
  try {
    const ids = await Promise.all(Array.from({length:5}, async (_, i) => {
      const a = i * 2 + 1, b = a + 1;
      let m = await call(a,'/matches',{playerAId:`p${a}`});
      m = await call(b,`/matches/${m.id}/join`,{playerBId:`p${b}`});
      for (const p of [a,b]) m = await call(p,`/matches/${m.id}/configure`,
        {playerId:`p${p}`,kind:'prepare',ids:['fire','wind'],revision:m.revision});
      for (const p of [a,b]) {
        const result = await call(p,`/matches/${m.id}/turns`,
          {actorId:`p${p}`,elementIds:['fire'],revision:m.revision});
        m = result.match;
      }
      assert.equal(m.state.hp[`p${a}`].current,95);
      assert.equal(m.state.hp[`p${b}`].current,95);
      await Promise.all([call(a,`/matches/${m.id}`),call(b,`/matches/${m.id}`)]);
      return m.id;
    }));
    assert.equal(new Set(ids).size,5);
  } finally { server.closeAllConnections(); server.close(); }
});

test('auth precedes storage; room creation throttles with Retry-After; oversized JSON is rejected', async () => {
  let reads = 0;
  const store = new MatchStore();
  const run = store.run.bind(store);
  store.run = (...args) => { reads++; return run(...args); };
  const server = createServer(store).listen(0);
  const base = `http://localhost:${(server.address() as AddressInfo).port}`;
  const headers = {Authorization:`Bearer ${'a'.repeat(64)}`,'Content-Type':'application/json'};
  try {
    assert.equal((await fetch(base+'/matches/ABC123')).status,401);
    assert.equal(reads,0);
    assert.equal((await fetch(base+'/matches/%GG',{headers})).status,404);
    assert.equal((await fetch(base+'/health')).status,200);
    const big = await fetch(base+'/matches',{method:'POST',headers,body:JSON.stringify({playerAId:'x'.repeat(70000)})});
    assert.equal(big.status,413);
    for(let i=0;i<5;i++) assert.equal((await fetch(base+'/matches',{method:'POST',headers,body:'{"playerAId":"a"}'})).status,201);
    const throttled = await fetch(base+'/matches',{method:'POST',headers,body:'{"playerAId":"a"}'});
    assert.equal(throttled.status,429);
    assert.ok(Number(throttled.headers.get('retry-after')) > 0);
    assert.equal(throttled.headers.get('cache-control'),'no-store');
  } finally { server.closeAllConnections(); server.close(); }
});
