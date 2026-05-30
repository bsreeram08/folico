import CoreServices
import Foundation

struct LiveFileSystemEvent: Equatable {
    enum ItemKind {
        case file
        case folder
    }

    var path: String
    var kind: ItemKind
}

final class FolderLiveUpdateService {
    private let queue = DispatchQueue(label: "folico.live-folder-updates", qos: .utility)
    private let onEvents: ([LiveFileSystemEvent]) -> Void
    private var stream: FSEventStreamRef?
    private var watchedPaths: [String] = []

    init(onEvents: @escaping ([LiveFileSystemEvent]) -> Void) {
        self.onEvents = onEvents
    }

    deinit {
        stop()
    }

    func update(paths: [String]) {
        let normalizedPaths = Array(Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })).sorted()
        guard normalizedPaths != watchedPaths else { return }

        stop()
        watchedPaths = normalizedPaths
        guard !normalizedPaths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagWatchRoot
        )

        guard let stream = FSEventStreamCreate(
            nil,
            Self.callback,
            &context,
            normalizedPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        watchedPaths = []
    }

    private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
        let events = zip(paths, flags).compactMap { path, flags -> LiveFileSystemEvent? in
            guard Self.isCreatedOrRenamed(flags) else { return nil }
            guard Self.isFile(flags) || Self.isFolder(flags) else { return nil }
            return LiveFileSystemEvent(
                path: URL(fileURLWithPath: path).standardizedFileURL.path,
                kind: Self.isFolder(flags) ? .folder : .file
            )
        }

        guard !events.isEmpty else { return }
        onEvents(events)
    }

    private static let callback: FSEventStreamCallback = { _, info, eventCount, eventPaths, eventFlags, _ in
        guard let info else { return }
        let service = Unmanaged<FolderLiveUpdateService>.fromOpaque(info).takeUnretainedValue()
        let paths = (unsafeBitCast(eventPaths, to: CFArray.self) as NSArray).compactMap { $0 as? String }
        let flags = Array(UnsafeBufferPointer(start: eventFlags, count: eventCount))
        service.handle(paths: paths, flags: flags)
    }

    private static func isCreatedOrRenamed(_ flags: FSEventStreamEventFlags) -> Bool {
        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
            || flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
    }

    private static func isFolder(_ flags: FSEventStreamEventFlags) -> Bool {
        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir) != 0
    }

    private static func isFile(_ flags: FSEventStreamEventFlags) -> Bool {
        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0
    }
}
