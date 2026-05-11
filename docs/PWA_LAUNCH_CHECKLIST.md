# PWA, Android, and iOS Launch Checklist

## Installability

- `manifest.webmanifest` or `manifest.json` exists in the production output.
- `display` is `standalone`.
- `start_url` and `scope` are correct for the deployed base path.
- 192x192 and 512x512 icons exist with both `any` and `maskable` purposes.
- `apple-touch-icon.png` exists.
- iOS splash images exist for current phone and tablet sizes.
- `theme-color`, `apple-mobile-web-app-capable`, and status-bar metadata are present.
- A service worker is registered and exported as `sw.js`.

## Runtime

- App boots over HTTPS.
- Offline refresh returns the app shell rather than a browser error.
- Auth redirects return to the installed app context.
- API failures render visible, recoverable states.
- Mobile viewport does not horizontally scroll.
- Keyboard, screen reader labels, and focus order work for critical flows.

## Android

- Validate install prompt on Chrome Android.
- Validate standalone launch from home screen.
- If Capacitor exists, run `npx cap sync android` after production build.
- Verify network security config disallows cleartext unless explicitly needed.
- Confirm app icon and splash render on a physical device or emulator.

## iOS

- Validate Add to Home Screen in Safari.
- Verify status bar color and safe-area behavior.
- Test auth redirects, camera/file uploads, and push-notification prompts if used.
- If Capacitor exists, run `npx cap sync ios` on macOS before Xcode archive.
- Confirm privacy policy and support URL are reachable.

## Store Assets

- App name and short description.
- 1024x1024 store icon.
- Phone screenshots.
- Tablet screenshots when supported.
- Privacy policy URL.
- Support URL.
- Data safety answers.

## CI Gate

Use `node-pwa-build.yml` to enforce installability basics on every pull request.
