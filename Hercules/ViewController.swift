//
//  ViewController.swift
//  Hercules
//
//  Created by Patrick Smith on 12/11/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Cocoa
import WebKit

extension NSTextStorage {
	fileprivate func formatAsURLField(string maybeString: String? = nil) {
		let string = maybeString ?? self.string
		let richText = NSAttributedString(string: string, attributes: [
			.font: NSFont.systemFont(ofSize: 14.0),
			.foregroundColor: NSColor.textColor,
			])
		self.replaceCharacters(in: NSRange(location: 0, length: self.length), with: richText)
	}
	
	fileprivate func update(from pages: Model.Pages) {
		self.beginEditing()
		pages.commit(to: self)
		self.endEditing()
		
//		let text = pages.text
//		
//		if text == self.string {
//			return
//		}
//		
//		self.beginEditing()
//		self.formatAsURLField(string: text)
//		self.endEditing()
	}
}

class ViewController: NSViewController {
	@IBOutlet var webStackView: NSStackView!
	@IBOutlet var urlsTextView: NSTextView!
	
	let minSize = CGSize(width: 375, height: 667)
	
	var orientation: NSUserInterfaceLayoutOrientation = .vertical
	
	var document: Document {
		return (self.view.window?.windowController?.document as? Document)!
	}
	
	var pagesState: Model.Pages {
		get {
			return document.pages
		}
		set(new) {
			document.pages = new
			//self.urlsTextView.textStorage!.update(from: new)
		}
	}
	
	var needsUpdate = false
	
	var layoutConstraintsForOrientation: [NSLayoutConstraint] = []
	
	func updateForOrientation() {
		let orientation = self.orientation
		webStackView.orientation = orientation
		webStackView.edgeInsets = .init(top: 20, left: 20, bottom: 20, right: 20)

		let webScrollView = self.webScrollView
		let clipView = webScrollView.contentView
		
		NSLayoutConstraint.deactivate(layoutConstraintsForOrientation)
		layoutConstraintsForOrientation.removeAll()
		
		switch orientation {
		case .horizontal:
			layoutConstraintsForOrientation.append(contentsOf: [
				webStackView.topAnchor.constraint(equalTo: clipView.topAnchor),
				webStackView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
				webStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: minSize.width),
				webStackView.widthAnchor.constraint(greaterThanOrEqualTo: clipView.widthAnchor, multiplier: 1.0),
			])
		case .vertical:
			layoutConstraintsForOrientation.append(contentsOf: [
				webScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: minSize.width + 40),
//				webStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 367),
//				webStackView.topAnchor.constraint(equalTo: clipView.topAnchor),
//				webStackView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
//				webStackView.widthAnchor.constraint(greaterThanOrEqualTo: clipView.widthAnchor, multiplier: 1.0),
			])
		default: break
		}
		
		layoutConstraintsForOrientation.append(contentsOf: [
			webScrollView.topAnchor.constraint(equalTo: clipView.topAnchor),
			webScrollView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
			webScrollView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
			webScrollView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor)
		])
		
		NSLayoutConstraint.activate(layoutConstraintsForOrientation)
	}
	
	var highlight: Model.ParsedPage.Highlight = .vanilla

	override func viewDidLoad() {
		super.viewDidLoad()
		
		webScrollView.backgroundColor = NSColor.black
		webScrollView.scrollerKnobStyle = .light
		
		webStackView.translatesAutoresizingMaskIntoConstraints = false
		webStackView.spacing = 20
		self.updateForOrientation()
		
		urlsTextView.delegate = self
		highlight.highlight(textView: urlsTextView)
	}
	
	override func viewDidAppear() {
		self.urlsTextView.textStorage!.update(from: self.pagesState)
		self.updateWebViews()
	}

	override var representedObject: Any? {
		didSet {
			// Update the view, if already loaded.
		}
	}
	
	var webScrollView: NSScrollView {
		return webStackView.enclosingScrollView!
	}
	
	var allWebViews: [WKWebView] {
		(self.webStackView.arrangedSubviews as NSArray).copy() as! [WKWebView]
	}
}

extension ViewController {
	static func makeConfiguration() -> WKWebViewConfiguration {
		let webViewConfig = WKWebViewConfiguration()
		return webViewConfig
	}
	
	func addWebView(for: URL?, configuration: WKWebViewConfiguration = makeConfiguration()) -> WKWebView {
		let minWidth: CGFloat = minSize.width
		
		let webView = WKWebView(frame: CGRect(origin: .zero, size: minSize), configuration: configuration)
		webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.5 Mobile/15E148 Safari/604.1"
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.allowsBackForwardNavigationGestures = true
		
		let webScrollView = self.webScrollView
		webView.translatesAutoresizingMaskIntoConstraints = false
		webStackView.addView(webView, in: .trailing)
		
		if self.orientation == .horizontal {
			NSLayoutConstraint.activate([
						webView.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
						webView.bottomAnchor.constraint(equalTo: webScrollView.contentView.bottomAnchor, constant: 20.0)
						])
		} else {
			NSLayoutConstraint.activate([
				webView.widthAnchor.constraint(equalToConstant: minSize.width),
				webView.heightAnchor.constraint(greaterThanOrEqualToConstant: minSize.height),
			//			webView.bottomAnchor.constraint(equalTo: webScrollView.contentView.bottomAnchor, constant: -20.0)
						])
		}
		
		return webView
	}
	
	struct UpdateResult : CustomDebugStringConvertible {
		var added: [WKWebView] = []
		var removed: [WKWebView] = []
		var changed: [WKWebView] = []
		var unchanged: [WKWebView] = []
		
		var debugDescription: String {
			func toDebugString(_ webViews: [WKWebView]) -> String {
				return webViews.map({ $0.url?.absoluteString ?? "?" }).joined(separator: ", ")
			}
			
			return """
			UpdateResult(added: [\(toDebugString(added))], removed: [\(toDebugString(removed))], changed: [\(toDebugString(changed))], unchanged: [\(toDebugString(unchanged))])
			"""
		}
	}
	
	@discardableResult func updateWebViews(configuration: WKWebViewConfiguration? = nil) -> UpdateResult {
		let webViews = self.allWebViews
		var openWebViewsCount = webViews.count
		
		let pages = self.pagesState.presentedPages
		var result = UpdateResult()
		
		for (index, page) in pages.enumerated() {
			var didAdd = false
			let webView: WKWebView
			if index < openWebViewsCount {
				webView = webViews[index]
			} else {
				if let configuration = configuration {
					webView = self.addWebView(for: page.url, configuration: configuration)
				} else {
					webView = self.addWebView(for: page.url)
				}
				result.added.append(webView)
				didAdd = true
			}
			
			switch page {
			case let .web(url):
				var didChange = false
				if
					let scheme = url.scheme,
					["https","http"].contains(scheme),
					webView.url != url
				{
					webView.load(URLRequest(url: url))
					didChange = true
				}
				
				if !didAdd {
					if didChange {
						result.changed.append(webView)
					} else {
						result.unchanged.append(webView)
					}
				}
			case let .uncommittedSearch(query):
				let html = HTMLTemplate.query(query: query).makeHTML()
				webView.loadHTMLString(html, baseURL: nil)
			case let .graphQLQuery(query):
				let html = HTMLTemplate.graphQLQuery(query: query).makeHTML()
				webView.loadHTMLString(html, baseURL: nil)
			case let .markdownDocument(content):
				let html = HTMLTemplate.markdown(content: content).makeHTML()
				webView.loadHTMLString(html, baseURL: nil)
			case .blank:
				webView.loadHTMLString("", baseURL: nil)
			}
		}
		
		openWebViewsCount = self.webStackView.arrangedSubviews.count
		if pages.count < openWebViewsCount {
			for indexToRemove in pages.count ..< openWebViewsCount {
				print("removing", indexToRemove)
				result.removed.append(webViews[indexToRemove])
				self.webStackView.removeArrangedSubview(webViews[indexToRemove])
			}
		}
		
		print("UPDATED WEB VIEWS \(result)")
		
		return result
	}
}

extension ViewController {
	var newPageURL: URL {
		return URL(string: "https://start.duckduckgo.com/")!
	}
	
	@IBAction func addPage(_ sender: Any?) {
		let url = self.newPageURL
		self.pagesState.pages.append(Model.Page.web(url: url))
		self.updateWebViews()
	}
	
	var selectedPageIndex: Int? {
		let selectionStart = urlsTextView.selectedRange().location
		if selectionStart != NSNotFound {
			let editorIndex = String.Index(utf16Offset: selectionStart, in: urlsTextView.string)
			return self.pagesState.parsedPages.firstIndex { (parsedPage) -> Bool in
				parsedPage.contains(index: editorIndex)
			}
		}
		
		return nil
	}

	@IBAction func performClosePage(_ sender: Any?) {
		if self.pagesState.pages.count > 0 {
			if let indexToRemove = self.selectedPageIndex {
				self.pagesState.pages.remove(at: indexToRemove)
			} else {
				self.pagesState.pages.removeLast()
			}
			self.updateWebViews()
		} else {
			NSApp.perform(#selector(NSWindow.performClose(_:)))
		}
	}
	
	@IBAction func reloadAllPages(_ sender: Any?) {
		for webView in self.allWebViews {
			webView.reload(sender)
		}
	}
}

extension ViewController : WKNavigationDelegate {
	private func urlDidChange(for webView: WKWebView) {
		guard let index = webStackView.arrangedSubviews.firstIndex(of: webView) else { return }
		guard let url = webView.url else { return }
		// TODO: use smarter way to change URL line in text view while keeping pending text editing changes
		switch self.pagesState.pages[index] {
		case .web:
			self.pagesState.pages[index] = Model.Page.web(url: url)
		default:
			break
		}
	}
	
	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		self.urlDidChange(for: webView)
	}
	
	func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
		self.urlDidChange(for: webView)
	}
	
	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		self.urlDidChange(for: webView)
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		self.urlDidChange(for: webView)
		
		if false {
			webView.evaluateJavaScript("""
	var s = document.createElement("script");
	s.type = "text/javascript";
	s.src = "https://cdn.jsdelivr.net/npm/axe-core@3.1.2/axe.min.js";
	s.integrity = "sha256-wIvlzfT77n6fOnSL6/oLbzB873rY7QHTW/e0Z0mOoYs=";
	s.crossorigin = "anonymous";
	document.head.appendChild(s);
	//var t = document.getElementsByTagName(o)[0];
	//t.parentNode.insertBefore(s, t);
	""") { (result, error) in
			}
		}
	}
	
//	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//		if navigationAction.navigationType == WKNavigationType.linkActivated {
//			decisionHandler(.allow)
//		}
//	}
}

extension ViewController : WKUIDelegate {
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
		if !isMainFrame {
			let request = navigationAction.request
			if let url = request.url {
				self.pagesState.pages.append(Model.Page.web(url: url))
				let result = self.updateWebViews(configuration: configuration)
				return result.added.first
			}
		}
		
		return nil
	}
}

extension ViewController : NSTextViewDelegate {
	func updatePagesFromText(commitSearches: Bool) {
        var pagesState = self.pagesState
        
        pagesState.text = self.urlsTextView.string
        if commitSearches {
            pagesState.commitSearches()
        }
        
        // Always keep the model in sync with the editor so selection/indexing works,
        // but only trigger web view updates (and reformatting) when committing.
        self.pagesState = pagesState
        
        if commitSearches {
            self.updateWebViews()
            // Refresh highlighting/formatting only on commit to avoid disrupting typing.
            self.urlsTextView.textStorage!.update(from: self.pagesState)
        }
        
        self.needsUpdate = false
	}
	
	func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
		if commandSelector == #selector(NSTextView.insertNewline(_:)) {
			self.needsUpdate = true
		}
		
		return false
	}
	
	func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        let before = (textView.string as NSString).substring(with: affectedCharRange)
        if before.contains("\n") || (replacementString?.contains("\n") ?? false) {
            self.needsUpdate = true
        }
        
        return true
	}
	
	func textDidChange(_ notification: Notification) {
//		self.urlsTextView.textStorage!.formatAsURLField()
		
		self.updatePagesFromText(commitSearches: self.needsUpdate)
	}
	
	func textViewDidChangeSelection(_ notification: Notification) {
		guard let index = self.selectedPageIndex else { return }
		
		let views = webStackView.arrangedSubviews
		guard index < views.count else { return }
		
		let view = views[index]
		
		view.scrollToVisible(view.bounds)
		
//		guard let selection = urlsTextView.selectedRanges.first else { return }
		
//		let start = selection.rangeValue.location
//		guard let string = urlsTextView.textStorage?.string else { return }
//		string.range
//		string.prefix(upTo: start)
		
	}
}

