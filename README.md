# Calendar

Source preview for Despia V3. The runtime update and automatic discovery rollout are awaiting release. Rebuild and install the native app to include these files; uploading them does not change an installed app.

A Despia V3 extension over iOS EventKit and the Android Calendar Provider. Shared routes cover event and calendar reads, writes, recurrence, alarms, permission state and native editor presentation. Named platform routes expose iOS Reminders and Android provider tables when there is no shared operation.

Part of Despia V3 Extensions. First-party V4 support comes through the new package registry.

Source preview. Requires the upcoming V3 runtime and calendar permission configuration release.

## Web frameworks and app builders

Use the Despia SDK with React, Vue, Svelte, Next.js, TanStack or HTML5. Projects built with Lovable, Base44, Replit and other app builders need custom JavaScript and static file hosting. Claude Code, Codex and Cursor can edit the same extension files.

## Install

1. Copy manifest.json, ios/ and android/ to public/despia/calendar/ in your web app.
2. Add calendar to public/despia/extensions.json. The prepared minimal index is `{ "extensions": ["calendar"] }`; use it only after the no-app-identity runtime reaches your build. Existing matching legacy identity blocks remain compatible. Do not add manifest_version to the index.
3. Supply the five purpose descriptions listed in `ios.app.requires.usage_descriptions`. With the runtime update under review, the verified manifest can provide these strings under `ios.app.info_plist` with `ios.app.custom_keys: true`. Write descriptions that explain your own app. Existing nonempty app-configured descriptions take priority. This path does not require a new backend permission setting.
4. Keep calendar.policy.json as build verification metadata. It declares the Android READ_CALENDAR and WRITE_CALENDAR permission additions. These declarations are separate from the user's runtime consent. The policy file is not served from your site.
5. Rebuild and install the native app with this extension.

Signed build verification binds source hashes, dependency pins, app identity and final artifacts. It is separate from human code review and does not require a per-app enrollment switch.

No Google Calendar cloud OAuth or server credential is included. Android reads calendars on the device, which may be synced by installed Google, Exchange or other account providers. iOS reads the calendars EventKit exposes. Neither OS guarantees that every cloud calendar or remote sharing feature is available through its device API.

## JavaScript SDK

Install the published SDK in your web app:

```sh
npm install despia-native
```

Import `despia` directly from `despia-native`. The examples use SDK 1.0.28. Run native calls from browser event handlers or mounted client hooks; importing the SDK during server rendering is safe. The installed Despia V3 app must include the compiled extension.

Pass the route's exact output variable as the second argument. The SDK resolves an object whose matching property contains the full native envelope: `ok`, `code`, `error` and `data`, with runtime metadata. A native `ok: false` answer does not reject the SDK promise. Check `ok` before reading `data`. A single watched value becomes `undefined` after 30 seconds without an answer. Await calls using the same output variable sequentially.

## Call from the page

Call `readCalendars` from a user action. A permission request can answer `pending` first; query again after the user answers the system prompt.

```javascript
import despia from 'despia-native';

export async function readCalendars() {
  const permissionReply = await despia(
    'extension://calendar/permissions?request=true&access=full',
    ['calendarPermissionsResult']
  );
  const permission = permissionReply.calendarPermissionsResult;
  if (!permission?.ok) throw new Error(permission?.error ?? 'No native answer');
  if (permission.data.pending || permission.data.events !== 'full') return;

  const calendarsReply = await despia(
    'extension://calendar/calendars', ['calendarCalendarsResult']
  );
  const calendars = calendarsReply.calendarCalendarsResult;
  if (!calendars?.ok) throw new Error(calendars?.error ?? 'No native answer');
  return calendars.data;
}

export async function saveEvent(calendarId) {
  const appointment = {
    calendar_id: calendarId, title: 'Example appointment',
    start_ms: Date.now() + 3600000, end_ms: Date.now() + 7200000,
    timezone: 'Europe/Paris', alarms: [{ minutes: 15 }]
  };
  const savedReply = await despia(
    `extension://calendar/event_save?data=${encodeURIComponent(JSON.stringify(appointment))}`,
    ['calendarEventSaveResult']
  );
  const saved = savedReply.calendarEventSaveResult;
  if (!saved?.ok) throw new Error(saved?.error ?? 'No native answer');
  return saved.data;
}
```

Optional native events call `globalThis.onCalendarPermission`, `globalThis.onCalendarChanged` and `globalThis.onCalendarEditor` with their payloads. For example, register the permission handler in mounted client code before requesting access:

```js
const previousCalendarHandler = globalThis.onCalendarPermission;
const handleCalendarEvent = payload => {
  if (typeof previousCalendarHandler === 'function') previousCalendarHandler(payload);
  console.log(payload);
};
globalThis.onCalendarPermission = handleCalendarEvent;

export function cleanupCalendarEvents() {
  if (globalThis.onCalendarPermission === handleCalendarEvent) {
    globalThis.onCalendarPermission = previousCalendarHandler;
  }
}
```

Call `cleanupCalendarEvents` when the client component unmounts. It restores the previous callback only while this component still owns the callback.

The SDK's property proxy reads values; assigning a function on `despia` does not register a native event handler.

IDs are opaque strings, not portable identifiers between platforms or accounts. Dates use Unix milliseconds. A route's `data` parameter is a JSON object encoded into a string of at most 4096 characters.

## Shared routes

| Route | Parameters | Successful data | SDK output variable |
| --- | --- | --- | --- |
| capabilities | None | Provider and supported feature booleans | `calendarCapabilitiesResult` |
| permissions | Optional request boolean, access full, write_only or reminders | Current permission state. A request is acknowledged promptly, then permission event reports the answer. | `calendarPermissionsResult` |
| calendars | Optional entity events or reminders, default events | Calendar rows with common id, title and writable fields. Android also returns raw provider fields under android. Reminders entity is iOS only. | `calendarCalendarsResult` |
| calendar_save | data object with title, optional id; optional entity | Saved calendar id and native metadata where available. New iOS calendars may need source_id. New Android calendars use a local account. | `calendarCalendarSaveResult` |
| calendar_delete | id, optional entity | deleted: true | `calendarCalendarDeleteResult` |
| events | start_ms and end_ms required; optional calendar_id, offset, limit 1..100 | Event occurrences, next_offset, has_more | `calendarEventsResult` |
| event_get | id | Event fields, with platform metadata | `calendarEventGetResult` |
| event_save | data object; optional span this or future; optional occurrence_ms | id, saved: true; Android also series_id with occurrence_ms (this) or split_ms (future) for a recurring event | `calendarEventSaveResult` |
| event_delete | id; optional span this or future; optional occurrence_ms | deleted: true | `calendarEventDeleteResult` |
| present | Optional id, data and mode view, edit or create | presented: true, which does not mean saved | `calendarPresentResult` |

Event data supports id, calendar_id, title, start_ms, end_ms, all_day, timezone, location, notes and alarms. iOS also supports url. New Android events require calendar_id. An update preserves fields not supplied. EventKit requires a writable calendar. Android providers enforce their account and calendar rules.

Alarm writes use `{minutes: 15}` for a reminder 15 minutes before the event. iOS reads return minutes for time-only relative alarms, alongside offset_seconds. Native iOS triggers use an ios object: absolute_ms for an absolute date, structured_location with title, latitude, longitude and radius for a location, and proximity for the native EventKit proximity value. Location alarms can also include offset_seconds. These native fields are available for event and reminder alarm writes. Android event_get returns native reminder rows; the shared Android save route accepts nonnegative minutes before the event.

Recurrence writes use an array of objects with frequency 0 daily, 1 weekly, 2 monthly or 3 yearly, a positive interval, optional end_count or end_ms, days_of_week objects with day 1 Sunday through 7 Saturday and optional week ordinal, and optional days_of_month, months_of_year, weeks_of_year, days_of_year and set_positions. iOS accepts EventKit recurrence rules. Android accepts one RRULE through the shared writer and returns raw RRULE/RDATE/EXRULE/EXDATE under android metadata. For a recurring Android save, include start_ms and end_ms so duration can be formed.

For a recurring event, span this (the default) changes or deletes one occurrence, and span future that occurrence and every later one. occurrence_ms names the occurrence by its start in Unix milliseconds, as events returns it in start_ms; without it the span acts from the first occurrence, so a future delete without occurrence_ms deletes the whole series. An occurrence_ms that is not an occurrence of the event answers not_found. iOS uses EventKit's this-event and future-event spans. Android writes the same result through the Calendar Provider in one atomic batch: this inserts an exception (a changed or cancelled occurrence) for a series a sync account owns; the provider matches exceptions to their series by sync ID, so for a local calendar this adds the occurrence to the series EXDATE and, for a save, writes the changed occurrence as its own event, returned as id with the series as series_id. future ends the series before the occurrence with an RRULE UNTIL and, for a save, starts a new series there carrying the changes, the remaining COUNT and the alarms; the new series has its own id, returned as id with the old one as series_id. The id events returns for an occurrence changed earlier is that occurrence's own exception row: span this acts on that occurrence alone, and span future acts on its series from the occurrence it replaced, as EventKit does. On a local calendar the changed occurrence is its own event with no link back to the series (the provider expands exceptions by sync ID only: AOSP CalendarProvider CalendarInstancesHelper, read 24 November 2026), so a span on that id acts on that event alone.

## Platform methods and native UI

| Route | SDK output variable |
| --- | --- |
| `ios_sources` | `calendarIosSourcesResult` |
| `ios_reminders` | `calendarIosRemindersResult` |
| `ios_reminder_save` | `calendarIosReminderSaveResult` |
| `ios_reminder_delete` | `calendarIosReminderDeleteResult` |
| `android_table` | `calendarAndroidTableResult` |

- ios_sources lists EventKit sources after event or reminders access is granted.
- ios_reminders lists reminder records, optionally filtered by calendar_id and completed, with offset/limit pagination.
- ios_reminder_save accepts a data object with id for updates, calendar_id, title, notes, location, url, priority, completed, start_ms, due_ms, completed_ms, timezone, alarms and recurrence. The device calendar interprets date components. ios_reminder_delete deletes by id. Android returns unsupported for these routes: Calendar Provider reminders are event alarms, not task lists.
- android_table exposes query, insert, update and delete for events, calendars, attendees and reminders, plus read-only instances. Query supports optional id or event_id where appropriate, offset/limit, and start_ms/end_ms for instances. Writes use data with native provider column names and scalar values. Update/delete require a specific id. Sync-adapter-owned fields are not writable through this ordinary-app API. iOS returns unsupported.
- present uses EventKit UI on iOS and installed calendar app intents on Android. iOS 17 can present a create editor without full calendar access; older iOS requires access. Reading an existing event requires full access. The iOS editor event reports saved, deleted, canceled or dismissed. Out-of-process editing does not provide an authoritative saved event payload. Android only acknowledges the handoff and does not claim a saved result; it can return unavailable if no calendar app handles the intent.

No adapter can grant permissions itself. A system dialog may remain open longer than a route deadline, so permission completion is an event and state remains queryable. Activity recreation uses the same namespaced Android Activity Result Registry key. After the app process dies, query state again rather than relying on a past event. changed is a signal to refresh, not a durable change journal. Read results in small pages; provider data and long notes may exceed bridge output limits.

## Platform limits

Current V3 iOS target is 16.6 and later. Android module minSdk24 and compileSdk36. Providers can reject read-only calendars, remote account writes or unsupported columns. iOS attendee fields are read-only in this adapter. Platform-only routes do not promise that every OS SDK method is already wrapped; the source is supplied so developers can add methods their app requires.

[Despia V3 Extensions documentation](https://setup.despia.com/experiments/v3-extensions), [troubleshooting](https://setup.despia.com/experiments/extension-troubleshooting) and [extension skill](https://github.com/despia-legacy/extension-skill).

Platform references: [Apple EventKit access](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui), [Android Calendar Provider](https://developer.android.com/identity/providers/calendar-provider).

## License

[Despia V3 Extension Source-Available Commercial License](LICENSE), version 1.4.
This template is proprietary and source available.

You may inspect, fork, customize, build and run it for noncommercial development,
evaluation and testing without a paid Despia license, including work on an app
you plan to release commercially later.

Production or commercial use requires a valid Despia project and an applicable
Despia license for that application and operating system. A Solo Pack covers
its licensed OS, iOS or Android. A Hybrid Pack covers both. Your applicable
license includes all provided V3 templates you have lawful access to and any
number of your own extensions, with no separate extension purchase or
per-extension fee.

Keep the license and applicable notices. Third-party material keeps its own
terms. Experimental V3 extensions do not include a commitment to maintenance
or a V4 port. See [LICENSE](LICENSE) for the full terms and [Despia](https://despia.com)
for licensing.
