import Foundation
import CoreGraphics

/// SVG <path d="..."> is its own tiny drawing language.
///
/// Example: M 10 10 L 100 10 L 100 100 Z
/// M = move, L = line, Z = close path.
///
/// Real SVG files also contain curves and elliptical arcs. The supplied files
/// use M/L/H/V/C/S/Q/A plus lowercase relative versions, so this parser covers
/// those commands. The output is a native CGPath that CAShapeLayer can render
/// and hit-test.
final class SVGPathParser {
    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    func makePath(from d: String) -> CGPath? {
        let tokens = tokenize(d)
        guard !tokens.isEmpty else { return nil }

        let path = CGMutablePath()
        var i = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?
        var lastQuadControl: CGPoint?

        func hasNumber() -> Bool {
            guard i < tokens.count else { return false }
            if case .number = tokens[i] { return true }
            return false
        }

        func takeNumber() -> CGFloat? {
            guard i < tokens.count else { return nil }
            if case .number(let value) = tokens[i] {
                i += 1
                return value
            }
            return nil
        }

        func point(_ x: CGFloat, _ y: CGFloat, relative: Bool) -> CGPoint {
            relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            if case .command(let c) = tokens[i] {
                command = c
                i += 1
            }

            let relative = command.isLowercase
            switch command.uppercased() {
            case "M":
                guard let x = takeNumber(), let y = takeNumber() else { continue }
                current = point(x, y, relative: relative)
                path.move(to: current)
                subpathStart = current
                lastCubicControl = nil
                lastQuadControl = nil

                // SVG rule: extra coordinate pairs after M/m behave like L/l.
                while hasNumber() {
                    guard let x = takeNumber(), let y = takeNumber() else { break }
                    current = point(x, y, relative: relative)
                    path.addLine(to: current)
                }

            case "L":
                while hasNumber() {
                    guard let x = takeNumber(), let y = takeNumber() else { break }
                    current = point(x, y, relative: relative)
                    path.addLine(to: current)
                }
                lastCubicControl = nil; lastQuadControl = nil

            case "H":
                while hasNumber() {
                    guard let x = takeNumber() else { break }
                    current.x = relative ? current.x + x : x
                    path.addLine(to: current)
                }
                lastCubicControl = nil; lastQuadControl = nil

            case "V":
                while hasNumber() {
                    guard let y = takeNumber() else { break }
                    current.y = relative ? current.y + y : y
                    path.addLine(to: current)
                }
                lastCubicControl = nil; lastQuadControl = nil

            case "C":
                while hasNumber() {
                    guard let x1 = takeNumber(), let y1 = takeNumber(),
                          let x2 = takeNumber(), let y2 = takeNumber(),
                          let x = takeNumber(), let y = takeNumber() else { break }
                    let c1 = point(x1, y1, relative: relative)
                    let c2 = point(x2, y2, relative: relative)
                    let end = point(x, y, relative: relative)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    current = end
                    lastCubicControl = c2
                    lastQuadControl = nil
                }

            case "S":
                while hasNumber() {
                    guard let x2 = takeNumber(), let y2 = takeNumber(),
                          let x = takeNumber(), let y = takeNumber() else { break }
                    let c1: CGPoint
                    if let previous = lastCubicControl {
                        c1 = CGPoint(x: 2 * current.x - previous.x,
                                     y: 2 * current.y - previous.y)
                    } else {
                        c1 = current
                    }
                    let c2 = point(x2, y2, relative: relative)
                    let end = point(x, y, relative: relative)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    current = end
                    lastCubicControl = c2
                    lastQuadControl = nil
                }

            case "Q":
                while hasNumber() {
                    guard let x1 = takeNumber(), let y1 = takeNumber(),
                          let x = takeNumber(), let y = takeNumber() else { break }
                    let c = point(x1, y1, relative: relative)
                    let end = point(x, y, relative: relative)
                    path.addQuadCurve(to: end, control: c)
                    current = end
                    lastQuadControl = c
                    lastCubicControl = nil
                }

            case "T":
                while hasNumber() {
                    guard let x = takeNumber(), let y = takeNumber() else { break }
                    let c: CGPoint
                    if let previous = lastQuadControl {
                        c = CGPoint(x: 2 * current.x - previous.x,
                                    y: 2 * current.y - previous.y)
                    } else {
                        c = current
                    }
                    let end = point(x, y, relative: relative)
                    path.addQuadCurve(to: end, control: c)
                    current = end
                    lastQuadControl = c
                    lastCubicControl = nil
                }

            case "A":
                while hasNumber() {
                    guard let rx = takeNumber(), let ry = takeNumber(),
                          let angle = takeNumber(), let largeArc = takeNumber(),
                          let sweep = takeNumber(), let x = takeNumber(), let y = takeNumber() else { break }
                    let end = point(x, y, relative: relative)
                    addArc(to: path, from: current, to: end,
                           rx: abs(rx), ry: abs(ry),
                           xAxisRotationDegrees: angle,
                           largeArc: largeArc != 0,
                           sweep: sweep != 0)
                    current = end
                    lastCubicControl = nil; lastQuadControl = nil
                }

            case "Z":
                path.closeSubpath()
                current = subpathStart
                lastCubicControl = nil; lastQuadControl = nil

            default:
                // Unknown command: advance once so malformed data cannot lock us
                // in an infinite loop.
                if i < tokens.count { i += 1 }
            }
        }

        return path
    }

    // MARK: Tokenization

    private func tokenize(_ d: String) -> [Token] {
        let pattern = #"[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(d.startIndex..<d.endIndex, in: d)

        return regex.matches(in: d, range: range).compactMap { match in
            guard let r = Range(match.range, in: d) else { return nil }
            let raw = String(d[r])
            if raw.count == 1, let c = raw.first, c.isLetter { return .command(c) }
            return Double(raw).map { .number(CGFloat($0)) }
        }
    }

    // MARK: SVG elliptical arc -> cubic Bezier curves

    /// Core Graphics does not directly understand SVG endpoint-arc syntax.
    /// We convert SVG's A/a command into one or more cubic Bezier segments using
    /// the algorithm described by the SVG specification.
    private func addArc(to path: CGMutablePath,
                        from p0: CGPoint,
                        to p1: CGPoint,
                        rx initialRX: CGFloat,
                        ry initialRY: CGFloat,
                        xAxisRotationDegrees phiDegrees: CGFloat,
                        largeArc: Bool,
                        sweep: Bool) {
        guard initialRX > 0, initialRY > 0, p0 != p1 else {
            path.addLine(to: p1)
            return
        }

        let phi = phiDegrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        var rx = initialRX, ry = initialRY

        // Transform the two endpoints into the ellipse's local coordinate space.
        let dx = (p0.x - p1.x) / 2
        let dy = (p0.y - p1.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // SVG allows radii that are too small; scale them up when necessary.
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let factor = sqrt(lambda)
            rx *= factor; ry *= factor
        }

        let rx2 = rx * rx, ry2 = ry * ry
        let x1p2 = x1p * x1p, y1p2 = y1p * y1p
        let numerator = max(0, rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2)
        let denominator = rx2 * y1p2 + ry2 * x1p2
        var coef = denominator == 0 ? 0 : sqrt(numerator / denominator)
        if largeArc == sweep { coef = -coef }

        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * (-ry * x1p / rx)

        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2

        func vectorAngle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            guard len > 0 else { return 0 }
            let clamped = max(-1, min(1, dot / len))
            var angle = acos(clamped)
            if ux * vy - uy * vx < 0 { angle = -angle }
            return angle
        }

        let ux = (x1p - cxp) / rx
        let uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx
        let vy = (-y1p - cyp) / ry

        var theta1 = vectorAngle(1, 0, ux, uy)
        var delta = vectorAngle(ux, uy, vx, vy)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        // Use at most 90° per cubic segment for a good approximation.
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)

        func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: cx + cosPhi * rx * x - sinPhi * ry * y,
                    y: cy + sinPhi * rx * x + cosPhi * ry * y)
        }

        for _ in 0..<segments {
            let theta2 = theta1 + step
            let t = (4.0 / 3.0) * tan((theta2 - theta1) / 4.0)

            let cos1 = cos(theta1), sin1 = sin(theta1)
            let cos2 = cos(theta2), sin2 = sin(theta2)

            let c1 = map(cos1 - t * sin1, sin1 + t * cos1)
            let c2 = map(cos2 + t * sin2, sin2 - t * cos2)
            let end = map(cos2, sin2)
            path.addCurve(to: end, control1: c1, control2: c2)
            theta1 = theta2
        }
    }
}
