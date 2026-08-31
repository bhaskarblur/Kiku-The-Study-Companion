# Kiku — Functional Requirements Document (FRD)

**Version:** 1.0
**Platform:** Native macOS app (SwiftUI, macOS 14+)
**Audience:** An individual learner (study companion). Distributed as a `.app` / `.dmg`.
**Goal:** Make studying easy to plan, delightful to do, and satisfying to track — so she stays consistent and never regrets skipping.

---

## 1. Product Vision

Kiku is a calm, cute-but-professional study companion for macOS. It is her **single source of truth** for:

- **Planning** — build a weekly study timetable and one-off study events.
- **Doing** — focus sessions with a Pomodoro timer and gentle presence check-ins.
- **Tracking** — streaks, goals, stats, and a session journal.
- **Staying honest** — native macOS notifications + optional "are you actually doing this?" nudges.
- **Reflecting** — a warm weekly AI recap that celebrates wins and flags gaps.

It reaches her phone by syncing to her existing macOS Calendar (including a Google account added in System Settings), so reminders follow her everywhere without any OAuth setup.

**Design north star:** Notion-clean, Things-3-smooth, with small cute moments. Never noisy, never guilt-trippy.

---

## 2. Personas & Key Scenarios

**Primary user — "the learner":** motivated but sometimes lazy; skips and later regrets. Needs low-friction planning, visible momentum, and kind accountability.

**Scenarios**
1. **Sunday planning** — lays out the week's study blocks in a few clicks using templates.
2. **Daily study** — gets a banner 5 min before a block, starts a Pomodoro, studies, logs what she did.
3. **Wobble day** — feels lazy; a gentle nudge + her streak at risk pulls her back.
4. **Weekend reflection** — reads the AI recap: "Great week — 6/7 days, French vocab was your strongest. You skipped Thursday grammar — want to reschedule?"

---

## 3. Feature Requirements

Priorities: **P0** = v1 must-have · **P1** = fast-follow · **P2** = later.

### 3.1 Scheduling & Calendar (P0)
- Create/edit/delete **study events** with: title, subject, date, start/end time, notes, color, reminder lead time.
- **Recurring events** (daily, weekdays, weekly on chosen days) for a repeatable timetable.
- **Timetable templates**: save a week layout and apply it to any week.
- Views: **Day**, **Week** (default), and an **Agenda / upcoming list**.
- Drag to move/resize events in Week view (P1).
- Conflicts are visually flagged (overlapping blocks).

### 3.2 Notifications & Nudges (P0)
- Native macOS notifications via `UNUserNotificationCenter`.
- Per-event **reminder lead time** (e.g., 5/10/15 min before).
- **Start nudge** at event start ("Time to study French ✨").
- **Presence check-in** (toggleable per event or global): every N minutes (default 10) after start, "Still on it? 👀" with quick actions **Yes / Snooze / Stop**.
- **Skip detection**: if an event ends with no logged session, a gentle end-of-day nudge ("Thursday grammar slipped — reschedule?").
- Quiet hours (no notifications in a chosen window) (P1).

### 3.3 Focus / Pomodoro (P0)
- Pomodoro timer: configurable focus (default 25) + short/long breaks.
- Start a session **from an event** or ad-hoc.
- Live timer with pause/resume/stop; menu-bar countdown (P1).
- On finish: **session log prompt** — "What did you study?" (subject, minutes auto-filled, free note, optional mood/effort rating).

### 3.4 Study Tracking (P0)
- **Streaks**: consecutive days with ≥1 completed session (configurable daily target).
- **Goals**: daily minutes target + weekly minutes/sessions target, shown as progress rings/bars.
- **Session journal**: chronological log of everything studied.
- **Rewards/celebrations**: confetti + encouraging copy on streak milestones and goal completion.

### 3.5 Stats & Insights (P0/P1)
- Dashboard: today's progress, current streak, week overview.
- Charts (Swift Charts): minutes per day, by subject, streak history. (P1 for richer charts.)

### 3.6 Weekly AI Recap (P1)
- Every weekend, generate a warm summary via **Gemini API** from the week's data.
- Highlights: consistency, strongest subject, missed blocks, one kind suggestion.
- Requires a user-supplied API key stored in Keychain. Fully skippable/offline-friendly.

### 3.7 Calendar Sync (P1)
- Two-way-ish sync with macOS Calendar via **EventKit**, so events appear on her phone (incl. Google calendar added to macOS).
- Choose which local Kiku calendar/EventKit calendar to mirror to.
- Kiku remains source of truth; sync is additive and safe.

### 3.8 Settings (P0)
- Appearance: **System / Light / Dark**, accent color.
- Defaults: Pomodoro lengths, reminder lead time, daily target, nudge interval + on/off.
- Permissions status (Notifications, Calendar) with one-click request.
- Gemini API key (P1). Data location / export (P2).

---

## 4. Data Model (SwiftData)

- **Subject** — `id, name, colorHex, icon, createdAt`.
- **StudyEvent** — `id, title, subjectID?, start, end, notes, colorHex, reminderLeadMinutes, recurrenceRule?, presenceCheckEnabled, createdAt`.
- **StudySession** — `id, eventID?, subjectID?, startedAt, endedAt, focusMinutes, note, moodRating?, source (pomodoro/manual)`.
- **Goal** — `id, type (dailyMinutes/weeklyMinutes/weeklySessions), target, createdAt`.
- **StreakState** — `currentStreak, longestStreak, lastCompletedDay`.
- **TimetableTemplate** — `id, name, blocks:[TemplateBlock]`.
- **AppSettings** — appearance, accent, pomodoro config, reminder defaults, nudge config, quietHours, geminiKeyRef.

---

## 5. Technical Approach

- **UI:** SwiftUI, macOS 14+, `MVVM`-lite with observable stores.
- **Storage:** SwiftData (local, offline-first). No account/login.
- **Notifications:** `UNUserNotificationCenter` with notification categories/actions for the check-in.
- **Timers:** a focus engine that survives view changes; app runs with a menu-bar presence.
- **Calendar sync:** EventKit (`NSCalendarsUsageDescription` already declared).
- **AI:** Gemini REST call, key in Keychain, network entitlement already set.
- **Build/deploy:** XcodeGen (`project.yml`) → `xcodebuild` → package as `.dmg`.

---

## 6. Non-Functional Requirements

- **Offline-first:** everything except AI recap and calendar sync works with no network.
- **Privacy:** all study data stays local; nothing leaves the Mac except explicit AI recap and calendar sync.
- **Performance:** instant view switching; smooth 60fps animations.
- **Accessibility:** full light/dark, Dynamic Type friendly, VoiceOver labels on key controls.
- **Resilience:** denied permissions degrade gracefully with clear in-app guidance.

---

## 7. v1 Scope (Definition of Done)

**In:** app shell + theming, Subjects, Day/Week/Agenda calendar with recurring events, event reminders + start nudge + presence check-in, Pomodoro + session log, streaks + goals + dashboard, basic stats, Settings.

**Fast-follow (P1):** Swift Charts insights, Gemini weekly recap, EventKit sync, drag-to-edit, menu-bar timer, quiet hours.

**Later (P2):** template sharing, data export, iOS companion.

---

## 8. Open Questions

1. Gemini API key — do you have one, or should the AI recap ship disabled until you add it?
2. Should the presence check-in default **on** or **off** for new events?
3. Preferred accent color for Kiku's brand (default: soft indigo/lavender)?
