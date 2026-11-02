import SwiftUI

public struct GlassProbe: View {
    public let label: String
    public init(label: String) { self.label = label }
    public var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 18) {
                Text("DAY + SwiftUI").font(.title.bold())
                Text(label)
                Button("Liquid Glass nativo") {}.buttonStyle(.glass)
                Text("Vista SwiftUI compilada mediante day-piece-swiftui")
                    .font(.caption)
            }.padding(28).glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }
}
