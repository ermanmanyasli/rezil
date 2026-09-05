# REZİL — Product and Engineering Specification

**Document status:** Living handoff specification  
**Platform:** Native iOS  
**Language:** Turkish-first  
**Project name:** `rezil`  
**Bundle identifier:** `com.manyasli.rezil`  
**Owner:** Erman Manyaslı  
**Last updated:** 2026-09-04

## 1. One-line product definition

REZİL is a location-based civic reporting app where anyone can document a real-world local problem in seconds, place it on a map, and let nearby people verify, discuss, and strengthen the report.

## 2. Vision

Many local problems are visible to citizens but invisible to the organizations responsible for solving them. Reports are scattered across social media, call centers, municipal systems, private messages, and personal photo galleries. They are difficult to aggregate, validate, prioritize, and act on.

REZİL turns these observations into structured, location-aware, evidence-based records.

The long-term product has two sides:

1. **Citizens use it free of charge** to report and discover local problems.
2. **Institutions pay for structured access** to aggregated reports, trends, evidence, prioritization, dashboards, exports, alerts, or APIs.

The valuable asset is not merely a stream of complaints. It is a continuously growing, structured dataset containing where a problem exists, when it was observed, what type of problem it is, how much supporting evidence exists, how many people are affected, whether it remains active, and which organization may be responsible.

## 3. Product principles

### 3.1 Reporting must take seconds

The primary action is always visible as a large `+` button. A user should be able to open the app, take a photo, accept or adjust the detected location, write one or two sentences, and publish.

Target completion time: **20–30 seconds**.

### 3.2 The map is the product

The default screen is a map of nearby reports. Users should immediately understand what is happening around them and which problems have the strongest local support.

### 3.3 Verification, not likes

Do not describe the primary social action as “like” or “upvote.” Use language grounded in real observation:

- `Bende gördüm` — I saw this too.
- Later: `Ben de etkileniyorum` — This affects me too.
- Later: `Hâlâ devam ediyor` — It is still unresolved.
- Later: `Çözüldü` — It appears resolved.

These actions produce more defensible institutional data than generic engagement.

### 3.4 Evidence over outrage

The brand may be sharp and provocative, but the product should reward accurate, useful, civil reports. The interface must not incentivize harassment, insults, targeting individuals, or viral outrage without evidence.

### 3.5 Native, light, and calm

Use native SwiftUI controls, MapKit, system typography, haptics, responsive transitions, and restrained motion. The experience should feel fast and polished, not like a heavy social network.

### 3.6 Structure data from day one

Even before a paid API exists, all backend entities and events should be designed so institutions can later query data consistently by geography, category, status, time, severity, support, and responsible organization.

### 3.7 Onboarding must explain the mission fast

First-time users should see a short onboarding that explains what REZİL is, why it exists, and what kind of behavior the app rewards.

- Keep onboarding to **2-3 short screens**
- Focus on the product vision, not feature tours
- Make the tone direct, calm, and motivating
- End onboarding by asking for location permission with a plain-language reason
- Do not ask for signup during onboarding unless the user is about to create content

The onboarding should help a first-time user understand:

1. REZİL is a map of real local problems.
2. The app turns observations into structured, useful civic data.
3. Verification, evidence, and resolution matter more than outrage.

## 4. Brand

### Name

**REZİL** (`rezil.net`)

### Wordmark

Use `REZ!L`, where the red exclamation mark visually replaces the Turkish dotted `İ`. The intended reading is still “REZİL.”

### Visual direction

- Heavy, condensed, uppercase wordmark
- Near-black primary text
- Vivid warning red accent
- Minimal, bold, slightly provocative
- Avoid generic speech bubbles, megaphones, gradients, glossy 3D effects, or corporate stock-logo aesthetics
- Compact app/social icon: `R!` in white on a red field

### Core color

Current prototype accent: approximately `#FF2417`.

### Possible tagline

`Gördüğün rezilliği bildir.`

This tagline is optional and should not appear on every screen.

## 5. Target users

### Citizen reporter

Notices broken sidewalks, blocked accessibility spaces, trash, road damage, lighting failures, illegal dumping, unsafe infrastructure, or similar public/local issues. Wants a faster and more visible channel than a formal petition.

### Nearby resident

Wants to see problems around home, work, school, or daily routes. Can verify a report, add evidence, comment, follow updates, or confirm resolution.

### Institutional customer — later phase

Municipalities, public bodies, infrastructure operators, property/site management, utility providers, mobility companies, insurers, mapping/data companies, research organizations, media, NGOs, and other organizations that need structured local issue data.

### Moderator/operator

Reviews abusive, duplicate, dangerous, unlawful, privacy-invasive, misleading, or low-quality content and handles appeals.

## 6. Core user journey

### First launch

1. Show a short onboarding sequence that explains the mission and vision.
2. Request location permission with a plain-language explanation.
3. Open the map centered on the user’s approximate area.
4. Keep browsing and reading available without forcing account creation.

Avoid a long onboarding carousel.

### First-time onboarding content

Suggested sequence:

1. **REZİL ne işe yarar?**
   - `Mahallendeki gerçek sorunları haritada topla.`
   - `Çözüme giden yolu görünür hale getir.`
2. **Neden farklı?**
   - `Yorum değil, gözlem önemlidir.`
   - `Bende gördüm, hâlâ devam ediyor, çözüldü gibi sinyaller veri üretir.`
3. **Konum izni**
   - `Yakındaki sorunları gösterebilmek için konumuna ihtiyacımız var.`
   - `İstersen haritayı elle de gezebilirsin ama en iyi deneyim için izin öneriyoruz.`

The onboarding is not a feature tutorial. It should communicate purpose, trust, and the value of location as quickly as possible.

### Create a report

1. User taps the persistent large `+` button.
2. Camera opens as the preferred action; photo library remains available.
3. User captures or selects one photo.
4. Current location is detected automatically.
5. User may move the map under a fixed center pin to correct the location.
6. User writes a concise description, maximum 240 characters.
7. User chooses or confirms a category.
8. User taps `Haritaya bırak`.
9. The report appears on the map immediately with a satisfying but subtle animation and haptic feedback.

Minimum publishing requirements for MVP:

- One photo
- A valid coordinate
- Non-empty description
- Category
- Authenticated user

### Discover reports

The user can browse:

- `En güçlü`: highest verified/relevant reports in the visible map area
- `Yeni`: most recently created
- `Yakınımda`: distance-weighted nearby reports
- Later: followed areas, categories, unresolved/resolved, date range

### Open a report

Report detail should include:

- Photos and later evidence gallery
- Description
- Category
- Approximate location and map
- Creation time
- Reporter identity at an appropriate privacy level
- Verification count
- Comments/contributions
- Status and history
- `Bende gördüm` action
- Share and report-content actions

### Strengthen a report

Users can:

- Verify that they also saw it
- Add a comment
- Add another photo/evidence later
- Indicate they are affected later
- Confirm that it still exists later
- Suggest that it has been resolved later

### Account creation rules

Browsing, reading, and discovering reports should remain available without signup.

Authentication is required only for data-creating actions that change the shared dataset:

- Publishing a new report
- Adding a comment
- Adding supporting evidence to an existing report
- Applying verification/support signals such as `Bende gördüm`
- Any future user-generated content or moderation-relevant contribution

This means `Apple ile devam et` is not part of first launch by default. Instead, present sign-in only when the user attempts one of the actions above.

When sign-in is requested:

- Explain that signing in is required to protect the dataset from spam and abuse
- Make it clear that reading the map does not require an account
- Keep the flow short and focused on the action the user already tried to take
- Preserve the draft if the user decides to sign in later

## 7. Information architecture

Primary bottom navigation:

1. **Harita** — default local map and report selection
2. **Keşfet** — ranked/list presentation of reports
3. **Profil** — user contributions, saved/followed items, settings

The large central `+` floats above navigation and launches report creation from every primary tab.

Do not add more primary tabs until usage proves the need.

## 8. MVP scope

### Must have

- Native SwiftUI application
- Apple MapKit map
- Current-location permission and centering
- Visible report pins with support count
- Strongest/newest/nearby ordering
- Camera and photo-library input
- Location confirmation/correction
- Short description and category
- Create/publish report
- Report detail
- `Bende gördüm` verification
- Comments
- Optional sign in with Apple for creation actions only
- User profile and own reports
- Remote database and image storage
- Basic content reporting and moderation controls
- Loading, empty, offline, permission-denied, and error states
- Privacy policy and terms links before public release

### Should have shortly after MVP

- Push notifications for comments, verification milestones, status changes, and nearby important reports
- Duplicate detection based on location, time, category, and image/text similarity
- Add evidence to an existing report instead of creating a duplicate
- Follow an area or report
- Report status lifecycle
- Admin moderation console
- Institution ownership/routing rules
- Shareable public web links
- Basic analytics and operational monitoring

### Not required for initial citizen MVP

- Paid institutional dashboard
- Public commercial API
- Complex gamification
- Direct messaging
- Follower counts or creator-style popularity systems
- Advertising
- Cross-platform Android client

## 9. Current implementation state

The existing Xcode project is a native SwiftUI prototype and currently contains:

- `rezilApp.swift` — application entry point
- `ContentView.swift` — primary tab shell, persistent add button, sheet presentation
- `Complaint.swift` — complaint and category domain models
- `ComplaintStore.swift` — in-memory sample data and support toggling
- `ComplaintMapView.swift` — MapKit map, pins, ranking controls, selected report card
- `NewComplaintView.swift` — photo, description, category, location, and local publish flow
- `LocationService.swift` — Core Location permission, current location, reverse geocoding
- `CameraPicker.swift` — UIKit camera bridge for SwiftUI
- `DiscoverView.swift` — ranked report feed
- `ProfileView` currently lives inside `DiscoverView.swift` — profile shell
- `README.md` — basic run instructions

The prototype also contains Info.plist-generated permission descriptions for camera, photo library, and location. `Combine` is explicitly imported in `ComplaintStore.swift` and `LocationService.swift` for `ObservableObject` and `@Published` support.

### Current limitations

- Data is in memory and disappears after app restart.
- Sample reports are centered in Çankaya, Ankara.
- No backend, authentication, remote image upload, comments implementation, or push notifications yet.
- Camera requires a physical iPhone; the simulator falls back to the photo library.
- The prototype was authored outside macOS, so every change must be compiled and validated locally in Xcode before proceeding.

## 10. Recommended technical architecture

### iOS

- SwiftUI
- MapKit
- Core Location
- PhotosUI
- AVFoundation or the existing `UIImagePickerController` bridge for camera
- Sign in with Apple / AuthenticationServices
- async/await networking
- MVVM or a similarly lightweight feature-oriented architecture

Avoid unnecessary third-party UI and architecture dependencies.

### Backend recommendation

Use **Supabase** for the first production backend:

- PostgreSQL database
- PostGIS for geo queries
- Supabase Auth with Apple identity integration
- Supabase Storage for report images
- Row Level Security
- Edge Functions for protected server actions
- Realtime only where it creates clear product value

The backend must own authorization and trust-sensitive calculations. Do not treat the iOS client as authoritative for support counts, report status, moderation state, or entitlements.

### Suggested iOS layers

```text
App
├── Core
│   ├── Networking
│   ├── Authentication
│   ├── Location
│   ├── Media
│   └── DesignSystem
├── Features
│   ├── Map
│   ├── ReportCreation
│   ├── ReportDetail
│   ├── Discover
│   ├── Comments
│   └── Profile
├── Models
└── Services
```

Prefer feature folders once the prototype grows. Do not over-engineer with a large framework before the remote data flow is established.

## 11. Proposed data model

All identifiers should be UUIDs. All timestamps should be stored in UTC. Coordinates should use PostGIS geography/geometry in the database.

### `profiles`

- `id` — references authenticated user
- `display_name`
- `avatar_path`
- `home_city` — optional, not an exact home address
- `reputation_score` — internal/optional
- `created_at`
- `suspended_at` — nullable

### `reports`

- `id`
- `author_id`
- `description`
- `category_id`
- `location` — PostGIS point
- `public_location_label`
- `geohash` — optional optimization
- `status` — `open`, `acknowledged`, `in_progress`, `resolved`, `rejected`, `archived`
- `visibility` — `public`, `limited`, `hidden`
- `support_count` — cached/server-maintained
- `comment_count` — cached/server-maintained
- `evidence_count` — cached/server-maintained
- `created_at`
- `updated_at`
- `resolved_at` — nullable
- `responsible_organization_id` — nullable
- `duplicate_of_report_id` — nullable
- `moderation_state`

### `report_media`

- `id`
- `report_id`
- `uploader_id`
- `storage_path`
- `media_type`
- `captured_at` — when available
- `created_at`
- `moderation_state`
- `blurred_storage_path` — optional

Do not expose raw storage paths or permanent public bucket URLs if signed access is more appropriate.

### `report_support`

- `report_id`
- `user_id`
- `support_type` — initially `seen`; later `affected`, `still_present`, `resolved`
- `created_at`
- `approximate_location_at_action` — optional and privacy-controlled

Unique constraint should prevent the same user from applying the same active support type repeatedly.

### `comments`

- `id`
- `report_id`
- `author_id`
- `body`
- `parent_comment_id` — nullable; avoid deep nesting
- `created_at`
- `edited_at` — nullable
- `deleted_at` — nullable
- `moderation_state`

### `categories`

- `id`
- `slug`
- `display_name_tr`
- `icon`
- `active`
- `default_responsible_organization_type`

Initial categories:

- Yol
- Kaldırım
- Çöp
- Aydınlatma
- Erişilebilirlik
- Park/işgal
- Su/kanalizasyon
- Gürültü
- Çevre
- Diğer

### `organizations`

- `id`
- `name`
- `organization_type`
- `service_area` — PostGIS polygon/multipolygon
- `categories_handled`
- `contact_metadata`
- `verified`

### `content_flags`

- `id`
- `reporter_user_id`
- `target_type`
- `target_id`
- `reason`
- `notes`
- `status`
- `created_at`
- `reviewed_at`

### `status_events`

- `id`
- `report_id`
- `from_status`
- `to_status`
- `actor_type` — user, moderator, organization, system
- `actor_id`
- `evidence`
- `created_at`

Keep an append-only status history even when `reports.status` stores the current state.

## 12. Ranking and map behavior

The map must not rank only by raw support count. A future server-computed priority score should combine:

- Unique verified users
- Recency
- Distance to viewing user or map center
- Severity/category
- Additional evidence count
- “Still present” confirmations
- Resolution signals
- Trust/reputation signals
- Duplicate aggregation
- Abuse/manipulation risk

Illustrative logic only:

```text
priority = support_quality × recency_decay × severity_weight × evidence_confidence
```

Do not hard-code this formula as the business model. Instrument components separately so ranking can evolve.

### Map clustering

At lower zoom levels, cluster reports. Cluster labels should show meaningful volume or priority, not create an unreadable wall of pins. When a report is selected, show a compact bottom card and allow navigation to detail.

### Location privacy

- Public infrastructure reports may display an accurate issue coordinate.
- Never expose a reporter’s live or historical personal location.
- Strip unnecessary image metadata before public upload.
- Warn or automatically protect reports that appear to reveal private homes, license plates, faces, children, or sensitive locations.

## 13. Comments and contribution rules

Comments exist to improve the report, not to create a general discussion forum.

Encourage:

- Additional factual context
- Date/time updates
- Alternative access routes
- Responsible department information
- Resolution evidence

Discourage or remove:

- Personal insults
- Doxxing
- Unverified accusations against identifiable people
- Political spam unrelated to the specific issue
- Phone numbers, personal addresses, or sensitive personal data
- Duplicate comments and coordinated manipulation

Initial comments can be chronological. Ranking and threading can come later.

## 14. Moderation, trust, and legal safety

This is a central product requirement, not an afterthought.

### Before upload

- Explain that users must report observable facts.
- Prohibit personal targeting and unlawful content.
- Offer automatic face and license-plate blurring when feasible.
- Strip EXIF metadata not required by the product.

### After upload

- Content flagging
- Rate limits for reports, supports, comments, and account creation
- Spam and duplicate detection
- Moderator queue and audit log
- Soft deletion and appeal process
- Ability to hide content without destroying evidence needed for review
- Account restrictions and suspension

### Trust signals

Potential future inputs:

- Account age
- Successful local verifications
- Reports later confirmed by others
- Reports resolved by institutions
- History of rejected or abusive content
- Device/account abuse patterns

Never expose a simplistic public “citizen score” without careful research.

### Legal/product review before launch

Obtain Turkish legal advice for KVKK, hosting/user-generated content obligations, terms, takedown processes, commercial data licensing, public-sector procurement, and image/privacy rules. The app must clearly distinguish user-submitted observations from verified legal findings.

## 15. Institutional product and monetization

Citizen access remains free. Monetization should come from helping organizations understand and act on the structured dataset.

Potential paid products:

- Geographic dashboard
- Category and trend analytics
- Prioritized work queue
- Alerts for service areas
- Evidence exports
- SLA/status workflow
- Organization responses visible to citizens
- CSV/GeoJSON export
- Webhooks
- API access
- Historical benchmarking
- White-label or embedded views

### API — later phase

Potential read endpoints:

```text
GET /v1/reports
GET /v1/reports/{id}
GET /v1/areas/{id}/summary
GET /v1/categories
GET /v1/organizations/{id}/reports
```

Filters should include bounding box or radius, category, status, created/updated time, support threshold, and responsible organization. Use pagination, scoped API keys, quotas, audit logs, and contract/version management.

Do not expose citizen PII through institutional products. Sell access to structured issue intelligence, not personal identities.

## 16. Analytics and success metrics

### North-star candidate

**Useful verified reports per active area**, where “useful” eventually includes meaningful verification, institutional acknowledgement, or resolution.

### Creation funnel

- Add-button tap
- Camera/library selection
- Photo accepted
- Location accepted/adjusted
- Description completed
- Category selected
- Publish success/failure
- Time to publish
- Abandonment step

### Community health

- Reports with at least one independent verification
- Median time to first verification
- Reports with additional evidence
- Comment quality/flag rate
- Duplicate rate
- Abuse rejection rate

### Outcome metrics

- Reports acknowledged by an institution
- Reports marked in progress
- Reports resolved
- Median time to resolution
- Resolution confirmation by citizens

### Retention

- Reporter return rate
- Nearby-resident weekly engagement
- Followed-area notification usefulness

Do not optimize raw complaint volume or outrage-driven engagement.

## 17. Non-functional requirements

- Fast launch and responsive map interactions
- Smooth behavior on current supported iPhones
- Graceful offline/read-only states
- Upload retry and progress indication
- Image compression before upload
- Pagination and server-side geo filtering
- Accessibility labels, Dynamic Type, sufficient contrast, VoiceOver support
- Turkish localization first, localization-ready strings from the start
- No secrets or service-role credentials in the app binary
- Structured logging without sensitive personal data
- Crash reporting and performance monitoring before public beta
- Unit tests for models/services and UI tests for the create-report happy path

## 18. Important UX states

Every primary feature must define:

- Loading
- Empty
- Error
- Offline
- Permission denied
- Auth required
- Uploading
- Upload failed/retry
- Content removed/moderated
- No reports in visible area

Specific copy should be human and direct. Avoid blaming the user.

Examples:

- Location denied: `Konumu otomatik bulamadık. Haritadan seçebilirsin.`
- Location prompt: `Yakındaki sorunları göstermek için konum izni gerekiyor.`
- Empty map: `Bu bölgede henüz bir şey bildirilmemiş.`
- Upload failure: `Şikâyet gönderilemedi. Taslağın kaybolmadı.`
- Auth required: `Bu işlemi yapmak için giriş yapman gerekiyor. Okumaya devam edebilirsin.`

## 19. Recommended delivery phases

### Phase 0 — stabilize the local prototype

1. Open the project in the latest installed Xcode.
2. Build for an iPhone simulator.
3. Fix all compiler errors before adding features.
4. Test camera and location on a physical iPhone.
5. Refactor `ProfileView` into its own file.
6. Add a real report-detail screen and comments UI shell.
7. Add basic unit/UI tests.

### Phase 1 — production backend foundation

1. Create separate development and production Supabase projects.
2. Add database migrations for profiles, reports, media, support, comments, categories, and flags.
3. Enable PostGIS and write geo query functions.
4. Configure Apple authentication.
5. Implement Row Level Security before exposing tables to the client.
6. Replace `ComplaintStore` in-memory behavior with repository/service abstractions.
7. Implement image upload, retry, and cleanup.

### Phase 2 — closed citizen beta

1. Moderation queue
2. Duplicate detection
3. Push notifications
4. Analytics and crash monitoring
5. TestFlight distribution
6. Focus beta on one defined area, preferably Çankaya/Ankara, to create density

### Phase 3 — institutional pilot

1. Validate data needs with one or two organizations.
2. Create a minimal web dashboard or scheduled export.
3. Test routing and acknowledgement/status updates.
4. Define data licensing, privacy, and commercial terms.
5. Build the public API only after repeated customer needs are clear.

## 20. Instructions for the next AI coding agent

1. Read this entire file before changing code.
2. Inspect the current repository and `git status`; preserve unrelated user changes.
3. Treat the existing SwiftUI project as a prototype, not a finalized architecture.
4. Work in small, compileable increments.
5. After every meaningful change, run an Xcode build or ask the user to paste the exact compiler output if the environment cannot run Xcode.
6. Fix compiler/runtime issues before expanding scope.
7. Use native Apple frameworks unless a third-party dependency has a clear, documented benefit.
8. Keep the main report flow extremely short. Do not add fields casually.
9. Do not call verification a like/upvote.
10. Keep public user access free and keep the institutional/API model as a later B2B layer.
11. Never place Supabase service-role keys or administrative credentials in the iOS app.
12. Add database migrations and RLS policies to version control when backend work begins.
13. Do not fabricate completed backend functionality. Clearly label mock, local, development, and production behavior.
14. Preserve Turkish copy quality and Turkish characters.
15. Do not make destructive Git operations or overwrite user changes.

## 21. Immediate next task

The next agent should begin with **Phase 0 stabilization**:

1. Compile the current project locally in Xcode.
2. Resolve every reported compiler error.
3. Run the simulator and visually inspect all three tabs plus the complete add-report flow.
4. Confirm location-denied behavior and photo-library behavior.
5. Record any runtime problems.
6. Only after the prototype is stable, implement the report-detail and comments flow.

Do not start Supabase integration until the local user flow compiles and behaves correctly.
