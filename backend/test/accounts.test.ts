import {test} from 'node:test';
import assert from 'node:assert/strict';
import type {AddressInfo} from 'node:net';
import type {Firestore} from 'firebase-admin/firestore';
import {Accounts} from '../src/auth/accounts.js';
import {sha256} from '../src/auth/identity.js';
import {MatchStore} from '../src/matches/match-store.js';
import {createServer} from '../src/server.js';

async function setup(run: (url:string, data:Map<string,unknown>, roomId:string) => Promise<void>) {
  const data = new Map<string,unknown>();
  const snapshot = (key:string) => ({exists:data.has(key),data:()=>data.get(key)});
  const db = {collection:(c:string)=>({doc:(id:string)=>({key:`${c}/${id}`,get:async()=>snapshot(`${c}/${id}`)})}),
    runTransaction:async(fn:Function)=>{
      const pending: Array<[string,unknown]> = [];
      const result = await fn({get:async(ref:{key:string})=>snapshot(ref.key),
        create:(ref:{key:string},value:unknown)=>{assert.equal(data.has(ref.key),false);pending.push([ref.key,value]);}});
      for(const [key,value] of pending) data.set(key,value);
      return result;
    }} as unknown as Firestore;
  const accounts = new Accounts(db, async token => {
    if(token === 'invalid.jwt.sig') throw new Error('invalid signature');
    return {uid:token.split('.')[0]!,email_verified:token !== 'unverified.jwt.sig',firebase:{sign_in_provider:'password'}};
  });
  const memory = new MatchStore();
  const match = memory.create('ana','a'.repeat(64));
  data.set(`elementosMatches/${match.id}`,memory.snapshot(match.id));
  const server = createServer(memory,accounts).listen(0);
  try { await run(`http://localhost:${(server.address() as AddressInfo).port}`,data,match.id); }
  finally { server.closeAllConnections(); server.close(); }
}

const request = (url:string,token:string,body?:unknown) => fetch(url,{method:body ? 'POST':'GET',
  headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});

test('link preserves legacy room, binds verified identity and revokes legacy login', async()=>setup(async(url,data,id)=>{
  const before = structuredClone(data.get(`elementosMatches/${id}`));
  const link = {playerId:'ana',legacyToken:'a'.repeat(64),matchId:id};
  assert.equal((await request(`${url}/account`,'unverified.jwt.sig',link)).status,403);
  assert.equal((await request(`${url}/account`,'invalid.jwt.sig',link)).status,401);
  assert.equal((await request(`${url}/account`,'user.jwt.sig',link)).status,200);
  assert.deepEqual(data.get(`elementosMatches/${id}`),before);
  assert.deepEqual(await (await request(`${url}/account`,'user.jwt.sig')).json(),{playerId:'ana'});
  assert.equal((await request(`${url}/matches/${id}`,'user.jwt.sig')).status,200);
  assert.equal((await request(`${url}/matches/${id}`,'a'.repeat(64))).status,401);
  assert.equal((await request(`${url}/matches`,'user.jwt.sig',{playerAId:'other'})).status,403);
  assert.equal((await request(`${url}/matches`,'user.new.signature',{playerAId:'ana'})).status,201);
  assert.equal((await request(`${url}/matches/${id}`,`digest:${sha256('a'.repeat(64))}`)).status,401);
}));

test('claim is exclusive and retries do not replace any profile/account',async()=>setup(async(url,data,id)=>{
  const link = {playerId:'ana',legacyToken:'a'.repeat(64),matchId:id};
  await request(`${url}/account`,'user.jwt.sig',link);
  const before = structuredClone([...data.entries()]);
  assert.equal((await request(`${url}/account`,'user.jwt.sig',link)).status,200);
  assert.deepEqual([...data.entries()],before);
  assert.equal((await request(`${url}/account`,'other.jwt.sig',link)).status,409);
  assert.equal((await request(`${url}/account`,'user.jwt.sig',{playerId:'different'})).status,409);
  assert.deepEqual([...data.entries()],before);
}));

test('legacy proof is required; matching finished profile can be recovered without room',async()=>setup(async(url,data,id)=>{
  const link = {playerId:'ana',legacyToken:'b'.repeat(64),matchId:id};
  assert.equal((await request(`${url}/account`,'user.jwt.sig',link)).status,403);
  const key = sha256(JSON.stringify(['ana',sha256('a'.repeat(64))]));
  const profile = {progress:{discoveries:['lava']},skills:['unlock_fire']};
  data.set(`elementosProfiles/${key}`,profile);
  assert.equal((await request(`${url}/account`,'user.jwt.sig',{playerId:'ana',legacyToken:'a'.repeat(64)})).status,200);
  assert.deepEqual(data.get(`elementosProfiles/${key}`),profile);
}));

test('fresh account has private identity; two accounts sharing a name cannot access each other',async()=>setup(async(url)=>{
  assert.equal((await request(`${url}/account`,'user.jwt.sig')).status,404);
  await request(`${url}/account`,'user.jwt.sig',{playerId:'ana'});
  await request(`${url}/account`,'other.jwt.sig',{playerId:'ana'});
  const result = await request(`${url}/matches`,'user.jwt.sig',{playerAId:'ana'});
  const match = await result.json() as {id:string};
  assert.equal(result.status,201);
  assert.equal((await request(`${url}/matches/${match.id}`,'other.jwt.sig')).status,403);
}));
