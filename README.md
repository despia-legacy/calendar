# Calendar

Source preview for Despia V3. This snapshot requires the runtime update currently awaiting release and an approved extension-enabled native build. Uploading these files does not change an installed app.

A Despia V3 extension over iOS EventKit and the Android Calendar Provider. Shared routes cover event and calendar reads, writes, recurrence, alarms, permission state and native editor presentation. Named platform routes expose iOS Reminders and Android provider tables when there is no shared operation.

Part of Despia V3 Extensions. First-party V4 support comes through the new package registry.

Source preview. Requires the upcoming V3 runtime and calendar permission configuration release.

## Web frameworks and app builders

Use the Despia SDK with React, Vue, Svelte, Next.js, TanStack or HTML5. Projects built with Lovable, Base44, Replit and other app builders need custom JavaScript and static file hosting. Claude Code, Codex and Cursor can edit the same extension files.

## Install in an approved extension build

1. Copy manifest.json, ios/ and android/ to public/despia/calendar/ in your web app.
2. Add calendar to public/despia/extensions.json. The prepared minimal index is `{ "extensions": ["calendar"] }`; use it only after the no-app-identity runtime reaches your build. Existing matching legacy identity blocks remain compatible. Do not add manifest_version to the index.
3. Supply the five purpose descriptions listed in `ios.app.requires.usage_descriptions`. With the runtime update under review, the approved manifest can provide these strings under `ios.app.info_plist` with `ios.app.custom_keys: true`. Write descriptions that explain your own app. Existing nonempty app-configured descriptions take priority. This path does not require a new backend permission setting.
4. Send calendar.policy.json with the approval request. It declares the Android READ_CALENDAR and WRITE_CALENDAR permission additions. These declarations are separate from the user's runtime consent. The policy file is not served from your site.
5. Approve the source and rebuild through the extension-enabled path, then install that artifact.

No Google Calendar cloud OAuth or server credential is included. Android reads calendars on the device, which may be synced by installed Google, Exchange or other account providers. iOS reads the calendars EventKit exposes. Neither OS guarantees that every cloud calendar or remote sharing feature is available through its device API.

## JavaScript SDK

Install the SDK in your web app:

```sh
npm install despia-native
```

Copy `example/src/lib/despia-extension.js` to your app's `src/lib/` and adjust the import path if needed. It imports `despia` from `despia-native`, calls the SDK and returns the native answer's `data`. It checks native error envelopes and throws an error with their `code`. The SDK itself resolves native `ok: false` envelopes; it does not reject them. A single watched value becomes `undefined` after 30 seconds, which this helper reports as `sdk_timeout`.

Each helper call forwards a unique native callback into a separate watched value, so overlapping calls do not share response globals. `onExtensionEvent` registers the declared native event callbacks and returns a cleanup function. Events are callbacks, not values you can poll from the SDK proxy.

Importing the SDK is safe during server rendering. Run calls and event subscriptions only from browser click handlers or mounted client hooks. React and Vue can use the browser APIs used by this helper; in Next.js and other server-rendered apps, keep these calls in client code. The extension must be included in the installed Despia V3 app; a browser preview has no native extension features.

## Call from the page

```javascript
import { extensionCall, onExtensionEvent } from './lib/despia-extension.js';
const calendar = (route, params) => extensionCall('calendar', route, params);
const stopPermissions = onExtensionEvent('onCalendarPermission', state => console.log(state));
const stopChanges = onExtensionEvent('onCalendarChanged', change => console.log(change));

export async function readCalendars() {
  const permission = await calendar('permissions', { request: true, access: 'full' });
  if (permission.pending || permission.events !== 'full') return;
  return calendar('calendars');
}
export const saveEvent = calendarId => calendar('event_save', { data: {
  calendar_id: calendarId, title: 'Example appointment',
  start_ms: Date.now() + 3600000, end_ms: Date.now() + 7200000,
  timezone: 'Europe/Paris', alarms: [{ minutes: 15 }]
}});
// A permission request may answer pending first. Read again after its permission event.
// On unmount: stopPermissions(); stopChanges();
```

The helper waits for each answer and returns its data. Native permission and editor updates use the declared event callbacks. IDs are opaque strings, not portable identifiers between platforms or accounts. Dates use Unix milliseconds. The route's data parameter is a JSON object encoded into a string of at most 4096 characters.

## Shared routes

| Route | Parameters | Successful data |
| --- | --- | --- |
| capabilities | None | Provider and supported feature booleans |
| permissions | Optional request boolean, access full, write_only or reminders | Current permission state. A request is acknowledged promptly, then permission event reports the answer. |
| calendars | Optional entity events or reminders, default events | Calendar rows with common id, title and writable fields. Android also returns raw provider fields under android. Reminders entity is iOS only. |
| calendar_save | data object with title, optional id; optional entity | Saved calendar id and native metadata where available. New iOS calendars may need source_id. New Android calendars use a local account. |
| calendar_delete | id, optional entity | deleted: true |
| events | start_ms and end_ms required; optional calendar_id, offset, limit 1..100 | Event occurrences, next_offset, has_more |
| event_get | id | Event fields, with platform metadata |
| event_save | data object; optional span this or future | id, saved: true |
| event_delete | id; optional span | deleted: true for supported operations |
| present | Optional id, data and mode view, edit or create | presented: true, which does not mean saved |

Event data supports id, calendar_id, title, start_ms, end_ms, all_day, timezone, location, notes and alarms. iOS also supports url. New Android events require calendar_id. An update preserves fields not supplied. EventKit requires a writable calendar. Android providers enforce their account and calendar rules.

Alarm writes use `{minutes: 15}` for a reminder 15 minutes before the event. iOS reads return minutes for time-only relative alarms, alongside offset_seconds. Native iOS triggers use an ios object: absolute_ms for an absolute date, structured_location with title, latitude, longitude and radius for a location, and proximity for the native EventKit proximity value. Location alarms can also include offset_seconds. These native fields are available for event and reminder alarm writes. Android event_get returns native reminder rows; the shared Android save route accepts nonnegative minutes before the event.

Recurrence writes use an array of objects with frequency 0 daily, 1 weekly, 2 monthly or 3 yearly, a positive interval, optional end_count or end_ms, days_of_week objects with day 1 Sunday through 7 Saturday and optional week ordinal, and optional days_of_month, months_of_year, weeks_of_year, days_of_year and set_positions. iOS accepts EventKit recurrence rules. Android accepts one RRULE through the shared writer and returns raw RRULE/RDATE/EXRULE/EXDATE under android metadata. For a recurring Android save, include start_ms and end_ms so duration can be formed.

EventKit supports this-event and future-event mutations. Android future-series splitting and recurring-series deletion need explicit provider operations through android_table. The shared delete route returns unsupported rather than silently deleting a recurring series. This extension does not implement an atomic Android series-split helper. Use native code when the operation needs a transaction spanning multiple provider rows.

## Platform methods and native UI

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

[Despia V3 Extension Source-Available Commercial License](LICENSE).
You may inspect the source. Using or modifying this extension requires a valid
Despia commercial license and a valid Despia project for the particular app.
The standard price is **USD 249 per application per operating system**.
iOS and Android require separate licenses. See [Despia](https://despia.com).
Third-party SDKs keep their own licenses. Experimental V3 extensions do not
include a commitment to maintenance or a V4 port.

## Source and licensing

Browse, clone or fork this source to inspect it. Public GitHub forks remain public. For private development, clone into a private workspace or private repository. Modification, building, execution and deployment require a valid Despia commercial license and a valid Despia project for the application. The standard price is USD 249 per application per operating system. Licensed users may customize the extension or use it as a reference for new functionality in that licensed app. Keep the license and applicable notices. See [LICENSE](LICENSE) for the terms.
