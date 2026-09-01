import SwiftUI

struct TreemapView: View {
    let nodes: [FSNode]
    let onTap: (FSNode) -> Void

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let layout = TreemapLayout.squarify(nodes: nodes, in: rect)
            ZStack(alignment: .topLeading) {
                ForEach(layout, id: \.node.id) { item in
                    TreemapCell(node: item.node, rect: item.rect)
                        .position(x: item.rect.midX, y: item.rect.midY)
                        .onTapGesture {
                            onTap(item.node)
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
