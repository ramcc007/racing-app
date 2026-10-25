import Foundation

/// One finished run of a track, kept so it can race you again as an echo (the echo ladder keeps your best five).
/// Frames are x, y, heading, flags per tick from the moment the clock started, stored as little-endian Float32.
public struct SavedRun: Codable, Equatable, Sendable {
    public static let ladderSize = 5

    public let trackID: String
    public let carID: String
    public let totalTime: Double
    let frames: Data

    public init(trackID: String, carID: String, totalTime: Double, frames: [Float]) {
        self.trackID = trackID
        self.carID = carID
        self.totalTime = totalTime
        var data = Data(capacity: frames.count * 4)
        for f in frames {
            var bits = f.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        self.frames = data
    }

    /// Captures the run a finished race recorded.
    public init(race: Race) {
        self.init(trackID: race.track.def.id, carID: race.spec.id, totalTime: race.time, frames: race.recordedFrames)
    }

    public var frameCount: Int { frames.count / 16 }

    public func floats() -> [Float] {
        let n = frames.count / 4
        var out = [Float](repeating: 0, count: n)
        frames.withUnsafeBytes { raw in
            for i in 0..<n {
                let bits = raw.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self)
                out[i] = Float(bitPattern: UInt32(littleEndian: bits))
            }
        }
        return out
    }

    /// The run as an echo car, tagged with its rung on the ladder (1 = your best).
    public func echo(rung: Int) -> Echo { Echo(lap: rung, frames: floats()) }

    /// The best `count` runs of a track as echoes, fastest first (rung 1 is your best).
    public static func ladder(_ runs: [SavedRun], count: Int) -> [Echo] {
        runs.sorted { $0.totalTime < $1.totalTime }.prefix(max(0, count)).enumerated().map { $1.echo(rung: $0 + 1) }
    }

    /// Adds a run and keeps only the best `ladderSize`, fastest first.
    public static func keepBest(_ runs: [SavedRun], adding run: SavedRun) -> [SavedRun] {
        Array((runs + [run]).sorted { $0.totalTime < $1.totalTime }.prefix(ladderSize))
    }
}
