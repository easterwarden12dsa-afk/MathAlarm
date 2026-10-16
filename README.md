# Math Alarm

An iPhone alarm clock that only goes quiet when you solve a math problem, or
press **Surrender**. It's built with Swift + SwiftUI and Apple's AlarmKit
(iOS 26 and later).

You don't need a Mac. A free macOS machine on GitHub compiles the app, and
**Sideloadly** on your Windows PC installs it with your free Apple ID.

---

## One-time setup (about 30 minutes)

### 1. GitHub (builds the app for you)
1. Create a free account at <https://github.com>.
2. Create a new **public** repository called `MathAlarm`. Public repositories
   get unlimited free macOS build minutes. The code has no secrets in it.
3. Connect GitHub to Claude at <https://claude.ai/connect-github> and allow
   it to access the `MathAlarm` repository. Claude can then push code and
   fix any build errors itself.

Every time code is pushed, GitHub builds the app automatically. To get it:
**Repository → Actions tab → latest green ✓ run → scroll down to
"Artifacts" → MathAlarm-ipa**. You download a `.zip` file; unzip it to get
`MathAlarm.ipa`.

### 2. Windows PC (installs the app)
1. Install **iTunes** and **iCloud** from Apple's website. Sideloadly needs
   the versions from apple.com, *not* the Microsoft Store versions:
   - iTunes: <https://www.apple.com/itunes/download/win64>
   - iCloud: <https://support.apple.com/en-us/HT204283>
2. Install **Sideloadly** from <https://sideloadly.io>.
3. Connect your iPhone with a USB cable. On the iPhone, tap **Trust** and enter
   your passcode.

### 3. Install the app
1. Open Sideloadly. Your iPhone appears in the "iDevice" box.
2. Drag `MathAlarm.ipa` onto Sideloadly.
3. Enter your Apple ID email and press **Start**. Sign in with your password
   and 2-factor code when asked. Sideloadly signs the app with your free Apple
   ID; the password goes only to Apple.
4. First time only, on the iPhone:
   - **Settings → Privacy & Security → Developer Mode → On**. The phone
     restarts; confirm "Turn On".
   - **Settings → General → VPN & Device Management →** your Apple ID **→
     Trust**.
5. Open **Math Alarm**, tap **Allow alarms**, then **Continue**.

### The 7-day rule (free Apple ID)
Apps signed with a free Apple ID stop opening **7 days** after install. Before
day 7, plug in and run step 3 again with the latest `.ipa`. Your alarms and
settings are kept because it installs over the old copy. Don't delete the app
first, or you lose your alarms. Set a weekly reminder.

Free accounts can also have only 3 sideloaded apps at a time. Math Alarm uses
two App IDs, one for the app and one for its lock-screen widget.

---

## How ringing works (and its honest limits)

| Situation | What happens |
|---|---|
| Phone locked / Silent / Focus / app closed | AlarmKit rings a real system alarm, like the Clock app. |
| You tap **Solve** | The app opens on the challenge and plays the sound itself. Silent mode doesn't stop it. |
| You tap the system **Stop** | It rings again ~5 s later, with a backup at 60 s, until you solve or surrender. |
| You leave the app mid-challenge | The sound keeps playing. Reopening the app shows the same challenge. |
| You swipe the app away | A "watchdog" system alarm, always kept ≤45 s ahead, rings again. |
| **Mute** | Silent for exactly 90 s with a countdown, then the sound returns, even if the app was suspended. |
| **Surrender** | Off immediately. Repeating alarms still ring next time. |

**What no app can do:**
- Remove the system Stop button. We re-ring instead.
- Ring while the phone is off or the battery is dead.
- Stop you deleting the app or turning off its alarm permission in Settings.

**Volume:** the system alarm uses your *Alarm* volume. Inside the app the sound
uses your *media* volume, and the ringing screen warns you if it's low.

---

## Project layout

```
project.yml              XcodeGen recipe; the cloud Mac generates the Xcode project from it
.github/workflows/       the cloud build
MathAlarm/
  App/                   app entry, onboarding, root view
  Alarms/                alarm model, storage, AlarmKit scheduling, list + editor screens
  Ringing/               ring session logic, sound player, ringing screen
  Intents/               Stop / Solve actions run by the system alarm
  Support/               JSON persistence
  Resources/Sounds/      alarm sounds (generated tones, under 30 s)
MathAlarmWidget/         lock-screen / Dynamic Island view AlarmKit requires
Shared/                  code used by both the app and the widget
```

Milestones: **M1** alarms + ringing (this build) · **M2** math engine, keypad,
Integral & Derivative · **M3** Graph Sketch · **M4** timers, polish, tests.
