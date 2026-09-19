import SwiftUI
import WebKit

// 要打包的网站地址，改这里就能换站点
let kHomeURL = URL(string: "https://am-4u2.pages.dev/")!

@main
struct WrapperApp: App {
    var body: some Scene {
        WindowGroup {
            WebContainer()
                .ignoresSafeArea(edges: .bottom)
                .preferredColorScheme(.dark)
        }
    }
}

struct WebContainer: UIViewRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true                 // 视频内联播放，不强制全屏
        config.mediaTypesRequiringUserActionForPlayback = []     // 允许自动播放
        config.allowsPictureInPictureMediaPlayback = true
        config.websiteDataStore = .default()                     // 保留 Cookie / localStorage

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true       // 左滑返回
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // 下拉刷新
        let refresh = UIRefreshControl()
        refresh.tintColor = .white
        refresh.addTarget(context.coordinator,
                          action: #selector(Coordinator.reload(_:)),
                          for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        context.coordinator.webView = webView

        webView.load(URLRequest(url: kHomeURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?

        @objc func reload(_ sender: UIRefreshControl) {
            webView?.reload()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        // target="_blank" 的链接在当前 WebView 打开，否则会被吞掉
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // 非 http(s) 的 scheme（微信、支付宝、外部播放器等）交给系统
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

        // 网页里的 alert / confirm 不处理的话点了没反应
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
