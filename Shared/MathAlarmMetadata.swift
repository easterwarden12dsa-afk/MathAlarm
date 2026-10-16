import AlarmKit

/// Extra data AlarmKit hands to the lock-screen / Dynamic Island widget.
/// Shared by the app and the widget extension.
struct MathAlarmMetadata: AlarmMetadata {
    var label: String
    var challenge: String
    var purpose: String
}
