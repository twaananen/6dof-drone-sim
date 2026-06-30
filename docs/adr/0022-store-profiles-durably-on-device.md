# Store profiles durably on device

Tunable Control Profiles, Drone Profiles, and Last Good Bindings should be stored on the Quest headset so they survive reboots and application updates. Profile changes should auto-save because the Quick Tuning Loop and Solo Pilot Operation depend on trusted profile state persisting across sessions.

When profile formats change, the app should migrate Device-Persistent Profiles automatically where possible and clearly mark profiles incompatible in setup when safe migration is not possible.
