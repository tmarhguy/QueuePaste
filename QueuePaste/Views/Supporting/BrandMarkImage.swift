import SwiftUI

/// Raster brand mark from asset catalog (`BrandMark`) — matches the app icon artwork.
struct BrandMarkImage: View {
    var length: CGFloat = 28
    var cornerRadius: CGFloat = 7

    var body: some View {
        Image("BrandMark")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: length, height: length)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
