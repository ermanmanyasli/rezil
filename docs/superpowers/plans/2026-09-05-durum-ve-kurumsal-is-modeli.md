# Durum ve Kurumsal Is Modeli Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vatandaş uygulamasında beşli alt navigasyonu anlamlı bir `Katkılar` alanıyla tamamlamak; kurumlara dönük durum takibi ve gelir modelini sonraki B2B fazına hazırlamak.

**Architecture:** Vatandaş uygulaması `Harita | Keşfet | + | Katkılar | Profil` yapısını kullanır. `Katkılar`, kullanıcının oluşturduğu raporları, yaptığı doğrulamaları ve yorumları toplar; `Profil` hesap ve ayarlara odaklanır. Kurum eşleme, durum geçmişi ve kurumsal dashboard veri modeli şimdi vatandaş arayüzüne açılmadan sonraki B2B fazı için hazırlanır.

**Tech Stack:** SwiftUI, MapKit, Supabase/Postgres, PostGIS, Row Level Security, ileride web dashboard ve scoped API.

**Spec:** `spec.md`, özellikle bölümler 3.6, 7, 11, 15, 16 ve 19.

## Global Constraints

- Citizen access remains free.
- The map is the product and reporting must remain a 20–30 second flow.
- Use `Bende gördüm`, `Hâlâ devam ediyor`, and `Çözüldü` language instead of likes/upvotes.
- Backend owns status, support counts, moderation state, routing, and entitlements.
- Do not expose citizen PII through institutional products.
- Preserve Turkish copy quality and Turkish characters.
- Add database migrations and RLS policies to version control.
- Never put Supabase service-role keys or administrative credentials in the iOS app.

---

### Task 1: Add the citizen contributions tab

**Files:**
- Modify: `rezil/ContentView.swift`
- Create: `rezil/ContributionsView.swift`
- Modify: `rezil/OwnedContentViews.swift`
- Test: `rezilTests/rezilTests.swift`

**Interfaces:**
- `AppTab` gains `.contributions` with title `Katkılar` and icon `person.crop.circle.badge.checkmark`.
- `ContributionsView` consumes the authenticated user's reports, comments, and verification actions.
- `ProfileView` remains responsible for identity, account, and settings; personal content moves to `Katkılar`.

- [ ] Add a failing view-model test asserting that a user's reports, comments, and verifications are separated into stable sections.
- [ ] Run the focused test and verify it fails before the contributions grouping exists.
- [ ] Implement `ContributionsView` with `Şikâyetlerim`, `Doğrulamalarım`, and `Yorumlarım` sections.
- [ ] Move the existing `Şikâyetlerim ve yorumlarım` destination out of `ProfileView` without changing its data behavior.
- [ ] Add empty/loading/error states and preserve the sign-in gate for personal content.
- [ ] Run unit tests and an Xcode build.

### Task 2: Add routing and status history to the database

**Files:**
- Create: `supabase/migrations/009_organizations_and_status_events.sql`
- Modify: `supabase/migrations/001_initial.sql` only if required for compatibility
- Test: `rezilTests/rezilTests.swift`

**Interfaces:**
- `organizations(id, name, organization_type, service_area, categories_handled, contact_metadata, verified)`.
- `status_events(id, report_id, from_status, to_status, actor_type, actor_id, evidence, created_at)`.
- A routing function selects the verified organization whose `service_area` contains the report location and whose handled categories include the report category.

- [ ] Write migration-level checks for enum values, foreign keys, and one status event per transition.
- [ ] Add indexes for report status, responsible organization, updated time, and PostGIS service-area lookup.
- [ ] Add RLS so public users can read safe organization/status fields, while only authorized organization or moderator identities can write transitions.
- [ ] Add a transaction or database function that updates `reports.status`, `responsible_organization_id`, `updated_at`, and inserts the matching `status_events` row atomically.
- [ ] Verify that a normal citizen cannot change a report status or assign an organization.
- [ ] Apply the migration in a development Supabase environment and record the exact result.

### Task 3: Build the internal routing and moderation workflow

**Files:**
- Modify: `rezil/ComplaintStore.swift`
- Modify: `rezil/SupabaseClient.swift`
- Create: `rezil/Organization.swift`
- Create: `rezil/OrganizationRoutingService.swift`
- Test: `rezilTests/rezilTests.swift`

**Interfaces:**
- `OrganizationRoutingService.route(report:) async throws -> Organization?`.
- `ComplaintStore.updateStatus(reportID:to:evidence:) async throws` delegates authorization and transition validation to Supabase.
- `Complaint.statusHistory` is loaded from `status_events`, never reconstructed from the current status alone.

- [ ] Test routing precedence: exact category plus containing service area beats category-only fallback; no match leaves the organization nil.
- [ ] Test invalid transitions such as `resolved -> in_progress` unless explicitly reopened by a moderator.
- [ ] Implement service/store calls with retry-safe request identifiers.
- [ ] Surface institution acknowledgement and status changes to citizens without exposing internal notes.
- [ ] Run tests and build after each store/API change.

### Task 4: Define the first institutional pilot product

**Files:**
- Create: `docs/institutional-pilot.md`
- Modify: `spec.md` to link the pilot decisions if they become product commitments

**Interfaces:**
- Pilot roles: `organization_admin`, `organization_operator`, `moderator`.
- Minimum organization view: map/list, filters by category/status/date, priority queue, evidence preview, status update, and export.
- Citizen-facing response fields: public status, response summary, updated time, and organization name.

- [ ] Select one municipality or public operator and one defined service area for the pilot.
- [ ] Define the end-to-end SLA: report routed, acknowledged, assigned, in progress, resolved, and citizen-confirmed.
- [ ] Define which evidence and response text are public versus internal.
- [ ] Define a weekly pilot report with acknowledged reports, in-progress reports, resolved reports, median resolution time, and citizen confirmation rate.
- [ ] Document KVKK, image/privacy, takedown, data licensing, and public-sector procurement questions for legal review.

### Task 5: Validate the monetization model before building a full dashboard

**Files:**
- Create: `docs/institutional-pricing-hypotheses.md`
- Modify: `spec.md` only after customer discovery confirms a product decision

**Interfaces:**
- Free citizen product remains unchanged.
- Paid institutional package is evaluated as a service-area subscription first, with export/API as later add-ons.

- [ ] Interview 3–5 potential customers across municipality, zabıta, utility, and property/site management contexts.
- [ ] Test three value propositions: operational work queue, trend/coverage analytics, and scheduled evidence export.
- [ ] Measure willingness to pay against resolution-time reduction and reporting workload reduction, not raw report volume.
- [ ] Choose the first paid unit: service area plus operator seats, monthly data export, or API access.
- [ ] Do not implement billing until one pilot customer confirms the repeated workflow and required data fields.

### Task 6: Add outcome analytics and launch gates

**Files:**
- Create: `docs/metrics-status.md`
- Modify: `spec.md` analytics section if metrics are finalized

**Interfaces:**
- Events: `report_routed`, `institution_acknowledged`, `status_changed`, `report_resolved`, `resolution_confirmed`.
- Core metrics: median time to first verification, acknowledgement rate, resolution rate, median time to resolution, and citizen confirmation rate.

- [ ] Instrument the event funnel without storing unnecessary personal data.
- [ ] Build a weekly internal view for one pilot area.
- [ ] Set launch gates: routing accuracy, status update adoption, duplicate/abuse rate, and resolution evidence quality.
- [ ] Review metrics after the closed beta and decide whether a second institution or dashboard investment is justified.

## Delivery Order

1. Ship the citizen-facing `Katkılar` tab and simplify `Profil`.
2. Keep status and organization data in the backend model without exposing a citizen-facing `Durum` tab.
3. Validate report density and data quality in one closed citizen beta.
4. Run one institutional pilot with a single service area.
5. Validate repeated institutional workflows and pricing.
6. Build the smallest dashboard or scheduled export that solves the validated workflow.

## Self-Review Checklist

- `Keşfet` remains the ranked report list; `Katkılar` owns personal reports, verifications, and comments.
- `Profil` owns identity, followed items, and settings; it is not duplicated by `Katkılar`.
- Institution actions are authorized server-side and leave an auditable status event.
- Public users see useful resolution progress without seeing citizen PII or internal notes.
- The business model is tested through a pilot before billing, dashboard, or public API work.
