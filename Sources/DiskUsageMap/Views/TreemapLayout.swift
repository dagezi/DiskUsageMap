import Foundation
import CoreGraphics

struct TreemapItem {
    let node: FSNode
    let rect: CGRect
}

/// Squarified treemap layout (Bruls, Huizing, van Wijk 2000).
/// Lays out nodes so rectangles stay close to square, which keeps small
/// items readable instead of degenerating into thin slivers.
enum TreemapLayout {
    static func squarify(nodes: [FSNode], in rect: CGRect, minSize: CGFloat = 1) -> [TreemapItem] {
        let positiveNodes = nodes.filter { $0.size > 0 }
        guard !positiveNodes.isEmpty, rect.width > minSize, rect.height > minSize else { return [] }

        let total = positiveNodes.reduce(Int64(0)) { $0 + $1.size }
        guard total > 0 else { return [] }

        let area = Double(rect.width) * Double(rect.height)
        let scale = area / Double(total)

        var result: [TreemapItem] = []
        var remaining = positiveNodes.map { (node: $0, area: Double($0.size) * scale) }
        var currentRect = rect

        while !remaining.isEmpty {
            let shorterSide = Double(min(currentRect.width, currentRect.height))
            var row = [remaining[0]]
            var bestWorst = worstRatio(areas: row.map(\.area), side: shorterSide)

            var i = 1
            while i < remaining.count {
                let candidate = row + [remaining[i]]
                let candidateWorst = worstRatio(areas: candidate.map(\.area), side: shorterSide)
                if candidateWorst <= bestWorst {
                    row = candidate
                    bestWorst = candidateWorst
                    i += 1
                } else {
                    break
                }
            }

            let (laidOut, newRect) = layoutRow(row: row, rect: currentRect)
            result.append(contentsOf: laidOut)
            currentRect = newRect
            remaining.removeFirst(row.count)
        }

        return result
    }

    private static func worstRatio(areas: [Double], side: Double) -> Double {
        guard side > 0 else { return .infinity }
        let sum = areas.reduce(0, +)
        guard sum > 0 else { return .infinity }
        let thickness = sum / side
        guard thickness > 0 else { return .infinity }
        var worst = 0.0
        for a in areas {
            let length = a / thickness
            let ratio = max(thickness / length, length / thickness)
            worst = max(worst, ratio)
        }
        return worst
    }

    private static func layoutRow(row: [(node: FSNode, area: Double)], rect: CGRect) -> ([TreemapItem], CGRect) {
        let sum = row.reduce(0.0) { $0 + $1.area }
        let horizontal = rect.width >= rect.height

        if horizontal {
            let columnWidth = CGFloat(sum / Double(rect.height))
            var y = rect.minY
            let items: [TreemapItem] = row.map { entry in
                let h = CGFloat(entry.area) / max(columnWidth, 0.0001)
                let itemRect = CGRect(x: rect.minX, y: y, width: columnWidth, height: h)
                y += h
                return TreemapItem(node: entry.node, rect: itemRect)
            }
            let remainingRect = CGRect(
                x: rect.minX + columnWidth, y: rect.minY,
                width: max(0, rect.width - columnWidth), height: rect.height
            )
            return (items, remainingRect)
        } else {
            let rowHeight = CGFloat(sum / Double(rect.width))
            var x = rect.minX
            let items: [TreemapItem] = row.map { entry in
                let w = CGFloat(entry.area) / max(rowHeight, 0.0001)
                let itemRect = CGRect(x: x, y: rect.minY, width: w, height: rowHeight)
                x += w
                return TreemapItem(node: entry.node, rect: itemRect)
            }
            let remainingRect = CGRect(
                x: rect.minX, y: rect.minY + rowHeight,
                width: rect.width, height: max(0, rect.height - rowHeight)
            )
            return (items, remainingRect)
        }
    }
}
