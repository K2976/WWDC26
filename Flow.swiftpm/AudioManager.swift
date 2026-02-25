import Foundation
import AVFoundation

// MARK: - Audio Manager
// Uses AVAudioPlayer with in-memory WAV data to avoid AVAudioEngine format issues

@MainActor
@Observable
final class AudioManager {
    
    private var calmPlayer: AVAudioPlayer?
    private var stressPlayer: AVAudioPlayer?
    
    private(set) var isPlaying: Bool = false
    var isMuted: Bool = false
    
    private let sampleRate: Double = 44100
    private let bufferDuration: Double = 4.0 // 4-second loop
    
    init() {
        setupAudio()
    }
    
    // MARK: - Setup
    
    private func setupAudio() {
        // Generate WAV data in memory — no AVAudioEngine needed
        if let calmData = generateWAVData(frequency: 220, amplitude: 0.08) {
            calmPlayer = try? AVAudioPlayer(data: calmData)
            calmPlayer?.numberOfLoops = -1 // loop forever
            calmPlayer?.volume = 0.6
            calmPlayer?.prepareToPlay()
        }
        
        if let stressData = generateWAVData(frequency: 440, amplitude: 0.05, modulation: true) {
            stressPlayer = try? AVAudioPlayer(data: stressData)
            stressPlayer?.numberOfLoops = -1
            stressPlayer?.volume = 0.0
            stressPlayer?.prepareToPlay()
        }
    }
    
    /// Generate a WAV file in memory with a sine tone
    private func generateWAVData(frequency: Double, amplitude: Float, modulation: Bool = false) -> Data? {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let frameCount = Int(sampleRate * bufferDuration)
        let bytesPerSample = Int(bitsPerSample / 8)
        let dataSize = frameCount * Int(numChannels) * bytesPerSample
        
        var data = Data()
        
        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(&data, UInt32(36 + dataSize))      // file size - 8
        data.append(contentsOf: "WAVE".utf8)
        
        
        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(&data, 16)                           // chunk size
        appendUInt16(&data, 1)                            // PCM format
        appendUInt16(&data, numChannels)
        appendUInt32(&data, UInt32(sampleRate))
        appendUInt32(&data, UInt32(sampleRate * Double(numChannels) * Double(bytesPerSample))) // byte rate
        appendUInt16(&data, numChannels * UInt16(bytesPerSample)) // block align
        appendUInt16(&data, bitsPerSample)
        
        // data chunk
        data.append(contentsOf: "data".utf8)
        appendUInt32(&data, UInt32(dataSize))
        
        // Generate samples
        let fadeLength = 2000
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample = sin(2.0 * .pi * frequency * t) * Double(amplitude)
            
            if modulation {
                let lfo = sin(2.0 * .pi * 3.0 * t) * 0.3
                sample *= (1.0 + lfo)
            }
            
            // Crossfade at boundaries for seamless looping
            if i < fadeLength {
                sample *= Double(i) / Double(fadeLength)
            } else if i > frameCount - fadeLength {
                sample *= Double(frameCount - i) / Double(fadeLength)
            }
            
            // Convert to 16-bit PCM
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * Double(Int16.max))
            appendInt16(&data, intSample)
        }
        
        return data
    }
    
    // MARK: - WAV Helpers
    
    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }
    
    private func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 4))
    }
    
    private func appendInt16(_ data: inout Data, _ value: Int16) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }
    
    // MARK: - Playback
    
    func startAmbient() {
        guard !isPlaying else { return }
        
        calmPlayer?.play()
        stressPlayer?.play()
        isPlaying = true
    }
    
    func stopAmbient() {
        calmPlayer?.stop()
        stressPlayer?.stop()
        isPlaying = false
    }
    
    func updateForScore(_ score: Double) {
        guard isPlaying, !isMuted else { return }
        
        let normalizedScore = min(max(score, 0), 100) / 100.0
        
        // Calm fades out as stress rises
        calmPlayer?.volume = Float(1.0 - normalizedScore * 0.6)
        stressPlayer?.volume = Float(normalizedScore * 0.7)
    }
    
    func setFocusMode(_ enabled: Bool) {
        if enabled {
            stressPlayer?.volume = 0
            calmPlayer?.volume = 0.8
        }
    }
    
    func playEventChime() {
        guard isPlaying, !isMuted else { return }
        let originalVolume = calmPlayer?.volume ?? 0.6
        calmPlayer?.volume = min(originalVolume + 0.3, 1.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.calmPlayer?.volume = originalVolume
        }
    }
    
    func playCompletionChime() {
        guard !isMuted else { return }
        let originalVolume = calmPlayer?.volume ?? 0.6
        calmPlayer?.volume = 1.0
        stressPlayer?.volume = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.calmPlayer?.volume = originalVolume
        }
    }
}
