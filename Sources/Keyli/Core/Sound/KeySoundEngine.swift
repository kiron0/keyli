import Foundation
import AVFoundation
import AudioToolbox
import Combine
import QuartzCore

public final class KeySoundEngine {
    public static let shared = KeySoundEngine()

    public enum Source: Int {
        case onScreen = 1
        case physical = 2
    }

    struct ClipPair {
        var down: AVAudioPCMBuffer?
        var up: AVAudioPCMBuffer?
    }

    struct PackClips {
        var clips: [UInt16: ClipPair]
        var fallback: ClipPair
        var gain: Double
        var randomPitch: Bool
    }

    struct Variation: Equatable {
        var rate: Float
        var gain: Float

        static let none = Variation(rate: 1, gain: 1)

        static func random<G: RandomNumberGenerator>(wide: Bool, using generator: inout G) -> Variation {
            let spread: Float = wide ? 0.06 : 0.035
            return Variation(
                rate: Float.random(in: (1 - spread)...(1 + spread), using: &generator),
                gain: Float.random(in: 0.86...1, using: &generator)
            )
        }
    }

    static func decibels(_ linear: Float) -> Float {
        guard linear > 0.0001 else { return -96 }
        return max(-96, min(24, 20 * log10(linear)))
    }

    static func voiceVolume(sourceVolume: Double, packGain: Double, variation: Variation) -> Float {
        Float(max(0, min(1, sourceVolume * packGain * Double(variation.gain))))
    }

    private struct SliceKey: Hashable {
        var file: String
        var segment: SoundSegment
    }

    private static let voiceCount = 32
    private static let idleShutdown: CFTimeInterval = 60
    private static let maxClipSeconds: Double = 2.5
    private static let fadeInSeconds: Double = 0.002
    private static let fadeOutSeconds: Double = 0.005

    private let engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []
    private var pitchUnits: [AVAudioUnitVarispeed] = []
    private var voiceGains: [AVAudioUnitEQ] = []
    private var packGain: Double = 1
    private var packRandomPitch = false
    private var previewGain: Double = 1
    private var generator = SystemRandomNumberGenerator()
    private var voiceFreeAt: [CFTimeInterval] = []
    private var nextVoice = 0
    private var format: AVAudioFormat
    private var graphReady = false

    private var clips: [UInt16: ClipPair] = [:]
    private var defaultClip = ClipPair()
    private var loadedPackId: String?
    private var clipsPackId: String?
    private var previewCache: (id: String, pack: PackClips)?
    private var loadGeneration = 0
    private let loadQueue = DispatchQueue(label: "io.coreify.keyli.keysounds.load", qos: .userInitiated)

    private var held: Set<Int> = []
    private var lastPlay: CFTimeInterval = 0
    private var idleTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var activated = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
    }

    public func activate() {
        guard !activated else { return }
        activated = true
        if ConfigStore.shared.config.keySoundQuietTimesEnabled {
            KeySoundMuteRules.shared.refreshMicrophoneIfNeeded(force: true)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        ConfigStore.shared.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.apply(config)
            }
            .store(in: &cancellables)
        SoundPackLibrary.shared.$packs
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.loadedPackId = nil
                self.apply(ConfigStore.shared.config)
            }
            .store(in: &cancellables)
    }

    public var isEnabled: Bool {
        ConfigStore.shared.config.playKeyClickSound
    }

    public func keyDown(_ keyCode: UInt16, source: Source, isRepeat: Bool = false) {
        guard isEnabled, !isRepeat else { return }
        held.insert(heldKey(keyCode, source))
        guard !KeySoundMuteRules.shared.isMuted else { return }
        if let buffer = clip(for: keyCode).down {
            play(buffer, source: source)
        }
    }

    public func keyUp(_ keyCode: UInt16, source: Source) {
        guard held.remove(heldKey(keyCode, source)) != nil else { return }
        guard isEnabled, !KeySoundMuteRules.shared.isMuted, let buffer = clip(for: keyCode).up else { return }
        play(buffer, source: source)
    }

    private func sourceVolume(_ source: Source) -> Double {
        let config = ConfigStore.shared.config
        if source == .physical && config.keySoundSeparatePhysicalVolume {
            return config.keySoundPhysicalVolume
        }
        return config.keySoundVolume
    }

    public func tap(_ keyCode: UInt16, source: Source = .onScreen) {
        keyDown(keyCode, source: source)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.keyUp(keyCode, source: source)
        }
    }

    public func releaseAll(source: Source) {
        held = held.filter { $0 / 1000 != source.rawValue }
    }

    public func preview() {
        playSequence(PackClips(clips: clips, fallback: defaultClip, gain: packGain, randomPitch: packRandomPitch))
    }

    public func preview(pack info: SoundPackInfo) {
        if info.id == clipsPackId, !clips.isEmpty {
            preview()
            return
        }
        if let cached = previewCache, cached.id == info.id {
            playSequence(cached.pack)
            return
        }
        setupGraphIfNeeded()
        let target = format
        loadQueue.async { [weak self] in
            guard let result = try? Self.buildClips(folder: info.folder, format: target) else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.previewCache = (info.id, result)
                self.playSequence(result)
            }
        }
    }

    private func playSequence(_ pack: PackClips) {
        let sequence: [UInt16] = [4, 14, 37, 37, 31, 49, 13, 31, 15, 37, 2, 36]
        for (index, keyCode) in sequence.enumerated() {
            let pair = pack.clips[keyCode] ?? pack.fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.11) { [weak self] in
                guard let self else { return }
                if let down = pair.down { self.play(down, source: .onScreen, gain: pack.gain, randomPitch: pack.randomPitch) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    if let up = pair.up { self.play(up, source: .onScreen, gain: pack.gain, randomPitch: pack.randomPitch) }
                }
            }
        }
    }

    private func heldKey(_ keyCode: UInt16, _ source: Source) -> Int {
        source.rawValue * 1000 + Int(keyCode)
    }

    private func clip(for keyCode: UInt16) -> ClipPair {
        clips[keyCode] ?? defaultClip
    }

    private func apply(_ config: KeyliConfig) {
        guard config.playKeyClickSound else {
            stopEngine()
            return
        }
        let resolved = SoundPackLibrary.shared.pack(id: config.keySoundPackId)
        if resolved?.id != loadedPackId {
            load(resolved)
        } else if !clips.isEmpty, graphReady, !engine.isRunning {
            lastPlay = CACurrentMediaTime()
            _ = ensureRunning()
        }
    }

    private func setupGraphIfNeeded() {
        guard !graphReady else { return }
        let hardware = engine.outputNode.outputFormat(forBus: 0)
        let rate = hardware.sampleRate > 0 ? hardware.sampleRate : 48_000
        format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        for _ in 0..<Self.voiceCount {
            let node = AVAudioPlayerNode()
            let pitch = AVAudioUnitVarispeed()
            let mixer = AVAudioUnitEQ(numberOfBands: 0)
            engine.attach(node)
            engine.attach(pitch)
            engine.attach(mixer)
            engine.connect(node, to: pitch, format: format)
            engine.connect(pitch, to: mixer, format: format)
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
            voices.append(node)
            pitchUnits.append(pitch)
            voiceGains.append(mixer)
            voiceFreeAt.append(0)
        }
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
        graphReady = true
    }

    private func setLowLatencyBuffer() {
        guard let unit = engine.outputNode.audioUnit else { return }
        var frames: UInt32 = 256
        AudioUnitSetProperty(
            unit,
            kAudioDevicePropertyBufferFrameSize,
            kAudioUnitScope_Global,
            0,
            &frames,
            UInt32(MemoryLayout<UInt32>.size)
        )
    }

    private func ensureRunning() -> Bool {
        setupGraphIfNeeded()
        if !engine.isRunning {
            setLowLatencyBuffer()
            do {
                try engine.start()
            } catch {
                return false
            }
            for node in voices where !node.isPlaying {
                node.play()
            }
            startIdleTimer()
        }
        return true
    }

    private func stopEngine() {
        idleTimer?.invalidate()
        idleTimer = nil
        guard graphReady, engine.isRunning else { return }
        voices.forEach { $0.stop() }
        engine.stop()
        for index in voiceFreeAt.indices { voiceFreeAt[index] = 0 }
    }

    private func pauseEngine() {
        idleTimer?.invalidate()
        idleTimer = nil
        guard graphReady, engine.isRunning else { return }
        engine.pause()
    }

    private func startIdleTimer() {
        idleTimer?.invalidate()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            if CACurrentMediaTime() - self.lastPlay > Self.idleShutdown {
                self.pauseEngine()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    private func play(_ buffer: AVAudioPCMBuffer, source: Source, gain: Double? = nil, randomPitch: Bool? = nil) {
        guard buffer.format == format, ensureRunning() else { return }
        let variation = ConfigStore.shared.config.keySoundVariation
            ? Variation.random(wide: randomPitch ?? packRandomPitch, using: &generator)
            : .none
        let now = CACurrentMediaTime()
        lastPlay = now
        let count = voices.count
        var chosen: Int?
        for offset in 0..<count {
            let index = (nextVoice + offset) % count
            if voiceFreeAt[index] <= now {
                chosen = index
                break
            }
        }
        let index = chosen ?? voiceFreeAt.indices.min { voiceFreeAt[$0] < voiceFreeAt[$1] } ?? 0
        nextVoice = (index + 1) % count
        let node = voices[index]
        pitchUnits[index].rate = variation.rate
        voiceGains[index].globalGain = Self.decibels(Self.voiceVolume(sourceVolume: sourceVolume(source), packGain: gain ?? packGain, variation: variation))
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying {
            node.play()
        }
        voiceFreeAt[index] = now + Double(buffer.frameLength) / format.sampleRate / Double(variation.rate) + 0.02
    }

    @objc private func handleConfigurationChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.graphReady else { return }
            let hardware = self.engine.outputNode.outputFormat(forBus: 0)
            let rate = hardware.sampleRate > 0 ? hardware.sampleRate : self.format.sampleRate
            for index in self.voiceFreeAt.indices { self.voiceFreeAt[index] = 0 }
            guard rate != self.format.sampleRate else {
                if self.isEnabled, !self.clips.isEmpty {
                    self.lastPlay = CACurrentMediaTime()
                    _ = self.ensureRunning()
                }
                return
            }
            self.format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
            for index in self.voices.indices {
                let node = self.voices[index], pitch = self.pitchUnits[index], mixer = self.voiceGains[index]
                self.engine.disconnectNodeOutput(node)
                self.engine.disconnectNodeOutput(pitch)
                self.engine.disconnectNodeOutput(mixer)
                self.engine.connect(node, to: pitch, format: self.format)
                self.engine.connect(pitch, to: mixer, format: self.format)
                self.engine.connect(mixer, to: self.engine.mainMixerNode, format: self.format)
            }
            self.clips = [:]
            self.clipsPackId = nil
            self.loadedPackId = nil
            self.previewCache = nil
            self.apply(ConfigStore.shared.config)
        }
    }

    private func load(_ info: SoundPackInfo?) {
        loadGeneration += 1
        let generation = loadGeneration
        loadedPackId = info?.id
        guard let info else {
            clipsPackId = nil
            clips = [:]
            defaultClip = ClipPair()
            return
        }
        setupGraphIfNeeded()
        let target = format
        loadQueue.async { [weak self] in
            let result = try? Self.buildClips(folder: info.folder, format: target)
            DispatchQueue.main.async {
                guard let self, generation == self.loadGeneration else { return }
                self.clips = result?.clips ?? [:]
                self.defaultClip = result?.fallback ?? ClipPair()
                self.clipsPackId = result == nil ? nil : info.id
                self.packGain = result?.gain ?? 1
                self.packRandomPitch = result?.randomPitch ?? false
                if self.isEnabled, result != nil {
                    self.lastPlay = CACurrentMediaTime()
                    _ = self.ensureRunning()
                }
            }
        }
    }

    static func buildClips(folder: URL, format: AVAudioFormat) throws -> PackClips {
        let manifest = try SoundPackLibrary.loadManifest(in: folder)
        var decoded: [String: AVAudioPCMBuffer] = [:]
        var failed: Set<String> = []
        var slices: [SliceKey: AVAudioPCMBuffer] = [:]

        func source(_ file: String) -> AVAudioPCMBuffer? {
            if let cached = decoded[file] { return cached }
            if failed.contains(file) { return nil }
            guard let buffer = try? decode(url: folder.appendingPathComponent(file), format: format) else {
                failed.insert(file)
                return nil
            }
            decoded[file] = buffer
            return buffer
        }

        func slice(_ file: String, _ segment: SoundSegment?) -> AVAudioPCMBuffer? {
            guard let segment else { return nil }
            let key = SliceKey(file: file, segment: segment)
            if let cached = slices[key] { return cached }
            guard let full = source(file), let cut = makeSlice(of: full, segment: segment) else { return nil }
            slices[key] = cut
            return cut
        }

        func pair(_ definition: KeySoundDefinition?) -> ClipPair {
            guard let definition else { return ClipPair() }
            return ClipPair(down: slice(definition.file, definition.down), up: slice(definition.file, definition.up))
        }

        var clips: [UInt16: ClipPair] = [:]
        for keyCode in SoundKeyMap.macKeyNames.keys {
            clips[keyCode] = pair(manifest.definition(forMacKeyCode: keyCode))
        }
        let fallback = pair(manifest.definition(forKeyName: "KeyA"))
        return PackClips(clips: clips, fallback: fallback, gain: manifest.recommendedVolume, randomPitch: manifest.randomPitch)
    }

    static func decode(url: URL, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let raw = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frames) else {
            throw SoundPackError.unplayableAudio(pack: url.deletingLastPathComponent().lastPathComponent, file: url.lastPathComponent)
        }
        try file.read(into: raw)

        var resampled = raw
        if sourceFormat.sampleRate != format.sampleRate {
            guard let middle = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: sourceFormat.channelCount, interleaved: false),
                  let converter = AVAudioConverter(from: sourceFormat, to: middle) else {
                throw SoundPackError.unplayableAudio(pack: url.deletingLastPathComponent().lastPathComponent, file: url.lastPathComponent)
            }
            let capacity = AVAudioFrameCount(Double(raw.frameLength) * format.sampleRate / sourceFormat.sampleRate) + 1024
            guard let output = AVAudioPCMBuffer(pcmFormat: middle, frameCapacity: capacity) else {
                throw SoundPackError.unplayableAudio(pack: url.deletingLastPathComponent().lastPathComponent, file: url.lastPathComponent)
            }
            var supplied = false
            var conversionError: NSError?
            converter.convert(to: output, error: &conversionError) { _, status in
                if supplied {
                    status.pointee = .endOfStream
                    return nil
                }
                supplied = true
                status.pointee = .haveData
                return raw
            }
            if let conversionError { throw conversionError }
            resampled = output
        }

        guard let stereo = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: resampled.frameLength),
              let input = resampled.floatChannelData,
              let out = stereo.floatChannelData else {
            throw SoundPackError.unplayableAudio(pack: url.deletingLastPathComponent().lastPathComponent, file: url.lastPathComponent)
        }
        let length = Int(resampled.frameLength)
        let channels = Int(resampled.format.channelCount)
        let left = input[0]
        let right = channels > 1 ? input[1] : input[0]
        out[0].update(from: left, count: length)
        out[1].update(from: right, count: length)
        stereo.frameLength = resampled.frameLength
        return stereo
    }

    static func makeSlice(of buffer: AVAudioPCMBuffer, segment: SoundSegment) -> AVAudioPCMBuffer? {
        let rate = buffer.format.sampleRate
        let total = Int(buffer.frameLength)
        let start = min(total, max(0, Int((segment.startMs / 1000 * rate).rounded())))
        var end = segment.endMs.map { Int(($0 / 1000 * rate).rounded()) } ?? total
        end = min(total, end, start + Int(maxClipSeconds * rate))
        let length = end - start
        guard length > 0,
              let slice = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(length)),
              let input = buffer.floatChannelData,
              let output = slice.floatChannelData else { return nil }

        let fadeIn = min(length / 2, Int(fadeInSeconds * rate))
        let fadeOut = min(length / 2, Int(fadeOutSeconds * rate))
        for channel in 0..<Int(buffer.format.channelCount) {
            let destination = output[channel]
            destination.update(from: input[channel].advanced(by: start), count: length)
            if fadeIn > 0 {
                for frame in 0..<fadeIn {
                    destination[frame] *= Float(frame) / Float(fadeIn)
                }
            }
            if fadeOut > 0 {
                for frame in 0..<fadeOut {
                    destination[length - 1 - frame] *= Float(frame) / Float(fadeOut)
                }
            }
        }
        slice.frameLength = AVAudioFrameCount(length)
        return slice
    }
}
