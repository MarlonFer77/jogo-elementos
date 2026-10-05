import { createServer } from "./server.js";
import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { FirestoreMatchStore } from './matches/firestore-match-store.js';
import {getAuth} from 'firebase-admin/auth';
import {Accounts} from './auth/accounts.js';

const port = Number(process.env.PORT ?? 3000);

const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const firestoreEnabled = process.env.MATCH_STORE === 'firestore';
const store = firestoreEnabled ? new FirestoreMatchStore(getFirestore(initializeApp({
  credential: serviceAccount ? cert(JSON.parse(serviceAccount)) : applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID ?? 'elements-1173d',
}))) : undefined;

const accounts = firestoreEnabled ? new Accounts(getFirestore(), token => getAuth().verifyIdToken(token)) : undefined;
createServer(store, accounts).listen(port, () => {
  console.log(`backend ouvindo em http://localhost:${port}`);
});
