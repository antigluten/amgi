//
//  Log.swift
//  AppCore
//
//  Created by Vladimir Gusev on 20.08.2026.
//

public import OSLog

/// One `Logger` factory for the whole app.
///
/// Lives in `AppCore` because it is engine-free and already linked by
/// every consumer including the widget and the watch, so routing logging
/// through it adds no dependency edges.
///
/// Two rules for anything logged here: never interpolate note or card
/// content (it is the user's private study material), and never
/// interpolate credentials or absolute paths.
public enum Log {
    public static let subsystem = "com.amgiapp"

    public static let review = Logger(subsystem: subsystem, category: "review")
    public static let browse = Logger(subsystem: subsystem, category: "browse")
    public static let decks = Logger(subsystem: subsystem, category: "decks")
    public static let reader = Logger(subsystem: subsystem, category: "reader")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let widget = Logger(subsystem: subsystem, category: "widget")
    public static let charts = Logger(subsystem: subsystem, category: "charts")
}
