// PulseLight addition, 2026. See CHANGELOG.md and NOTICE.
import Foundation

/// The single traffic-light state shown by the collapsed rail.
///
/// Hook events are kept per session so a completed turn in one terminal does
/// not hide an approval request or a running turn in another.
enum AgentSignal: String, Codable, Sendable, Equatable {
    case idle
    case running
    case completed
    case attention
}

/// A tiny file inbox shared by hook-mode invocations and the running app.
/// Hook processes only append/replace their own session record and exit; the
/// panel samples those records alongside its transcript-based activity check.
enum AgentEventInbox {
    private struct Record: Codable, Sendable {
        let provider: Provider
        let sessionID: String
        let signal: AgentSignal
        let event: String
        let capturedAt: TimeInterval
    }

    private static let runningLifetime: TimeInterval = 90
    private static let attentionLifetime: TimeInterval = 30 * 60
    private static let completedLifetime: TimeInterval = 8
    private static let retention: TimeInterval = 12 * 60 * 60

    private static var directory: URL {
        if let override = ProcessInfo.processInfo.environment["PULSELIGHT_EVENT_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return PulseStorage.directory.appending(path: "agent-events", directoryHint: .isDirectory)
    }

    static func capture(provider: Provider, event: String, payload: Data) {
        guard let signal = signal(for: event) else { return }

        let root = (try? JSONSerialization.jsonObject(with: payload)) ?? [:]
        let sessionID = findSessionID(in: root) ?? "global"
        let record = Record(
            provider: provider,
            sessionID: sessionID,
            signal: signal,
            event: event,
            capturedAt: Date().timeIntervalSince1970
        )

        guard let data = try? JSONEncoder().encode(record) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file(for: provider, sessionID: sessionID), options: .atomic)
    }

    static func currentSignal(transcriptRunning: Bool, now: Date = Date()) -> AgentSignal {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        var hasAttention = false
        var hasRunning = transcriptRunning
        var hasCompleted = false

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let record = try? JSONDecoder().decode(Record.self, from: data)
            else { continue }

            let age = now.timeIntervalSince1970 - record.capturedAt
            if age > retention {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            guard age >= 0 else { continue }

            switch record.signal {
            case .attention where age <= attentionLifetime: hasAttention = true
            case .running where age <= runningLifetime: hasRunning = true
            case .completed where age <= completedLifetime: hasCompleted = true
            default: break
            }
        }

        if hasAttention { return .attention }
        if hasRunning { return .running }
        if hasCompleted { return .completed }
        return .idle
    }

    private static func signal(for event: String) -> AgentSignal? {
        switch event {
        case "PermissionRequest": .attention
        case "Stop", "StopFailure", "SubagentStop", "SessionEnd": .completed
        case "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
             "PreCompact", "PostCompact", "SubagentStart": .running
        default: nil
        }
    }

    private static func findSessionID(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            for key in ["session_id", "sessionId", "thread_id", "threadId",
                        "conversation_id", "conversationId"] {
                if let string = dictionary[key] as? String, !string.isEmpty { return string }
            }
            for nested in dictionary.values {
                if let found = findSessionID(in: nested) { return found }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                if let found = findSessionID(in: nested) { return found }
            }
        }
        return nil
    }

    private static func file(for provider: Provider, sessionID: String) -> URL {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(provider.rawValue):\(sessionID)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return directory.appending(path: "\(provider.rawValue)-\(String(hash, radix: 16)).json")
    }
}

/// Installs same-executable hooks for Claude Code and Codex. Existing hook
/// groups are preserved; PulseLight only removes or replaces commands carrying
/// its own mode argument.
enum AgentEventHook {
    static let modeArgument = "--pulselight-agent-event"

    private struct Target {
        let provider: Provider
        let settingsFile: URL
        let events: [String]
    }

    private static let claudeEvents = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
        "Stop", "StopFailure", "PermissionRequest"
    ]
    private static let codexEvents = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
        "PermissionRequest", "PreCompact", "PostCompact", "Stop",
        "SubagentStart", "SubagentStop"
    ]

    static func runAsHook() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: modeArgument),
              arguments.indices.contains(index + 2),
              let provider = Provider(rawValue: arguments[index + 1])
        else { return }

        AgentEventInbox.capture(
            provider: provider,
            event: arguments[index + 2],
            payload: FileHandle.standardInput.readDataToEndOfFile()
        )
    }

    @discardableResult
    static func install() -> Bool {
        let executable = executablePath
        guard !executable.isEmpty else { return false }

        var succeeded = true
        for target in targets where FileManager.default.fileExists(
            atPath: target.settingsFile.deletingLastPathComponent().path
        ) {
            guard var settings = currentSettings(at: target.settingsFile) else {
                succeeded = false
                continue
            }
            guard var hooks = hookDictionary(from: settings) else {
                succeeded = false
                continue
            }

            removeOwnHooks(from: &hooks)
            for event in target.events {
                var groups = hooks[event] as? [Any] ?? []
                groups.append([
                    "hooks": [[
                        "type": "command",
                        "command": "\(shellQuoted(executable)) \(modeArgument) \(target.provider.rawValue) \(event)"
                    ]]
                ])
                hooks[event] = groups
            }
            settings["hooks"] = hooks
            if !write(settings, to: target.settingsFile) { succeeded = false }
        }
        return succeeded
    }

    @discardableResult
    static func uninstall() -> Bool {
        var succeeded = true
        for target in targets where FileManager.default.fileExists(atPath: target.settingsFile.path) {
            guard var settings = currentSettings(at: target.settingsFile),
                  var hooks = hookDictionary(from: settings)
            else {
                succeeded = false
                continue
            }
            removeOwnHooks(from: &hooks)
            if hooks.isEmpty {
                settings.removeValue(forKey: "hooks")
            } else {
                settings["hooks"] = hooks
            }
            if !write(settings, to: target.settingsFile) { succeeded = false }
        }
        return succeeded
    }

    /// Reinstalling is also path repair: a build moved to Applications writes
    /// the new executable path while leaving every unrelated hook intact.
    static func installOrRepair() {
        _ = install()
    }

    private static var targets: [Target] {
        let home = ProcessInfo.processInfo.environment["PULSELIGHT_HOOK_HOME"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? URL(fileURLWithPath: NSHomeDirectory())
        return [
            Target(
                provider: .claudeCode,
                settingsFile: home.appending(path: ".claude/settings.json"),
                events: claudeEvents
            ),
            Target(
                provider: .codex,
                settingsFile: home.appending(path: ".codex/hooks.json"),
                events: codexEvents
            )
        ]
    }

    private static var executablePath: String {
        ProcessInfo.processInfo.arguments.first.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        } ?? Bundle.main.executablePath ?? ""
    }

    private static func currentSettings(at file: URL) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        guard let data = try? Data(contentsOf: file),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return root
    }

    /// Nil means an existing `hooks` value has an unknown shape and must not
    /// be overwritten.
    private static func hookDictionary(from settings: [String: Any]) -> [String: Any]? {
        guard let value = settings["hooks"] else { return [:] }
        return value as? [String: Any]
    }

    private static func removeOwnHooks(from hooks: inout [String: Any]) {
        for event in Array(hooks.keys) {
            guard let groups = hooks[event] as? [Any] else { continue }
            var cleaned: [Any] = []

            for rawGroup in groups {
                guard var group = rawGroup as? [String: Any],
                      let commands = group["hooks"] as? [Any]
                else {
                    cleaned.append(rawGroup)
                    continue
                }

                let remaining = commands.filter { rawCommand in
                    guard let command = rawCommand as? [String: Any],
                          let text = command["command"] as? String
                    else { return true }
                    return !text.contains(modeArgument)
                }
                guard !remaining.isEmpty else { continue }
                group["hooks"] = remaining
                cleaned.append(group)
            }

            if cleaned.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = cleaned
            }
        }
    }

    private static func write(_ settings: [String: Any], to file: URL) -> Bool {
        guard let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return false }

        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let backup = file.appendingPathExtension("pulselight-backup")
        if !FileManager.default.fileExists(atPath: backup.path),
           let original = try? Data(contentsOf: file) {
            try? original.write(to: backup, options: .atomic)
        }
        return (try? data.write(to: file, options: .atomic)) != nil
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
