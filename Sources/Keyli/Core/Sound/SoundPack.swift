import Foundation

public struct SoundSegment: Equatable, Hashable {
    public var startMs: Double
    public var endMs: Double?

    public init(startMs: Double, endMs: Double?) {
        self.startMs = startMs
        self.endMs = endMs
    }

    public static let wholeFile = SoundSegment(startMs: 0, endMs: nil)

    public var isValid: Bool {
        guard startMs >= 0 else { return false }
        if let endMs { return endMs > startMs }
        return true
    }
}

public struct KeySoundDefinition: Equatable {
    public var file: String
    public var down: SoundSegment
    public var up: SoundSegment?

    public init(file: String, down: SoundSegment, up: SoundSegment? = nil) {
        self.file = file
        self.down = down
        self.up = up
    }
}

public enum SoundPackError: Error, Equatable, LocalizedError {
    case notAPackSource(String)
    case unreadableArchive(String)
    case emptyArchive(String)
    case archiveTooLarge(String)
    case missingConfig(String)
    case invalidConfig(String)
    case noDefinitions(String)
    case mousePack(String)
    case missingAudio(pack: String, file: String)
    case unplayableAudio(pack: String, file: String)
    case unsafePath(pack: String, file: String)

    public var errorDescription: String? {
        switch self {
        case .notAPackSource(let name):
            return "“\(name)” isn't a sound pack. Choose a .zip file or a folder that contains config.json."
        case .unreadableArchive(let name):
            return "“\(name)” isn't a valid zip file, or it's damaged."
        case .emptyArchive(let name):
            return "“\(name)” is empty."
        case .archiveTooLarge(let name):
            return "“\(name)” is larger than 200 MB, which is too big for a sound pack."
        case .missingConfig(let name):
            return "“\(name)” doesn't contain a sound pack. Keyli looks for a config.json file inside it."
        case .invalidConfig(let name):
            return "The config.json in “\(name)” isn't valid JSON, so the pack can't be read."
        case .noDefinitions(let name):
            return "The config.json in “\(name)” doesn't define any key sounds."
        case .mousePack(let name):
            return "“\(name)” is a mouse sound pack. Keyli plays keyboard packs only."
        case .missingAudio(let pack, let file):
            return "“\(pack)” is missing its sound file “\(file)”."
        case .unplayableAudio(let pack, let file):
            return "The sound file “\(file)” in “\(pack)” can't be played. Use OGG, MP3, WAV, FLAC or M4A audio."
        case .unsafePath(let pack, let file):
            return "“\(pack)” points to a sound file outside its folder (“\(file)”), so it wasn't imported."
        }
    }
}

public struct SoundPackManifest: Equatable {
    public enum Method: String, Equatable {
        case single
        case multi
    }

    public var id: String
    public var name: String
    public var author: String?
    public var method: Method
    public var keys: [String: KeySoundDefinition]
    public var recommendedVolume: Double = 1
    public var randomPitch: Bool = false

    public var audioFiles: Set<String> {
        Set(keys.values.map(\.file))
    }

    public func definition(forKeyName name: String) -> KeySoundDefinition? {
        if let direct = keys[name] { return direct }
        var visited: Set<String> = [name]
        var queue = SoundKeyMap.fallbacks[name] ?? []
        while !queue.isEmpty {
            let next = queue.removeFirst()
            guard visited.insert(next).inserted else { continue }
            if let found = keys[next] { return found }
            queue.append(contentsOf: SoundKeyMap.fallbacks[next] ?? [])
        }
        for generic in SoundKeyMap.genericFallbacks {
            if let found = keys[generic] { return found }
        }
        return keys.keys.sorted().first.flatMap { keys[$0] }
    }

    public func definition(forMacKeyCode keyCode: UInt16) -> KeySoundDefinition? {
        guard let name = SoundKeyMap.name(forMacKeyCode: keyCode) else {
            return definition(forKeyName: "KeyA")
        }
        return definition(forKeyName: name)
    }

    public static func parse(_ data: Data, fallbackId: String, sourceName: String? = nil) throws -> SoundPackManifest {
        let source = sourceName ?? fallbackId
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SoundPackError.invalidConfig(source)
        }
        if (root["soundpack_type"] as? String)?.lowercased() == "mouse" {
            throw SoundPackError.mousePack(source)
        }
        let rawId = (root["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackId
        let name = (root["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? rawId
        let author = root["author"] as? String

        let isV2 = root["definitions"] != nil || root["defs"] != nil || root["definition_method"] != nil
        let keys = isV2 ? parseV2(root) : parseV1(root)
        let keyboardKeys = keys.filter { !$0.key.hasPrefix("Mouse") }
        guard !keyboardKeys.isEmpty else {
            throw keys.isEmpty ? SoundPackError.noDefinitions(source) : SoundPackError.mousePack(source)
        }

        let methodString = (root["definition_method"] as? String) ?? (root["key_define_type"] as? String) ?? "single"
        let method = Method(rawValue: methodString.lowercased()) ?? .single
        var manifest = SoundPackManifest(id: sanitizedId(rawId), name: name, author: author, method: method, keys: keyboardKeys)
        if let options = root["options"] as? [String: Any] {
            if let volume = number(options["recommended_volume"]), volume > 0 {
                manifest.recommendedVolume = min(2, max(0.1, volume))
            }
            manifest.randomPitch = (options["random_pitch"] as? Bool) ?? false
        }
        return manifest
    }

    public static func folderName(for name: String) -> String {
        var result = ""
        var lastWasDash = false
        for scalar in name.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash && !result.isEmpty {
                result.append("-")
                lastWasDash = true
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        if result.count > 60 {
            result = String(result.prefix(60))
            while result.hasSuffix("-") { result.removeLast() }
        }
        return result.isEmpty ? "sound-pack" : result
    }

    public static func sanitizedId(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let result = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "pack" : result
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func parseV1(_ root: [String: Any]) -> [String: KeySoundDefinition] {
        guard let defines = root["defines"] as? [String: Any] else { return [:] }
        let type = ((root["key_define_type"] as? String) ?? "single").lowercased()
        let mainSound = root["sound"] as? String
        var result: [String: KeySoundDefinition] = [:]
        var priority: [String: Int] = [:]

        for (codeString, value) in defines {
            guard let code = Int(codeString), let name = SoundKeyMap.nameForLegacyCode[code] else { continue }
            let rank = SoundKeyMap.legacyCodes[name]?.firstIndex(of: code) ?? 0
            if let existing = priority[name], existing <= rank { continue }

            let definition: KeySoundDefinition?
            if type == "multi" {
                if let file = value as? String, !file.isEmpty {
                    definition = KeySoundDefinition(file: file, down: .wholeFile)
                } else {
                    definition = nil
                }
            } else if let file = mainSound,
                      let pair = value as? [Any], pair.count >= 2,
                      let start = number(pair[0]), let duration = number(pair[1]), duration > 0 {
                let segment = SoundSegment(startMs: start, endMs: start + duration)
                definition = segment.isValid ? KeySoundDefinition(file: file, down: segment) : nil
            } else {
                definition = nil
            }

            if let definition {
                result[name] = definition
                priority[name] = rank
            }
        }
        return result
    }

    private static func parseV2(_ root: [String: Any]) -> [String: KeySoundDefinition] {
        guard let definitions = (root["definitions"] ?? root["defs"]) as? [String: Any] else { return [:] }
        let mainFile = (root["audio_file"] as? String) ?? (root["sound"] as? String)
        var result: [String: KeySoundDefinition] = [:]

        for (name, value) in definitions {
            guard let entry = value as? [String: Any] else { continue }
            let file = (entry["audio_file"] as? String) ?? mainFile
            guard let file, !file.isEmpty else { continue }

            let segments: [SoundSegment] = ((entry["timing"] as? [Any]) ?? []).compactMap { item in
                guard let pair = item as? [Any], pair.count >= 2,
                      let start = number(pair[0]), let end = number(pair[1]) else { return nil }
                let segment = SoundSegment(startMs: start, endMs: end)
                return segment.isValid ? segment : nil
            }

            switch segments.count {
            case 1:
                result[name] = KeySoundDefinition(file: file, down: segments[0])
            case 2...:
                result[name] = KeySoundDefinition(file: file, down: segments[0], up: segments[1])
            default:
                if entry["audio_file"] != nil {
                    result[name] = KeySoundDefinition(file: file, down: .wholeFile)
                }
            }
        }
        return result
    }
}

public struct SoundPackInfo: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var author: String?
    public var folder: URL
    public var isBundled: Bool
}
