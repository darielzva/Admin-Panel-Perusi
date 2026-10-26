import SwiftUI
import WebKit
import UIKit

/// Muestra el panel (admin.html) dentro de la app y conecta lo que un WebView no hace solo:
/// ventanas de alerta, copiar al portapapeles y guardar/compartir archivos.
struct AdminWebView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // El HTML habla con la app mediante window.webkit.messageHandlers.native
        config.userContentController.add(context.coordinator, name: "native")

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.alwaysBounceHorizontal = false
        web.uiDelegate = context.coordinator
        web.navigationDelegate = context.coordinator
        context.coordinator.webView = web
        context.coordinator.loadPanel()
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {

        weak var webView: WKWebView?

        /// baseURL https => la página corre en un contexto seguro (como una web normal):
        /// fetch a Supabase y el portapapeles funcionan sin problemas.
        func loadPanel() {
            guard let url = Bundle.main.url(forResource: "admin", withExtension: "html"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else { return }
            webView?.loadHTMLString(html, baseURL: URL(string: "https://admin.local"))
        }

        // MARK: Mensajes desde el HTML (copiar / guardar archivo)

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "copy":
                if let text = body["text"] as? String {
                    UIPasteboard.general.string = text
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            case "saveFile":
                if let filename = body["filename"] as? String,
                   let content = body["content"] as? String {
                    share(filename: filename, content: content)
                }
            default:
                break
            }
        }

        /// Abre la hoja de compartir de iOS (Guardar en Archivos, AirDrop, etc.)
        private func share(filename: String, content: String) {
            let safeName = filename
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)

            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                return
            }

            let sheet = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = sheet.popoverPresentationController, let web = webView {
                popover.sourceView = web
                popover.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            Self.topViewController()?.present(sheet, animated: true)
        }

        private static func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }

        /// Muestra la alerta; si no hay pantalla donde mostrarla, responde para no dejar el JS colgado.
        private func present(_ alert: UIAlertController, orElse fallback: () -> Void) {
            if let top = Self.topViewController() {
                top.present(alert, animated: true)
            } else {
                fallback()
            }
        }

        // MARK: Ventanas nativas de JavaScript (por si alguna quedara en el HTML)

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            present(alert, orElse: completionHandler)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in completionHandler(true) })
            present(alert, orElse: { completionHandler(false) })
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            present(alert, orElse: { completionHandler(nil) })
        }

        // MARK: Navegación

        /// Los enlaces externos se abren en Safari, no dentro del panel.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        /// Si iOS cierra el proceso web por falta de memoria, se vuelve a cargar el panel.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loadPanel()
        }
    }
}
