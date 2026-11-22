import Foundation
import NotchpadCore

/// Runs AppleScript with NSAppleScript. Call it off the main thread (AppModel uses a serial queue).
struct AppleScriptRunner: ScriptRunning {
    func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { DebugTools.log("applescript error: \(error[NSAppleScript.errorNumber] ?? "?")") }
        return result
    }
}
