// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The shared folder the Macs sync through: a folder in the user's own iCloud
/// Drive, or any folder a test names. Each Mac writes `<device>.json` and
/// nothing else of the others'; images live once under `Images/<hash>.png`,
/// so two Macs that upload the same picture write the same bytes.
///
/// Only this folder is ever read. Nothing else in iCloud Drive is listed or
/// opened, so no other file is downloaded on the Mac's behalf.
struct ClipboardHistorySyncFolder {
    let root: URL

    var imagesURL: URL { root.appendingPathComponent("Images", isDirectory: true) }

    /// `~/Library/Mobile Documents/com~apple~CloudDocs`, the folder Finder
    /// shows as iCloud Drive. It only exists while iCloud Drive is on.
    static func iCloudDriveURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let url = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        return url
    }

    static func inICloudDrive(home: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> ClipboardHistorySyncFolder? {
        iCloudDriveURL(home: home).map {
            ClipboardHistorySyncFolder(root: $0.appendingPathComponent("Vorssaint/Clipboard History",
                                                                       isDirectory: true))
        }
    }

    func deviceFileURL(_ device: String) -> URL {
        root.appendingPathComponent(device + ".json")
    }

    func imageURL(_ hash: String) -> URL {
        imagesURL.appendingPathComponent(hash + ".png")
    }

    @discardableResult
    func prepare() -> Bool {
        let manager = FileManager.default
        return (try? manager.createDirectory(at: imagesURL, withIntermediateDirectories: true)) != nil
    }

    // MARK: - Device files

    struct Listing: Equatable {
        let device: String
        let url: URL
        let modified: Date
    }

    /// The other Macs' files that are ready to read. One iCloud has not
    /// brought down yet is asked for and left for a later look, so a read
    /// never waits on the network.
    func otherDevices(excluding device: String) -> [Listing] {
        scan(excluding: device).listings
    }

    /// Also says whether any Mac's file is still on its way, when what the
    /// listings name is not the whole picture.
    func scan(excluding device: String) -> (listings: [Listing], waiting: Bool) {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: root.path) else { return ([], true) }
        var listings: [Listing] = []
        var waiting = false
        for name in names {
            // Before iCloud Drive moved to File Provider, a file that was not
            // downloaded showed up as a hidden `.<name>.icloud` stand-in.
            if name.hasPrefix("."), name.hasSuffix(".json.icloud") {
                let real = String(name.dropFirst().dropLast(".icloud".count))
                let stem = String(real.dropLast(".json".count))
                if ClipboardHistorySync.isValidDevice(stem), stem != device {
                    try? manager.startDownloadingUbiquitousItem(at: root.appendingPathComponent(real))
                    waiting = true
                }
                continue
            }
            guard name.hasSuffix(".json") else { continue }
            let stem = String(name.dropLast(".json".count))
            guard ClipboardHistorySync.isValidDevice(stem), stem != device else { continue }
            let url = root.appendingPathComponent(name)
            guard let values = try? url.resourceValues(forKeys: Self.fileKeys),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate
            else { continue }
            if Self.needsDownload(values) {
                try? manager.startDownloadingUbiquitousItem(at: url)
                waiting = true
                continue
            }
            listings.append(Listing(device: stem, url: url, modified: modified))
        }
        return (listings.sorted { $0.device < $1.device }, waiting)
    }

    /// Every picture the other Macs' files name, or nil when one of them
    /// could not be read: a sweep then waits rather than guess.
    func imagesNamedByOthers(excluding device: String, now: Date = Date()) -> Set<String>? {
        let scan = scan(excluding: device)
        guard !scan.waiting else { return nil }
        var referenced: Set<String> = []
        for listing in scan.listings where !ClipboardHistorySync.isStale(modified: listing.modified, now: now) {
            guard let file = read(listing) else { return nil }
            referenced.formUnion(file.records.compactMap { ClipboardHistorySync.imageHash(fromKey: $0.key) })
        }
        return referenced
    }

    func read(_ listing: Listing) -> ClipboardHistorySyncFile? {
        guard let data = coordinatedRead(listing.url, limit: ClipboardHistorySync.maxFileBytes) else { return nil }
        return ClipboardHistorySync.decoded(data, device: listing.device)
    }

    func write(_ data: Data, device: String) -> Bool {
        guard prepare() else { return false }
        return coordinatedWrite(data, to: deviceFileURL(device))
    }

    func removeDeviceFile(_ device: String) {
        coordinatedRemove(deviceFileURL(device))
    }

    // MARK: - Images

    func hasImage(_ hash: String) -> Bool {
        FileManager.default.fileExists(atPath: imageURL(hash).path)
    }

    /// Writes a picture once. Its name is the hash of its bytes, so a file
    /// already there is the same picture and is left alone.
    func writeImage(_ data: Data, hash: String) -> Bool {
        guard ClipboardHistorySync.isHash(hash), data.count <= ClipboardHistorySync.maxImageBytes,
              ClipboardHistorySync.sha256Hex(data) == hash else { return false }
        if hasImage(hash) { return true }
        guard prepare() else { return false }
        return coordinatedWrite(data, to: imageURL(hash))
    }

    /// The picture, or nil while it is still on its way or when its bytes do
    /// not match its name.
    func readImage(_ hash: String) -> Data? {
        guard ClipboardHistorySync.isHash(hash) else { return nil }
        let url = imageURL(hash)
        guard let values = try? url.resourceValues(forKeys: Self.fileKeys),
              values.isRegularFile == true, values.isSymbolicLink != true
        else {
            let standIn = imagesURL.appendingPathComponent("." + hash + ".png.icloud")
            if FileManager.default.fileExists(atPath: standIn.path) {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            return nil
        }
        if Self.needsDownload(values) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return nil
        }
        guard let data = coordinatedRead(url, limit: ClipboardHistorySync.maxImageBytes),
              ClipboardHistorySync.sha256Hex(data) == hash else { return nil }
        return data
    }

    /// Removes pictures no Mac's file names any more. A file younger than
    /// `grace` stays: the Mac that wrote it may not have published the entry
    /// naming it yet, or its file may still be on its way here. No grace
    /// removes every unnamed picture, whatever its date.
    func collectGarbage(referenced: Set<String>, now: Date = Date(), grace: TimeInterval = 7 * 86_400) {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: imagesURL.path) else { return }
        for name in names {
            let hash = name.hasSuffix(".png") ? String(name.dropLast(".png".count)) : ""
            if ClipboardHistorySync.isHash(hash), referenced.contains(hash) { continue }
            let url = imagesURL.appendingPathComponent(name)
            guard let values = try? url.resourceValues(forKeys: Self.fileKeys),
                  values.isSymbolicLink != true,
                  grace <= 0 || values.contentModificationDate.map({ now.timeIntervalSince($0) > grace }) == true
            else { continue }
            coordinatedRemove(url)
        }
    }

    /// Leaves nothing behind once the last Mac stops syncing.
    func removeIfEmpty() {
        let manager = FileManager.default
        for url in [imagesURL, root, root.deletingLastPathComponent()] {
            guard let names = try? manager.contentsOfDirectory(atPath: url.path),
                  names.allSatisfy({ $0 == ".DS_Store" }) else { return }
            try? manager.removeItem(at: url)
        }
    }

    // MARK: - File access

    private static let fileKeys: Set<URLResourceKey> = [
        .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey,
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
    ]

    private static func needsDownload(_ values: URLResourceValues) -> Bool {
        values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current
    }

    /// Reads through the file coordinator, the way iCloud expects, and checks
    /// the size before trusting the bytes.
    private func coordinatedRead(_ url: URL, limit: Int) -> Data? {
        var result: Data?
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: .withoutChanges,
                                                         error: &error) { readURL in
            guard let values = try? readURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true, let size = values.fileSize, size <= limit,
                  let data = try? Data(contentsOf: readURL), data.count <= limit
            else { return }
            result = data
        }
        return result
    }

    private func coordinatedWrite(_ data: Data, to url: URL) -> Bool {
        var written = false
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing,
                                                         error: &error) { writeURL in
            written = (try? data.write(to: writeURL, options: .atomic)) != nil
        }
        return written
    }

    private func coordinatedRemove(_ url: URL) {
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forDeleting,
                                                         error: &error) { deleteURL in
            try? FileManager.default.removeItem(at: deleteURL)
        }
    }
}
