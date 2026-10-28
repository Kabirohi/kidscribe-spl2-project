# KidScribe

KidScribe is an Android tablet app that teaches children aged 5 to 8 how to
write by hand. The child writes on the screen with a pen (a stylus), and the
app tells them how they did.

Made by **SPL Group 18**, Islamic University of Technology, CSE:

| Name | Student ID |
| --- | --- |
| Hasan Mahi | 230042129 |
| Zuhaaer Mustafa Sadab | 230042132 |
| Md Shahib Al Kabir | 230042157 |

## What the app can do

**The five stages**

1. **Strokes** — lines and curves, the shapes that make letters.
2. **Letters** — all 26 letters, one level each. Each letter has two halves:
   trace on numbered points, then write it free hand. A Google ML model reads
   the free-hand letter and gives a score out of 100. Both halves must be
   done before the next letter opens.
3. **Words** — write a whole word, one letter at a time.
4. **Sentences** — put the words in the right order, start with a capital
   letter, and end with a full stop.
5. **Parent hub** — sync and Premium.

**Games:** Free Writing, Letter Match and Letter Ninja.

**For grown-ups**

- A parent adds their children. A teacher makes classes and adds students.
  **Only a child can practise**, so a grown-up must first add a child and
  pick who is learning.
- Give a task, or a timed test with no help on screen, and give more time
  later.
- Give a mark, an answer key and written feedback.
- See a progress report, and save it as a file.
- Set a daily practice reminder.
- **Toy Words:** take a photo of a toy, and the toy's name becomes a word the
  child can practise. Blurry photos are refused.
- Badges and a daily streak.
- Sync progress between tablets, and a Premium plan.

> **Premium is only a demo.** It never asks for card details, and no real
> money is taken. There is even a button to test a failed payment.

## App design

The interface follows a modern kids-app look: a violet brand colour, one
orange call-to-action per screen, chunky pill buttons that sit on a solid
"ledge" and sink when pressed, big rounded cards, and a dark home screen.

| File | What it does |
| --- | --- |
| `lib/theme/app_colors.dart` | The whole colour palette and gradients. |
| `lib/theme/app_theme.dart` | App-wide theme (font, buttons, snack bars, switches). |
| `lib/widgets/common.dart` | Shared pieces: `KidPage`, `KidHeader`, `KidCard`, `KidButton`, `KidTag`, `KidInput`... |
| `lib/widgets/auth_shell.dart` | Log in / Sign up frame (two-panel on tablets). |
| `lib/widgets/mascot.dart` | "Penny" the pencil mascot, drawn in code. |
| `lib/widgets/parent_gate.dart` | "Parents only" year-of-birth check before Sync & Premium. |

To change the look of the whole app, edit `app_colors.dart` first.

## How to run it

You need Flutter and an Android phone or an Android emulator.

```bash
flutter pub get
flutter run
```

If you use the emulator from Android Studio, start it first, then run:

```bash
flutter run -d emulator-5554
```

The app is **Android only**. There is no web version.

The first build is slow, because Gradle downloads a lot. Also, the first
free-hand check downloads the Google handwriting model (about 20 MB) once.
After that the app works offline.

## Unit tests

```bash
flutter test unit_testing/test
```

129 test cases, covering 58 of the 80 unit tests in our SRS. The other 22
need a real phone, so they are run by hand. The `unit_testing` folder holds
the test code, the output of our last run, and a paper explaining how every
test was run.

## Firebase (already connected)

The app logs in with **Firebase Authentication**, in the Firebase project
**kidscribe-c322f**. The settings are already written in
`lib/firebase_options.dart`.

> ⚠️ **Do not run `flutterfire configure`.** The settings file is already
> there and is written by hand. Running that command would overwrite it and
> break the Android package name, which must stay `com.example.kidsscibe`.

In the Firebase console, project **kidscribe-c322f**, two things must be on:

1. **Authentication → Sign-in method → Email/Password → enable.**
2. **Firestore Database → Create database** (only needed for sync). Then put
   these rules, so each user can read and write only their own data:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /kidscribe_sync/{uid} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```

### What "tokens" means here

When a user logs in, Firebase gives back a signed **ID token (a JWT)** and a
**refresh token**. Firebase keeps them on the device, sends the ID token with
each request, and gets a fresh one about once an hour. So the app never keeps
the password itself.

To see a real token, call `AuthService().getIdToken()` and paste the text into
<https://jwt.io>.

## Who can log in

Only a **Parent** or a **Teacher** makes an account. **Children do not log in**
(this is FR-1 in our SRS). A parent adds a child profile, a teacher adds a
student to a class, and the app then saves that child's work under them.

Firebase Auth keeps the email, the password and the name. It has no "role"
field, so the role is kept on the device with SharedPreferences, and it also
goes to Firestore when the parent turns sync on.

## Where the work is saved

Everything is saved **on the tablet** with SharedPreferences, under the child
who is learning. Reports are saved as text files in the app's own folder.

Sync is extra: it copies the saved work to Firestore and back, so two tablets
show the same progress.

> **One limit of sync:** it only adds and joins data, so nothing is ever lost.
> The other side of that is that a child or a task you delete on one tablet
> comes back after the next sync.

## What is inside

```
lib/
├── screens/     what the user sees
├── blocs/       the rules and the state (BLoC)
├── services/    saving, Firebase, the ML checks
├── widgets/     pieces used by many screens
├── models/      plain data classes
└── data/        the letters, words and sentences
```

The app uses the **BLoC architecture**: the screen only draws, a bloc holds
the rules, and a service keeps the data. [ARCHITECTURE.md](ARCHITECTURE.md)
explains this with a diagram and an example.
