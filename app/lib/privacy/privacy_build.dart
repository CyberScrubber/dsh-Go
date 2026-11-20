// Privacy build switch. `--dart-define=DSH_PRIVACY=1` turns the app into the
// build that talks to nothing but the model provider (and a linked desktop
// DSH): no anonymous usage stats, no engine OTel feedback, no ML Kit, no
// update checks. Keep every gate behind this flag so a normal build stays
// upstream-compatible and a sync only has to keep these small branches.
//
// The engine side is switched separately: DSH_TELEMETRY_DISABLED=1 and the
// privacy rows in AppAuthGuest.PATCH_YAML. See privacy/README.md.

const privacyBuild = bool.fromEnvironment('DSH_PRIVACY');
