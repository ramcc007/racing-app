import Foundation

/// Your best run on a track, replayed as a see-through car you can race (never solid, separate from echoes).
/// Recorded 30 times a second from the moment the clock starts; positions in between are interpolated.
public struct Ghost: Codable, Equatable, Sendable {
    public static let interval = 4 * Physics.dt

    public let trackID: String
    public let totalTime: Double
    /// x, y, heading per frame.
    let frames: [Float]

    public var frameCount: Int { frames.count / 3 }

    public func pose(at time: Double) -> (position: Vec2, heading: Double)? {
        guard frameCount > 1, time >= 0 else { return nil }
        let f = time / Ghost.interval
        let i = Int(f)
        guard i + 1 < frameCount else { return nil }
        let t = f - Double(i)
        let a = Vec2(Double(frames[i * 3]), Double(frames[i * 3 + 1]))
        let b = Vec2(Double(frames[(i + 1) * 3]), Double(frames[(i + 1) * 3 + 1]))
        let ha = Double(frames[i * 3 + 2]), hb = Double(frames[(i + 1) * 3 + 2])
        return (a + (b - a) * t, ha + wrapAngle(hb - ha) * t)
    }
}

/// Collects a ghost while racing; call `capture` after every tick.
public struct GhostRecorder: Sendable {
    private var frames: [Float] = []

    public init() {}

    public mutating func capture(_ race: Race) {
        guard race.crossedStart, race.phase == .racing else { return }
        let due = Int(race.time / Ghost.interval) + 1
        while frames.count / 3 < due {
            frames.append(Float(race.car.position.x))
            frames.append(Float(race.car.position.y))
            frames.append(Float(race.car.heading))
        }
    }

    public func ghost(trackID: String, totalTime: Double) -> Ghost {
        Ghost(trackID: trackID, totalTime: totalTime, frames: frames)
    }
}
