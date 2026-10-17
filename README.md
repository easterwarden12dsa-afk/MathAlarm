# Math Alarm

An iPhone alarm clock that only goes quiet when you solve a math challenge
(an **integral**, a **derivative**, or **sketching a graph**), or press
**Surrender**. Built with Swift + SwiftUI and Apple's AlarmKit (iOS 26.1+).
It works fully offline.

No Mac is needed: GitHub's free macOS machines build the app, and you install
it from a Windows PC with **iloader** and a free Apple ID.

---

## Installing (free Apple ID + Windows PC)

1. **Get the app file.** Every push to `main` publishes a new build on the
   **Releases** page as "Latest build":
   `https://github.com/easterwarden12dsa-afk/MathAlarm/releases/download/latest/MathAlarm.ipa`
   - The release notes show its SHA-256 fingerprint. Check your download with
     `certutil -hashfile MathAlarm.ipa SHA256` in Command Prompt.
   - Some antivirus tools flag unsigned iPhone apps they haven't seen before.
     To check one yourself, paste the link into the URL tab of
     https://www.virustotal.com.
2. **PC setup (once):** install iTunes from apple.com (needed for the USB
   connection; you don't have to sign in), then **iloader** from
   https://iloader.app.
3. **Install:** plug in the iPhone, open iloader, sign in with your Apple ID,
   choose **Import IPA** and pick `MathAlarm.ipa`.
4. **First time only, on the iPhone:**
   - Settings → Privacy & Security → **Developer Mode** → On (the phone
     restarts).
   - Settings → General → VPN & Device Management → your Apple ID → **Trust**.

### The 7-day rule
Free-Apple-ID installs stop opening **7 days** after installing.
- The app shows a warning 2 days before.
- Settings → "Remind me the day before" also sends a notification.
- Reinstall the same way, **over** the existing app. Don't delete it first,
  or your alarms are lost.

### Optional: refresh on the phone with SideStore
1. In iloader choose **Install SideStore** (once, with the PC).
2. Open SideStore on the iPhone, sign in with the same Apple ID, and import
   `MathAlarm.ipa` (Files app → share → SideStore, or SideStore's **+**).
3. Once a week, open SideStore and tap **Refresh All**. No PC is needed while
   SideStore's own setup stays valid. If SideStore ever stops working, go
   back to the iloader steps above.

---

## Using it

**Tabs:** Alarms · Timer · Practice · Settings.

- **Alarms:** one-time (date and time), every day, or chosen weekdays each
  with its own time. Each alarm has its own sound, challenge (Integral,
  Derivative, Graph Sketch or Random) and difficulty (Easy, Medium, Hard, or
  **Bagrut 5U**, which uses only the 5-unit syllabus). "Ring in 10 seconds"
  tests the whole flow.
- **Timer:** countdown with a live Lock Screen / Dynamic Island display and
  Pause/Resume. At zero it rings exactly like an alarm.
- **Practice:** every challenge without an alarm, with full step-by-step
  solutions (and "Reveal" for sketches).
- **Settings:**
  - problems per ring (1–3);
  - sketch strictness;
  - the challenge used by timers and the test button;
  - install expiry and reminder;
  - stats (solved, surrenders, day streak).

### While it rings
- **Mute** (top left): silent for exactly 90 s with a countdown, then it rings
  again by itself. It can be used repeatedly.
- **Surrender** (top right): off immediately. Repeating alarms still ring
  next time.
- Typing: a custom math keypad with a live typeset preview.
  - Tap anywhere in your answer to move the cursor there.
  - **a/b** turns the last term you typed into a fraction's top.
- Wrong answer: no penalty. **Why?** explains it; for an integral it
  differentiates your answer step by step.
- **Steps** shows the full worked solution. During an alarm you then get a
  fresh problem, so it can't simply be copied.
- Problems are not repeated (the last 400 are remembered).

---

## How ringing works (and its honest limits)

| Situation | What happens |
|---|---|
| Phone locked / Silent / Focus / app closed | AlarmKit rings a real system alarm, like the Clock app. |
| You tap **Solve** | The app opens on the challenge and plays the sound itself (Silent mode doesn't stop it). |
| You tap the system **Stop** | It rings again ~5 s later (backup at 60 s) until solved or surrendered. |
| You leave the app mid-challenge | The sound keeps playing; reopening returns you to the same challenge and what you typed. |
| You swipe the app away | A "watchdog" system alarm, always kept ≤45 s ahead, rings again. |
| Phone restarted | AlarmKit alarms survive a restart. |
| Time-zone / daylight-saving change | Repeating alarms follow local time automatically; one-time alarms are moved when the app next opens. |
| Two alarms close together | The second joins the ring already in progress: one challenge stops both. |

**No app can:**
- remove the system Stop button (we re-ring instead);
- ring while the phone is off;
- stop you deleting the app or turning off its alarm permission in Settings.

**Volume:** the system alarm uses your *Alarm* volume. Inside the app, the
sound uses *media* volume, and the screen warns you if it's low. Imported
sounds come from the Files app. Streaming songs (Spotify, Apple Music) are
copy-protected and can't be used.

---

## How answers are checked

- **Integrals and derivatives.** Your expression is compared with the
  correct one at 40 random points (tolerance 1e-6, relative). Any equivalent
  form passes: simplified or not, with or without "+ C".
  - For an integral, your answer is differentiated and compared with the
    integrand.
  - For a derivative, it's compared with both the symbolic derivative and a
    numerical one, so a bug in one can't reject a correct answer.
  - **Domain rule:** points are taken only from the interval shown with the
    problem (if one is shown). On that interval ln(u) and ln|u| give the
    same values, so both are accepted.
- **Graph Sketch.** The drawing becomes y(x) in 80 columns.
  - It is judged in 8 strips (mean error ÷ the function's range), at both
    ends, at every zero, and at every peak or dip (position and shape).
  - Thresholds live in `SketchTolerance`, with relaxed / moderate / strict
    presets.
  - Failing strips are shaded red with hints such as "Too high in the red
    band" or "Missing the dip near x = 0". The correct curve is never shown
    during an alarm.

---

## Project layout

```
project.yml                 XcodeGen recipe (the cloud Mac generates the Xcode project)
.github/workflows/          build.yml (app + release), tests.yml (math engine tests)
Packages/MathEngine/        all math, no UI:
  Expr, Evaluate, Differentiate     expression tree, evaluation, symbolic d/dx
  IntegralGenerator, DerivativeGenerator, Problem   problem templates + validation
  Checker, SolutionSteps            answer checking, worked solutions, "Why?"
  EditorModel, RowParser, ExprDisplay   structured editor ↔ expression tree
  Sketch                            graph problems, sketch checker, tolerances
  Tests/                            43 unit tests (run on every push)
MathAlarm/
  App/        app entry, tabs, onboarding, settings
  Alarms/     alarm model, storage, AlarmKit scheduling, editor, sounds
  Ringing/    ring session logic, sound player, ringing screen
  Challenges/ integral/derivative + sketch challenge screens, practice, solutions
  MathInput/  typeset math view, keypad
  Timers/     countdown timers
  Intents/    Stop / Solve actions run by the system alarm
  Support/    persistence, settings, haptics/toasts
MathAlarmWidget/   Lock Screen / Dynamic Island countdown for alarms and timers
```

## Troubleshooting

- **"Untrusted Developer":** Settings → General → VPN & Device Management →
  Trust.
- **The app won't open after a week:** the 7-day free install expired.
  Reinstall it (alarms are kept if you install over it).
- **Nothing rings:** Settings → Math Alarm → allow Alarms & Timers; check the
  Alarm volume.
- **iloader / Sideloadly can't sign in:** try your phone's hotspot. Some home
  networks block Apple's sign-in server.
