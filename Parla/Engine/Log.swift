import OSLog

/// One place for the little that Parla records: enough to diagnose a stuck
/// session, nothing that identifies what you said.
enum Log {
    static let speech = Logger(subsystem: "app.fornace.parla", category: "speech")
    static let tutor = Logger(subsystem: "app.fornace.parla", category: "tutor")
    static let debrief = Logger(subsystem: "app.fornace.parla", category: "debrief")
    static let store = Logger(subsystem: "app.fornace.parla", category: "store")
}
