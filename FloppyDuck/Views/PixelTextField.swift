import SwiftUI
import UIKit

/// UIViewRepresentable wrapper that forces the pixel font on UITextField.
/// SwiftUI's TextField sometimes ignores .font(.custom(...)) for custom bitmap fonts.
struct PixelTextField: UIViewRepresentable {
    @Binding var text: String
    let pixelFontName: String
    let fontSize: CGFloat

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.font = UIFont(name: pixelFontName, size: fontSize)
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
