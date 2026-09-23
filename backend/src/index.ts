import { createServer } from "./server.js";
import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { FirestoreMatchStore } from './matches/firestore-match-store.js';

const port = Number(process.env.PORT ?? 3000);

const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const firestoreEnabled = process.env.MATCH_STORE === 'firestore';
const store = firestoreEnabled ? new FirestoreMatchStore(getFirestore(initializeApp({
  credential: serviceAccount ? cert(JSON.parse(serviceAccount)) : applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID ?? 'elements-1173d',
}))) : undefined;

createServer(store).listen(port, () => {
  console.log(`backend ouvindo em http://localhost:${port}`);
});
