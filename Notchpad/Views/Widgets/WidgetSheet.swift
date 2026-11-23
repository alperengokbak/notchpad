import NotchpadCore
import SwiftUI

/// `--widget-sheet <png>`: every widget at every size, on demo data, at its real size in the panel.
struct WidgetSheet: View {
    static let area = CGSize(width: 636, height: 146)
    let inputs: WidgetInputs

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(WidgetKind.allCases, id: \.self) { kind in
                HStack(alignment: .top, spacing: 18) {
                    ForEach(kind.sizes, id: \.self) { size in
                        let frame = WidgetGrid.frame(size: size, column: 0, half: size == .small ? .top : .full,
                                                     in: Self.area, gap: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(kind.title) · \(size.title)").font(.system(size: 10)).foregroundStyle(Color(white: 0.5))
                            WidgetView(kind: kind, size: size, inputs: inputs)
                                .frame(width: frame.width, height: frame.height)
                                .overlay(Rectangle().strokeBorder(Color(white: 0.2), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(Color.black)
    }
}
