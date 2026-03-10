import SwiftUI
import UIKit

/// UIViewRepresentable wrapper that forces the pixel font on UITextField.
/// SwiftUI's TextField sometimes ignores .font(.custom(...)) for custom bitmap fonts.
struct PixelTextField: UIViewRepresentable {
    @Binding var text: String
    let pixelFontName: String
    let fontSize: CGFloat

    /// Resolve the correct UIFont, trying common PostScript name variants.
    private static func resolveFont(name: String, size: CGFloat) -> UIFont {
        // Try the exact name first
        if let font = UIFont(name: name, size: size) { return font }
        // Try without the style suffix (e.g., "PressStart2P-Regular" → "PressStart2P")
        let base = name.components(separatedBy: "-").first ?? name
        if let font = UIFont(name: base, size: size) { return font }
        // Try with spaces (e.g., "Press Start 2P")
        let spaced = base.replacingOccurrences(
            of: "(?<=[a-z])(?=[A-Z0-9])",
            with: " ",
            options: .regularExpression
        )
        if let font = UIFont(name: spaced, size: size) { return font }
        // Fallback: scan registered fonts for a partial match
        for family in UIFont.familyNames {
            for fontName in UIFont.fontNames(forFamilyName: family) {
                if fontName.lowercased().contains("pressstart") || fontName.lowercased().contains("press start") {
                    if let font = UIFont(name: fontName, size: size) { return font }
                }
            }
        }
        return UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.font = Self.resolveFont(name: pixelFontName, size: fontSize)
        tf.textColor = UIColor(GK.Colors.panelBorder)
        tf.borderStyle = .none
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .words
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.text = text
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if tf.text != text {
            tf.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        func textFieldDidChangeSelection(_ tf: UITextField) {
            DispatchQueue.main.async {
                self.text = tf.text ?? ""
            }
        }

        func textFieldShouldReturn(_ tf: UITextField) -> Bool {
            tf.resignFirstResponder()
            return true
        }
    }
}
