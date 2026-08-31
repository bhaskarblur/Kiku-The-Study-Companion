# Kiku — UI Design Requirements

**Feel:** Notion-clean · Things-3-smooth · a few cute moments. Calm, spacious, professional — never noisy, never guilt-trippy.
**Rule of thumb:** if a screen feels busy, remove something. Every action she does daily must be ≤ 2 clicks.

---

## 1. Design Principles

1. **Quiet by default, delightful on action.** Neutral canvas; color and motion appear when she *does* something (start focus, complete a goal, hit a streak).
2. **One primary action per screen.** Obvious, single accent-colored button. Everything else is secondary/tertiary.
3. **Fast over fancy.** Keyboard shortcuts, quick-add, and sensible defaults beat deep menus.
4. **Kind, not clingy.** Encouraging microcopy. Nudges are gentle and always dismissible.
5. **Consistent rhythm.** One spacing scale, one radius scale, one type scale — used everywhere.

---

## 2. Layout & Structure

**App shell:** macOS split view.
- **Left sidebar (~220pt):** Kiku wordmark, primary nav — **Today · Calendar · Focus · Stats · Journal**, then Subjects list, and Settings pinned at bottom.
- **Main content:** the active view, generous padding (24pt), max content width for readability.
- **Toolbar:** title + one primary action (context-aware: "＋ New event", "Start focus").

**Window:** min 900×640; remembers size/position. Sidebar collapsible.

---

## 3. Color System

Semantic tokens, defined once, adapting to light/dark automatically.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | #FAFAFA | #1A1A1D | app background |
| `surface` | #FFFFFF | #242428 | cards, sheets |
| `surfaceAlt` | #F2F2F4 | #2E2E33 | hover / subtle fills |
| `border` | #E7E7EA | #37373D | hairlines |
| `textPrimary` | #1C1C1E | #F5F5F7 | headings/body |
| `textSecondary` | #6B6B72 | #A0A0A8 | captions/meta |
| `accent` | #7C6BF0 (soft indigo) | #9A8BF5 | primary actions, focus |
| `success` | #34C77B | #3FD98A | goals/streaks |
| `warning` | #F5A623 | #FFB84D | skips/at-risk |

- **Subject colors:** a curated pastel palette (lavender, mint, peach, sky, rose, butter) — soft in both modes.
- Never rely on color alone; pair with icon/label.

---

## 4. Typography

- **Font:** SF Pro (system). Rounded (`.rounded`) for numbers/timers and playful headers → the "cute" touch without hurting readability.
- **Scale:** LargeTitle 28 · Title 20 · Headline 16(semibold) · Body 14 · Caption 12.
- Numerals in timers/stats use rounded + tabular figures so they don't jitter.

---

## 5. Spacing, Radius, Elevation

- **Spacing scale:** 4 · 8 · 12 · 16 · 24 · 32. Default card padding 16–20.
- **Radius:** controls 8, cards 14, sheets 18, pills/rings fully rounded.
- **Elevation:** flat by default; cards get a soft shadow (y2, blur 12, ~6% black) only when interactive or floating. Dark mode uses lighter surfaces instead of heavy shadows.

---

## 6. Motion & Micro-interactions (the "cute & fun")

Keep it subtle and spring-based (`.spring(response: 0.35, dampingFraction: 0.8)`).

- **Buttons:** scale to 0.97 on press, gentle springs back.
- **Hover:** cards lift 1–2pt and brighten `surfaceAlt`.
- **Pomodoro ring:** smooth sweeping progress; soft pulse on the timer digits each minute.
- **Goal complete:** ring fills → check pops → tasteful confetti burst.
- **Streak milestone:** a small mascot/emoji bounce (🔥) + one-line praise.
- **View transitions:** cross-fade + slight slide; nothing longer than 350ms.
- **Empty states:** friendly illustration/emoji + one-line encouragement + primary action.
- Respect **Reduce Motion** (fall back to fades).

---

## 7. Key Screens

**Today (home):** greeting ("Good morning ☀️"), today's date, **next study block** hero card with a big Start Focus button, three compact stat chips (streak · today's minutes vs goal · sessions), and today's timeline below.

**Calendar:** segmented **Day / Week / Agenda**. Week grid with soft hour lines, rounded event blocks in subject colors, current-time indicator line, "＋" quick-add on any empty slot. Clean, lots of whitespace.

**Focus:** large centered Pomodoro **ring** with the subject and remaining time; primary Start/Pause; secondary Stop. Minimal chrome — this is a calm, single-purpose screen. Completion → log sheet.

**Stats:** progress rings for daily/weekly goals, minutes-per-day bar chart, subject breakdown, streak history. Card-based, scannable.

**Journal:** reverse-chronological session cards (subject dot, minutes, note, mood). Feels like a warm diary.

**Settings:** grouped list (Appearance, Focus defaults, Reminders & Nudges, Calendar sync, AI recap, Permissions). Native macOS form styling.

**Event editor (sheet):** title, subject picker (color chips), date + time, repeat, reminder lead, presence-check toggle, notes. One **Save** primary button.

---

## 8. Components Library (build these once, reuse)

- `KCard` — padded rounded surface with optional hover lift.
- `KPrimaryButton` / `KSecondaryButton` — accent-filled / bordered, press spring.
- `StatChip` — icon + value + label pill.
- `ProgressRing` — animated circular progress (goals, Pomodoro).
- `SubjectTag` — colored dot + name.
- `EmptyState` — emoji + message + action.
- `SegmentedControl` — Day/Week/Agenda + Stats ranges.
- `SessionLogSheet` — "What did you study?" form.

---

## 9. Accessibility & States

- Full **light/dark/system**; test both.
- Every interactive element: VoiceOver label + focus ring; keyboard operable.
- Provide loading, empty, error, and permission-denied states for each screen (friendly copy, clear next step).
- Contrast ≥ WCAG AA for text on backgrounds.

---

## 10. Microcopy Tone

Warm, short, first-person-friendly. Examples:
- Empty calendar: *"A fresh week 🌱 — add your first study block."*
- Streak at risk: *"Your 5-day streak is waving 👋 — a quick 25 min keeps it alive."*
- Goal done: *"Daily goal smashed 🎉 proud of you."*
- Skip nudge: *"Thursday grammar slipped by — want to reschedule?"* (never shaming)
