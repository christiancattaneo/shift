import SwiftUI
import UIKit

// MARK: - Custom Text Input to fix keyboard constraint conflicts
struct CustomMessageInput: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let maxHeight: CGFloat
    
    init(text: Binding<String>, placeholder: String = "Type a message...", maxHeight: CGFloat = 100) {
        self._text = text
        self.placeholder = placeholder
        self.maxHeight = maxHeight
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // Configure text view
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.keyboardType = .default
        
        // CRITICAL: Disable input assistant view to avoid constraint conflicts
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        
        // Set delegate
        textView.delegate = context.coordinator
        
        // Add placeholder
        updatePlaceholder(textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            updatePlaceholder(uiView)
        }
        
        // Adjust height based on content
        let newHeight = min(maxHeight, max(44, uiView.contentSize.height))
        if uiView.frame.height != newHeight {
            DispatchQueue.main.async {
                uiView.invalidateIntrinsicContentSize()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updatePlaceholder(_ textView: UITextView) {
        if text.isEmpty {
            textView.text = placeholder
            textView.textColor = UIColor.placeholderText
        } else {
            textView.textColor = UIColor.label
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: CustomMessageInput
        
        init(_ parent: CustomMessageInput) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                parent.updatePlaceholder(textView)
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Only update if text actually changed
            let newText = textView.text == parent.placeholder ? "" : textView.text ?? ""
            if newText != parent.text {
                parent.text = newText
            }
            
            // Adjust height
            textView.invalidateIntrinsicContentSize()
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Allow all text changes
            return true
        }
    }
}

// MARK: - View Extension for Intrinsic Height
extension UITextView {
    override open var intrinsicContentSize: CGSize {
        let fixedWidth = frame.size.width
        let newSize = sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: fixedWidth, height: newSize.height)
    }
} 