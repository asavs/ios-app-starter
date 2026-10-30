import Foundation

/// One generated note.
struct Tone: Sendable, Equatable {
    static let sampleRate = 44_100

    var frequency: Double
    /// Seconds.
    var duration: Double

    /// Samples in -1...1: a sine with a 5 ms attack and an exponential release, so it doesn't click.
    var samples: [Double] {
        let count = Int(duration * Double(Self.sampleRate))
        let attack = Double(Self.sampleRate) * 0.005
        return (0..<count).map { index in
            let time = Double(index) / Double(Self.sampleRate)
            let envelope = min(1, Double(index) / attack) * exp(-4 * time / duration)
            return sin(2 * .pi * frequency * time) * envelope * 0.6
        }
    }

    static func wav(_ tones: [Tone]) -> Data {
        let pcm = tones.flatMap(\.samples).map { Int16(($0 * Double(Int16.max)).rounded()) }
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(pcm.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)) // PCM, mono
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)) // sample rate, bytes per second
        append(UInt16(2)); append(UInt16(16)) // block align, bits per sample
        data.append(contentsOf: Array("data".utf8)); append(bytes)
        pcm.forEach { append($0) }
        return data
    }
}
