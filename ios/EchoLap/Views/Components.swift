import SwiftUI
import EchoLapCore

/// Three stars, filled up to `count`.
struct StarsView: View {
    let count: Int
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < count ? Theme.gold : Theme.muted.opacity(0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 stars")
    }
}

/// The echo ladder: five dots, filled up to the rung, gold when the track is mastered.
struct LadderDots: View {
    let rung: Int
    let mastered: Bool
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: size * 0.35) {
            ForEach(0..<TrackRecord.topRung, id: \.self) { i in
                Circle()
                    .fill(i < rung ? (mastered ? Theme.gold : Theme.echoColor(lap: i + 1)) : Theme.muted.opacity(0.25))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mastered ? "Track mastered" : "Echo ladder rung \(rung) of \(TrackRecord.topRung)")
    }
}

/// A small counter: stars, Sparks, level.
struct CounterPill: View {
    let systemImage: String
    let value: String
    let color: Color
    var label: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(color)
            Text(value).font(Theme.rounded(.subheadline, .heavy)).monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassCard(cornerRadius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

/// Section title in the menus.
struct SectionTitle: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(Theme.rounded(.title3, .heavy))
            Spacer()
            if let trailing { Text(trailing).font(Theme.rounded(.footnote, .semibold)).foregroundStyle(Theme.muted) }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// The circuit's shape, scaled to fit, with its shortcut, bays and patches.
struct TrackPreview: View {
    let track: Track
    var lineWidth: CGFloat = 7

    var body: some View {
        Canvas { context, size in
            let b = track.bounds(margin: track.halfWidth + 20)
            let w = b.max.x - b.min.x, h = b.max.y - b.min.y
            let k = min(size.width / w, size.height / h)
            let ox = (size.width - w * k) / 2, oy = (size.height - h * k) / 2
            func pt(_ v: Vec2) -> CGPoint { CGPoint(x: ox + (v.x - b.min.x) * k, y: size.height - (oy + (v.y - b.min.y) * k)) }
            let style = WorldStyle.of(track.def.world)
            if let sc = track.shortcut {
                var lane = Path()
                lane.move(to: pt(sc.a)); lane.addLine(to: pt(sc.b))
                context.stroke(lane, with: .color(Color(hex: 0xF2A93B).opacity(0.85)), style: StrokeStyle(lineWidth: lineWidth * 0.55, lineCap: .round, dash: [4, 4]))
            }
            var road = Path()
            road.move(to: pt(track.points[0]))
            for p in track.points.dropFirst() { road.addLine(to: pt(p)) }
            road.closeSubpath()
            context.stroke(road, with: .color(Color(hex: style.kerbB)), style: StrokeStyle(lineWidth: lineWidth + 3, lineJoin: .round))
            context.stroke(road, with: .color(Color(hex: style.asphalt).opacity(1)), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
            for patch in track.patches {
                var p = Path()
                for k2 in stride(from: 0, through: patch.count, by: 2) {
                    let i = track.wrap(patch.startIndex + k2)
                    if k2 == 0 { p.move(to: pt(track.points[i])) } else { p.addLine(to: pt(track.points[i])) }
                }
                context.stroke(p, with: .color(patch.kind == .ice ? Color(hex: 0xBFE6F7) : Color(hex: 0xE2C07A)),
                               style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round))
            }
            for bay in track.bays {
                let c = pt(bay.center)
                context.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)),
                             with: .color(bay.kind == .pad ? Theme.good : Color(hex: 0x2B8FD6)))
            }
            let s = pt(track.points[0])
            context.fill(Path(ellipseIn: CGRect(x: s.x - 4, y: s.y - 4, width: 8, height: 8)), with: .color(.white))
        }
        .accessibilityHidden(true)
    }
}

/// A racer drawn in SwiftUI (same shapes as the race sprites), pointing up.
struct CarPreview: View {
    let car: CarSpec
    var paint: String = "paint.factory"
    var body: some View {
        Canvas { context, size in
            let k = min(size.width / 56, size.height / 92)
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: k, y: k)
            context.rotate(by: .degrees(-90))
            let body = Self.bodyColor(car, paint)
            let tyre = Color(hex: 0x1C1E22), canopy = Color(hex: 0x16263A)
            func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
            }
            for (x, y) in [(-22.0, -24.0), (14, -24), (-22, 16), (14, 16)] { context.fill(rr(x, y, 18, 8, 3), with: .color(tyre)) }
            switch car.shape {
            case "wedge":
                var p = Path()
                p.addLines([CGPoint(x: -34, y: -18), CGPoint(x: 10, y: -18), CGPoint(x: 42, y: -4), CGPoint(x: 42, y: 4), CGPoint(x: 10, y: 18), CGPoint(x: -34, y: 18)])
                p.closeSubpath()
                context.fill(p, with: .color(body))
                var c = Path()
                c.addLines([CGPoint(x: -8, y: -10), CGPoint(x: 14, y: -8), CGPoint(x: 24, y: 0), CGPoint(x: 14, y: 8), CGPoint(x: -8, y: 10)])
                c.closeSubpath()
                context.fill(c, with: .color(canopy))
            case "buggy":
                context.fill(rr(-28, -14, 60, 28, 14), with: .color(body))
                context.stroke(rr(-12, -18, 26, 36, 6), with: .color(tyre), lineWidth: 4)
                context.fill(Path(ellipseIn: CGRect(x: -6, y: -8, width: 16, height: 16)), with: .color(canopy))
            case "brick":
                context.fill(rr(-34, -20, 74, 40, 9), with: .color(body))
                context.fill(rr(-10, -15, 30, 30, 5), with: .color(canopy))
            case "needle":
                var p = Path()
                p.move(to: CGPoint(x: -36, y: -10)); p.addLine(to: CGPoint(x: 20, y: -8)); p.addQuadCurve(to: CGPoint(x: 46, y: 0), control: CGPoint(x: 46, y: -3))
                p.addQuadCurve(to: CGPoint(x: 20, y: 8), control: CGPoint(x: 46, y: 3)); p.addLine(to: CGPoint(x: -36, y: 10)); p.closeSubpath()
                context.fill(p, with: .color(body))
                context.fill(rr(-40, -22, 10, 44, 3), with: .color(body.opacity(0.85)))
                context.fill(Path(ellipseIn: CGRect(x: -12, y: -6, width: 20, height: 12)), with: .color(canopy))
            case "hover":
                context.fill(Path(ellipseIn: CGRect(x: -38, y: -22, width: 80, height: 44)), with: .color(body))
                context.stroke(Path(ellipseIn: CGRect(x: -38, y: -22, width: 80, height: 44)), with: .color(.white.opacity(0.6)), lineWidth: 3)
                context.fill(Path(ellipseIn: CGRect(x: -7, y: -10, width: 26, height: 20)), with: .color(canopy))
            default:
                var p = Path()
                p.move(to: CGPoint(x: -34, y: -12)); p.addQuadCurve(to: CGPoint(x: -24, y: -20), control: CGPoint(x: -34, y: -20))
                p.addLine(to: CGPoint(x: 18, y: -18)); p.addQuadCurve(to: CGPoint(x: 40, y: 0), control: CGPoint(x: 38, y: -14))
                p.addQuadCurve(to: CGPoint(x: 18, y: 18), control: CGPoint(x: 38, y: 14)); p.addLine(to: CGPoint(x: -24, y: 20))
                p.addQuadCurve(to: CGPoint(x: -34, y: 12), control: CGPoint(x: -34, y: 20)); p.closeSubpath()
                context.fill(p, with: .color(body))
                context.fill(Path(ellipseIn: CGRect(x: -10, y: -9, width: 24, height: 18)), with: .color(canopy))
            }
            if let second = Self.stripeColor(paint) { context.fill(rr(-30, -3, 64, 6, 3), with: .color(second)) }
            if car.shape != "hover" {
                context.fill(rr(33, -12, 7, 7, 3), with: .color(Color(hex: 0xFFE9A8)))
                context.fill(rr(33, 5, 7, 7, 3), with: .color(Color(hex: 0xFFE9A8)))
            }
        }
        .accessibilityLabel(car.name)
    }

    static func bodyColor(_ car: CarSpec, _ paint: String) -> Color {
        if let first = Cosmetics.item(paint)?.colors.first { return Color(hex: first) }
        return Color(hex: car.color)
    }

    static func stripeColor(_ paint: String) -> Color? {
        guard let colors = Cosmetics.item(paint)?.colors, colors.count > 1 else { return nil }
        return Color(hex: colors[1])
    }
}

/// A bar of five segments for racer stats.
struct StatBar: View {
    let label: String
    let value: Int
    var body: some View {
        HStack {
            Text(label).font(Theme.rounded(.footnote, .semibold)).foregroundStyle(Theme.muted).frame(width: 64, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3).fill(i < value ? Theme.text : Theme.raised).frame(height: 10)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) of 5")
    }
}

/// Quiet backdrop for the menus: deep colour with faint track curves (no animation, battery friendly).
struct MenuBackground: View {
    var tint: Color = Theme.accent
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [tint.opacity(0.22), .clear], center: .topTrailing, startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color(hex: 0x56B4E9).opacity(0.12), .clear], center: .bottomLeading, startRadius: 10, endRadius: 480)
            Canvas { context, size in
                for k in 0..<4 {
                    var p = Path()
                    let y0 = size.height * (0.2 + 0.2 * CGFloat(k))
                    p.move(to: CGPoint(x: -40, y: y0))
                    p.addCurve(to: CGPoint(x: size.width + 40, y: y0 - 120),
                               control1: CGPoint(x: size.width * 0.3, y: y0 + 140), control2: CGPoint(x: size.width * 0.7, y: y0 - 220))
                    context.stroke(p, with: .color(Theme.echo[k].opacity(0.07)), lineWidth: 26)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A link row used in footers and settings.
struct LinkRow: View {
    var body: some View {
        HStack(spacing: 16) {
            Link("Privacy", destination: AppLinks.privacy)
            Link("Terms", destination: AppLinks.terms)
            Link("Support", destination: AppLinks.support)
        }
        .font(Theme.rounded(.footnote, .semibold))
        .foregroundStyle(Theme.muted)
    }
}
