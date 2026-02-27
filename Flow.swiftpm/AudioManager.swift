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
    private let bufferDuration: Double = 10.0 // 10-second loop for seamless playback
    
    init() {
        setupAudio()
    }
    
    // MARK: - Setup
    
    private func setupAudio() {
        // Calm tone: 180Hz carrier modulated at 20Hz beat rate
        if let calmData = generateWAVData(carrier: 180, beatRate: 20, amplitude: 0.12) {
            calmPlayer = try? AVAudioPlayer(data: calmData)
            calmPlayer?.numberOfLoops = -1
            calmPlayer?.volume = 0.6
            calmPlayer?.prepareToPlay()
        }
        
        // Stress tone: 200Hz carrier modulated at 40Hz beat rate
        if let stressData = generateWAVData(carrier: 200, beatRate: 40, amplitude: 0.10) {
            stressPlayer = try? AVAudioPlayer(data: stressData)
            stressPlayer?.numberOfLoops = -1
            stressPlayer?.volume = 0.0
            stressPlayer?.prepareToPlay()
        }
    }
    
    /// Generate a WAV file with an audible carrier modulated at a target beat frequency
    /// This creates isochronal beats in the 30–50Hz gamma range
    private func generateWAVData(carrier: Double, beatRate: Double, amplitude: Float) -> Data? {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        
        // Phase-aligned frame count: exact cycles of both carrier and beat rate
        let desiredDuration = bufferDuration
        let completeCycles = Int(desiredDuration * beatRate)
        let frameCount = Int(Double(completeCycles) / beatRate * sampleRate)
        
        let bytesPerSample = Int(bitsPerSample / 8)
        let dataSize = frameCount * Int(numChannels) * bytesPerSample
        
        var data = Data()
        
        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(&data, UInt32(36 + dataSize))
        data.append(contentsOf: "WAVE".utf8)
        
        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(&data, 16)
        appendUInt16(&data, 1)  // PCM
        appendUInt16(&data, numChannels)
        appendUInt32(&data, UInt32(sampleRate))
        appendUInt32(&data, UInt32(sampleRate * Double(numChannels) * Double(bytesPerSample)))
        appendUInt16(&data, numChannels * UInt16(bytesPerSample))
        appendUInt16(&data, bitsPerSample)
        
        // data chunk
        data.append(contentsOf: "data".utf8)
        appendUInt32(&data, UInt32(dataSize))
        
        // Generate samples: carrier sine modulated by beat-rate envelope
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            
            // Carrier tone (audible frequency)
            let carrierWave = sin(2.0 * .pi * carrier * t)
            
            // Beat modulation envelope: smoothly pulses at beatRate Hz
            // Uses (1 + cos) / 2 for smooth 0→1→0 pulse shape
            let beatEnvelope = (1.0 + cos(2.0 * .pi * beatRate * t)) / 2.0
            
            let sample = carrierWave * beatEnvelope * Double(amplitude)
            
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
