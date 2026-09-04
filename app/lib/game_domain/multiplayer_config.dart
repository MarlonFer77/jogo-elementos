/// Backend base URL for the Multiplayer client. `localhost:3000` is where
/// `npm run dev` serves it (see backend/package.json, .claude/launch.json)
/// — there's no deployed backend yet (ver ARCHITECTURE.md), so this only
/// works with the backend running locally alongside the app.
const defaultMultiplayerBaseUrl = 'http://localhost:3000';
