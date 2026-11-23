import NotchpadCore
import SwiftUI

/// One tab's widgets on the 3-column grid.
struct WidgetGridView: View {
    static let gap: CGFloat = 10
    let page: TabPage
    let inputs: WidgetInputs

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if page.widgets.isEmpty {
                    Text("Right-click → Edit widgets to add some")
                        .font(.system(size: 12)).foregroundStyle(Color(white: 0.45))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                ForEach(page.widgets) { w in
                    let frame = WidgetGrid.frame(size: w.size, column: w.column, half: w.half, in: geo.size, gap: Self.gap)
                    WidgetView(kind: w.kind, size: w.size, inputs: inputs)
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
        }
    }
}
