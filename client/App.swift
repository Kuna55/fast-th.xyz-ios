// NFSU2 client for iOS: fast-th.xyz in a full-screen web view, as nfsu2desktop
// is on Windows.  The game, its saves and online play are the website's; this
// app adds what a Safari tab or a Home Screen icon lacks or makes awkward:
//   - full screen without browser bars, the Home indicator hidden and edge
//     swipes deferred (a first swipe from an edge goes to the game);
//   - the screen stays on while the app is in front;
//   - the page is told it runs from the Home Screen (navigator.standalone),
//     so it does not ask for that, and Safari's user agent, so it treats this
//     view exactly as Safari (WKWebView leaves Safari's tokens out);
//   - sound plays with the silent switch on, mixed with other apps' audio;
//   - links to other sites open in Safari, downloads (the log, save backups)
//     go to Files > NFSU2 > Downloads, the page's dialogs (alert, confirm,
//     prompt) show as iOS alerts, and a crashed page reloads.
// Unofficial: not made or endorsed by fast-th.xyz or Electronic Arts.
import UIKit
import WebKit
import AVFoundation

// The one place the site's domain is set.  If fast-th.xyz redirects to another
// domain (CDN, login page), add that domain to extraSiteHosts so it stays in the app.
let siteHost = "fast-th.xyz"
let extraSiteHosts: [String] = []
let siteURL = URL(string: "https://\(siteHost)/")!

func isSiteHost(_ host: String) -> Bool {
    let h = host.lowercased()
    return ([siteHost] + extraSiteHosts).contains { h == $0 || h.hasSuffix("." + $0) }
}

func isSite(_ url: URL) -> Bool {
    guard let h = url.host else { return false }
    return isSiteHost(h)
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // playback: sound with the silent switch on; mixWithOthers: music apps keep playing
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Game", sessionRole: session.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.backgroundColor = .black
        w.rootViewController = GameViewController()
        w.makeKeyAndVisible()
        window = w
    }
    func sceneDidBecomeActive(_ scene: UIScene) { UIApplication.shared.isIdleTimerDisabled = true }
    func sceneWillResignActive(_ scene: UIScene) { UIApplication.shared.isIdleTimerDisabled = false }
}

final class GameViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    private var web: WKWebView!
    private var downloads: [ObjectIdentifier: URL] = [:]

    override func loadView() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()                 // saves and settings kept between launches
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.defaultWebpagePreferences.preferredContentMode = .mobile
        // No element full screen: the app already is full screen, and WebKit's would add its own
        // banner, close button and status bar over the game.  Without it the page (display.ts:
        // canFullscreen false, fromHomeScreen true) neither asks for it nor shows its button.
        // Safari's user agent: WKWebView sends "... (KHTML, like Gecko) Mobile/15E148" without
        // Safari's "Version/x Safari/604.1", and the page reads the Safari version from it
        let v = ProcessInfo.processInfo.operatingSystemVersion
        cfg.applicationNameForUserAgent = "Version/\(v.majorVersion).\(v.minorVersion) Mobile/15E148 Safari/604.1"
        // started from the Home Screen as far as the page is concerned (web/src/app/display.ts:
        // fromHomeScreen), so it neither asks to be added there nor tries the browser's full screen
        let standalone = "try{Object.defineProperty(Navigator.prototype,'standalone',{get:function(){return true},configurable:true})}catch(e){}"
        cfg.userContentController.addUserScript(WKUserScript(source: standalone, injectionTime: .atDocumentStart,
                                                             forMainFrameOnly: true))
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = self
        w.uiDelegate = self
        w.isOpaque = true
        w.backgroundColor = .black
        w.scrollView.backgroundColor = .black
        w.scrollView.contentInsetAdjustmentBehavior = .never   // the page lays itself out to the screen's edges
        w.scrollView.bounces = false
        w.allowsBackForwardNavigationGestures = false
        w.allowsLinkPreview = false
        if #available(iOS 16.4, *) { w.isInspectable = true }  // Safari's Web Inspector from a Mac, if ever needed
        web = w
        view = w
        w.load(URLRequest(url: siteURL))
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    // ---- navigation: the site stays here, everything else opens in Safari ----
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.shouldPerformDownload { decisionHandler(.download); return }
        guard let url = action.request.url else { decisionHandler(.allow); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "nfsu2-retry" { decisionHandler(.cancel); webView.load(URLRequest(url: siteURL)); return }
        if ["about", "blob", "data", "javascript"].contains(scheme) { decisionHandler(.allow); return }
        // frames inside the page (embeds) load as the page wants
        if let f = action.targetFrame, !f.isMainFrame { decisionHandler(.allow); return }
        if isSite(url) { decisionHandler(.allow); return }
        if scheme == "http" || scheme == "https" || scheme == "mailto" || scheme == "discord" {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }
    // window.open / target=_blank
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if isSite(url) { webView.load(action.request) } else { UIApplication.shared.open(url) }
        }
        return nil
    }

    // ---- a page that could not load, or crashed ----
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let e = error as NSError
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        showOffline(error.localizedDescription)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // the page ran out of memory or crashed: start it again rather than leave a blank screen
        webView.load(URLRequest(url: siteURL))
    }
    private func showOffline(_ why: String) {
        let esc = why.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        let html = """
        <!doctype html><meta name=viewport content="width=device-width,initial-scale=1">
        <body style="background:#0e1014;color:#eee;font:17px -apple-system,sans-serif;display:flex;
          align-items:center;justify-content:center;height:100vh;margin:0;text-align:center">
        <div><p style="font-size:22px;font-weight:600">\(siteHost) could not be reached</p>
        <p style="color:#aaa">\(esc)</p>
        <p><a href="nfsu2-retry://" style="display:inline-block;padding:12px 24px;border-radius:8px;
          background:#c8f088;color:#111;text-decoration:none;font-weight:600">Try again</a></p></div>
        """
        web.loadHTMLString(html, baseURL: nil)
    }

    // ---- the page's dialogs ----
    private func present(_ a: UIAlertController) {
        var vc: UIViewController = self
        while let p = vc.presentedViewController { vc = p }
        vc.present(a, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { [weak a] _ in completionHandler(a?.textFields?.first?.text) })
        present(a)
    }
    // a controller or the page asking for the microphone/camera: the site's own
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(isSiteHost(origin.host) ? .prompt : .deny)
    }

    // ---- downloads: into Documents/Downloads (Files > On My iPhone > NFSU2) ----
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = suggestedFilename.isEmpty ? "download" : suggestedFilename
        var url = dir.appendingPathComponent(name)
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"); n += 1
        }
        downloads[ObjectIdentifier(download)] = url
        completionHandler(url)
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        let a = UIAlertController(title: "Downloaded",
                                  message: "\(url.lastPathComponent) is in Files, On My iPhone > NFSU2 > Downloads.",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            let s = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            s.popoverPresentationController?.sourceView = self?.view
            s.popoverPresentationController?.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 1, height: 1)
            self?.present(s, animated: true)
        })
        a.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(a)
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeValue(forKey: ObjectIdentifier(download))
        let a = UIAlertController(title: "Download failed", message: error.localizedDescription, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a)
    }
}
