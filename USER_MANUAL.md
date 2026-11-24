# GeoPulse Employee Attendance — User Manual

## Before first use

1. Install the production-signed Android application supplied by your company.
2. Open GeoPulse and enter the HTTPS address of your company ERPNext/Frappe site.
3. Sign in with your employee account. The account must be linked to an active Employee record.
4. Grant precise location and notification access. For background geofence monitoring, also select **Allow all the time**.
5. Exclude GeoPulse from battery optimization when your company uses automatic ENTER/EXIT monitoring.

## How automatic geofence logging works

A geofence is a virtual circle around an assigned work location. The location's latitude, longitude, and allowed radius define the monitored area. GeoPulse asks Android to monitor enabled locations, including while the app is minimized or the screen is locked.

Automatic geofence logs and manual attendance are separate:

- **ENTER** and **EXIT** are automatic boundary events shown in the **Geofence entry & exit log**.
- **Check In** and **Check Out** are attendance actions made with the button on the **Home** screen.
- An automatic ENTER does not press Check In for the employee, and an automatic EXIT does not press Check Out.

### When a geofence log is created

- **ENTER** is created when Android reports that the phone has moved from outside an enabled geofence to inside it.
- **EXIT** is created when Android reports that the phone has moved from inside an enabled geofence to outside it.
- When monitoring starts and the phone is already inside, the initial inside state may create an ENTER.
- When monitoring starts and the phone is already outside, GeoPulse only establishes the outside state. It does **not** create a false EXIT.

GeoPulse does not create another log while the phone remains in the same state. Duplicate callbacks, callbacks older than the last accepted event, and opposite callbacks received within 45 seconds of the last event are ignored. This reduces duplicate logs caused by GPS movement near the boundary.

The radius is a boundary, not a continuous attendance check. The displayed distance and captured location provide context, but they do not independently create an ENTER or EXIT; an Android geofence callback is required.

### Conditions required for automatic logging

- The employee must have an assigned, enabled location registered on the phone.
- Android Location must be turned on.
- Precise location and **Allow all the time** background location permission must remain granted.
- Google Play services and Android geofencing must be available.
- The app must not be force-stopped. After a force-stop or some device restarts, open GeoPulse once so monitoring can resume or be checked.
- Battery Saver or manufacturer background restrictions can delay or prevent callbacks. Excluding GeoPulse from battery optimization is recommended.

Internet is not required at the moment of entry or exit. GeoPulse first saves the event on the phone as **Pending**, then uploads it when synchronization and internet access are available. Do not clear application data while events are pending.

Android controls when geofence callbacks are delivered. A log can appear later than the physical crossing, especially indoors, with weak GPS, under Battery Saver, or when moving only a short distance across the boundary. Exact real-time delivery is not guaranteed. For reliable testing, walk well beyond the configured radius and allow Android time to update.

### Information captured for an automatic event

Each automatic event includes a unique event ID, ENTER or EXIT type, callback time, geofence ID and name, configured radius, and sync status. When location data is available, it also includes latitude, longitude, accuracy, and calculated distance from the geofence center. Device context includes battery percentage, charging state, network type, internet availability, installation/device ID, Android version, manufacturer, and model. If a fresh callback location is unavailable, some location fields may use the last known position or remain empty.

After a log is accepted, GeoPulse shows a local ENTER or EXIT notification. Users can review logs in **Home > Geofence entry & exit log** or **Event history**. Administrators can review **Pending**, **Synced**, and **Failed** counts on the synchronization/health screens.

## Check in

1. Turn on Android Location and wait for an accurate position.
2. Open **Home** and tap **Check In**.
3. A successful action appears under **Today**. A cloud-upload icon means it is safely stored on the phone and waiting for internet; a cloud-done icon means the server accepted it.

## Check out

Open **Home** and tap **Check Out**. GeoPulse prevents two consecutive check-ins or check-outs on the same installation.

## Offline use

Check In and Check Out can be saved without internet after the employee has signed in. Location must still be enabled. Pending records remain in the local database and are retried when connectivity returns and the app synchronizes.

## Information captured

Every attendance action records the action and event time, latitude, longitude, reported accuracy, battery percentage and charging state, network transport, installation ID, Android version, manufacturer, and model. The server separately records its receipt time. Management access is controlled by Frappe roles.

## Location warning

Android does not allow an application to prevent a user from disabling Location. GeoPulse displays a high-priority notification when Location is switched off. Attendance cannot be recorded until Location is restored.

## Troubleshooting

- **Location accuracy is too low:** move near a window or outdoors and retry.
- **Session expired:** sign in again; pending local attendance remains stored.
- **Not linked to an Employee:** ask HR to set the employee's User ID and ensure the Employee is Active.
- **Pending upload:** confirm internet access and pull down to refresh. Do not clear application data.
- **No Location alert:** allow notifications in Android settings.

## Administrator deployment

Install and migrate the included `geofence_logger` Frappe app. Give reporting access only to HR Manager, Geofence Manager, or System Manager. Use valid TLS, a release signing key, backups, log monitoring, rate limiting, and an organization-specific privacy/retention policy before rollout.
