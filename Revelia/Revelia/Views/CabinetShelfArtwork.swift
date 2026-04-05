import SwiftUI

struct CabinetShelfArtwork: View {
    var width: CGFloat
    var tint: Color
    var highlightOpacity: Double = 0.16
    var shadowOpacity: Double = 0.26

    private var shelfHeight: CGFloat {
        max(28, width * 0.16)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(shadowOpacity))
                .frame(width: width * 0.88, height: max(16, shelfHeight * 0.72))
                .blur(radius: width * 0.03)
                .offset(y: shelfHeight * 0.55)

            Image("WoodenShelf")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: shelfHeight)
                .clipped()
                .shadow(color: Color.black.opacity(0.24), radius: width * 0.025, x: 0, y: width * 0.015)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(highlightOpacity),
                                    tint.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width * 0.78, height: max(5, shelfHeight * 0.16))
                        .blur(radius: width * 0.012)
                        .offset(y: shelfHeight * 0.06)
                }
        }
        .frame(width: width, height: shelfHeight + shelfHeight * 0.62, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
