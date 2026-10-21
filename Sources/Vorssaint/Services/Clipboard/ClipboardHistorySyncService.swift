// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import IOKit

/// Opt-in sync of the clipboard history between the user's Macs, through a
/// folder in their own iCloud Drive (issue #3142).
///
/// CloudKit would need an iCloud container entitlement backed by a
/// provisioning profile of one developer team, which a build signed by anyone
/// else, or signed locally, cannot carry. A plain folder in iCloud Drive needs
/// nothing of the sort: iCloud Drive moves the files, and every Mac signed in
/// to the same Apple Account sees the same folder. Each Mac writes only its
/// own file and merges the others' into its history; see ClipboardHistorySync
/// for the rules.
///
/// Main-thread state, with every file operation on one serial queue.
final class ClipboardHistorySyncService: ObservableObject {
    static let shared = ClipboardHistorySyncService()

    enum Status: Equatable {
        case off
        case checking
        case noICloudDrive
        case unreachable
        case synced(at: Date, otherMacs: Int)
    }

    @Published private(set) var status: Status = .off

    /// What this Mac remembers between launches: its deletions and pin
    /// changes, plus those adopted from the other Macs.
    private struct State: Codable, Equatable {
        var deleted: [String: Date] = [:]
        var pinChanges: [String: Date] = [:]
    }

    /// What decides which remote entries fit here; a change merges again.
    private struct Signature: Equatable {
        let policy: ClipboardHistorySyncPolicy
        let limit: Int
        let retentionDays: Int
    }

    private let queue = DispatchQueue(label: "com.vorssaint.utils.clipboard-sync", qos: .utility)
    private static let stateQueue = DispatchQueue(label: "com.vorssaint.utils.clipboard-sync-state",
                                                  qos: .utility)
    private var running = false
    private var device: String?
    private var folder: ClipboardHistorySyncFolder?
    private var state = State()
    private var stateLoaded = false
    private var timer: Timer?
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var defaultsObserver: NSObjectProtocol?
    private var signature: Signature?
    private var publishScheduled = false
    private var publishPending = false
    private var pullScheduled = false
    private var pullInFlight = false
    private var pullAgain = false
    /// Merge even when no file changed: the local limits or filters moved, or
    /// an image was still on its way at the last look.
    private var forceMerge = true

    // Owned by `queue`.
    private var cache: [String: (modified: Date, file: ClipboardHistorySyncFile)] = [:]
    private var lastWritten: Data?
    private var lastCollection: Date?

    private init() {}

    private var wanted: Bool {
        let defaults = UserDefaults.standard
        return AppFeature.clipboardHistory.isAvailable
            && defaults.bool(forKey: DefaultsKey.clipboardHistoryEnabled)
            && defaults.bool(forKey: DefaultsKey.clipboardHistorySyncEnabled)
    }

    func syncWithPreferences() {
        wanted ? start() : stop()
    }

    /// The settings switch. Turning it off also takes this Mac's copy out of
    /// iCloud Drive; the other Macs keep what they already received.
    func setEnabled(_ enabled: Bool) {
        if enabled {
            syncWithPreferences()
            return
        }
        stop()
        state = State()
        saveState()
        guard let device = device ?? Self.deviceIdentifier() else { return }
        queue.async { [weak self] in
            guard let self, let folder = ClipboardHistorySyncFolder.inICloudDrive() else { return }
            folder.removeDeviceFile(device)
            // Pictures another Mac may still name stay for that Mac's own
            // sweep when its file cannot be read right now.
            if let referenced = folder.imagesNamedByOthers(excluding: device) {
                folder.collectGarbage(referenced: referenced, grace: 0)
                folder.removeIfEmpty()
            }
            self.cache = [:]
            self.lastWritten = nil
        }
    }

    // MARK: - Hooks from the history

    /// Any saved change: a new copy, a re-copy, a move, an edit, a trim.
    func historyDidChange() {
        guard running else { return }
        schedulePublish()
    }

    /// Entries the user deleted or cleared, as opposed to ones the local
    /// limits dropped: only these are deleted on the other Macs too.
    func historyDidRemove(_ removed: [ClipboardHistoryEntry]) {
        guard running, !removed.isEmpty else { return }
        let now = Date()
        for key in ClipboardHistorySync.deletedKeys(for: removed, policy: Self.currentPolicy()) {
            state.deleted[key] = now
        }
        saveState()
        schedulePublish()
    }

    func historyDidChangePin(_ entry: ClipboardHistoryEntry) {
        guard running, ClipboardHistorySync.allows(entry, policy: Self.currentPolicy()),
              let key = ClipboardHistorySync.key(for: entry) else { return }
        state.pinChanges[key] = Date()
        saveState()
        schedulePublish()
    }

    /// Quit must not lose a deletion made just before it: the next launch
    /// would otherwise take the entry back from another Mac.
    func flushBeforeTermination() {
        Self.stateQueue.sync {}
    }

    // MARK: - Running

    private func start() {
        guard !running else { return }
        running = true
        status = .checking
        loadState()
        device = device ?? Self.deviceIdentifier()
        forceMerge = true
        lastPublishNeeded = true
        signature = currentSignature()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.preferencesMayHaveChanged()
        }
        tick()
    }

    private func stop() {
        guard running else { return }
        running = false
        timer?.invalidate()
        timer = nil
        watcher?.cancel()
        watcher = nil
        watchedURL = nil
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        defaultsObserver = nil
        status = .off
    }

    /// Finds the folder (iCloud Drive can be turned on or off at any time),
    /// then looks for news and publishes whatever is waiting.
    private func tick() {
        guard running else { return }
        guard device != nil else {
            status = .unreachable
            return
        }
        queue.async { [weak self] in
            let folder = ClipboardHistorySyncFolder.inICloudDrive()
            let ready = folder?.prepare() ?? false
            DispatchQueue.main.async {
                guard let self, self.running else { return }
                self.folder = ready ? folder : nil
                guard let folder, ready else {
                    self.status = folder == nil ? .noICloudDrive : .unreachable
                    self.unwatch()
                    return
                }
                if self.status == .noICloudDrive || self.status == .unreachable {
                    self.status = .checking
                    self.lastPublishNeeded = true
                }
                self.watch(folder.root)
                self.pull()
                if self.publishPending || self.lastPublishNeeded { self.publish() }
            }
        }
    }

    /// The first look after starting always publishes, so a Mac that just
    /// turned sync on shows up for the others even with nothing new copied.
    private var lastPublishNeeded = true

    private func preferencesMayHaveChanged() {
        guard running else { return }
        let current = currentSignature()
        guard current != signature else { return }
        signature = current
        forceMerge = true
        schedulePull()
        schedulePublish()
    }

    private func currentSignature() -> Signature {
        let defaults = UserDefaults.standard
        return Signature(
            policy: Self.currentPolicy(),
            limit: Defaults.sanitizedClipboardHistoryLimit(defaults.integer(forKey: DefaultsKey.clipboardHistoryLimit)),
            retentionDays: Defaults.sanitizedClipboardHistoryRetentionDays(
                defaults.integer(forKey: DefaultsKey.clipboardHistoryRetentionDays)))
    }

    /// The same filters the history applies while it records, read now: an
    /// app added to the ignore list or the sensitive filter turned on also
    /// keeps entries saved before from leaving this Mac.
    static func currentPolicy() -> ClipboardHistorySyncPolicy {
        let defaults = UserDefaults.standard
        return ClipboardHistorySyncPolicy(
            includesImages: defaults.bool(forKey: DefaultsKey.clipboardHistorySyncImages)
                && defaults.bool(forKey: DefaultsKey.clipboardHistoryIncludeImagesFiles),
            skipsSensitiveText: defaults.bool(forKey: DefaultsKey.clipboardHistoryFilterSensitiveText),
            ignoredApps: Set(ClipboardIgnoredApps.shared.apps))
    }

    // MARK: - Watching the folder

    private func watch(_ url: URL) {
        guard watchedURL != url else { return }
        unwatch()
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .rename, .delete],
                                                               queue: .main)
        source.setEventHandler { [weak self] in self?.schedulePull() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
        watchedURL = url
    }

    private func unwatch() {
        watcher?.cancel()
        watcher = nil
        watchedURL = nil
    }

    // MARK: - Publishing

    private func schedulePublish() {
        publishPending = true
        guard !publishScheduled else { return }
        publishScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.publishScheduled = false
            self.publish()
        }
    }

    private func publish() {
        guard running, let device, let folder else { return }
        publishPending = false
        lastPublishNeeded = false
        let entries = ClipboardHistoryService.shared.entries
        let policy = Self.currentPolicy()
        let keys = Set(entries.compactMap { ClipboardHistorySync.key(for: $0) })
        state.deleted = ClipboardHistorySync.prunedTombstones(state.deleted)
        state.pinChanges = ClipboardHistorySync.prunedPinChanges(state.pinChanges, keeping: keys)
        let deleted = state.deleted
        let pinChanges = state.pinChanges
        let imageDirectory = ClipboardImageStore.directory
        queue.async { [weak self] in
            guard let self else { return }
            let records = ClipboardHistorySync.records(for: entries, policy: policy, pinChanges: pinChanges) {
                entry in
                guard let name = entry.imageFile, let imageDirectory,
                      let values = try? imageDirectory.appendingPathComponent(name)
                          .resourceValues(forKeys: [.fileSizeKey]) else { return nil }
                return values.fileSize
            }
            let file = ClipboardHistorySyncFile(device: device, records: records, deleted: deleted)
            guard let data = ClipboardHistorySync.encoded(file) else { return }
            var succeeded = true
            if data != self.lastWritten
                || !FileManager.default.fileExists(atPath: folder.deviceFileURL(device).path) {
                // Pictures first, so no Mac reads an entry before its picture.
                let names = Dictionary(entries.compactMap { entry in
                    entry.imageHash.flatMap { hash in entry.imageFile.map { (hash, $0) } }
                }, uniquingKeysWith: { first, _ in first })
                for record in records {
                    guard let hash = ClipboardHistorySync.imageHash(fromKey: record.key),
                          !folder.hasImage(hash),
                          let name = names[hash],
                          let png = ClipboardImageStore.imageData(named: name) else { continue }
                    _ = folder.writeImage(png, hash: hash)
                }
                succeeded = folder.write(data, device: device)
                if succeeded { self.lastWritten = data }
            }
            if succeeded, self.lastCollection.map({ Date().timeIntervalSince($0) > 86_400 }) ?? true,
               let others = folder.imagesNamedByOthers(excluding: device) {
                self.lastCollection = Date()
                let own = records.compactMap { ClipboardHistorySync.imageHash(fromKey: $0.key) }
                folder.collectGarbage(referenced: others.union(own))
            }
            let otherMacs = self.cache.count
            DispatchQueue.main.async {
                guard self.running else { return }
                self.status = succeeded ? .synced(at: Date(), otherMacs: otherMacs) : .unreachable
            }
        }
    }

    // MARK: - Pulling

    private func schedulePull() {
        guard !pullScheduled else { return }
        pullScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.pullScheduled = false
            self.pull()
        }
    }

    private func pull() {
        guard running, let device, let folder else { return }
        guard !pullInFlight else {
            pullAgain = true
            return
        }
        pullInFlight = true
        let history = ClipboardHistoryService.shared
        let snapshot = history.entries
        let protectedIDs = Set([history.editingEntryID].compactMap { $0 })
        let signature = currentSignature()
        let deleted = state.deleted
        let pinChanges = state.pinChanges
        let force = forceMerge
        forceMerge = false
        queue.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let listings = folder.otherDevices(excluding: device)
                .filter { !ClipboardHistorySync.isStale(modified: $0.modified, now: now) }
            var changed = force
            var files: [ClipboardHistorySyncFile] = []
            for listing in listings {
                if let cached = self.cache[listing.device], cached.modified == listing.modified {
                    files.append(cached.file)
                } else if let file = folder.read(listing) {
                    self.cache[listing.device] = (listing.modified, file)
                    files.append(file)
                    changed = true
                } else if let cached = self.cache[listing.device] {
                    files.append(cached.file)
                }
            }
            let present = Set(listings.map(\.device))
            if self.cache.keys.contains(where: { !present.contains($0) }) {
                self.cache = self.cache.filter { present.contains($0.key) }
            }
            guard changed else {
                DispatchQueue.main.async { self.finishPull(nil, otherMacs: files.count) }
                return
            }
            let merge = ClipboardHistorySync.merge(local: snapshot, remotes: files, tombstones: deleted,
                                                   pinChanges: pinChanges, policy: signature.policy,
                                                   protectedIDs: protectedIDs, now: now) { _ in
                ClipboardHistorySync.pendingImageFile
            }
            // The local limits apply before any picture is fetched, so a long
            // history elsewhere never downloads what this Mac would drop.
            let trimmed = ClipboardHistoryEditing.retainedEntries(merge.entries,
                                                                  recentLimit: signature.limit,
                                                                  retentionDays: signature.retentionDays,
                                                                  ageExemptIDs: protectedIDs)
            var images: [String: Data] = [:]
            let pending = ClipboardHistorySync.pendingImageHashes(trimmed)
            for hash in pending {
                images[hash] = folder.readImage(hash)
            }
            let result = PullResult(snapshot: snapshot, merge: merge, signature: signature,
                                    protectedIDs: protectedIDs, images: images,
                                    waitingForImages: images.count < pending.count)
            DispatchQueue.main.async { self.finishPull(result, otherMacs: files.count) }
        }
    }

    private struct PullResult {
        let snapshot: [ClipboardHistoryEntry]
        let merge: ClipboardHistorySync.Merge
        let signature: Signature
        let protectedIDs: Set<UUID>
        let images: [String: Data]
        let waitingForImages: Bool
    }

    private func finishPull(_ result: PullResult?, otherMacs: Int) {
        pullInFlight = false
        guard running else { return }
        if let result {
            state.deleted = ClipboardHistorySync.latest(state.deleted, result.merge.tombstones)
            state.pinChanges = ClipboardHistorySync.latest(state.pinChanges, result.merge.pinChanges)
            saveState()
            let history = ClipboardHistoryService.shared
            if history.entries == result.snapshot {
                // Stored here on the main thread, in the same turn the entries
                // land: the history's own sweep runs here too and would
                // otherwise take a picture whose entry is not in the list yet.
                var stored: [String: String] = [:]
                for (hash, data) in result.images {
                    stored[hash] = ClipboardImageStore.store(data)
                }
                // Trimmed again once the pictures that did not arrive are out,
                // so they never push a local entry past the limit.
                let resolved = ClipboardHistoryEditing.retainedEntries(
                    ClipboardHistorySync.resolvingImages(result.merge.entries, stored: stored),
                    recentLimit: result.signature.limit,
                    retentionDays: result.signature.retentionDays,
                    ageExemptIDs: result.protectedIDs)
                if resolved != result.snapshot { history.applySyncedEntries(resolved) }
                forceMerge = forceMerge || result.waitingForImages
            } else {
                // The history moved while the files were read; merge again.
                forceMerge = true
                pullAgain = true
            }
        }
        // A failed write says more than a successful read, until a write lands.
        if status != .unreachable {
            status = .synced(at: Date(), otherMacs: otherMacs)
        }
        if pullAgain {
            pullAgain = false
            schedulePull()
        }
    }

    // MARK: - Local state

    private static var stateURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent("ClipboardHistorySync.json")
    }

    private func loadState() {
        guard !stateLoaded else { return }
        stateLoaded = true
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let url = Self.stateURL,
              let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true, (values.fileSize ?? .max) <= ClipboardHistorySync.maxFileBytes,
              let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode(State.self, from: data)
        else { return }
        state = State(deleted: ClipboardHistorySync.prunedTombstones(decoded.deleted),
                      pinChanges: decoded.pinChanges.filter { ClipboardHistorySync.isValidKey($0.key) })
    }

    private func saveState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        guard let url = Self.stateURL else { return }
        let empty = state == State()
        let data = empty ? nil : try? encoder.encode(state)
        Self.stateQueue.async {
            guard let data else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            PrivateFileStore.createDirectory(at: url.deletingLastPathComponent())
            PrivateFileStore.write(data, to: url)
        }
    }

    // MARK: - This Mac

    /// A hash of the Mac's hardware identifier, the account and the bundle,
    /// so a restored backup or a migrated account on a new Mac never writes
    /// the same file as the Mac it came from.
    static func deviceIdentifier() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let hardware = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString,
                                                             kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String, !hardware.isEmpty
        else { return nil }
        return ClipboardHistorySync.deviceIdentifier(hardware: hardware, user: NSUserName(),
                                                     bundle: Bundle.main.bundleIdentifier ?? "")
    }
}
