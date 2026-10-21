// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// iCloud sync of the clipboard history, played out between simulated Macs:
/// each one a history, a pin clock, a set of deletions and a device id, all of
/// them writing into one shared folder on disk the way iCloud Drive shows it.
enum ClipboardHistorySyncTests {
    static let textOnly = ClipboardHistorySyncPolicy(includesImages: false, skipsSensitiveText: false,
                                                     ignoredApps: [])
    static let withImages = ClipboardHistorySyncPolicy(includesImages: true, skipsSensitiveText: false,
                                                       ignoredApps: [])

    /// One Mac: what its history holds and what it remembers for sync. It
    /// publishes and merges through the production functions and the
    /// production folder code.
    final class Mac {
        let device: String
        var entries: [ClipboardHistoryEntry] = []
        var deleted: [String: Date] = [:]
        var pinChanges: [String: Date] = [:]
        var policy: ClipboardHistorySyncPolicy
        let folder: ClipboardHistorySyncFolder
        /// The image store of this Mac: stored name to bytes.
        var images: [String: Data] = [:]

        init(_ name: String, folder: ClipboardHistorySyncFolder, policy: ClipboardHistorySyncPolicy = textOnly) {
            device = ClipboardHistorySync.deviceIdentifier(hardware: name, user: "tester", bundle: "com.example")
            self.folder = folder
            self.policy = policy
        }

        func copy(_ text: String, at date: Date, source: String? = nil) {
            entries.removeAll { $0.kind == .text && $0.text == text }
            var entry = ClipboardHistoryEntry(text: text, copiedAt: date)
            entry.sourceBundleID = source
            let firstRecent = entries.firstIndex { !$0.isPinned } ?? entries.endIndex
            entries.insert(entry, at: firstRecent)
        }

        func copyImage(_ data: Data, at date: Date) {
            let name = UUID().uuidString + ".png"
            images[name] = data
            let entry = ClipboardHistoryEntry(text: "", copiedAt: date, kind: .image, imageFile: name,
                                              imageHash: ClipboardHistorySync.sha256Hex(data),
                                              imageWidth: 2, imageHeight: 1)
            let firstRecent = entries.firstIndex { !$0.isPinned } ?? entries.endIndex
            entries.insert(entry, at: firstRecent)
        }

        func delete(_ text: String, at date: Date) {
            let removed = entries.filter { $0.text == text }
            entries.removeAll { $0.text == text }
            for key in ClipboardHistorySync.deletedKeys(for: removed, policy: policy) { deleted[key] = date }
        }

        func pin(_ text: String, _ pinned: Bool, at date: Date) {
            guard let index = entries.firstIndex(where: { $0.text == text }) else { return }
            var entry = entries.remove(at: index)
            entry.pinnedAt = pinned ? date : nil
            if !pinned { entry.copiedAt = date }
            entries.insert(entry, at: pinned ? 0 : (entries.firstIndex { !$0.isPinned } ?? entries.endIndex))
            if let key = ClipboardHistorySync.key(for: entry) { pinChanges[key] = date }
        }

        @discardableResult
        func publish() -> Bool {
            let records = ClipboardHistorySync.records(for: entries, policy: policy, pinChanges: pinChanges) {
                entry in entry.imageFile.flatMap { self.images[$0]?.count }
            }
            for record in records {
                guard let hash = ClipboardHistorySync.imageHash(fromKey: record.key),
                      let entry = entries.first(where: { $0.imageHash == hash }),
                      let data = entry.imageFile.flatMap({ images[$0] }) else { continue }
                _ = folder.writeImage(data, hash: hash)
            }
            let file = ClipboardHistorySyncFile(device: device, records: records, deleted: deleted)
            guard let data = ClipboardHistorySync.encoded(file) else { return false }
            return folder.write(data, device: device)
        }

        /// What the service does: merge with stand-ins, trim, fetch the
        /// pictures that survive, store them, resolve.
        func pull(now: Date, limit: Int = 50) {
            let remotes = folder.otherDevices(excluding: device).compactMap { folder.read($0) }
            let merge = ClipboardHistorySync.merge(local: entries, remotes: remotes, tombstones: deleted,
                                                   pinChanges: pinChanges, policy: policy, now: now) { _ in
                ClipboardHistorySync.pendingImageFile
            }
            let trimmed = ClipboardHistoryEditing.retainedEntries(merge.entries, recentLimit: limit, now: now)
            var stored: [String: String] = [:]
            for hash in ClipboardHistorySync.pendingImageHashes(trimmed) {
                guard let data = folder.readImage(hash) else { continue }
                let name = UUID().uuidString + ".png"
                images[name] = data
                stored[hash] = name
            }
            entries = ClipboardHistoryEditing.retainedEntries(
                ClipboardHistorySync.resolvingImages(merge.entries, stored: stored), recentLimit: limit, now: now)
            deleted = ClipboardHistorySync.latest(deleted, merge.tombstones)
            pinChanges = ClipboardHistorySync.latest(pinChanges, merge.pinChanges)
        }

        var texts: [String] { entries.map { $0.kind == .text ? $0.text : "image:" + ($0.imageHash ?? "") } }
    }

    static func run(_ suite: TestSuite) {
        suite.run("clipboard sync") {
            keysAndGate(suite)
            publishing(suite)
            reading(suite)
            merging(suite)
            twoMacs(suite)
            folderSafety(suite)
            statusDisplay(suite)
            strings(suite)
        }
    }

    private static func temporaryFolder() -> (ClipboardHistorySyncFolder, URL) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("vorssaint-clipboard-sync-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("Vorssaint/Clipboard History", isDirectory: true)
        return (ClipboardHistorySyncFolder(root: root), base)
    }

    private static func keysAndGate(_ suite: TestSuite) {
        let text = ClipboardHistoryEntry(text: "Hello")
        suite.expect(ClipboardHistorySync.key(for: text) == ClipboardHistorySync.textKey("Hello")
                     && ClipboardHistorySync.key(for: ClipboardHistoryEntry(text: "Hello", copiedAt: .distantPast))
                     == ClipboardHistorySync.key(for: text),
                     "the same text has the same key on every Mac, whenever it was copied")
        suite.expect(ClipboardHistorySync.key(for: ClipboardHistoryEntry(text: "Hello ")) != ClipboardHistorySync.key(for: text),
                     "different text has a different key")
        let hash = ClipboardHistorySync.sha256Hex(Data([1, 2, 3]))
        let image = ClipboardHistoryEntry(text: "", kind: .image, imageFile: "a.png", imageHash: hash)
        suite.expect(ClipboardHistorySync.key(for: image) == "i:" + hash
                     && ClipboardHistorySync.imageHash(fromKey: "i:" + hash) == hash,
                     "an image is keyed by the hash of its bytes, which is also its file name")
        let files = ClipboardHistoryEntry(text: "", kind: .files, filePaths: ["/Users/me/report.pdf"])
        suite.expect(ClipboardHistorySync.key(for: files) == nil
                     && !ClipboardHistorySync.allows(files, policy: withImages),
                     "copied files never sync: a path only means something on one Mac")
        suite.expect(ClipboardHistorySync.key(for: ClipboardHistoryEntry(text: "", kind: .image, imageFile: "a.png",
                                                                         imageHash: "../../etc"))
                     == nil && ClipboardHistorySync.imageHash(fromKey: "i:../x") == nil,
                     "a hash that is not one never becomes a key or a file name")
        suite.expect(!ClipboardHistorySync.allows(image, policy: textOnly)
                     && ClipboardHistorySync.allows(image, policy: withImages),
                     "images sync only when the user chose text and images")
        let secret = ClipboardHistoryEntry(text: "export API_KEY=abc123")
        let strict = ClipboardHistorySyncPolicy(includesImages: false, skipsSensitiveText: true, ignoredApps: [])
        suite.expect(!ClipboardHistorySync.allows(secret, policy: strict)
                     && ClipboardHistorySync.allows(secret, policy: textOnly),
                     "the sensitive text filter also keeps entries saved before it was on from syncing")
        var fromIgnored = ClipboardHistoryEntry(text: "From the password app")
        fromIgnored.sourceBundleID = "com.example.vault"
        let ignoring = ClipboardHistorySyncPolicy(includesImages: false, skipsSensitiveText: false,
                                                  ignoredApps: ["com.example.vault"])
        suite.expect(!ClipboardHistorySync.allows(fromIgnored, policy: ignoring),
                     "an entry from an app added to the ignore list later stays on this Mac")
        suite.expect(ClipboardHistorySync.deletedKeys(for: [secret, text, files], policy: strict)
                     == [ClipboardHistorySync.textKey("Hello")],
                     "deleting something that never synced publishes not even its hash")
        let a = ClipboardHistorySync.deviceIdentifier(hardware: "HW-1", user: "me", bundle: "com.vorssaint.utils")
        suite.expect(a == ClipboardHistorySync.deviceIdentifier(hardware: "HW-1", user: "me", bundle: "com.vorssaint.utils")
                     && a != ClipboardHistorySync.deviceIdentifier(hardware: "HW-2", user: "me", bundle: "com.vorssaint.utils")
                     && a != ClipboardHistorySync.deviceIdentifier(hardware: "HW-1", user: "me",
                                                                   bundle: "com.vorssaint.utils.developer")
                     && ClipboardHistorySync.isValidDevice(a) && !a.contains("HW"),
                     "each Mac, account and app build writes its own file, named without revealing the Mac")
    }

    private static func publishing(_ suite: TestSuite) {
        let now = Date()
        var pinned = ClipboardHistoryEntry(text: "Pinned", copiedAt: now.addingTimeInterval(-50))
        pinned.pinnedAt = now.addingTimeInterval(-40)
        let recent = ClipboardHistoryEntry(text: "Recent", copiedAt: now)
        let huge = ClipboardHistoryEntry(text: String(repeating: "x", count: ClipboardHistorySync.maxTextBytes + 1))
        let blank = ClipboardHistoryEntry(text: "   ")
        let small = ClipboardHistoryEntry(text: "", kind: .image, imageFile: "small.png",
                                          imageHash: ClipboardHistorySync.sha256Hex(Data([1])))
        let big = ClipboardHistoryEntry(text: "", kind: .image, imageFile: "big.png",
                                        imageHash: ClipboardHistorySync.sha256Hex(Data([2])))
        let gone = ClipboardHistoryEntry(text: "", kind: .image, imageFile: "gone.png",
                                         imageHash: ClipboardHistorySync.sha256Hex(Data([3])))
        let sizes = ["small.png": 10, "big.png": ClipboardHistorySync.maxImageBytes + 1]
        let records = ClipboardHistorySync.records(for: [recent, pinned, huge, blank, small, big, gone],
                                                   policy: withImages,
                                                   pinChanges: [ClipboardHistorySync.textKey("Pinned"): now]) {
            $0.imageFile.flatMap { sizes[$0] }
        }
        suite.expect(records.map(\.key) == [ClipboardHistorySync.textKey("Pinned"), ClipboardHistorySync.textKey("Recent"),
                                            "i:" + small.imageHash!],
                     "pinned entries go first, and text or pictures too large to sync, or gone, stay here")
        suite.expect(records[0].pinnedAt == pinned.pinnedAt && records[0].pinChangedAt == now
                     && records[1].pinChangedAt == nil && records[2].text.isEmpty,
                     "a record carries its pin and when the pin last changed")
        let many = (0..<(ClipboardHistorySync.maxRecords + 20)).map { ClipboardHistoryEntry(text: "Item \($0)") }
        let capped = ClipboardHistorySync.records(for: many, policy: textOnly, pinChanges: [:]) { _ in nil }
        suite.expect(capped.count == ClipboardHistorySync.maxRecords && capped.first?.text == "Item 0",
                     "an unlimited history publishes only its newest entries")
        let pictures = (0..<(ClipboardHistorySync.maxImages + 5)).map { index in
            ClipboardHistoryEntry(text: "", kind: .image, imageFile: "\(index).png",
                                  imageHash: ClipboardHistorySync.sha256Hex(Data("\(index)".utf8)))
        }
        suite.expect(ClipboardHistorySync.records(for: pictures, policy: withImages, pinChanges: [:]) { _ in 100 }.count
                     == ClipboardHistorySync.maxImages,
                     "the number of synced pictures is bounded")
    }

    private static func reading(_ suite: TestSuite) {
        let device = ClipboardHistorySync.deviceIdentifier(hardware: "A", user: "u", bundle: "b")
        let good = ClipboardHistorySyncRecord(key: ClipboardHistorySync.textKey("Fine"), kind: .text, text: "Fine",
                                              copiedAt: Date(timeIntervalSince1970: 1_000), pinnedAt: nil,
                                              pinChangedAt: nil, source: "com.apple.Safari",
                                              imageWidth: nil, imageHeight: nil)
        let file = ClipboardHistorySyncFile(device: device, records: [good],
                                            deleted: [ClipboardHistorySync.textKey("Old"): Date(timeIntervalSince1970: 900)])
        let data = ClipboardHistorySync.encoded(file)!
        suite.expect(ClipboardHistorySync.decoded(data, device: device) == file,
                     "a published file reads back exactly")
        suite.expect(ClipboardHistorySync.decoded(data, device: "abcdef") == nil,
                     "a file whose name does not match the Mac inside it is ignored")
        suite.expect(ClipboardHistorySync.encoded(file) == data,
                     "the same history encodes to the same bytes, so nothing is rewritten for no change")

        func json(_ records: String, format: Int = 1) -> Data {
            Data("{\"format\":\(format),\"device\":\"\(device)\",\"deleted\":{},\"records\":[\(records)]}".utf8)
        }
        let goodJSON = String(data: try! JSONEncoder.syncTest.encode(good), encoding: .utf8)!
        let tampered = goodJSON.replacingOccurrences(of: "\"Fine\"", with: "\"Changed\"")
        let filesKind = goodJSON.replacingOccurrences(of: "\"kind\":\"text\"", with: "\"kind\":\"files\"")
        suite.expect(ClipboardHistorySync.decoded(json(goodJSON + "," + tampered + "," + filesKind))?.records == [good],
                     "a record whose text does not match its key, or that names files, is dropped")
        let mixed = ClipboardHistorySync.decoded(json("{\"kind\":\"rich\",\"key\":\"x\"}," + goodJSON))
        suite.expect(mixed?.records == [good],
                     "a record of a kind a newer version added is skipped, the rest still syncs, found \(String(describing: mixed))")
        suite.expect(ClipboardHistorySync.decoded(json(goodJSON, format: 2)) == nil,
                     "a file in a format this version does not know is left alone")
        suite.expect(ClipboardHistorySync.decoded(Data(count: ClipboardHistorySync.maxFileBytes + 1)) == nil
                     && ClipboardHistorySync.decoded(Data("not json".utf8)) == nil,
                     "oversized or broken files are ignored")
        let now = Date()
        suite.expect(ClipboardHistorySync.isStale(modified: now.addingTimeInterval(-ClipboardHistorySync.tombstoneLifetime - 1),
                                                  now: now)
                     && !ClipboardHistorySync.isStale(modified: now.addingTimeInterval(-86_400), now: now),
                     "a Mac silent for longer than deletions are remembered no longer counts")
        var tombstones: [String: Date] = [:]
        for index in 0..<(ClipboardHistorySync.maxTombstones + 10) {
            tombstones[ClipboardHistorySync.textKey("\(index)")] = now.addingTimeInterval(-Double(index))
        }
        tombstones[ClipboardHistorySync.textKey("ancient")] = now.addingTimeInterval(-ClipboardHistorySync.tombstoneLifetime - 5)
        tombstones["t:not-a-hash"] = now
        let pruned = ClipboardHistorySync.prunedTombstones(tombstones, now: now)
        suite.expect(pruned.count == ClipboardHistorySync.maxTombstones
                     && pruned[ClipboardHistorySync.textKey("0")] != nil
                     && pruned[ClipboardHistorySync.textKey("ancient")] == nil && pruned["t:not-a-hash"] == nil,
                     "deletions are remembered for a bounded time and number, newest first")
    }

    private static func merging(_ suite: TestSuite) {
        let now = Date()
        let device = ClipboardHistorySync.deviceIdentifier(hardware: "remote", user: "u", bundle: "b")
        func record(_ text: String, _ copiedAt: Date, pinnedAt: Date? = nil, pinChangedAt: Date? = nil,
                    source: String? = nil) -> ClipboardHistorySyncRecord {
            ClipboardHistorySyncRecord(key: ClipboardHistorySync.textKey(text), kind: .text, text: text,
                                       copiedAt: copiedAt, pinnedAt: pinnedAt, pinChangedAt: pinChangedAt,
                                       source: source, imageWidth: nil, imageHeight: nil)
        }
        func merge(_ local: [ClipboardHistoryEntry], _ records: [ClipboardHistorySyncRecord],
                   deleted: [String: Date] = [:], own: [String: Date] = [:], pins: [String: Date] = [:],
                   policy: ClipboardHistorySyncPolicy = textOnly, protected: Set<UUID> = [])
            -> ClipboardHistorySync.Merge {
            ClipboardHistorySync.merge(local: local,
                                       remotes: [ClipboardHistorySyncFile(device: device, records: records,
                                                                          deleted: deleted)],
                                       tombstones: own, pinChanges: pins, policy: policy,
                                       protectedIDs: protected, now: now) { _ in ClipboardHistorySync.pendingImageFile }
        }
        let older = ClipboardHistoryEntry(text: "Older", copiedAt: now.addingTimeInterval(-300))
        let newer = ClipboardHistoryEntry(text: "Newer", copiedAt: now.addingTimeInterval(-100))
        let arrived = merge([newer, older], [record("Middle", now.addingTimeInterval(-200), source: "com.apple.Notes")])
        suite.expect(arrived.entries.map(\.text) == ["Newer", "Middle", "Older"],
                     "a copy from elsewhere slots in by its copy time, found \(arrived.entries.map(\.text))")
        suite.expect(arrived.entries[1].sourceBundleID == "com.apple.Notes"
                     && arrived.entries[1].copiedAt == now.addingTimeInterval(-200),
                     "it keeps the app and the time it was copied")
        // A manual move put the older entry first; that order stays.
        let moved = merge([older, newer], [record("Fresh", now.addingTimeInterval(-50))])
        suite.expect(moved.entries.map(\.text) == ["Fresh", "Older", "Newer"],
                     "the order the user gave the other entries by hand stays, found \(moved.entries.map(\.text))")
        let recopied = merge([newer, older], [record("Older", now.addingTimeInterval(-10))])
        suite.expect(recopied.entries.map(\.text) == ["Older", "Newer"] && recopied.entries[0].id == older.id,
                     "copying the same text on another Mac moves the existing entry up instead of adding one")
        let stale = merge([newer, older], [record("Older", now.addingTimeInterval(-1_000))])
        suite.expect(stale.entries == [newer, older], "an older copy elsewhere changes nothing")

        let deletedAfter = merge([newer, older], [], deleted: [ClipboardHistorySync.textKey("Older"): now.addingTimeInterval(-50)])
        suite.expect(deletedAfter.entries.map(\.text) == ["Newer"],
                     "a deletion made after the last copy removes the entry")
        let copiedAfter = merge([newer], [record("Older", now.addingTimeInterval(-20))],
                                own: [ClipboardHistorySync.textKey("Older"): now.addingTimeInterval(-50)])
        suite.expect(copiedAfter.entries.map(\.text) == ["Older", "Newer"],
                     "copying it again after the deletion brings it back")
        let deletedBefore = merge([newer], [record("Older", now.addingTimeInterval(-300))],
                                  own: [ClipboardHistorySync.textKey("Older"): now.addingTimeInterval(-50)])
        suite.expect(deletedBefore.entries.map(\.text) == ["Newer"],
                     "a Mac that still holds a deleted entry cannot bring it back")
        suite.expect(deletedAfter.tombstones[ClipboardHistorySync.textKey("Older")] != nil,
                     "deletions from other Macs are passed on, so they outlive the Mac that made them")

        let farFuture = now.addingTimeInterval(365 * 86_400)
        let skewed = merge([], [record("Skewed", farFuture)])
        suite.expect(skewed.entries.first?.copiedAt == now,
                     "a Mac with its clock far ahead cannot pin an entry to the top for ever")
        let deletedFromFuture = merge([newer], [], deleted: [ClipboardHistorySync.textKey("Newer"): farFuture])
        suite.expect(deletedFromFuture.tombstones[ClipboardHistorySync.textKey("Newer")] == now
                     && deletedFromFuture.entries.isEmpty,
                     "nor keep a deletion in force past any later copy")

        let pinnedElsewhere = merge([newer, older], [record("Older", older.copiedAt, pinnedAt: now.addingTimeInterval(-5),
                                                            pinChangedAt: now.addingTimeInterval(-5))])
        suite.expect(pinnedElsewhere.entries.map(\.text) == ["Older", "Newer"]
                     && pinnedElsewhere.entries[0].isPinned
                     && pinnedElsewhere.pinChanges[ClipboardHistorySync.textKey("Older")] == now.addingTimeInterval(-5),
                     "a pin made on another Mac pins the entry here, on top")
        var pinnedHere = older
        pinnedHere.pinnedAt = now.addingTimeInterval(-60)
        let unpinnedLater = merge([pinnedHere, newer], [record("Older", now.addingTimeInterval(-4), pinnedAt: nil,
                                                               pinChangedAt: now.addingTimeInterval(-4))],
                                  pins: [ClipboardHistorySync.textKey("Older"): now.addingTimeInterval(-60)])
        suite.expect(unpinnedLater.entries.map(\.text) == ["Older", "Newer"] && !unpinnedLater.entries[0].isPinned,
                     "a later unpin elsewhere unpins it here, as the newest recent entry")
        let unpinnedEarlier = merge([pinnedHere, newer], [record("Older", older.copiedAt, pinnedAt: nil,
                                                                 pinChangedAt: now.addingTimeInterval(-90))],
                                    pins: [ClipboardHistorySync.textKey("Older"): now.addingTimeInterval(-60)])
        suite.expect(unpinnedEarlier.entries[0].isPinned, "an older unpin loses to a newer pin")
        let untouched = merge([newer, older], [record("Older", older.copiedAt)])
        suite.expect(untouched.entries == [newer, older], "nobody changed the pin, so each Mac keeps its own")
        let pinnedAfterClear = merge([], [record("Kept", now.addingTimeInterval(-100), pinnedAt: now.addingTimeInterval(-5),
                                                 pinChangedAt: now.addingTimeInterval(-5))],
                                     own: [ClipboardHistorySync.textKey("Kept"): now.addingTimeInterval(-30)])
        suite.expect(pinnedAfterClear.entries.map(\.text) == ["Kept"],
                     "an entry pinned elsewhere after this Mac cleared it is kept")

        let strict = ClipboardHistorySyncPolicy(includesImages: false, skipsSensitiveText: true,
                                                ignoredApps: ["com.example.vault"])
        let filtered = merge([], [record("password=hunter2", now), record("From vault", now, source: "com.example.vault"),
                                  record("Plain", now)], policy: strict)
        suite.expect(filtered.entries.map(\.text) == ["Plain"],
                     "what this Mac's history would skip is not taken from another Mac either")
        var keptHere = ClipboardHistoryEntry(text: "Same words", copiedAt: now.addingTimeInterval(-500))
        keptHere.sourceBundleID = "com.example.vault"
        let doubled = merge([keptHere], [record("Same words", now, source: "com.apple.Safari")], policy: strict)
        suite.expect(doubled.entries == [keptHere],
                     "an entry kept off sync still stands for its content, so the same text from elsewhere never doubles it")
        let imageRecord = ClipboardHistorySyncRecord(key: "i:" + ClipboardHistorySync.sha256Hex(Data([9])), kind: .image,
                                                     text: "", copiedAt: now, pinnedAt: nil, pinChangedAt: nil,
                                                     source: nil, imageWidth: 3, imageHeight: 4)
        suite.expect(merge([], [imageRecord]).entries.isEmpty, "a text only Mac does not take pictures")
        let pending = merge([], [imageRecord], policy: withImages)
        suite.expect(ClipboardHistorySync.pendingImageHashes(pending.entries) == [ClipboardHistorySync.sha256Hex(Data([9]))]
                     && pending.entries[0].imageWidth == 3,
                     "a picture this Mac lacks waits for its bytes")
        let resolved = ClipboardHistorySync.resolvingImages(pending.entries + [newer],
                                                            stored: [ClipboardHistorySync.sha256Hex(Data([9])): "stored.png"])
        suite.expect(resolved.map(\.imageFile) == ["stored.png", nil] && resolved[0].id == pending.entries[0].id,
                     "a fetched picture takes its stored file name")
        suite.expect(ClipboardHistorySync.resolvingImages(pending.entries + [newer], stored: [:]) == [newer],
                     "a picture still on its way is left out until the next look")
        let localPicture = ClipboardHistoryEntry(text: "", kind: .image, imageFile: "mine.png",
                                                 imageHash: ClipboardHistorySync.sha256Hex(Data([5])))
        let pictureDeleted = merge([localPicture], [], deleted: ["i:" + ClipboardHistorySync.sha256Hex(Data([5])): now])
        suite.expect(pictureDeleted.entries == [localPicture],
                     "a text only Mac keeps its own pictures when another Mac deletes them")
        let files = ClipboardHistoryEntry(text: "", kind: .files, filePaths: ["/tmp/a"])
        suite.expect(merge([files, newer], [], policy: withImages).entries == [files, newer],
                     "entries that never sync are left where they are")
        let editing = merge([newer], [], deleted: [ClipboardHistorySync.textKey("Newer"): now], protected: [newer.id])
        suite.expect(editing.entries == [newer], "an entry open in the editor is not taken away mid-edit")
        let tie = merge([], [record("b", now.addingTimeInterval(-1)), record("a", now.addingTimeInterval(-1))])
        let tieAgain = merge([], [record("a", now.addingTimeInterval(-1)), record("b", now.addingTimeInterval(-1))])
        suite.expect(tie.entries.map(\.text) == tieAgain.entries.map(\.text),
                     "entries copied at the same moment settle in the same order on every Mac")
    }

    /// Two Macs and a third that arrives later, writing into one folder.
    private static func twoMacs(_ suite: TestSuite) {
        let (folder, base) = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: base) }
        let start = Date().addingTimeInterval(-3_600)
        func at(_ seconds: Double) -> Date { start.addingTimeInterval(seconds) }
        let a = Mac("MacBook", folder: folder, policy: withImages)
        let b = Mac("iMac", folder: folder, policy: withImages)

        a.copy("Meeting at 10", at: at(1), source: "com.apple.mail")
        a.copy("Shopping list", at: at(2))
        suite.expect(a.publish(), "a Mac writes its file into the shared folder")
        suite.expect(folder.otherDevices(excluding: a.device).isEmpty
                     && folder.otherDevices(excluding: b.device).map(\.device) == [a.device],
                     "a Mac never reads its own file, and sees the other's")
        b.pull(now: at(3))
        suite.expect(b.texts == ["Shopping list", "Meeting at 10"],
                     "entries copied on one Mac show up on the other, found \(b.texts)")
        suite.expect(b.entries.last?.sourceBundleID == "com.apple.mail", "with the app they came from")

        b.copy("From the iMac", at: at(4))
        b.publish()
        a.pull(now: at(5))
        suite.expect(a.texts == ["From the iMac", "Shopping list", "Meeting at 10"],
                     "and the other way round, found \(a.texts)")

        a.delete("Shopping list", at: at(6))
        a.publish()
        b.pull(now: at(7))
        suite.expect(b.texts == ["From the iMac", "Meeting at 10"],
                     "deleting on one Mac deletes on the other, found \(b.texts)")
        b.publish()
        a.pull(now: at(8))
        suite.expect(a.texts == ["From the iMac", "Meeting at 10"],
                     "the other Mac's older copy does not bring it back")

        // Clear unpinned on B, with a pinned entry kept.
        b.pin("Meeting at 10", true, at: at(9))
        b.publish()
        a.pull(now: at(10))
        suite.expect(a.entries.first?.text == "Meeting at 10" && a.entries.first?.isPinned == true,
                     "a pin made on one Mac pins on the other")
        for text in b.entries.filter({ !$0.isPinned }).map(\.text) { b.delete(text, at: at(11)) }
        b.publish()
        a.pull(now: at(12))
        suite.expect(a.texts == ["Meeting at 10"], "clearing history on one Mac clears it on the other, found \(a.texts)")

        let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4])
        a.copyImage(png, at: at(13))
        a.publish()
        let hash = ClipboardHistorySync.sha256Hex(png)
        suite.expect(folder.hasImage(hash) && folder.readImage(hash) == png,
                     "a picture is uploaded once, under the hash of its bytes")
        suite.expect(folder.imagesNamedByOthers(excluding: b.device) == [hash]
                     && folder.imagesNamedByOthers(excluding: a.device) == [],
                     "a sweep knows which pictures the other Macs still name")
        b.policy = textOnly
        b.pull(now: at(14))
        suite.expect(!b.texts.contains("image:" + hash), "a text only Mac leaves the picture out")
        b.policy = withImages
        b.pull(now: at(15))
        let picture = b.entries.first { $0.kind == .image }
        suite.expect(picture?.imageHash == hash && picture.flatMap { $0.imageFile.flatMap { b.images[$0] } } == png,
                     "a Mac syncing images stores the picture locally, found \(b.texts)")

        // A third Mac whose limit is smaller takes only what fits.
        let c = Mac("Mac mini", folder: folder)
        for index in 0..<5 { c.copy("Mini \(index)", at: at(16 + Double(index))) }
        c.publish()
        a.pull(now: at(30), limit: 3)
        suite.expect(a.entries.filter { !$0.isPinned }.count == 3,
                     "the local limit still applies to what arrives, found \(a.texts)")

        // Turning sync off on C removes its file; the others keep what they got.
        folder.removeDeviceFile(c.device)
        a.pull(now: at(31), limit: 3)
        suite.expect(a.entries.filter { !$0.isPinned }.count == 3 && !folder.otherDevices(excluding: a.device)
                        .contains { $0.device == c.device },
                     "a Mac that stops syncing leaves the others' histories alone")
    }

    private static func folderSafety(_ suite: TestSuite) {
        let (folder, base) = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: base) }
        let manager = FileManager.default
        let device = ClipboardHistorySync.deviceIdentifier(hardware: "x", user: "y", bundle: "z")
        let file = ClipboardHistorySyncFile(device: device, records: [], deleted: [:])
        suite.expect(folder.write(ClipboardHistorySync.encoded(file)!, device: device), "the folder is created on first write")
        // Conflict copies iCloud makes, stray files and links are never read.
        try? Data("{}".utf8).write(to: folder.root.appendingPathComponent(device + " 2.json"))
        try? Data("{}".utf8).write(to: folder.root.appendingPathComponent("notes.txt"))
        let linked = String(repeating: "a", count: 32)
        try? manager.createSymbolicLink(at: folder.root.appendingPathComponent(linked + ".json"),
                                        withDestinationURL: folder.deviceFileURL(device))
        suite.expect(folder.otherDevices(excluding: "0").map(\.device) == [device],
                     "only plain files named like a Mac's file count")

        let bytes = Data("picture".utf8)
        let hash = ClipboardHistorySync.sha256Hex(bytes)
        suite.expect(!folder.writeImage(bytes, hash: ClipboardHistorySync.sha256Hex(Data("other".utf8))),
                     "a picture is never written under a name that is not its hash")
        suite.expect(folder.writeImage(bytes, hash: hash), "a picture is written under its hash")
        let forged = ClipboardHistorySync.sha256Hex(Data("forged".utf8))
        try? Data("not forged".utf8).write(to: folder.imageURL(forged))
        suite.expect(folder.readImage(forged) == nil && folder.readImage(hash) == bytes,
                     "a picture whose bytes do not match its name is not taken")

        let old = Date().addingTimeInterval(-30 * 86_400)
        let unreferenced = ClipboardHistorySync.sha256Hex(Data("unreferenced".utf8))
        let young = ClipboardHistorySync.sha256Hex(Data("young".utf8))
        _ = folder.writeImage(Data("unreferenced".utf8), hash: unreferenced)
        _ = folder.writeImage(Data("young".utf8), hash: young)
        for url in [folder.imageURL(hash), folder.imageURL(unreferenced), folder.imageURL(forged)] {
            try? manager.setAttributes([.modificationDate: old], ofItemAtPath: url.path)
        }
        folder.collectGarbage(referenced: [hash])
        suite.expect(folder.hasImage(hash) && !folder.hasImage(unreferenced) && !folder.hasImage(forged)
                     && folder.hasImage(young),
                     "unreferenced pictures go after a grace period, referenced and recent ones stay")

        let away = String(repeating: "b", count: 32)
        let standIn = folder.root.appendingPathComponent("." + away + ".json.icloud")
        try? Data().write(to: standIn)
        suite.expect(folder.scan(excluding: device).waiting && folder.imagesNamedByOthers(excluding: device) == nil,
                     "while a Mac's file is still on its way, no picture is swept on a guess")
        try? manager.removeItem(at: standIn)
        folder.removeDeviceFile(device)
        folder.collectGarbage(referenced: [], grace: 0)
        try? manager.removeItem(at: folder.root.appendingPathComponent(device + " 2.json"))
        try? manager.removeItem(at: folder.root.appendingPathComponent("notes.txt"))
        try? manager.removeItem(at: folder.root.appendingPathComponent(linked + ".json"))
        folder.removeIfEmpty()
        suite.expect(!manager.fileExists(atPath: folder.root.deletingLastPathComponent().path)
                     && manager.fileExists(atPath: base.path),
                     "the last Mac to stop syncing leaves no folder behind, and nothing above it is touched")

        let home = base.appendingPathComponent("home", isDirectory: true)
        suite.expect(ClipboardHistorySyncFolder.inICloudDrive(home: home) == nil,
                     "without iCloud Drive there is no folder to sync through")
        try? manager.createDirectory(at: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs"),
                                     withIntermediateDirectories: true)
        suite.expect(ClipboardHistorySyncFolder.inICloudDrive(home: home)?.root.path.hasSuffix(
                         "Library/Mobile Documents/com~apple~CloudDocs/Vorssaint/Clipboard History") == true,
                     "with iCloud Drive on, the folder sits in it under Vorssaint")
    }

    /// The history window's status line, for every state sync can be in.
    private static func statusDisplay(_ suite: TestSuite) {
        let now = Date()
        let english = FeatureStrings.clipboardSync(.enUS)
        func shown(_ status: ClipboardHistorySyncStatus, syncing: Bool = false, at moment: Date = now,
                   language: AppLanguage = .enUS) -> ClipboardSyncStatusDisplay {
            ClipboardSyncStatusDisplay(status: status, syncing: syncing, now: moment, language: language)
        }
        suite.expect(!ClipboardSyncStatusDisplay.isShown(.off) && ClipboardSyncStatusDisplay.isShown(.checking)
                     && ClipboardSyncStatusDisplay.isShown(.synced(at: now, otherMacs: 0)),
                     "the window shows sync only while it is on")
        let fresh = shown(.synced(at: now.addingTimeInterval(-20), otherMacs: 2))
        suite.expect(fresh.text == "Synced just now · Other Macs: 2" && fresh.tone == .normal
                     && fresh.symbol == "checkmark.icloud",
                     "a sync under a minute old reads as just now, with the other Macs, found \(fresh.text)")
        suite.expect(shown(.synced(at: now.addingTimeInterval(30), otherMacs: 1)).text.hasPrefix("Synced just now"),
                     "a sync a changed clock puts ahead still reads as just now")
        let synced = Date(timeIntervalSince1970: 1_800_000_000)
        let twoMinutes = shown(.synced(at: synced, otherMacs: 1), at: synced.addingTimeInterval(125))
        let fiveMinutes = shown(.synced(at: synced, otherMacs: 1), at: synced.addingTimeInterval(305))
        suite.expect(twoMinutes.text.hasPrefix("Synced ") && !twoMinutes.text.hasPrefix("Synced just now")
                     && twoMinutes.text.contains("2") && twoMinutes.text.hasSuffix(" · Other Macs: 1")
                     && fiveMinutes.text.contains("5") && twoMinutes.text != fiveMinutes.text,
                     "an older sync says how long ago, and the line moves on while the window stays open, found \(twoMinutes.text) then \(fiveMinutes.text)")
        for status in [ClipboardHistorySyncStatus.checking, .noICloudDrive, .unreachable,
                       .synced(at: now, otherMacs: 3)] {
            let busy = shown(status, syncing: true)
            suite.expect(busy.text == english.statusSyncing && busy.tone == .busy
                         && busy.symbol == "arrow.clockwise.icloud",
                         "while a read or write is under way the line says so, whatever came before (\(status))")
        }
        let checking = shown(.checking)
        let off = shown(.noICloudDrive)
        let unreachable = shown(.unreachable)
        suite.expect(checking.text == "Checking…" && checking.tone == .busy
                     && off.text == "iCloud Drive is off" && off.tone == .warning && off.symbol == "icloud.slash"
                     && unreachable.text == "Can’t reach iCloud Drive" && unreachable.tone == .warning,
                     "each state has its own short line")
        suite.expect(fresh.help == english.statusHelp && off.help.hasPrefix(english.noICloudDrive)
                     && off.help.hasSuffix(english.statusHelp) && unreachable.help.hasPrefix(english.unreachable),
                     "the tooltip says when it syncs, and what to do when it cannot")
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.clipboardSync(language)
            let old = shown(.synced(at: synced, otherMacs: 4), at: synced.addingTimeInterval(3 * 3_600), language: language)
            suite.expect(old.text.contains("3") && old.text.contains("4")
                         && !old.text.contains("%") && old.text != strings.statusJustNow,
                         "the status line takes its time and count in \(language.rawValue), found \(old.text)")
            suite.expect(strings.statusHelp.contains("iCloud Drive") || language == .zhHans || language == .zhTW
                         || language == .zhHK,
                         "the tooltip names iCloud Drive (\(language.rawValue))")
        }
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = FeatureStrings.clipboardSync(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 21 && values.allSatisfy { !$0.isEmpty },
                         "every sync string is translated (\(language.rawValue))")
            suite.expect(values.allSatisfy { !$0.contains("\u{2014}") && !$0.contains("\u{2013}") && !$0.contains("'") },
                         "sync strings use no long dashes and curly apostrophes (\(language.rawValue))")
            suite.expect(String(format: text.syncedFormat, "10:00").contains("10:00")
                         && String(format: text.otherMacsFormat, 2).contains("2"),
                         "the status formats take their values (\(language.rawValue))")
            suite.expect(text.caption.contains("Vorssaint"), "the caption names the folder (\(language.rawValue))")
        }
    }
}

private extension JSONEncoder {
    static var syncTest: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}
