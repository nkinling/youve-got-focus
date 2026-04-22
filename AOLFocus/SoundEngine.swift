import AVFoundation

/// Procedurally generates dial-up modem sounds using AVAudioEngine.
/// No audio files needed — pure synthesis.
class SoundEngine: NSObject {

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44100

    // Stored after engine connects so all buffers use the exact same format
    private var playFormat: AVAudioFormat?

    // File-based player for "You've Got Focus" voice clip
    private var voicePlayer: AVAudioPlayer?

    // Pre-baked buffers
    private var dialupBuffer: AVAudioPCMBuffer?
    private var connectBuffer: AVAudioPCMBuffer?
    private var goodbyeBuffer: AVAudioPCMBuffer?
    private var urgentBeepBuffer: AVAudioPCMBuffer?
    private var busyBuffer: AVAudioPCMBuffer?

    // Serial queue — ALL engine and buffer ops run here, no races
    private let audioQueue = DispatchQueue(label: "com.aolfocus.audio", qos: .userInitiated)

    override init() {
        super.init()
        audioQueue.async { [weak self] in
            self?.setupEngine()
        }
    }

    // MARK: - Setup (audioQueue only)

    private func setupEngine() {
        engine.attach(playerNode)

        // Connect with nil format first so AVAudioEngine chooses its preferred format
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)

        // Now query the format the engine actually negotiated — this is what buffers MUST match
        let negotiatedFormat = playerNode.outputFormat(forBus: 0)
        playFormat = negotiatedFormat

        do {
            try engine.start()
        } catch {
            return
        }

        // Pre-bake all buffers using the negotiated format
        dialupBuffer     = buildDialupBuffer()
        connectBuffer    = buildChime(notes: [880, 1108, 1320], durations: [0.12, 0.12, 0.25])
        goodbyeBuffer    = buildChime(notes: [523, 659, 784, 1047], durations: [0.18, 0.18, 0.18, 0.4])
        urgentBeepBuffer = buildTone(freq: 1200, duration: 0.12, volume: 0.15, waveType: .square)
        busyBuffer       = buildBusySignal()
    }

    // MARK: - Public API (safe to call from any thread)

    func playDialup(completion: @escaping () -> Void) {
        audioQueue.async { [weak self] in
            guard let self else { DispatchQueue.main.async { completion() }; return }
            guard let buf = self.dialupBuffer else {
                // Engine not ready yet — just fire completion after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { completion() }
                return
            }
            let duration = Double(buf.frameLength) / self.sampleRate
            self.scheduleAndPlay(buf)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { completion() }
        }
    }

    func playConnect() {
        audioQueue.async { [weak self] in
            guard let self, let buf = self.connectBuffer else { return }
            self.scheduleAndPlay(buf)
        }
    }

    func playGoodbye() {
        audioQueue.async { [weak self] in
            guard let self, let buf = self.goodbyeBuffer else { return }
            self.scheduleAndPlay(buf)
        }
    }

    func playUrgentBeep() {
        audioQueue.async { [weak self] in
            guard let self, let buf = self.urgentBeepBuffer else { return }
            self.scheduleAndPlay(buf)
        }
    }

    func playBusySignal() {
        audioQueue.async { [weak self] in
            guard let self, let buf = self.busyBuffer else { return }
            self.scheduleAndPlay(buf)
        }
    }

    func playYouveGotFocus() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            // Stop any in-progress synthesis (dial-up noise) before the voice plays
            self.playerNode.stop()
            guard let url = Bundle.main.url(forResource: "youve_got_focus", withExtension: "aiff") else { return }
            DispatchQueue.main.async {
                self.voicePlayer = try? AVAudioPlayer(contentsOf: url)
                self.voicePlayer?.volume = 0.95
                self.voicePlayer?.play()
            }
        }
    }

    // MARK: - scheduleAndPlay (audioQueue only)

    private func scheduleAndPlay(_ buffer: AVAudioPCMBuffer) {
        guard engine.isRunning else { return }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    // MARK: - Buffer builders (audioQueue only, playFormat must be set)

    private func buildDialupBuffer() -> AVAudioPCMBuffer {
        var all = [Float]()

        // 1. DTMF dialing tones
        let dtmfFreqs: [(Double, Double)] = [
            (941, 1336), (697, 1477), (770, 1209), (852, 1336),
            (941, 1209), (697, 1336), (770, 1477), (852, 1209)
        ]
        for (f1, f2) in dtmfFreqs {
            all += mixTones(freqs: [f1, f2], duration: 0.12, volume: 0.5)
            all += silence(0.04)
        }
        all += silence(0.3)

        // 2. Carrier detection
        let carrierSeq: [(Double, Double)] = [
            (2100, 0.08), (1300, 0.08), (2100, 0.08), (1300, 0.08),
            (2100, 0.08), (1800, 0.08), (1300, 0.08), (2400, 0.08),
            (1800, 0.08), (2100, 0.08)
        ]
        for (freq, dur) in carrierSeq {
            all += singleTone(freq: freq, duration: dur, volume: 0.5, waveType: .sawtooth)
        }
        all += silence(0.2)

        // 3. Handshake screech — deterministic sequence
        let scrFreqs: [Double] = [1200,800,2400,600,3000,1600,2800,400,2200,1000,
                                   3200,700,1800,2600,900,1400,2000,500,1100,2900,
                                   650,1700,2300,850,1500,2700,1300,750,1900,2500,
                                   450,1050,2150,950,1650,2450,550,1250,1950,2350,
                                   680,1450,2050,830,1580]
        let scrDurs: [Double]  = [0.04,0.06,0.03,0.05,0.04,0.06,0.03,0.05,0.04,0.06,
                                   0.03,0.05,0.04,0.06,0.03,0.05,0.04,0.06,0.03,0.05,
                                   0.04,0.06,0.03,0.05,0.04,0.06,0.03,0.05,0.04,0.06,
                                   0.03,0.05,0.04,0.06,0.03,0.05,0.04,0.06,0.03,0.05,
                                   0.04,0.06,0.03,0.05,0.04]
        let scrVols: [Float]   = [0.4,0.5,0.6,0.4,0.5,0.3,0.6,0.4,0.5,0.6,
                                   0.4,0.5,0.3,0.6,0.4,0.5,0.6,0.4,0.5,0.3,
                                   0.6,0.4,0.5,0.6,0.4,0.5,0.3,0.6,0.4,0.5,
                                   0.6,0.4,0.5,0.3,0.6,0.4,0.5,0.6,0.4,0.5,
                                   0.3,0.6,0.4,0.5,0.6]
        let scrWaves: [WaveType] = [.sine,.sawtooth,.square,.sine,.sawtooth,.square,.sine,.sawtooth,.square,.sine,
                                     .square,.sine,.sawtooth,.square,.sine,.sawtooth,.square,.sine,.sawtooth,.square,
                                     .sine,.sawtooth,.square,.sine,.sawtooth,.square,.sine,.sawtooth,.square,.sine,
                                     .square,.sine,.sawtooth,.square,.sine,.sawtooth,.square,.sine,.sawtooth,.square,
                                     .sine,.sawtooth,.square,.sine,.sawtooth]
        for i in 0..<45 {
            all += singleTone(freq: scrFreqs[i], duration: scrDurs[i], volume: scrVols[i], waveType: scrWaves[i])
        }
        all += silence(0.1)

        // 4. Settling tone
        for step in 0..<20 {
            let freq = max(600.0, 2400.0 - Double(step) * 60.0)
            all += singleTone(freq: freq, duration: 0.04, volume: 0.4, waveType: .sine)
        }
        all += silence(0.2)

        return makePCMBuffer(monoSamples: all)
    }

    private func buildBusySignal() -> AVAudioPCMBuffer {
        var s = [Float]()
        for _ in 0..<3 {
            s += mixTones(freqs: [480, 620], duration: 0.35, volume: 0.2)
            s += silence(0.15)
        }
        return makePCMBuffer(monoSamples: s)
    }

    // MARK: - Waveform helpers

    enum WaveType { case sine, sawtooth, square }

    private func singleTone(freq: Double, duration: Double, volume: Float, waveType: WaveType) -> [Float] {
        let count = Int(sampleRate * duration)
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let phase = 2.0 * .pi * freq * t
            let raw: Double
            switch waveType {
            case .sine:     raw = sin(phase)
            case .sawtooth: raw = 2.0 * (freq * t - floor(0.5 + freq * t))
            case .square:   raw = sin(phase) >= 0 ? 1.0 : -1.0
            }
            let env = min(Double(i) / Double(max(1, count / 20)),
                          Double(count - i) / Double(max(1, count / 20)))
            return Float(raw * min(env, 1.0)) * volume
        }
    }

    private func mixTones(freqs: [Double], duration: Double, volume: Float) -> [Float] {
        let count = Int(sampleRate * duration)
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let mixed = freqs.reduce(0.0) { $0 + sin(2.0 * .pi * $1 * t) }
            let env = min(Double(i) / Double(max(1, count / 20)),
                          Double(count - i) / Double(max(1, count / 20)))
            return Float(mixed / Double(freqs.count) * min(env, 1.0)) * volume
        }
    }

    private func silence(_ duration: Double) -> [Float] {
        [Float](repeating: 0, count: Int(sampleRate * duration))
    }

    private func buildTone(freq: Double, duration: Double, volume: Float, waveType: WaveType) -> AVAudioPCMBuffer {
        makePCMBuffer(monoSamples: singleTone(freq: freq, duration: duration, volume: volume, waveType: waveType))
    }

    private func buildChime(notes: [Double], durations: [Double]) -> AVAudioPCMBuffer {
        var s = [Float]()
        for (freq, dur) in zip(notes, durations) {
            s += singleTone(freq: freq, duration: dur, volume: 0.2, waveType: .sine)
        }
        return makePCMBuffer(monoSamples: s)
    }

    /// Build a PCMBuffer using the engine's negotiated format.
    /// Mono samples are duplicated to all channels (stereo/surround safe).
    private func makePCMBuffer(monoSamples: [Float]) -> AVAudioPCMBuffer {
        // Use the negotiated format; fall back to stereo if not set yet
        let fmt = playFormat ?? AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let frameCount = AVAudioFrameCount(monoSamples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else {
            // Absolute fallback: mono buffer
            let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let b = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: frameCount)!
            b.frameLength = frameCount
            b.floatChannelData![0].update(from: monoSamples, count: monoSamples.count)
            return b
        }
        buffer.frameLength = frameCount
        // Copy mono signal into every channel
        let channelCount = Int(fmt.channelCount)
        for ch in 0..<channelCount {
            buffer.floatChannelData![ch].update(from: monoSamples, count: monoSamples.count)
        }
        return buffer
    }
}
