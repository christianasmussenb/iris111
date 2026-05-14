# Frontend folder

This folder contains the mobile-first UI for IRIS111.

## Current app

- `index.html`: single-screen console for pace, pending recommendations, dashboard, and feedback.
- `app.js`: browser-side consumer of the IRIS REST API.
- `styles.css`: responsive shell and operational cards.
- The same screen also includes a tiny POS mock injector that POSTs to `/pos/ingest`.

## How to use

1. Open `frontend/index.html` in a browser, or serve the folder with any static server.
2. Set the API base URL in the connection panel.
3. Load pace, pending recommendations, dashboard, and submit feedback from the same screen.
4. In IRIS, the same UI is also exposed as the public web app `/store-console/`.

## Notes

- The UI expects the IRIS REST API exposed under `/api` by default.
- Feedback is sent as form-encoded payload so it matches the current IRIS controller contract.
- The pending recommendations endpoint now uses the store code in the route path.
- POS mock injections use JSON over REST and go to `/pos/ingest`.
- When the UI is loaded from IRIS CSP, it auto-switches its API base to `/csp/user/API.UIController.cls`.
- When the UI is loaded from `/csp/store-console/`, it auto-switches its API base to `/csp/store-console`.
