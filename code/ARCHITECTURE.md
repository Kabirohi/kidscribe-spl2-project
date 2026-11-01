# KidScribe — BLoC Architecture

KidScribe is written in **Dart** with the **Flutter** framework, and it uses
the **BLoC architecture** for its state.

BLoC means **B**usiness **Lo**gic **C**omponent. The idea is simple: the
screens must not hold the rules of the app. The screens only draw. A bloc
holds the rules and the state, and tells the screen what to draw.

## The three layers

```
   ┌───────────────────────────────────────────┐
   │  1. UI LAYER            lib/screens       │
   │     Only draws. Sends events to a bloc.   │
   └───────────────────────┬───────────────────┘
                 events    │   states
                           ▼
   ┌───────────────────────────────────────────┐
   │  2. BUSINESS LAYER      lib/blocs         │
   │     All the rules and all the state.      │
   └───────────────────────┬───────────────────┘
                  calls    │   data
                           ▼
   ┌───────────────────────────────────────────┐
   │  3. DATA LAYER          lib/services      │
   │     SharedPreferences, Firebase, ML Kit.  │
   └───────────────────────────────────────────┘
```

The arrows only point down. A screen never calls a service, and a service
never knows that a screen exists.

## How one action travels through the app

The child taps **Log In**:

1. `login_screen.dart` sends the event `AuthLoginRequested(email, password)`.
2. `AuthBloc` receives it, emits a state with `submitting: true`
   (the button shows a spinner), and calls `AuthService.signIn(...)`.
3. `AuthService` asks Firebase and gets a token back.
4. `AuthBloc` emits a new state: `status: authenticated`, with the user.
5. `AuthGate` is listening, sees `authenticated`, and shows the home screen.

The screen made no decision at all. That is the point.

## Bloc or Cubit?

The bloc library gives two tools. We use both, on purpose:

| Tool | Where we use it | Why |
| --- | --- | --- |
| **Bloc** (events + states) | `AuthBloc` | Login has several different actions (start, log in, sign up, log out), so named events make the flow easy to read and to test. |
| **Cubit** (methods + states) | everything else | Here a screen just calls a method, like `check()` or `addStudent()`. A Cubit does the same job with less code, and the official bloc documentation recommends it when named events are not needed. |

## The files

Every screen in `lib/screens` has its own bloc or cubit. There is no
screen that talks to a service directly.

```
lib/
├── blocs/                     ← 2. BUSINESS LAYER
│   ├── auth/                    login, sign up, log out (Bloc)
│   │   ├── auth_event.dart      what the user can do
│   │   ├── auth_state.dart      what the screen must draw
│   │   └── auth_bloc.dart       the rules
│   ├── home/                    home screen cards, auto-sync
│   ├── children/                parent's child profiles
│   ├── classes/                 teacher's classes + one class
│   ├── stages/                  which stage is open
│   ├── learn/                   Stage 1 tracing, Stage 2 letter levels
│   ├── words/                   Stage 3 words
│   ├── sentence/                Stage 4 sentences
│   ├── games/                   Letter Match, Letter Ninja
│   ├── free_writing/            Free Writing game
│   ├── toys/                    toy photo -> toy word
│   ├── assign/                  give a task, grade, feedback
│   ├── tasks/                   the child's own task list
│   ├── badges/                  badge gallery + streak
│   ├── progress/                progress report
│   ├── report/                  advanced report (Premium)
│   ├── premium/                 Premium (demo payment)
│   ├── sync/                    cloud sync
│   ├── reminder/                daily reminder
│   └── common/ui_message.dart   a one-time message for the screen
│
├── services/                  ← 3. DATA LAYER (the repositories)
│   ├── auth_service.dart        Firebase login + token
│   ├── family_service.dart      children and classes
│   ├── progress_service.dart    stars, letters, words, sentences, games
│   ├── badge_service.dart       badges and streaks
│   ├── assignment_service.dart  tasks, tests, feedback
│   ├── trace_evaluator.dart     marks a traced letter
│   ├── freehand_checker.dart    ML Kit handwriting check
│   ├── sentence_checker.dart    capital letter + full stop rules
│   ├── custom_word_service.dart toy words, blurry-photo check
│   ├── premium_service.dart     Premium (demo, no card details)
│   ├── sync_service.dart        Cloud Firestore sync
│   ├── report_service.dart      progress reports
│   └── reminder_service.dart    daily reminders
│
├── widgets/                     shared pieces
│   ├── writing_pad.dart         the page the child writes on
│   └── common.dart              header, card, button, dialogs
├── models/                      plain data classes
├── data/                        letters, words, sentences
├── screens/                   ← 1. UI LAYER
└── main.dart                    puts the layers together
```

## Where the blocs are created

`main.dart` puts the repositories and the app-wide `AuthBloc` above every
screen:

```dart
MultiRepositoryProvider(          // the data layer
  providers: [ RepositoryProvider(create: (_) => AuthService()), ... ],
  child: MultiBlocProvider(       // the business layer
    providers: [ BlocProvider(create: (ctx) => AuthBloc(...)) ],
    child: MaterialApp( home: AuthGate() ),
  ),
)
```

Login state is needed everywhere, so `AuthBloc` lives at the top. Every
other bloc is created by the screen that needs it, and is thrown away when
that screen closes. This keeps memory small.

## The three widgets we use to draw a state

| Widget | What it does |
| --- | --- |
| `BlocBuilder` | Rebuilds the screen when the state changes. |
| `BlocListener` | Does something once, like showing a red error message. |
| `BlocConsumer` | Both together. |

Some things must happen only once, like a pop-up with the result or a
message at the bottom. For these the state carries a counter (for example
`resultTick`). Each new result adds 1, and the screen's `BlocListener`
only reacts when the counter changes. So a result never pops up twice.

## One honest note about the drawing screens

The screens where the child writes with the pen keep their pen strokes in
a small `WritingPadController` (in `widgets/writing_pad.dart`), not in a
bloc. This is on purpose: the pen sends a new point about 60 times a
second, and pushing every point through a bloc would make the app slow for
no gain. The moment the child taps **Check**, the finished strokes go to
the cubit, and the cubit checks them, saves them and gives the badges.
Animations (the demo pencil, the 💡 guide, confetti) also stay in the
screen, because they are only for looks. The bloc library's own
documentation gives the same advice: keep short-lived UI state local, and
put real business state in a bloc.
