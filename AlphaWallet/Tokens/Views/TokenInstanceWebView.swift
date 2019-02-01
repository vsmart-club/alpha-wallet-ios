// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import TrustKeystore
import WebKit

class TokenInstanceWebView: UIView {
    //TODO see if we can be smarter about just subscribing to the attribute once. Note that this is not `Subscribable.subscribeOnce()`
    private var subscribedAttributes = [Subscribable<AssetAttributeValue>]()
    private let config: Config
    private let walletAddress: Address

    //hhh make private
    lazy var webView: WKWebView = {
        let webViewConfig = WKWebViewConfiguration.make(for: config, address: walletAddress, with: config, in: ScriptMessageProxy(delegate: self))
        webViewConfig.websiteDataStore = .default()
        return .init(frame: .zero, configuration: webViewConfig)
    }()

    init(config: Config, walletAddress: Address) {
        self.config = config
        self.walletAddress = walletAddress
        super.init(frame: .zero)

        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //Implementation: String concatentation is slow, but it's not obvious at all
    func update(withTokenHolder tokenHolder: TokenHolder, asUserScript: Bool = false) {
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress)

        var token = [String: String]()
        token["_count"] = String(tokenHolder.count)
        for (name, value): (String, AssetAttributeValue) in tokenHolder.values {
            if let value = value as? SubscribableAssetAttributeValue {
                let subscribable = value.subscribable
                if let subscribedValue = subscribable.value {
                    if let value = formatValueAsJavaScriptValue(value: subscribedValue) {
                        token[name] = value
                    }
                } else {
                    if !subscribedAttributes.contains(where: { $0 === subscribable }) {
                        subscribedAttributes.append(subscribable)
                        subscribable.subscribe { [weak self] value in
                            guard let strongSelf = self else { return }
                            strongSelf.update(withTokenHolder: tokenHolder)
                        }
                    }
                }
            } else {
                if let value = formatValueAsJavaScriptValue(value: value) {
                    token[name] = value
                }
            }
        }

        var string = "\nweb3.tokens.data.currentInstance = "
        string += """
                  {
                  name: \"\(tokenHolder.name)\",
                  symbol: \"\(tokenHolder.symbol)\",
                  contractAddress: \"\(contractAddressAsEip55(tokenHolder.contractAddress))\",
                  """
        for (name, value) in token {
            string += "\(name): \(value),"
        }
        string += "\n}"

        var attributes = "{"
        attributes += "name: {value: \"\(tokenHolder.name)\"}, "
        attributes += "symbol: {value: \"\(tokenHolder.symbol)\"}, "
        for (id, name) in xmlHandler.fieldIdsAndNames {
            attributes += "\(id): {name: \"\(name)\"}, "
        }
        attributes += "}"
        string += "\nweb3.tokens.definition = {"
        string += "\n\"\(contractAddressAsEip55(tokenHolder.contractAddress))\": {"
        string += "\nattributes: \(attributes)"
        string += "\n}"
        string += "\n}"

        string += """
                  \nweb3.tokens.dataChanged(oldTokens, web3.tokens.data)
                  """
        let javaScript = """
                         const oldTokens = web3.tokens.data
                         """ + string
        let javaScriptWrappedInScope = """
                                       {
                                          \(javaScript)
                                       }
                                       """
        if asUserScript {
            let userScript = WKUserScript(source: javaScriptWrappedInScope, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            NSLog("xxx as user script")
            webView.configuration.userContentController.addUserScript(userScript)
        } else {
            NSLog("xxx evaluate JavaScript")
            webView.evaluateJavaScript(javaScriptWrappedInScope) { something, error in
                NSLog("xxx finish JS. something: \(something)")
                NSLog("xxx finish JS. error: \(error)")
            }
        }
    }

    //TODO we shouldn't need this once we don't don't pass arouund contract addresses as string
    private func contractAddressAsEip55(_ contractAddress: String) -> String {
        return Address(string: contractAddress)!.eip55String
    }

    private func formatValueAsJavaScriptValue(value: AssetAttributeValue) -> String? {
        if let value = value as? String {
            return "\"\(value)\""
        } else if let value = value as? Int {
            return String(value)
        } else if let value = value as? GeneralisedTime {
            return "new Date(\"\(value.formattedAsJavaScriptDateConstructorArgument)\")"
            //TODO how does array work? Do we need to worry about the type of the elements?
//        } else if let value = value as? Array {
//            return String(value)
        } else if let value = value as? Bool {
            return value ? "true" : "false"
        } else {
            return nil
        }
    }
}

extension TokenInstanceWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //No usual web3 signing support in TBML rendered view for now. Ever?
    }
}

//Block navigation. Still good to have even if we end up using XSLT?
extension TokenInstanceWebView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString, url == "about:blank" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}
