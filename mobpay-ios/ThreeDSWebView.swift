//
//  ThreeDSWebView.swift
//  mobpay-ios
//
//  Created by Allan Mageto on 13/08/2019.
//  Copyright © 2019 Allan Mageto. All rights reserved.
//

import UIKit
import WebKit


class ThreeDSWebView: UIViewController, WKUIDelegate {
    
    var webView: WKWebView!
    var webCardinalURL: URL!
    
    convenience init(webCardinalURL:URL){
        self.init()
        self.webCardinalURL = webCardinalURL
    }
    
    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()

        // JavaScript to disable zoom and set viewport
        let source = """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.getElementsByTagName('head')[0].appendChild(meta);
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)

        // Add the script to the webConfiguration
        webConfiguration.userContentController.addUserScript(script)

        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: webCardinalURL))
    }
}
