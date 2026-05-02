# Dewprofi Frontend

This Vite app is only the temporary web shell for Dewprofi:

- unauthenticated users see the launch/login gate
- authenticated non-superusers stay on the locked launch gate
- superusers see the Flutter web app embedded from `/flutter/index.html`

Build the Flutter web payload before a production/static frontend build:

```sh
npm run build:with-flutter
```

For local Vite-only work where the Flutter bundle already exists:

```sh
npm run dev
```

The iframe URL can be overridden with:

```sh
VITE_FLUTTER_APP_URL=/flutter/index.html
```
