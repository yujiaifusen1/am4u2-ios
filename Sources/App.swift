import SwiftUI
import WebKit

// 要打包的网站地址，改这里就能换站点
let kHomeURL = URL(string: "https://am-4u2.pages.dev/")!

@main
struct WrapperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea(edges: .bottom)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var statusText: String = "正在加载…"
    @State private var showStatus: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            WebContainer(statusText: $statusText, showStatus: $showStatus)

            if showStatus {
                Text(statusText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(8)
                    .padding(.top, 50)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct WebContainer: UIViewRepresentable {
    @Binding var statusText: String
    @Binding var showStatus: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(statusText: $statusText, showStatus: $showStatus)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        let refresh = UIRefreshControl()
        refresh.tintColor = .white
        refresh.addTarget(context.coordinator,
                          action: #selector(Coordinator.reload(_:)),
                          for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        context.coordinator.webView = webView

        webView.load(URLRequest(url: kHomeURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if context.coordinator.isLoading {
                statusText = "加载超过 10 秒仍未完成\n可能是网络较慢或页面被拦截"
            }
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        var isLoading = true
        @Binding var statusText: String
        @Binding var showStatus: Bool

        init(statusText: Binding<String>, showStatus: Binding<Bool>) {
            _statusText = statusText
            _showStatus = showStatus
        }

        @objc func reload(_ sender: UIRefreshControl) {
            isLoading = true
            statusText = "正在加载…"
            showStatus = true
            webView?.reload()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            webView.scrollView.refreshControl?.endRefreshing()
            statusText = "加载完成"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.showStatus = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            webView.scrollView.refreshControl?.endRefreshing()
            showStatus = true
            let nsError = error as NSError
            statusText = "加载失败：\n\(nsError.localizedDescription)\n(code \(nsError.code))"
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            webView.scrollView.refreshControl?.endRefreshing()
            showStatus = true
            let nsError = error as NSError
            statusText = "无法打开页面：\n\(nsError.localizedDescription)\n(domain: \(nsError.domain), code \(nsError.code))"
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https", scheme != "about" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            present(message: message, actions: [("好", completionHandler)])
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            present(message: message, actions: [
                ("取消", { completionHandler(false) }),
                ("确定", { completionHandler(true) })
            ])
        }

        private func present(message: String, actions: [(String, () -> Void)]) {
            guard let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first?.rootViewController else { return }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            for (title, handler) in actions {
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in handler() })
            }
            root.present(alert, animated: true)
        }
    }
}
