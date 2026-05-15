import SwiftUI
import AppKit

public struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor = .labelColor
    var isReadOnly: Bool = false
    
    public init(text: Binding<String>, font: NSFont, textColor: NSColor = .labelColor, isReadOnly: Bool = false) {
        self._text = text
        self.font = font
        self.textColor = textColor
        self.isReadOnly = isReadOnly
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        
        // Configure behavior based on isReadOnly
        textView.isEditable = !isReadOnly
        textView.isSelectable = true // Always allow selection
        
        // Use standard text container settings
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 5
        
        scrollView.documentView = textView
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = font
        textView.textColor = textColor
        textView.isEditable = !isReadOnly
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        init(_ parent: NativeTextEditor) { self.parent = parent }
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

extension NSFont {
    public func rounded() -> NSFont? {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return nil }
        return NSFont(descriptor: descriptor, size: pointSize)
    }
}
