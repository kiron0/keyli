import Testing
import Foundation
import AVFoundation
@testable import Keyli

@Suite("Sound Packs")
struct SoundPackTests {
    static var bundledCount: Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: packsRoot.path)) ?? []).filter { !$0.hasPrefix(".") }.count
    }

    static func writeTone(to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 800)!
        buffer.frameLength = 800
        for frame in 0..<800 { buffer.floatChannelData![0][frame] = sin(Float(frame) * 0.3) * 0.5 }
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    static let packsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Support/SoundPacks", isDirectory: true)

    @Test func parsesLegacySingleSpritePack() throws {
        let json = """
        {"id": "legacy pack!", "name": "Legacy", "key_define_type": "single", "sound": "sound.ogg",
         "defines": {"30": [100, 40], "57": [200, 80], "57416": [300, 50], "61000": [900, 50], "1": null, "999999": [0, 10]}}
        """
        let manifest = try SoundPackManifest.parse(Data(json.utf8), fallbackId: "x")
        #expect(manifest.id == "legacy-pack")
        #expect(manifest.method == .single)
        #expect(manifest.keys["KeyA"] == KeySoundDefinition(file: "sound.ogg", down: SoundSegment(startMs: 100, endMs: 140)))
        #expect(manifest.keys["Space"]?.down == SoundSegment(startMs: 200, endMs: 280))
        #expect(manifest.keys["ArrowUp"]?.down == SoundSegment(startMs: 300, endMs: 350))
        #expect(manifest.keys["Escape"] == nil)
        #expect(manifest.keys.count == 3)
    }

    @Test func parsesLegacyMultiPack() throws {
        let json = """
        {"name": "Multi", "key_define_type": "multi", "defines": {"28": "enter.wav", "30": "a.wav", "14": null}}
        """
        let manifest = try SoundPackManifest.parse(Data(json.utf8), fallbackId: "multi-folder")
        #expect(manifest.id == "multi-folder")
        #expect(manifest.method == .multi)
        #expect(manifest.keys["Enter"] == KeySoundDefinition(file: "enter.wav", down: .wholeFile))
        #expect(manifest.audioFiles == ["enter.wav", "a.wav"])
    }

    @Test func parsesV2PackWithPressAndRelease() throws {
        let json = """
        {"config_version": "2", "id": "v2", "name": "V2", "author": "me", "definition_method": "single",
         "audio_file": "s.wav", "definitions": {
            "KeyA": {"timing": [[0, 50], [60, 90]]},
            "KeyB": {"timing": [[100, 150]]},
            "KeyC": {"timing": [[50, 10]]},
            "Enter": {"audio_file": "enter.wav", "timing": [[0, 30], [30, 75]]}
         }}
        """
        let manifest = try SoundPackManifest.parse(Data(json.utf8), fallbackId: "x")
        #expect(manifest.keys["KeyA"]?.up == SoundSegment(startMs: 60, endMs: 90))
        #expect(manifest.keys["KeyB"]?.up == nil)
        #expect(manifest.keys["KeyC"] == nil)
        #expect(manifest.keys["Enter"]?.file == "enter.wav")
    }

    @Test func rejectsPacksWithoutDefinitions() {
        #expect(throws: SoundPackError.noDefinitions("x")) {
            try SoundPackManifest.parse(Data(#"{"name": "Empty", "defines": {}}"#.utf8), fallbackId: "x")
        }
        #expect(throws: SoundPackError.invalidConfig("x")) {
            try SoundPackManifest.parse(Data("[]".utf8), fallbackId: "x")
        }
    }

    @Test func fallsBackToRelatedKeys() throws {
        let json = """
        {"name": "Few", "sound": "s.wav", "defines": {"42": [0, 10], "28": [10, 10], "30": [20, 10], "2": [30, 10]}}
        """
        let manifest = try SoundPackManifest.parse(Data(json.utf8), fallbackId: "few")
        #expect(manifest.definition(forMacKeyCode: 60)?.down.startMs == 0)
        #expect(manifest.definition(forMacKeyCode: 76)?.down.startMs == 10)
        #expect(manifest.definition(forMacKeyCode: 83)?.down.startMs == 30)
        #expect(manifest.definition(forMacKeyCode: 105)?.down.startMs == 20)
        #expect(manifest.definition(forMacKeyCode: 250)?.down.startMs == 20)
    }

    @Test func macKeyCodesMapToLegacyCodes() {
        let expected: [UInt16: Int] = [0: 30, 49: 57, 36: 28, 51: 14, 53: 1, 56: 42, 60: 54, 59: 29, 62: 3613,
                                       58: 56, 61: 3640, 55: 3675, 54: 3676, 126: 57416, 123: 57419,
                                       122: 59, 111: 88, 50: 41, 117: 3667, 76: 3612]
        for (mac, legacy) in expected {
            let name = SoundKeyMap.name(forMacKeyCode: mac)
            #expect(name != nil)
            #expect(SoundKeyMap.legacyCodes[name ?? ""]?.first == legacy)
        }
        for name in SoundKeyMap.macKeyNames.values where name != "Fn" {
            #expect(SoundKeyMap.legacyCodes[name] != nil, "\(name) has no legacy code")
        }
    }

    @Test func onScreenKeysAllHaveSoundNames() {
        for (id, keyCode) in PhysicalKeyTests.ansiPhysicalKeys {
            #expect(SoundKeyMap.name(forMacKeyCode: UInt16(keyCode)) != nil, "\(id) code \(keyCode)")
        }
        for keyCode: UInt16 in [10, 93, 94, 102, 104, 179] where keyCode != 102 && keyCode != 104 {
            #expect(SoundKeyMap.name(forMacKeyCode: keyCode) != nil, "code \(keyCode)")
        }
    }

    @Test func bundledPacksLoadAndSlice() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let ids = try FileManager.default.contentsOfDirectory(atPath: Self.packsRoot.path).filter { !$0.hasPrefix(".") }
        #expect(ids.count == 7)
        for id in ids {
            let folder = Self.packsRoot.appendingPathComponent(id)
            let manifest = try SoundPackLibrary.loadManifest(in: folder)
            let built = try KeySoundEngine.buildClips(folder: folder, format: format)
            for keyCode in SoundKeyMap.macKeyNames.keys {
                let pair = built.clips[keyCode]
                #expect(pair?.down != nil, "\(id) \(keyCode) has no press sound")
                #expect(pair?.down?.format == format)
            }
            let peak = built.clips[0]?.down.map { buffer in
                (0..<Int(buffer.frameLength)).map { abs(buffer.floatChannelData![0][$0]) }.max() ?? 0
            } ?? 0
            #expect(peak > 0.05)
        }
    }

    @Test func slicesClampAndFade() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 1000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100)!
        buffer.frameLength = 100
        for channel in 0..<2 {
            for frame in 0..<100 { buffer.floatChannelData![channel][frame] = 1 }
        }
        let slice = try #require(KeySoundEngine.makeSlice(of: buffer, segment: SoundSegment(startMs: 50, endMs: 500)))
        #expect(slice.frameLength == 50)
        #expect(slice.floatChannelData![0][0] == 0)
        #expect(slice.floatChannelData![0][25] == 1)
        #expect(KeySoundEngine.makeSlice(of: buffer, segment: SoundSegment(startMs: 200, endMs: 300)) == nil)
    }

    @Test func importCopiesPackAndAvoidsBundledIds() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let userRoot = temp.appendingPathComponent("user")
        let library = SoundPackLibrary(bundledRoot: Self.packsRoot, userRoot: userRoot)
        #expect(library.packs.filter(\.isBundled).count == Self.bundledCount)

        let source = temp.appendingPathComponent("My Pack")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data(#"{"id": "keyli-slate-thock", "name": "Copy", "sound": "s.wav", "defines": {"30": [0, 10]}}"#.utf8)
            .write(to: source.appendingPathComponent("config.json"))
        #expect(throws: SoundPackError.missingAudio(pack: "Copy", file: "s.wav")) {
            try library.importPack(from: source)
        }
        try Data().write(to: source.appendingPathComponent("s.wav"))
        #expect(throws: SoundPackError.unplayableAudio(pack: "Copy", file: "s.wav")) {
            try library.importPack(from: source)
        }
        try Self.writeTone(to: source.appendingPathComponent("s.wav"))
        let info = try library.importPack(from: source)
        #expect(info.folder.lastPathComponent == "copy")
        #expect(info.id == "keyli-slate-thock-imported")
        #expect(!info.isBundled)
        #expect(library.pack(id: info.id)?.name == "Copy")

        try library.removePack(id: info.id)
        #expect(library.packs.count == Self.bundledCount)
        #expect(library.pack(id: "missing")?.id == SoundPackLibrary.defaultPackId)
    }

    @Test func importsZippedPackWithNestedFolder() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let library = SoundPackLibrary(bundledRoot: Self.packsRoot, userRoot: temp.appendingPathComponent("user"))
        let content = temp.appendingPathComponent("content/Zipped Pack")
        try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
        try Data(#"{"name": "Zipped", "sound": "s.wav", "defines": {"30": [0, 10]}}"#.utf8)
            .write(to: content.appendingPathComponent("config.json"))
        try Self.writeTone(to: content.appendingPathComponent("s.wav"))
        let zip = temp.appendingPathComponent("pack.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", content.path, zip.path]
        try process.run()
        process.waitUntilExit()

        let info = try library.importPack(from: zip)
        #expect(info.id == "Zipped-Pack")
        #expect(info.folder.lastPathComponent == "zipped")
        #expect(info.name == "Zipped")
        #expect(FileManager.default.fileExists(atPath: info.folder.appendingPathComponent("s.wav").path))

        let broken = temp.appendingPathComponent("broken.zip")
        try Data("not a zip".utf8).write(to: broken)
        #expect(throws: SoundPackError.unreadableArchive("broken.zip")) {
            try library.importPack(from: broken)
        }
    }

    @Test func catalogBuildsQueriesAndParsesPages() throws {
        let url = SoundPackCatalog.listURL(sort: .downloads, query: " cream ", cursor: "abc=")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "sort", value: "downloads")))
        #expect(items.contains(URLQueryItem(name: "type", value: "keyboard")))
        #expect(items.contains(URLQueryItem(name: "q", value: "cream")))
        #expect(items.contains(URLQueryItem(name: "cursor", value: "abc=")))
        #expect(!SoundPackCatalog.listURL(sort: .rating, query: "", cursor: nil).absoluteString.contains("q="))

        let json = #"{"packs":[{"id":"mv-1","name":"One","type":"keyboard","zipSize":10,"ratingAvg":5,"ratingCount":2},{"id":"mv-2","name":"Mouse","type":"mouse"}],"nextCursor":"next"}"#
        let page = try SoundPackCatalog.parsePage(Data(json.utf8))
        #expect(page.packs.map(\.id) == ["mv-1"])
        #expect(page.cursor == "next")
        #expect(SoundPackCatalog.downloadURL(for: page.packs[0]).absoluteString == "https://mechvibes.com/api/sound-packs/mv-1/download")
    }

    @Test func catalogVerifiesChecksums() {
        let data = Data("abc".utf8)
        #expect(SoundPackCatalog.verify(data, checksum: "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"))
        #expect(!SoundPackCatalog.verify(data, checksum: "00"))
        #expect(SoundPackCatalog.verify(data, checksum: nil))
    }

    @Test func importRejectsWrongSourcesWithClearErrors() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let library = SoundPackLibrary(bundledRoot: nil, userRoot: temp.appendingPathComponent("user"))

        let song = temp.appendingPathComponent("song.mp3")
        try Data("x".utf8).write(to: song)
        #expect(throws: SoundPackError.notAPackSource("song.mp3")) { try library.importPack(from: song) }

        let emptyFolder = temp.appendingPathComponent("Empty Folder")
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
        #expect(throws: SoundPackError.missingConfig("Empty Folder")) { try library.importPack(from: emptyFolder) }

        let badJSON = temp.appendingPathComponent("Bad JSON")
        try FileManager.default.createDirectory(at: badJSON, withIntermediateDirectories: true)
        try Data("{ nope".utf8).write(to: badJSON.appendingPathComponent("config.json"))
        #expect(throws: SoundPackError.invalidConfig("Bad JSON")) { try library.importPack(from: badJSON) }

        let mouse = temp.appendingPathComponent("Mouse")
        try FileManager.default.createDirectory(at: mouse, withIntermediateDirectories: true)
        try Data(#"{"name": "Clicky Mouse", "audio_file": "m.wav", "definition_method": "single", "definitions": {"MouseLeft": {"timing": [[0, 10]]}}}"#.utf8)
            .write(to: mouse.appendingPathComponent("config.json"))
        #expect(throws: SoundPackError.mousePack("Mouse")) { try library.importPack(from: mouse) }

        let escape = temp.appendingPathComponent("Escape")
        try FileManager.default.createDirectory(at: escape, withIntermediateDirectories: true)
        try Data(#"{"name": "Sneaky", "sound": "../song.mp3", "defines": {"30": [0, 10]}}"#.utf8)
            .write(to: escape.appendingPathComponent("config.json"))
        #expect(throws: SoundPackError.unsafePath(pack: "Sneaky", file: "../song.mp3")) { try library.importPack(from: escape) }

        let emptyZip = temp.appendingPathComponent("empty.zip")
        try (Data([0x50, 0x4B, 0x05, 0x06]) + Data(count: 18)).write(to: emptyZip)
        #expect(throws: SoundPackError.emptyArchive("empty.zip")) { try library.importPack(from: emptyZip) }

        let noPackZip = temp.appendingPathComponent("photos.zip")
        let photos = temp.appendingPathComponent("photos")
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: photos.appendingPathComponent("a.txt"))
        let zipper = Process()
        zipper.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zipper.arguments = ["-c", "-k", photos.path, noPackZip.path]
        try zipper.run()
        zipper.waitUntilExit()
        #expect(throws: SoundPackError.missingConfig("photos.zip")) { try library.importPack(from: noPackZip) }
        #expect(library.packs.isEmpty)
        #expect(SoundPackError.missingConfig("photos.zip").errorDescription?.contains("config.json") == true)
    }

    @Test func folderNamesComeFromPackNames() {
        #expect(SoundPackManifest.folderName(for: "WOB Rainy 75 PRO (FR4 + Kailh Cocoa)") == "wob-rainy-75-pro-fr4-kailh-cocoa")
        #expect(SoundPackManifest.folderName(for: "  ***  ") == "sound-pack")
        #expect(SoundPackManifest.folderName(for: String(repeating: "a b ", count: 40)).count <= 60)
    }

    @Test func reimportReplacesSamePackAndKeepsDistinctNames() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let library = SoundPackLibrary(bundledRoot: nil, userRoot: temp.appendingPathComponent("user"))
        func make(_ folder: String, id: String) throws -> URL {
            let url = temp.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try Data("{\"id\": \"\(id)\", \"name\": \"Same Name\", \"sound\": \"s.wav\", \"defines\": {\"30\": [0, 10]}}".utf8)
                .write(to: url.appendingPathComponent("config.json"))
            try Self.writeTone(to: url.appendingPathComponent("s.wav"))
            return url
        }
        let first = try library.importPack(from: try make("a", id: "one"))
        let again = try library.importPack(from: try make("b", id: "one"))
        let other = try library.importPack(from: try make("c", id: "two"))
        #expect(first.folder.lastPathComponent == "same-name")
        #expect(again.folder.lastPathComponent == "same-name")
        #expect(other.folder.lastPathComponent == "same-name-2")
        #expect(library.packs.map(\.id).sorted() == ["one", "two"])
    }

    @Test func pacerSpacesRequestsAndHonorsBackoff() {
        var pacer = RequestPacer(spacing: 1)
        let start = Date(timeIntervalSince1970: 1000)
        #expect(pacer.reserve(now: start) == 0)
        #expect(pacer.reserve(now: start) == 1)
        #expect(pacer.reserve(now: start.addingTimeInterval(0.5)) == 1.5)
        pacer.block(for: 30, now: start)
        #expect(pacer.reserve(now: start) == 30)
        #expect(RequestPacer.retryAfter("12") == 12)
        #expect(RequestPacer.retryAfter(nil) == 30)
        #expect(RequestPacer.retryAfter("9999") == 300)
        #expect(RequestPacer.retryAfter("Thu, 01 Jan 1970 00:17:00 GMT", now: start) == 20)
    }
}
