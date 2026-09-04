/// Backend base URL for the Multiplayer client. Points at the real
/// deployed backend (Render, free tier — ver DECISION-028) so Multiplayer
/// works without anyone running `npm run dev` locally. Free tier spins
/// down after ~15min idle — the first request after that takes longer
/// (cold start) while it wakes back up.
///
/// For local backend development, pass a `MultiplayerClient` pointing at
/// `http://localhost:3000` explicitly instead of relying on this default
/// (every screen that takes one already accepts an override).
const defaultMultiplayerBaseUrl = 'https://jogo-elementos-backend.onrender.com';
