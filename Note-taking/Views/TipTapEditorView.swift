import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit

struct TipTapEditorView: UIViewRepresentable {
    /// Always reflects the latest HTML from TipTap (updated on every keystroke)
    @Binding var html: String
    /// Called once when the WKWebView is ready — parent stores it for JS commands & export
    var onWebViewReady: ((WKWebView) -> Void)?

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: TipTapEditorView
        var webView: WKWebView?
        private var isLoaded = false
        private var initialContentSet = false

        init(_ parent: TipTapEditorView) {
            self.parent = parent
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "contentChanged":
                if let html = message.body as? String {
                    DispatchQueue.main.async { self.parent.html = html }
                }
            case "editorReady":
                isLoaded = true
                if !initialContentSet {
                    setInitialContent()
                }
            default:
                break
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // editorReady message fires from JS once TipTap initialises
        }

        // MARK: Helpers

        func setInitialContent() {
            guard let webView, isLoaded, !initialContentSet else { return }
            initialContentSet = true
            let html = parent.html
            guard !html.isEmpty else { return }
            if let data = try? JSONEncoder().encode(html),
               let json = String(data: data, encoding: .utf8) {
                webView.evaluateJavaScript("setContent(\(json))") { _, _ in }
            }
        }

        func flushContent(completion: @escaping (String) -> Void) {
            webView?.evaluateJavaScript("getContent()") { result, _ in
                completion((result as? String) ?? self.parent.html)
            }
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "contentChanged")
        controller.add(context.coordinator, name: "editorReady")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.webView = webView

        if let path = Bundle.main.path(forResource: "editor", ofType: "html"),
           let htmlString = try? String(contentsOfFile: path, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: URL(string: "https://local.app"))
        }

        DispatchQueue.main.async {
            self.onWebViewReady?(webView)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.setInitialContent()
    }
}
#endif
