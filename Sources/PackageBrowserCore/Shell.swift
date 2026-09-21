import Foundation

struct ShellResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    var succeeded: Bool { exitCode == 0 }
}

enum ShellError: Error, LocalizedError {
    case notFound(String)
    case timedOut(String)
    case failed(command: String, exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .notFound(let command):
            return "\(command) is not installed or not on PATH"
        case .timedOut(let command):
            return "\(command) did not finish in time"
        case .failed(let command, let exitCode, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(command) failed (exit \(exitCode))\(detail.isEmpty ? "" : ": \(detail)")"
        }
    }
}

/// Runs subprocesses on behalf of scanners.
///
/// GUI-launched apps inherit a minimal system PATH, so the search path is
/// seeded from an interactive login zsh (which sources .zprofile/.zshrc,
/// where users put brew/nvm/bun setup) plus well-known install locations.
enum Shell {
    static let defaultTimeout: TimeInterval = 20

    private static let fallbackPath = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        NSHomeDirectory() + "/.bun/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ].joined(separator: ":")

    private static let loginPath: String = {
        // `-il` so .zshrc (nvm, bun, etc.) is sourced too, not just .zprofile.
        // Must run with a bare environment: deriving it from `searchPath` here
        // would reenter this initializer while it is still running.
        let bareEnv = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory()]
        guard let result = exec("/bin/zsh", ["-il", "-c", #"printf %s "$PATH""#], timeout: 10, environment: bareEnv),
              result.succeeded
        else { return "" }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    /// PATH used to resolve commands, login-shell PATH first.
    static var searchPath: String {
        loginPath.isEmpty ? fallbackPath : loginPath + ":" + fallbackPath
    }

    /// Absolute path to `command` if it exists and is executable, else nil.
    static func which(_ command: String) -> String? {
        guard !command.contains("/") else {
            return FileManager.default.isExecutableFile(atPath: command) ? command : nil
        }
        for dir in searchPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent(command).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Runs `command` resolved against the user's PATH.
    @discardableResult
    static func run(command: String, _ arguments: [String], timeout: TimeInterval = defaultTimeout) throws -> ShellResult {
        guard let path = which(command) else {
            throw ShellError.notFound(command)
        }
        return try run(path: path, arguments, timeout: timeout)
    }

    /// Runs an absolute executable path.
    @discardableResult
    static func run(path: String, _ arguments: [String], timeout: TimeInterval = defaultTimeout) throws -> ShellResult {
        guard let result = exec(path, arguments, timeout: timeout, environment: ["PATH": searchPath, "HOME": NSHomeDirectory()]) else {
            throw ShellError.timedOut(path)
        }
        return result
    }

    private static func exec(_ path: String, _ arguments: [String], timeout: TimeInterval, environment: [String: String]) -> ShellResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Drain pipes concurrently so large output can't deadlock against the buffer.
        var stdoutData = Data()
        var stderrData = Data()
        let drainQueue = DispatchQueue(label: "packagebrowser.shell.drain", attributes: .concurrent)
        let drainGroup = DispatchGroup()
        drainGroup.enter()
        drainQueue.async { stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile(); drainGroup.leave() }
        drainGroup.enter()
        drainQueue.async { stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile(); drainGroup.leave() }

        do {
            try process.run()
        } catch {
            return ShellResult(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let exitSemaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { process.waitUntilExit(); exitSemaphore.signal() }
        if exitSemaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if exitSemaphore.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = exitSemaphore.wait(timeout: .now() + 5)
            }
            return nil
        }
        drainGroup.wait()

        return ShellResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}
