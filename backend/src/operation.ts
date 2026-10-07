/** Production must not silently fall back to an ephemeral, unauthenticated store. */
export function validateOperation(env: NodeJS.ProcessEnv): void {
  if ((env.RENDER === 'true' || env.NODE_ENV === 'production') &&
      (env.MATCH_STORE !== 'firestore' || !env.FIREBASE_PROJECT_ID?.trim())) {
    throw new Error('Produção exige MATCH_STORE=firestore e FIREBASE_PROJECT_ID. Inicialização interrompida.');
  }
}

export function publicRevision(env: NodeJS.ProcessEnv): string {
  const commit = env.RENDER_GIT_COMMIT ?? env.APP_COMMIT;
  return commit && /^[a-f0-9]{40}$/i.test(commit) ? commit.slice(0,12) : 'local';
}
