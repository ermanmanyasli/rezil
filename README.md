# REZİL iOS MVP

Native SwiftUI prototype for reporting and validating local problems.

## Supabase setup

1. In Supabase SQL Editor, run [`supabase/migrations/001_initial.sql`](supabase/migrations/001_initial.sql).
2. In Google Cloud, create an iOS OAuth client and copy its client ID and reversed client ID into the `GOOGLE_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID` User-Defined build settings.
3. In Xcode, set the existing `SUPABASE_URL` and `SUPABASE_ANON_KEY` User-Defined build settings on the `rezil` app target. The explicit Info.plist and native Google URL scheme are already in the project.
4. Enable Google in Supabase Authentication > Providers. Add both the iOS client ID and the Web client ID to Client IDs; add the Web client secret as required by Supabase.

Supported now: native Google Sign-In. Apple remains intentionally disabled until the Apple Developer account is available.

Use the Supabase project URL and publishable/anon key only. Never put the service-role key in the iOS app.

## Run

1. Open `rezil.xcodeproj` in Xcode.
2. Select an iPhone simulator or a connected iPhone.
3. Press Run.

Camera capture requires a physical iPhone. In the simulator, the camera button falls back to the photo library.

## Included

- Apple MapKit complaint map with strongest/newest/nearby sorting
- One-tap “Bende gördüm” validation
- Camera and photo-library input
- Automatic location and draggable map location picker
- 240-character report, category selection, and local publishing flow
- Discover feed backed by Supabase
- Google OAuth, email/password, magic-link authentication, and Keychain-backed sessions
- Supabase profiles, reports, report media, and verification persistence

The app has no seeded or fallback report data. Without Supabase configuration, it shows the sign-in/setup state instead of mock content.
