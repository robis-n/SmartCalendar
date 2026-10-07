# SmartCalendar

A calendar and accountability app. Plan tasks, prove you did them with a photo, and keep each other honest with friends.

Built with Flutter. The backend is Supabase.

## What it does

- **Tasks and calendar** – day and week views, repeating tasks, events from your phone's calendar.
- **Photo verification** – take a photo to prove a task is done. An AI check runs on the server, with an on-device check as a fallback.
- **Friends** – add friends, share tasks, send nudges.
- **Analytics** – see how many tasks you complete.
- **Reminders** – local notifications and alarms.

## Run it

You need Flutter 3.44 or newer.

1. Create a `.env` file in the project root:

   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

   Only put public values here. This file is packed into the app, so anything in it can be read by anyone who has the app.

2. Install packages and run:

   ```
   flutter pub get
   flutter run
   ```

## Backend

The Supabase project holds the database, sign-in and three Edge Functions:

| Function | What it does |
|---|---|
| `verify-photo` | Checks a verification photo with Claude. Needs the `ANTHROPIC_API_KEY` secret set in Supabase. |
| `login-with-username` | Signs a user in by username. The email lookup stays on the server. |
| `verify-task-photo` | Older version of `verify-photo`. Not used by the app. |

Source for `login-with-username` and the database change that goes with it are in `supabase/`.

## Builds

GitHub Actions does the building:

- **CI — Analyze & Test** runs on every push and pull request. It also builds the web version.
- **Build iOS IPA** builds an unsigned iOS file on every push to `main`, or when started by hand.

Download the results from the run's page under **Artifacts**. They are kept for 7 days.

GitHub needs two repository secrets: `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

## Project layout

```
lib/
  core/       theme, router, shared helpers
  features/   one folder per screen area (tasks, calendar, friends, ...)
  services/   Supabase, notifications, verification
  shared/     widgets used in more than one place
supabase/     Edge Function source and database changes
```
