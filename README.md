# REZİL iOS MVP

Native SwiftUI prototype for reporting and validating local problems.

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
- Discover feed and profile shell

Data is intentionally in memory for this first UI build. Authentication, remote photo storage, comments, moderation, notifications, Supabase, and the institutional API are the next backend phase.
