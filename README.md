# KidScribe

An Android tablet app that teaches children aged 5 to 8 how to write by hand.
The child writes on the screen with a stylus, and the app marks the writing
straight away — whether the whole letter was covered, whether the pen stayed
on the line, and whether the strokes were made in the order children are
taught. It works without internet.

**SPL Group 18**, Islamic University of Technology, CSE
Course: **SWE 4404 — Software Project Lab-II**, 2024-25
Supervisor: **Farzana Tabassum**

| Name | Student ID |
| --- | --- |
| Hasan Mahi | 230042129 |
| Zuhaaer Mustafa Sadab | 230042132 |
| Md Shahib Al Kabir | 230042157 |

## What is in this repository

```
code/   the Flutter application, its tests and its own README
doc/    the documents for all three SPL-II sessions
```

### `doc/`

| File | What it is |
| --- | --- |
| [`doc/srs.pdf`](doc/srs.pdf) | Software Requirements Specification — 24 functional requirements, 33 user stories with acceptance criteria, and 80 unit tests. |
| [`doc/srs.xlsx`](doc/srs.xlsx) | The same SRS as a spreadsheet. |
| [`doc/design.pdf`](doc/design.pdf) | Software Design Report — architecture, class and data design, the marking algorithms, and the alternatives we rejected. |
| [`doc/final-presentation.pdf`](doc/final-presentation.pdf) | The slides presented on 28 October 2026. |
| [`doc/final-report.pdf`](doc/final-report.pdf) | Final project report, all 12 sections. |

### `code/`

```
code/lib/            97 Dart files, about 19,800 lines
code/unit_testing/   129 automated test cases, plus how every test was run
code/assets/         artwork (Microsoft Fluent Emoji, MIT) and sounds
code/ARCHITECTURE.md the three layers, explained with an example
code/README.md       how to build and run the app, and the Firebase setup
```

## How to run it

You need Flutter and an Android phone or emulator.

```bash
cd code
flutter pub get
flutter run
```

The app is Android only. The first free-hand check downloads the Google
handwriting model (about 20 MB) once; after that everything works offline.

## How to run the tests

```bash
cd code
flutter test unit_testing/test
```

129 test cases, covering 58 of the 80 unit tests in the SRS. The other 22 need
a real device (Firebase, the camera, notifications, two-tablet sync) and are
run by hand against the written steps in
`code/unit_testing/KidScribe_Unit_Testing.pdf`.

Full build and Firebase instructions are in [`code/README.md`](code/README.md).
