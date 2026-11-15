import Testing
import Foundation
@testable import Keyli

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Sound Features")
struct SoundFeatureTests {
    @Test func variationStaysSubtleAndVaries() {
        var generator = SeededGenerator(state: 7)
        var rates: Set<Float> = []
        for _ in 0..<500 {
            let normal = KeySoundEngine.Variation.random(wide: false, using: &generator)
            #expect(normal.rate >= 0.965 && normal.rate <= 1.035)
            #expect(normal.gain >= 0.86 && normal.gain <= 1)
            let wide = KeySoundEngine.Variation.random(wide: true, using: &generator)
            #expect(wide.rate >= 0.94 && wide.rate <= 1.06)
            rates.insert(normal.rate)
        }
        #expect(rates.count > 400)
    }

    @Test func voiceVolumeCombinesSourcePackAndVariation() {
        #expect(KeySoundEngine.voiceVolume(sourceVolume: 0.5, packGain: 1, variation: .none) == 0.5)
        #expect(abs(KeySoundEngine.voiceVolume(sourceVolume: 0.5, packGain: 0.55, variation: .none) - 0.275) < 0.0001)
        #expect(KeySoundEngine.voiceVolume(sourceVolume: 1, packGain: 2, variation: .none) == 1)
        #expect(KeySoundEngine.voiceVolume(sourceVolume: 0, packGain: 2, variation: .none) == 0)
    }

    @Test func gainConvertsToDecibels() {
        #expect(KeySoundEngine.decibels(1) == 0)
        #expect(abs(KeySoundEngine.decibels(0.5) + 6.0206) < 0.01)
        #expect(KeySoundEngine.decibels(0) == -96)
        #expect(KeySoundEngine.decibels(100) == 24)
    }

    @Test func packOptionsAreRead() throws {
        let json = #"{"name": "Opt", "audio_file": "a.wav", "definition_method": "single", "definitions": {"KeyA": {"timing": [[0, 10]]}}, "options": {"recommended_volume": 0.55, "random_pitch": true}}"#
        let manifest = try SoundPackManifest.parse(Data(json.utf8), fallbackId: "opt")
        #expect(manifest.recommendedVolume == 0.55)
        #expect(manifest.randomPitch)
        let plain = try SoundPackManifest.parse(Data(#"{"name": "P", "sound": "a.wav", "defines": {"30": [0, 10]}}"#.utf8), fallbackId: "p")
        #expect(plain.recommendedVolume == 1)
        #expect(!plain.randomPitch)
        let loud = try SoundPackManifest.parse(Data(#"{"name": "L", "audio_file": "a.wav", "definitions": {"KeyA": {"timing": [[0, 10]]}}, "options": {"recommended_volume": 9}}"#.utf8), fallbackId: "l")
        #expect(loud.recommendedVolume == 2)
    }

    @Test func newSoundSettingsDecodeWithDefaults() throws {
        let config = try JSONDecoder().decode(KeyliConfig.self, from: Data("{}".utf8))
        #expect(config.keySoundVariation)
        #expect(!config.keySoundSeparatePhysicalVolume)
        #expect(config.keySoundPhysicalVolume == 0.6)
    }
}

@Suite("Mute Rules")
struct MuteRuleTests {
    @Test func mutesForCallsAndListedApps() {
        #expect(KeySoundMuteRules.shouldMute(muteDuringCalls: true, microphoneInUse: true, frontBundleId: "a", mutedApps: []))
        #expect(!KeySoundMuteRules.shouldMute(muteDuringCalls: false, microphoneInUse: true, frontBundleId: "a", mutedApps: []))
        #expect(!KeySoundMuteRules.shouldMute(muteDuringCalls: true, microphoneInUse: false, frontBundleId: "a", mutedApps: []))
        #expect(KeySoundMuteRules.shouldMute(muteDuringCalls: false, microphoneInUse: false, frontBundleId: "us.zoom.xos", mutedApps: ["us.zoom.xos"]))
        #expect(!KeySoundMuteRules.shouldMute(muteDuringCalls: false, microphoneInUse: false, frontBundleId: nil, mutedApps: ["us.zoom.xos"]))
    }

    @Test func appListAddsWithoutDuplicates() {
        #expect(AppListEditor.adding("a", to: ["a"]) == ["a"])
        #expect(AppListEditor.adding("b", to: ["a"]) == ["a", "b"])
        #expect(AppListEditor.appInfo(for: "com.apple.finder").name == "Finder")
    }

    @Test func microphoneProbeRunsQuickly() {
        _ = KeySoundMuteRules.shared.isMuted
        let start = Date()
        for _ in 0..<100 { _ = KeySoundMuteRules.shared.isMuted }
        #expect(Date().timeIntervalSince(start) < 0.05)
        let config = KeyliConfig()
        #expect(config.keySoundMuteDuringCalls)
        #expect(config.keySoundMutedApps.isEmpty)
    }
}

@Suite("Pack Favorites")
struct PackFavoriteTests {
    static func info(_ id: String, _ name: String, author: String? = nil) -> SoundPackInfo {
        SoundPackInfo(id: id, name: name, author: author, folder: URL(fileURLWithPath: "/tmp/\(id)"), isBundled: false)
    }
    static let packs = [info("a", "Slate Thock", author: "Keyli"), info("b", "Creamy Legendary", author: "502"), info("c", "Orange deluxe"), info("d", "WOB Rainy")]

    @Test func favoritesComeFirstAndSearchFilters() {
        let all = SoundPackPicker.sections(packs: Self.packs, favorites: ["c", "a"], query: "")
        #expect(all.favorites.map(\.id) == ["c", "a"])
        #expect(all.others.map(\.id) == ["b", "d"])
        let search = SoundPackPicker.sections(packs: Self.packs, favorites: ["c"], query: "cream")
        #expect(search.favorites.isEmpty)
        #expect(search.others.map(\.id) == ["b"])
        #expect(SoundPackPicker.sections(packs: Self.packs, favorites: [], query: "keyli").others.map(\.id) == ["a"])
        #expect(SoundPackPicker.sections(packs: Self.packs, favorites: ["gone"], query: "").favorites.isEmpty)
    }

    @Test func togglingAndCycling() {
        #expect(SoundPackPicker.toggling("a", in: []) == ["a"])
        #expect(SoundPackPicker.toggling("a", in: ["a", "b"]) == ["b"])
        #expect(SoundPackPicker.cycleOrder(packs: Self.packs, favorites: ["d", "b"]).map(\.id) == ["d", "b"])
        #expect(SoundPackPicker.cycleOrder(packs: Self.packs, favorites: ["d"]).count == 4)
        #expect(KeyliConfig().favoriteSoundPacks.isEmpty)
    }
}
