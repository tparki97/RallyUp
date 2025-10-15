import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let text: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let ui = makeQR(from: text) {
            Image(uiImage: ui)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Color.gray.opacity(0.1)
        }
    }

    private func makeQR(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Scale up for clarity
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgimg)
        }
        return nil
    }
}
