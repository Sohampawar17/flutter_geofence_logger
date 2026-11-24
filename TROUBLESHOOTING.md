# Troubleshooting

- No events: inspect Health for services, precise/background permission, Play Services, and native zone count. Walk well beyond the radius and allow Android time.
- Force-stopped: open GeoPulse; Android blocks receivers/jobs until launch.
- Reboot: unlock and allow boot receiver/Play Services time; open the app to reconcile.
- Pending: verify real internet, TLS, credentials, enrollment, and server. A network transport is not proof of internet.
- Authentication: rotate secret and ensure device registration API user matches.
- Boundary churn: increase radius for indoor/poor accuracy; 45-second opposite callbacks are suppressed.
- OEM delay: allow background activity/vendor battery exemption when policy permits.
- Storage failure: free space; do not clear app data before preserving pending events.

Diagnostics redact token-like values. Never include secrets in issue reports.
