# Unit testing

This folder holds the unit tests for KidScribe and the paper that explains
how each one was run.

| | |
| --- | --- |
| SRS unit tests | 80 |
| Run automatically by the computer | 58 |
| Run by hand on the emulator | 22 |
| Dart test cases written | 129 |
| Passed | **129** |
| Failed | 0 |

## Run the automatic tests

Open a terminal in the `kidscribe` folder and type:

```bash
flutter test unit_testing/test
```

It takes about 23 seconds. The last line should say `All tests passed!`.

## What is in this folder

| | |
| --- | --- |
| `test/` | The test code. One file per part of the app. |
| `results/flutter_test_output.txt` | The whole output of our last run. |
| `KidScribe_Unit_Testing.pdf` | How every one of the 80 tests was run, with the steps for the ones we did by hand. |

## The test files

| File | What it checks | SRS tests |
| --- | --- | --- |
| `password_rules_test.dart` | The password rules on the sign up screen | T_7 to T_11 |
| `family_service_test.dart` | Saving child profiles and classes | T_17, T_19, T_20, T_21 |
| `profile_cubits_test.dart` | The rules when adding a child or a class | T_18, T_22 |
| `trace_evaluator_test.dart` | Marking a traced stroke or letter | T_23 to T_28 |
| `sentence_checker_test.dart` | Stage 4 grammar rules | T_31 to T_34 |
| `stages_and_progress_test.dart` | The five stages, progress, saved work | T_35, T_36, T_59 to T_62 |
| `letter_match_test.dart` | The Letter Match game | T_37, T_38 |
| `badges_test.dart` | Badges and the daily streak | T_43, T_44 |
| `toy_words_test.dart` | The blurry photo check and word rules | T_48 |
| `assignment_service_test.dart` | Tasks, deadlines, timed tests, marks | T_49, T_50, T_55, T_72 to T_76, T_78 to T_80 |
| `teacher_dashboard_test.dart` | The class view and tasks with no goal | T_51 to T_54, T_56 |
| `report_service_test.dart` | Making and saving the report file | T_57, T_58 |
| `premium_test.dart` | The demo payment and the locked report | T_65 to T_68 |
| `feedback_test.dart` | Written feedback | T_69 to T_71 |
| `my_tasks_test.dart` | The child's task list and test mode | T_77 |

`helpers.dart` is not a test. It holds small pieces the other files share,
like starting each test with an empty storage.

## Why 22 tests are done by hand

Some tests cannot run on a computer on their own:

- **Signing up and logging in** (T_1 to T_6, T_12 to T_16) need Firebase's
  real servers.
- **Reading handwriting** (T_29, T_30, T_39 to T_42) needs Google's model,
  which only runs on an Android device.
- **Reminders** (T_45, T_46) are sent by Android itself.
- **Toy words** (T_47) needs the camera.
- **Sync** (T_63, T_64) needs two devices and the internet.

The PDF lists the exact steps for each of these.
