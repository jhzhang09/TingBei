import SwiftUI

// MARK: - 汉印篆白文朱砂印（App 与灵动岛小组件共享）

/// 汉印缪篆笔画：按方折篆法手绘为折线，单位坐标 0…1、原点左上。
/// 与 scripts/seal.py 的 GLYPHS 是同一份数据，改字形时两边同步。
enum SealGlyphs {
    static let strokes: [Character: [[CGPoint]]] = [
        // 停：亻 + 亭（亠、口、冂中含丁）
        "停": [
            [p(0.12, 0.96), p(0.12, 0.24), p(0.27, 0.04)],
            [p(0.66, 0.03), p(0.66, 0.14)],
            [p(0.38, 0.14), p(0.97, 0.14)],
            [p(0.50, 0.25), p(0.83, 0.25), p(0.83, 0.39), p(0.50, 0.39), p(0.50, 0.25)],
            [p(0.38, 0.96), p(0.38, 0.50), p(0.97, 0.50), p(0.97, 0.96)],
            [p(0.52, 0.65), p(0.83, 0.65)],
            [p(0.67, 0.65), p(0.67, 0.92), p(0.57, 0.92)],
        ],
        // 当（當）：尚 + 田
        "当": [
            [p(0.50, 0.03), p(0.50, 0.17)],
            [p(0.24, 0.05), p(0.24, 0.17)],
            [p(0.76, 0.05), p(0.76, 0.17)],
            [p(0.06, 0.49), p(0.06, 0.21), p(0.94, 0.21), p(0.94, 0.49)],
            [p(0.34, 0.30), p(0.66, 0.30), p(0.66, 0.42), p(0.34, 0.42), p(0.34, 0.30)],
            [p(0.06, 0.56), p(0.94, 0.56), p(0.94, 0.96), p(0.06, 0.96), p(0.06, 0.56)],
            [p(0.06, 0.76), p(0.94, 0.76)],
            [p(0.50, 0.56), p(0.50, 0.96)],
        ],
        // 止：中竖贯通，左短竖，右枝上折，底横
        "止": [
            [p(0.50, 0.04), p(0.50, 0.94)],
            [p(0.14, 0.44), p(0.14, 0.94)],
            [p(0.50, 0.42), p(0.86, 0.42), p(0.86, 0.14)],
            [p(0.04, 0.94), p(0.96, 0.94)],
        ],
        // 杯：木 + 不
        "杯": [
            [p(0.21, 0.04), p(0.21, 0.96)],
            [p(0.03, 0.10), p(0.03, 0.30), p(0.39, 0.30), p(0.39, 0.10)],
            [p(0.03, 0.78), p(0.03, 0.56), p(0.39, 0.56), p(0.39, 0.78)],
            [p(0.50, 0.08), p(0.97, 0.08)],
            [p(0.735, 0.08), p(0.735, 0.96)],
            [p(0.735, 0.34), p(0.55, 0.34), p(0.55, 0.78)],
            [p(0.735, 0.34), p(0.92, 0.34), p(0.92, 0.78)],
        ],
    ]

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// 单字占满印面；两字按传统印式自右向左分作两列（首字在右）。单位坐标。
    static func cells(count: Int) -> [CGRect] {
        guard count > 1 else { return [CGRect(x: 0, y: 0, width: 1, height: 1)] }
        let gap: CGFloat = 0.08
        let w = (1 - gap) / 2
        return [CGRect(x: w + gap, y: 0, width: w, height: 1), CGRect(x: 0, y: 0, width: w, height: 1)]
    }
}

/// 固定种子的伪随机数：同一方印每次绘制的斑驳都一样，不会随重绘闪动。
private struct SealRandom {
    private var state: UInt64

    init(seed: String) {
        state = seed.unicodeScalars.reduce(0x9E37_79B9_7F4A_7C15) { ($0 ^ UInt64($1.value)) &* 0x100_0000_01B3 }
    }

    mutating func next(_ range: ClosedRange<CGFloat>) -> CGFloat {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = CGFloat(state >> 11) / CGFloat(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}

/// 印面：边缘略有起伏的方形
private struct SealFace: Shape {
    let seed: String

    func path(in rect: CGRect) -> Path {
        var rnd = SealRandom(seed: seed + "face")
        let s = min(rect.width, rect.height)
        let m = s * 0.015
        let jitter = s * 0.008
        let n = 16
        var pts: [CGPoint] = []
        for side in 0..<4 {
            for i in 0..<n {
                let t = CGFloat(i) / CGFloat(n)
                let j = rnd.next(-jitter...jitter)
                let along = m + t * (s - 2 * m)
                switch side {
                case 0: pts.append(CGPoint(x: along, y: m + j))
                case 1: pts.append(CGPoint(x: s - m + j, y: along))
                case 2: pts.append(CGPoint(x: s - along, y: s - m + j))
                default: pts.append(CGPoint(x: m + j, y: s - along))
                }
            }
        }
        var path = Path()
        path.addLines(pts)
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// 刻字笔画：顶点略作抖动，模拟手刻刀口
private struct SealStrokes: Shape {
    let text: String

    func path(in rect: CGRect) -> Path {
        var rnd = SealRandom(seed: text + "strokes")
        let s = min(rect.width, rect.height)
        let border = s * 0.11
        let inner = s - 2 * border
        let jitter = s * 0.005
        let chars = Array(text)
        var path = Path()
        for (ch, cell) in zip(chars, SealGlyphs.cells(count: chars.count)) {
            for line in SealGlyphs.strokes[ch] ?? [] {
                let pts = line.map { pt in
                    CGPoint(
                        x: rect.minX + border + (cell.minX + pt.x * cell.width) * inner + rnd.next(-jitter...jitter),
                        y: rect.minY + border + (cell.minY + pt.y * cell.height) * inner + rnd.next(-jitter...jitter)
                    )
                }
                path.addLines(pts)
            }
        }
        return path
    }
}

/// 斑驳：印面内的散点漏白（rim 为 false），或沿边栏的崩口（rim 为 true）
private struct SealSpecks: Shape {
    let seed: String
    let rim: Bool

    func path(in rect: CGRect) -> Path {
        var rnd = SealRandom(seed: seed + (rim ? "rim" : "specks"))
        let s = min(rect.width, rect.height)
        var path = Path()
        if rim {
            for _ in 0..<18 {
                let side = Int(rnd.next(0...3.999))
                let along = rnd.next(0...s)
                let depth = rnd.next(-0.004...0.02) * s
                let center: CGPoint
                switch side {
                case 0: center = CGPoint(x: along, y: depth)
                case 1: center = CGPoint(x: s - depth, y: along)
                case 2: center = CGPoint(x: along, y: s - depth)
                default: center = CGPoint(x: depth, y: along)
                }
                let rx = rnd.next(0.012...0.04) * s
                let ry = rnd.next(0.01...0.03) * s
                path.addEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
            }
        } else {
            for _ in 0..<46 {
                let r = rnd.next(0.003...0.011) * s
                let x = rnd.next(0.05...0.95) * s
                let y = rnd.next(0.05...0.95) * s
                path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.6))
            }
        }
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// 白文朱砂方印：朱底、字口与漏白处透出纸色，边栏有崩口，印泥略有浓淡。
/// 一字占满印面，两字自右向左分两列。尺寸由外部 frame 决定（取宽高较小者）。
struct CarvedSeal: View {
    let text: String
    let color: Color
    /// 字口透出的纸色
    var paper: Color = Color(red: 0.945, green: 0.918, blue: 0.871)
    var tilt: Double = -8

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let strokeWidth = s * (text.count > 1 ? 0.052 : 0.072)
            ZStack {
                SealFace(seed: text).fill(paper)
                ZStack {
                    SealFace(seed: text).fill(color)
                    // 印泥浓淡：右下按压略轻
                    SealFace(seed: text).fill(
                        RadialGradient(colors: [.clear, paper.opacity(0.16)],
                                       center: .topLeading, startRadius: s * 0.4, endRadius: s * 1.3)
                    )
                    SealStrokes(text: text)
                        .stroke(.black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .square, lineJoin: .miter))
                        .blendMode(.destinationOut)
                    SealSpecks(seed: text, rim: false).fill(.black).blendMode(.destinationOut)
                }
                .compositingGroup()
                SealSpecks(seed: text, rim: true).fill(.black).blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: s, height: s)
            .rotationEffect(.degrees(tilt))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
