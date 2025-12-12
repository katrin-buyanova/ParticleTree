//
//  ContentView.swift
//  ParticleTree
//
//  Created by Katerina Buyanova on 09/12/2025.
//

import SwiftUI

struct ParticleTreeView: View {
    @State private var glowProgress: Double = 0
    @State private var isGlowing: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: [
                        .black,
                        Color(red: 0.02, green: 0.06, blue: 0.12)
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: max(geo.size.width, geo.size.height)
                )
                .ignoresSafeArea()
                let floorWidth = min(geo.size.width * 0.75, 330.0)

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.9),
                                Color.black.opacity(1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: floorWidth, height: floorWidth * 0.23)
                    .blur(radius: 32)
                    .position(
                        x: geo.size.width / 2,
                        y: geo.size.height * 0.83
                    )
                TimelineView(.animation) { timeline in
                    BinaryTreeStaticLayer(
                        glowProgress: glowProgress,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
                TimelineView(.animation) { timeline in
                    SnowLayer(time: timeline.date.timeIntervalSinceReferenceDate)
                }
                VStack {
                    Spacer()
                    Text("Tap to glow")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 24)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isGlowing.toggle()
                withAnimation(.easeInOut(duration: 1.2)) {
                    glowProgress = isGlowing ? 1 : 0
                }
            }
        }
    }
}

struct BinaryTreeStaticLayer: View {
    let glowProgress: Double
    let time: TimeInterval

    var body: some View {
        Canvas { ctx, size in
            draw(ctx: ctx, size: size)
        }
        .ignoresSafeArea()
        .drawingGroup()
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        let treeHeight = min(h * 0.60, w * 1.05)
        let topY = (h - treeHeight) / 2
        _ = topY + treeHeight
        let centerX = w / 2

        let rows = 26
        let baseJitter: CGFloat = 6

        let p = max(0, min(glowProgress, 1))

        for row in 0..<rows {
            let tRow = CGFloat(row) / CGFloat(rows - 1)
            let y = topY + tRow * treeHeight

            let widthProfile = tRow
            let rowWidth = w * 0.60 * widthProfile

            let bitsForRow: Int
            if row <= 1 {
                bitsForRow = 1
            } else if row == 2 {
                bitsForRow = 2
            } else if row == 3 {
                bitsForRow = 3
            } else {

                let t = Double(row - 3) / Double(rows - 4)   // 0…1
                let minBits = 4.0
                let maxBits = 18.0
                bitsForRow = Int(round(minBits + t * (maxBits - minBits)))
            }

            let jitter = baseJitter + 6 * tRow   // внизу чуть больше хаоса

            for col in 0..<bitsForRow {
                let colNorm: CGFloat
                if bitsForRow == 1 {
                    colNorm = 0.5
                } else {
                    colNorm = CGFloat(col) / CGFloat(bitsForRow - 1)   // 0…1
                }

                let baseX = centerX + (colNorm - 0.5) * rowWidth

                // Случайное смещение, чтобы не было сетки
                let seed = Double(row * 10_000 + col)
                let jx = (sin(seed * 12.98) * 0.5 + 0.5) * Double(jitter) - Double(jitter) / 2
                let jy = (sin(seed * 33.21) * 0.5 + 0.5) * Double(jitter) - Double(jitter) / 2

                let pos = CGPoint(
                    x: baseX + CGFloat(jx),
                    y: y + CGFloat(jy * 0.7)
                )

                drawBit(ctx: ctx, pos: pos, seed: seed, progress: p, time: time)
            }
        }
    }

    // Отрисовка битов и огоньков
    private func drawBit(
        ctx: GraphicsContext,
        pos: CGPoint,
        seed: Double,
        progress p: Double,
        time: Double
    ) {

        let r1 = fract(sin(seed * 1.2345) * 99999.123)
        let _  = fract(sin(seed * 5.6789) * 54321.987)      // r2 — можно игнорировать
        let r3 = fract(sin(seed * 9.4321) * 34567.654)      // для огоньков
        let rBlink = fract(sin(seed * 7.7777) * 123456)     // для мигания

        let bit = r1 > 0.5 ? "1" : "0"

        // Базовый цвет
        let grey = Color.gray.opacity(0.55)
        let neon = Color(red: 0.22, green: 1.0, blue: 0.50)

        // Фликер
        let flick = (sin(time * (1.3 + rBlink * 1.4) + seed) + 1) / 2    // 0..1
        let brightness = (1 - p) * 0.25 + p * (0.3 + flick * 0.7)

        let bitColor = grey
            .mix(with: neon, amount: p)
            .opacity(brightness)

        // --- Огоньки (жёлтые) — оставляем как есть ---
        if r3 > 0.88 && p > 0.05 {
            let lampFlick = (sin(time * (3.0 + r3 * 5.0)) + 1) / 2
            let lampOpacity = 0.4 + lampFlick * 0.6
            let size: CGFloat = 5 + lampFlick * 4

            let lampRect = CGRect(
                x: pos.x - size / 2,
                y: pos.y - size / 2,
                width: size,
                height: size
            )

            ctx.fill(
                Path(ellipseIn: lampRect),
                with: .color(Color.yellow.opacity(lampOpacity))
            )
        }

        // Отрисовка цифры
        let text = Text(bit)
            .font(.system(size: 15, weight: .medium, design: .monospaced))
            .foregroundColor(bitColor)

        ctx.draw(ctx.resolve(text), at: pos)
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }
}

//
// MARK: ------------------------------------------------------------
// MARK: СНЕГ
// MARK: ------------------------------------------------------------
//

struct SnowLayer: View {
    let time: TimeInterval

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let count = 140

            for i in 0..<count {
                let fi = Double(i)

                let r1 = fract(sin(fi * 12.3456) * 54321.987)
                let r2 = fract(sin(fi * 98.7654) * 12345.678)

                let x = CGFloat(r1) * w + CGFloat(sin(time * 0.5 + fi) * 10)
                var y = CGFloat(time * (14 + 18 * r2))
                    .truncatingRemainder(dividingBy: h + 40)
                y -= 20

                let radius = 1 + CGFloat(r2) * 2.3
                let alpha = 0.18 + 0.32 * (1 - CGFloat(r2))

                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }
}

// MARK: ------------------------------------------------------------
// MARK: Color blending helper
// ------------------------------------------------------------

extension Color {
    func mix(with other: Color, amount t: Double) -> Color {
        let t = max(0, min(t, 1))

        let c1 = UIColor(self)
        let c2 = UIColor(other)

        var r1: CGFloat = 0; var g1: CGFloat = 0; var b1: CGFloat = 0; var a1: CGFloat = 0
        var r2: CGFloat = 0; var g2: CGFloat = 0; var b2: CGFloat = 0; var a2: CGFloat = 0

        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t),
            opacity: Double(a1 + (a2 - a1) * t)
        )
    }
}
