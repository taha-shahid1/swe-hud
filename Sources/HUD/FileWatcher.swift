import Foundation

/// Watches a single file for changes via a kqueue-backed DispatchSource —
/// no polling. Handles the common case where the writer replaces the file
/// atomically (write-to-temp + rename, e.g. `Data.write(options: .atomic)`),
/// which invalidates the original file descriptor: on delete/rename we
/// close and reopen against the new inode rather than going silent.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    deinit {
        source?.cancel()
    }

    private func start() {
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            // File doesn't exist yet (or was briefly missing mid-rename).
            // Retry shortly rather than watching nothing forever.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.start()
            }
            return
        }

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        newSource.setEventHandler { [weak self, weak newSource] in
            guard let self else { return }
            let flags = newSource?.data ?? []
            self.onChange()
            if flags.contains(.delete) || flags.contains(.rename) {
                self.restart()
            }
        }
        let fd = fileDescriptor
        newSource.setCancelHandler {
            close(fd)
        }
        newSource.resume()
        source = newSource
    }

    private func restart() {
        source?.cancel()
        source = nil
        // Give the atomic-replace a beat to finish before reopening.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.start()
        }
    }
}
