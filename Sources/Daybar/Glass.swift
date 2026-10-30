import SwiftUI

extension View {
    @ViewBuilder func daybarGlass(radius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.16), lineWidth: 0.5))
        }
    }
}

