// One-time operator utility. Uses an existing Firebase CLI login; never prints
// credentials. Run from backend with FIREBASE_CLI_LIB pointing to its lib folder.
const { createRequire } = require('node:module');
const path = require('node:path');
const fs = require('node:fs');
const cli = createRequire(path.join(process.env.FIREBASE_CLI_LIB, 'api.js'));
const project = 'elements-1173d';
const email = `elementos-render@${project}.iam.gserviceaccount.com`;

async function main() {
  const account = cli('./auth').getProjectDefaultAccount(process.cwd());
  await cli('./requireAuth').requireAuth({...account, project, nonInteractive: true});
  const { Client } = cli('./apiv2');
  async function call(origin, method, url, body) {
    const response = await new Client({urlPrefix: origin}).request({method, path: url, body,
      skipLog: {body: true, resBody: true}});
    return response.body;
  }
  const billing = await call('https://cloudbilling.googleapis.com', 'GET', `/v1/projects/${project}/billingInfo`);
  if (billing.billingEnabled) throw new Error('Billing enabled: review cost controls before proceeding.');
  console.log('Billing disabled; no paid plan enabled.');
  const iam = 'https://iam.googleapis.com';
  const accounts = await call(iam, 'GET', `/v1/projects/${project}/serviceAccounts`);
  if (!(accounts.accounts ?? []).some(account => account.email === email)) {
    await call(iam, 'POST', `/v1/projects/${project}/serviceAccounts`, {
      accountId: 'elementos-render', serviceAccount: {displayName: 'Elementos Render Firestore'},
    });
  }
  const resource = 'https://cloudresourcemanager.googleapis.com';
  const policy = await call(resource, 'POST', `/v1/projects/${project}:getIamPolicy`, {});
  const member = `serviceAccount:${email}`;
  const binding = (policy.bindings ?? []).find(b => b.role === 'roles/datastore.user' && !b.condition);
  if (!binding?.members?.includes(member)) {
    if (binding) binding.members.push(member);
    else (policy.bindings ??= []).push({role: 'roles/datastore.user', members: [member]});
    await call(resource, 'POST', `/v1/projects/${project}:setIamPolicy`, {policy});
  }
  console.log(`Service account ready: ${email}; role: roles/datastore.user.`);
  if (process.argv.includes('--create-key')) {
    const target = path.resolve('data/firebase-service-account.json');
    if (fs.existsSync(target)) throw new Error('Key file already exists; refusing to create another key.');
    const key = await call(iam, 'POST', `/v1/projects/${project}/serviceAccounts/${email}/keys`, {
      privateKeyType: 'TYPE_GOOGLE_CREDENTIALS_FILE', keyAlgorithm: 'KEY_ALG_RSA_2048',
    });
    fs.mkdirSync(path.dirname(target), {recursive:true});
    const accountJson = Buffer.from(key.privateKeyData, 'base64').toString('utf8');
    fs.writeFileSync(target, accountJson, {mode:0o600, flag:'wx'});
    fs.writeFileSync(path.resolve('data/render.env'),
      `MATCH_STORE=firestore\nFIREBASE_PROJECT_ID=${project}\nFIREBASE_SERVICE_ACCOUNT_JSON='${JSON.stringify(JSON.parse(accountJson))}'\n`,
      {mode:0o600, flag:'wx'});
    console.log('Credential written to ignored backend/data file. No secret printed.');
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
