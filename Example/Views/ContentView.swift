//
//  ContentView.swift
//  Example
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI
import Altcraft
import UIKit
import WebKit

// MARK: - UIKit presenter bridge (SwiftUI -> UIKit)

private struct PresenterView: UIViewControllerRepresentable {
    let onReady: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear

        // Вызываем после того, как VC точно в иерархии
        DispatchQueue.main.async {
            onReady(vc)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Your ContentView with one-time present

struct ContentView: View {
    @Binding var mode: Int
    @State private var didShowTestInApp = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    switch mode {
                    case 1: MainView()
                    case 2: ExampleView()
                    case 3: LogsView()
                    case 4: ConfigurationView()
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)

                NavigatorView(mode: $mode)
                    .frame(height: 60)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .background(Color.white)

            // Невидимый мост, чтобы получить UIViewController для present()
            PresenterView { presenter in
                guard !didShowTestInApp else { return }
                didShowTestInApp = true

//                // Показ тестового in-app
//                InAppMessageWebViewTester.present(
//                    from: presenter,
//                    html: InAppMessageWebViewTester.sampleHTML()
//                )
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
    }
}

final class InAppMessageWebViewTester: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    // MARK: - Public API

    static func present(
        from presenter: UIViewController,
        html: String,
        baseURL: URL? = nil,
        modalStyle: UIModalPresentationStyle = .fullScreen,
        animated: Bool = true
    ) {
        DispatchQueue.main.async {
            let vc = InAppMessageWebViewTester(html: html, baseURL: baseURL)
            vc.modalPresentationStyle = modalStyle

            let top = topViewController(startingFrom: presenter) ?? presenter
            top.present(vc, animated: animated)
        }
    }

    private static func topViewController(startingFrom vc: UIViewController?) -> UIViewController? {
        var top = vc

        if top?.view.window == nil {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                top = window.rootViewController
            }
        }

        while true {
            if let presented = top?.presentedViewController {
                top = presented
                continue
            }
            if let nav = top as? UINavigationController {
                top = nav.visibleViewController
                continue
            }
            if let tab = top as? UITabBarController {
                top = tab.selectedViewController
                continue
            }
            break
        }

        return top
    }

    static func sampleHTML() -> String {
        return """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"/>
            <title> - </title>
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    overscroll-behavior: none;
                    background: #0466EA;
                }

                body {
                    font-family: Arial, sans-serif;
                    overflow: hidden;
                }

                .inapp * {
                    box-sizing: border-box;
                }

                .inapp,
                .inapp__body,
                .inapp__body.fullscreen {
                    position: fixed;
                    inset: 0;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    overflow: hidden;
                }

                .inapp__body.fullscreen,
                .inapp__body.fullscreen .wrap-pages {
                    display: flex;
                    flex-direction: row;
                    width: 100%;
                    height: 100%;
                }

                .wrap-pages {
                    display: flex;
                    overflow: hidden;
                    width: 100%;
                    height: 100%;
                    position: relative;
                    touch-action: pan-y;
                }

                .page {
                    min-width: 100%;
                    width: 100%;
                    height: 100%;
                    flex-shrink: 0;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    transition: transform 0.3s ease;
                    user-select: none;
                    background-color: #0466EA;
                    background-image: url('https://dev.amp4email.ru/inapp/bg.png');
                    background-size: cover;
                    background-position: center;
                    background-repeat: no-repeat;
                }

                .wrap-pages.dragging .page {
                    transition: none;
                }

                .block,
                .img,
                .btn,
                .social {
                    display: flex;
                }

                .block {
                    width: 100%;
                }

                .block .block__content {
                    flex-grow: 1;
                    display: flex;
                    width: 100%;
                }

                .block .block__content .column {
                    flex-grow: 1;
                    width: 100%;
                }

                .close {
                    position: absolute;
                    top: env(safe-area-inset-top, 0px);
                    right: 0;
                    z-index: 20;
                    padding: 10px;
                }

                .close button {
                    width: 40px;
                    height: 40px;
                    border: 0;
                    background: transparent;
                    padding: 0;
                    margin: 0;
                    appearance: none;
                    -webkit-appearance: none;
                }

                .close .px-sc__bg {
                    fill: rgba(255,255,255,0.4);
                    rx: 5px;
                    ry: 5px;
                    width: 40px;
                    height: 40px;
                }

                .close .px-sc {
                    fill: #ffffff;
                }

                .pagination {
                    position: absolute;
                    left: 0;
                    right: 0;
                    bottom: calc(env(safe-area-inset-bottom, 0px) + 8px);
                    z-index: 10;
                    display: flex;
                    gap: 10px;
                    padding: 10px 16px;
                }

                .pagination .pagination__item {
                    flex-grow: 1;
                    height: 5px;
                    border-radius: 3px;
                    background: rgba(255, 255, 255, 0.8);
                }

                .pagination .pagination__item.active {
                    background: rgba(255, 255, 255, 1);
                }

                .b-Mxp8EZbBDtN4YmkhM819w {
                    align-items: center;
                    gap: 0;
                    flex: 1;
                }

                .b-Mxp8EZbBDtN4YmkhM819w .block__content {
                    justify-content: center;
                }

                .c-a0TBlydnZZ2CnJ-zf7Ls3 {
                    border-radius: 10px;
                    padding: 20px;
                    align-items: center;
                    justify-content: center;
                }

                .i-YgmSfgPlhnl8qBxHJGK08 {
                    justify-content: center;
                }

                .i-YgmSfgPlhnl8qBxHJGK08 img {
                    width: 100%;
                    max-width: 320px;
                    height: auto;
                    display: block;
                }

                .b-r8nBLlYLxCbxOExk_bsxp {
                    align-items: center;
                    gap: 0;
                    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 40px);
                }

                .b-r8nBLlYLxCbxOExk_bsxp .block__content {
                    justify-content: center;
                }

                .c-n-YKEruVpw0aZHno_S2fC {
                    padding: 10px 20px 25px 20px;
                    align-items: center;
                    justify-content: flex-start;
                }

                .t-8-vkS8WUdklwjhjcB07Gh {
                    font-family: Arial, Geneva, sans-serif;
                    font-size: 30px;
                    line-height: 38px;
                    color: #ffffff;
                    text-align: left;
                    align-items: flex-start;
                    width: 100%;
                }

                .t-3MKWbKH4ladmsAoMUGFZt {
                    font-family: Arial, Geneva, sans-serif;
                    font-size: 20px;
                    line-height: 28px;
                    color: #ffffff;
                    text-align: left;
                    align-items: flex-start;
                    padding: 20px 0 0 0;
                    width: 100%;
                }

                .b-ip_AVNR59XMt8fjT38KdL {
                    padding: 20px 0 0 0;
                    justify-content: center;
                    width: 100%;
                }

                .b-ip_AVNR59XMt8fjT38KdL button {
                    width: 100%;
                    height: 56px;
                    background-color: #ffffff;
                    border-radius: 5px;
                    font-family: Verdana, Geneva, sans-serif;
                    font-size: 18px;
                    color: #0F5CF2;
                    border: 0;
                }

                .b-pov4hNvE49WQoq8bc3vc6,
                .b-8BYec-1VPBQ-_ofH0UEo4 {
                    align-items: center;
                    padding: 20px;
                    flex: 1;
                }

                .b-pov4hNvE49WQoq8bc3vc6 .block__content,
                .b-8BYec-1VPBQ-_ofH0UEo4 .block__content {
                    justify-content: center;
                }

                .c-liNxi5aqK6rPwwrdB-Yo-,
                .c-IejbucXdFs-8KIxNdfQ-b {
                    align-items: center;
                    justify-content: center;
                }

                .t-k7hUj1KKw9YS-S_K9yUMW,
                .t-Lq_e6GHvGO6gQO2Ut5p5m {
                    font-family: Arial, sans-serif;
                    font-size: 18px;
                    line-height: 28px;
                    color: #FFFFFF;
                    text-align: left;
                    align-items: flex-start;
                    padding: 20px 0;
                    width: 100%;
                }
            </style>
        </head>
        <body>
            <div class="inapp">
                <div class="inapp__body top fullscreen">
                    <div class="close">
                        <button type="button" onclick="sendClose()">
                            <svg width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                                <rect class="px-sc__bg" vector-effect="non-scaling-stroke" width="40" height="40" fill="#cccccc"/>
                                <path class="px-sc" d="M27.0724 14.6655L21.9352 19.7543L27.0724 24.843C27.3631 25.1661 27.5085 25.5377 27.5085 25.9577C27.5085 26.3777 27.3631 26.7493 27.0724 27.0724C26.7493 27.3631 26.3777 27.5085 25.9577 27.5085C25.5377 27.5085 25.1661 27.3631 24.843 27.0724L19.7543 21.9352L14.6655 27.0724C14.3424 27.3631 13.9709 27.5085 13.5509 27.5085C13.1308 27.5085 12.7593 27.3631 12.4362 27.0724C12.1454 26.7493 12 26.3777 12 25.9577C12 25.5377 12.1454 25.1661 12.4362 24.843L17.5734 19.7543L12.4362 14.6655C12.1454 14.3424 12 13.9709 12 13.5509C12 13.1308 12.1454 12.7593 12.4362 12.4362C12.7593 12.1454 13.1308 12 13.5509 12C13.9709 12 14.3424 12.1454 14.6655 12.4362L19.7543 17.5734L24.843 12.4362C25.1661 12.1454 25.5377 12 25.9577 12C26.3777 12 26.7493 12.1454 27.0724 12.4362C27.3631 12.7593 27.5085 13.1308 27.5085 13.5509C27.5085 13.9709 27.3631 14.3424 27.0724 14.6655Z" fill="white" />
                            </svg>
                        </button>
                    </div>

                    <div class="pagination">
                        <div class="pagination__item active"><div></div></div>
                        <div class="pagination__item"><div></div></div>
                        <div class="pagination__item"><div></div></div>
                    </div>

                    <div class="wrap-pages">
                        <div class="page p-SgKOlVzXEetPkW5S1F8iN">
                            <div class="block b-Mxp8EZbBDtN4YmkhM819w">
                                <div class="block__content">
                                    <div class="column c-a0TBlydnZZ2CnJ-zf7Ls3">
                                        <div class="img i-YgmSfgPlhnl8qBxHJGK08">
                                            <img src="https://dev.amp4email.ru/inapp/img.png" />
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div class="block b-r8nBLlYLxCbxOExk_bsxp">
                                <div class="block__content">
                                    <div class="column c-n-YKEruVpw0aZHno_S2fC">
                                        <div class="text t-8-vkS8WUdklwjhjcB07Gh">
                                            <div>In-app сообщения</div>
                                        </div>
                                        <div class="text t-3MKWbKH4ladmsAoMUGFZt">
                                            <div>В нужный момент <br />В нужном контексте</div>
                                        </div>
                                        <div class="btn b-ip_AVNR59XMt8fjT38KdL">
                                            <button type="button" data-href="#" onclick="sendCTA('Подробнее')">Подробнее</button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="page p-8y7z_sY-9SEiVSMU-28h7">
                            <div class="block b-pov4hNvE49WQoq8bc3vc6">
                                <div class="block__content">
                                    <div class="column c-liNxi5aqK6rPwwrdB-Yo-">
                                        <div class="text t-k7hUj1KKw9YS-S_K9yUMW">
                                            <div>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam non nibh ut velit suscipit tincidunt ac vitae sapien. Suspendisse convallis nibh quis vestibulum tincidunt.</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="page p-ZI1HcjcRzstSroLTtGxBy">
                            <div class="block b-8BYec-1VPBQ-_ofH0UEo4">
                                <div class="block__content">
                                    <div class="column c-IejbucXdFs-8KIxNdfQ-b">
                                        <div class="text t-Lq_e6GHvGO6gQO2Ut5p5m">
                                            <div>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam non nibh ut velit suscipit tincidunt ac vitae sapien. Suspendisse convallis nibh quis vestibulum tincidunt.2</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <script>
                const wrapper = document.querySelector('.wrap-pages');
                const pages = document.querySelectorAll('.page');
                const pagination = document.querySelector('.pagination');

                let current = 0;
                let startX = 0;
                let currentTranslate = 0;
                let prevTranslate = 0;
                let isDragging = false;
                let animationID = 0;
                let startTime = 0;
                let velocity = 0;

                function postToNative(payload) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.inapp) {
                        window.webkit.messageHandlers.inapp.postMessage(payload);
                    }
                }

                function sendClose() {
                    postToNative({ name: 'close' });
                }

                function sendCTA(title) {
                    postToNative({
                        name: 'cta',
                        payload: {
                            title: title
                        }
                    });
                }

                function pageWidth() {
                    return wrapper.offsetWidth;
                }

                function setSliderPosition(x) {
                    pages.forEach((page) => {
                        let value = x;
                        if (value > 0) value = 0;
                        const maxPosition = -1 * (pages.length - 1) * pageWidth();
                        if (value < maxPosition) value = maxPosition;
                        page.style.transform = 'translateX(' + value + 'px)';
                    });
                }

                function animation() {
                    setSliderPosition(currentTranslate);
                    if (isDragging) {
                        requestAnimationFrame(animation);
                    }
                }

                function startDrag(e) {
                    isDragging = true;
                    wrapper.classList.add('dragging');

                    startTime = Date.now();
                    startX = getX(e);
                    prevTranslate = -current * pageWidth();
                    currentTranslate = prevTranslate;
                    animationID = requestAnimationFrame(animation);
                }

                function moveDrag(e) {
                    if (!isDragging) return;
                    const currentX = getX(e);
                    const diff = currentX - startX;
                    currentTranslate = prevTranslate + diff;
                }

                function endDrag() {
                    if (!isDragging) return;

                    isDragging = false;
                    wrapper.classList.remove('dragging');
                    cancelAnimationFrame(animationID);

                    const movedBy = currentTranslate - prevTranslate;
                    const time = Math.max(Date.now() - startTime, 1);
                    velocity = movedBy / time;

                    const threshold = pageWidth() * 0.25;

                    if (Math.abs(velocity) > 0.5) {
                        if (velocity < 0 && current < pages.length - 1) current++;
                        if (velocity > 0 && current > 0) current--;
                    } else if (Math.abs(movedBy) > threshold) {
                        if (movedBy < 0 && current < pages.length - 1) current++;
                        if (movedBy > 0 && current > 0) current--;
                    }

                    snapToCurrent();
                }

                function snapToCurrent() {
                    if (pagination) {
                        pagination.querySelectorAll('.pagination__item').forEach((item, index) => {
                            item.classList.toggle('active', index === current);
                        });
                    }

                    currentTranslate = -current * pageWidth();
                    setSliderPosition(currentTranslate);
                }

                function getX(e) {
                    if (e.type.includes('mouse')) {
                        return e.pageX;
                    }
                    return e.touches[0].clientX;
                }

                wrapper.addEventListener('mousedown', startDrag);
                wrapper.addEventListener('mousemove', moveDrag);
                wrapper.addEventListener('mouseup', endDrag);
                wrapper.addEventListener('mouseleave', endDrag);

                wrapper.addEventListener('touchstart', startDrag, { passive: true });
                wrapper.addEventListener('touchmove', moveDrag, { passive: true });
                wrapper.addEventListener('touchend', endDrag);

                window.addEventListener('resize', snapToCurrent);

                snapToCurrent();
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Init

    private let html: String
    private let baseURL: URL?
    private var webView: WKWebView!

    init(html: String, baseURL: URL? = nil) {
        self.html = html
        self.baseURL = baseURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        setupWebView()
        loadHTML()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "inapp")
    }

    // MARK: - Setup

    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "inapp")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.isOpaque = true
        wv.backgroundColor = .white
        wv.scrollView.backgroundColor = .white
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.bounces = false
        wv.scrollView.alwaysBounceVertical = false
        wv.scrollView.alwaysBounceHorizontal = false
        wv.scrollView.isScrollEnabled = false

        if #available(iOS 16.4, *) {
            wv.isInspectable = true
        }

        webView = wv
        view.addSubview(wv)
    }

    private func loadHTML() {
        DispatchQueue.main.async {
            self.webView.loadHTMLString(self.html, baseURL: self.baseURL)
        }
    }

    private func dismissInApp() {
        DispatchQueue.main.async {
            self.dismiss(animated: true)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ WKWebView didFinish")
        webView.evaluateJavaScript("document.body && document.body.innerText ? document.body.innerText.length : -1") { result, error in
            if let error = error {
                print("⚠️ JS eval error:", error)
            } else {
                print("ℹ️ body.innerText.length =", result ?? "nil")
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WKWebView didFail navigation:", error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WKWebView didFailProvisionalNavigation:", error)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            print("🔗 Link tapped:", url.absoluteString)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "inapp" else { return }

        if let dict = message.body as? [String: Any] {
            let eventName = dict["name"] as? String ?? "unknown"
            let payload = dict["payload"]

            print("📩 InApp JS event:", eventName, "payload:", payload ?? "nil")

            switch eventName {
            case "close":
                dismissInApp()

            case "cta":
                showAlert(title: "CTA", message: "payload: \(stringify(payload))")

            default:
                break
            }
        } else {
            print("📩 InApp JS raw message:", message.body)
        }
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let ac = UIAlertController(title: "JS Alert", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        present(ac, animated: true)
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    private func stringify(_ value: Any?) -> String {
        guard let value else { return "nil" }

        if let s = value as? String {
            return s
        }

        if let n = value as? NSNumber {
            return n.stringValue
        }

        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }

        return String(describing: value)
    }
}
