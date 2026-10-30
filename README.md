# MyDay Assistant (Android / Flutter starter)

This is a starter project for the personal reminder app discussed in ChatGPT.

## Features in this first build
- Add tasks with a title, category, date/time and repeat choice
- Local task list and completion history
- Type `DONE` to confirm completion
- Three missed reminder attempts, then mark the occurrence overdue
- Categories for water, medication, exercise, study, office, login, meals, priority, night beauty and hair care

## Important status
This is a **starter project**, not a tested production APK. Exact alarms, recurring alarms, reboot recovery and manufacturer battery restrictions need device testing before relying on it for important reminders. Do not use this as the sole reminder for critical medication.

## Build
1. Install Flutter and Android Studio on a computer, or use a cloud Flutter build service.
2. Run `flutter pub get`.
3. Run `flutter run` on an Android device, or `flutter build apk --debug`.
4. Test notifications and alarm behaviour on the CMF Phone 1.

The GitHub Actions workflow in `.github/workflows/android.yml` attempts to build a debug APK on each push and makes it available as a workflow artifact.
