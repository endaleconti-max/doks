import Foundation

/// Monitors directories for new files and reports changes via an async sequence.
public final class FileSystemWatcher {
    private var watchedPaths: [String: DirectoryWatcher] = [:]
    private var fileCallbacks: [@Sendable ([URL]) -> Void] = []

    public init() {}

    /// Start monitoring a directory for new files.
    public func startWatching(directory url: URL) throws {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw FileSystemWatcherError.directoryNotFound(path)
        }

        let watcher = DirectoryWatcher(url: url) { [weak self] urls in
            self?.notifyCallbacks(urls)
        }
        watchedPaths[path] = watcher
        try watcher.start()
    }

    /// Set the callback to be invoked when files are added.
    public func setOnFilesAdded(_ callback: @escaping @Sendable ([URL]) -> Void) {
        fileCallbacks.append(callback)
    }

    private func notifyCallbacks(_ urls: [URL]) {
        for callback in fileCallbacks {
            callback(urls)
        }
    }

    /// Stop monitoring a directory.
    public func stopWatching(directory url: URL) {
        let path = url.path
        watchedPaths[path]?.stop()
        watchedPaths.removeValue(forKey: path)
    }

    /// Stop all monitoring.
    public func stopAll() {
        for (_, watcher) in watchedPaths {
            watcher.stop()
        }
        watchedPaths.removeAll()
    }

    /// List currently watched directories.
    public func watchedDirectories() -> [URL] {
        watchedPaths.keys.compactMap { URL(fileURLWithPath: $0) }
    }
}

public enum FileSystemWatcherError: Error, LocalizedError {
    case directoryNotFound(String)
    case watcherAlreadyStarted(String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .watcherAlreadyStarted(let path):
            return "Already watching: \(path)"
        }
    }
}

/// Internal directory watcher using FileSystemEvents.
private class DirectoryWatcher {
    private let url: URL
    private let callback: ([URL]) -> Void
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.org.filesystemwatcher", attributes: .concurrent)

    init(url: URL, callback: @escaping ([URL]) -> Void) {
        self.url = url
        self.callback = callback
    }

    func start() throws {
        let path = url.path
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            { streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
                guard let clientCallBackInfo = clientCallBackInfo else { return }
                let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
                
                let paths = UnsafeMutableRawPointer(mutating: eventPaths).assumingMemoryBound(to: UnsafeMutablePointer<CChar>.self)
                var newFiles: [URL] = []
                
                for i in 0 ..< numEvents {
                    let cPath = paths[Int(i)]
                    let path = String(cString: cPath)
                    let url = URL(fileURLWithPath: path)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
                       !isDir.boolValue {
                        newFiles.append(url)
                    }
                }
                
                if !newFiles.isEmpty {
                    watcher.callback(newFiles)
                }
            },
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents)
        )

        guard let streamRef = streamRef else {
            throw FileSystemWatcherError.directoryNotFound(path)
        }

        self.stream = streamRef
        FSEventStreamSetDispatchQueue(streamRef, queue)
        FSEventStreamStart(streamRef)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
