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
	private enum TextUpdateReason {
		case userCommitted
		case siteNavigated
		case navigationUpdate
		case modelChanged
	}
	
	private var textUpdateReason: TextUpdateReason?
	
	var layoutConstraintsForOrientation: [NSLayoutConstraint] = []
	// Maps arrangedSubviews web view index -> page index in pagesState.pages
	var webViewPageIndices: [Int] = []
	
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
		webScrollView.autohidesScrollers = false
		
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
	
	private final class HeadMetricsCollector: NSObject, URLSessionTaskDelegate {
		var metrics: URLSessionTaskMetrics?
		func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
			self.metrics = metrics
		}
	}
	
	func addWebView(for: URL?, configuration: WKWebViewConfiguration = makeConfiguration()) -> WKWebView {
		let minWidth: CGFloat = minSize.width
		
		let webView = WKWebView(frame: CGRect(origin: .zero, size: minSize), configuration: configuration)
		webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
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
        let existingWebViews = self.allWebViews
        var existingCount = existingWebViews.count
        
        let pages = self.pagesState.presentedPages
        // Build list of visible (non-blank) pages with their page indices
        let visible: [(pageIndex: Int, page: Model.Page)] = pages.enumerated()
            .filter { $0.element != .blank }
            .map { (pageIndex: $0.offset, page: $0.element) }
        var result = UpdateResult()
        var newMapping: [Int] = []
        
        for (webIndex, entry) in visible.enumerated() {
            let pageIndex = entry.pageIndex
            let page = entry.page
            var didAdd = false
            let webView: WKWebView
            if webIndex < existingCount {
                webView = existingWebViews[webIndex]
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
                if let scheme = url.scheme, ["https","http"].contains(scheme), webView.url != url {
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
            case let .head(url):
                // Perform a HEAD request with timing metrics and render headers
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"
                let collector = HeadMetricsCollector()
                let session = URLSession(configuration: .default, delegate: collector, delegateQueue: nil)
                let task = session.dataTask(with: request) { data, response, error in
                    // Extract metrics
                    let metrics = collector.metrics
                    let txn = metrics?.transactionMetrics.last
                    func ms(_ start: Date?, _ end: Date?) -> String {
                        guard let s = start, let e = end else { return "n/a" }
                        let interval = e.timeIntervalSince(s) * 1000.0
                        return String(format: "%.1f", interval)
                    }
                    let dns = ms(txn?.domainLookupStartDate, txn?.domainLookupEndDate)
                    let tcp = ms(txn?.connectStartDate, txn?.connectEndDate)
                    let tls = ms(txn?.secureConnectionStartDate, txn?.secureConnectionEndDate)
                    let server = ms(txn?.requestEndDate, txn?.responseStartDate)
                    
                    DispatchQueue.main.async {
                        defer { session.finishTasksAndInvalidate() }
                        if let http = response as? HTTPURLResponse {
                            let headers = http.allHeaderFields.map { "\($0): \($1)" }.sorted().joined(separator: "\n")
                            let content = """
                            HEAD \(url.absoluteString)
                            
                            Status: \(http.statusCode)
                            
                            Timing (ms):
                            DNS Lookup: \(dns)
                            TCP Connection: \(tcp)
                            TLS Handshake: \(tls)
                            Server Processing: \(server)
                            
                            \(headers)
                            """
                            let html = HTMLTemplate.headResult(content: content).makeHTML()
                            webView.loadHTMLString(html, baseURL: nil)
                        } else if let error = error {
                            let content = """
                            HEAD \(url.absoluteString)
                            
                            Error: \(error.localizedDescription)
                            
                            Timing (ms):
                            DNS Lookup: \(dns)
                            TCP Connection: \(tcp)
                            TLS Handshake: \(tls)
                            Server Processing: \(server)
                            """
                            let html = HTMLTemplate.headResult(content: content).makeHTML()
                            webView.loadHTMLString(html, baseURL: nil)
                        } else {
                            let content = """
                            HEAD \(url.absoluteString)
                            
                            No response
                            
                            Timing (ms):
                            DNS Lookup: \(dns)
                            TCP Connection: \(tcp)
                            TLS Handshake: \(tls)
                            Server Processing: \(server)
                            """
                            let html = HTMLTemplate.headResult(content: content).makeHTML()
                            webView.loadHTMLString(html, baseURL: nil)
                        }
                    }
                }
                task.resume()
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
                // Skipped; should not occur due to filtering
                break
            }
            
            newMapping.append(pageIndex)
        }
        
        // Remove extra web views if we have more than visible pages
        let visibleCount = visible.count
        if visibleCount < existingCount {
            for indexToRemove in visibleCount ..< existingCount {
                result.removed.append(existingWebViews[indexToRemove])
                self.webStackView.removeArrangedSubview(existingWebViews[indexToRemove])
            }
        }
        
        self.webViewPageIndices = newMapping
        
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
        
        // Update the text view to reflect the new page without triggering delegate loops.
        let savedSelection = self.urlsTextView.selectedRanges
        self.textUpdateReason = .modelChanged
        self.urlsTextView.textStorage!.update(from: self.pagesState)
        self.urlsTextView.selectedRanges = savedSelection
        self.textUpdateReason = nil
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
        if !self.pagesState.pages.isEmpty {
            // Preserve selection so the caret doesn't jump unexpectedly
            let savedSelection = self.urlsTextView.selectedRanges
            
            // Determine which page to remove: selected page, else last non-blank visible page, else last
            let indexToRemove: Int
            if let selected = self.selectedPageIndex {
                indexToRemove = selected
            } else if let lastVisible = self.pagesState.pages.lastIndex(where: { $0 != .blank }) {
                indexToRemove = lastVisible
            } else {
                indexToRemove = self.pagesState.pages.count - 1
            }
            
            // If that page has a visible web view, remove that specific web view immediately
            if self.pagesState.pages[indexToRemove] != .blank,
               let webIndex = self.webViewPageIndices.firstIndex(of: indexToRemove),
               webIndex < self.webStackView.arrangedSubviews.count {
                let view = self.webStackView.arrangedSubviews[webIndex]
                self.webStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            
            // Remove the page from the model
            self.pagesState.pages.remove(at: indexToRemove)
            
            // Update remaining web views to reflect the new state
            self.updateWebViews()
            
            // Update the text view content to reflect the removed page
            self.textUpdateReason = .modelChanged
            self.urlsTextView.textStorage!.update(from: self.pagesState)
            self.urlsTextView.selectedRanges = savedSelection
            self.textUpdateReason = nil
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
        guard let webIndex = webStackView.arrangedSubviews.firstIndex(of: webView) else { return }
        guard webIndex < webViewPageIndices.count else { return }
        let pageIndex = webViewPageIndices[webIndex]
        guard let url = webView.url else { return }
        // Update the model and reflect redirects in the URL text view.
        switch self.pagesState.pages[pageIndex] {
        case .web:
            self.pagesState.pages[pageIndex] = Model.Page.web(url: url)
            // Refresh the URL field to reflect the redirected URL without triggering delegate loops.
            let savedSelection = self.urlsTextView.selectedRanges
            self.textUpdateReason = .navigationUpdate
            self.urlsTextView.textStorage!.update(from: self.pagesState)
            self.urlsTextView.selectedRanges = savedSelection
            self.textUpdateReason = nil
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
	
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Command-click: open link as a new Page entry in the text field (not a new window)
        if navigationAction.navigationType == .linkActivated,
           navigationAction.modifierFlags.contains(.command),
           let url = navigationAction.request.url {
            // Insert after the page corresponding to this web view if possible
            if let webIndex = webStackView.arrangedSubviews.firstIndex(of: webView),
               webIndex < webViewPageIndices.count {
                let pageIndex = webViewPageIndices[webIndex]
                let insertIndex = min(pageIndex + 1, self.pagesState.pages.count)
                self.pagesState.pages.insert(.web(url: url), at: insertIndex)
            } else {
                self.pagesState.pages.append(.web(url: url))
            }
            
            // Update UI: web views and text field
            self.updateWebViews()
            let savedSelection = self.urlsTextView.selectedRanges
            self.textUpdateReason = .modelChanged
            self.urlsTextView.textStorage!.update(from: self.pagesState)
            self.urlsTextView.selectedRanges = savedSelection
            self.textUpdateReason = nil
            
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
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
            let savedSelection = self.urlsTextView.selectedRanges
            self.textUpdateReason = .userCommitted
            self.urlsTextView.textStorage!.update(from: self.pagesState)
            self.urlsTextView.selectedRanges = savedSelection
            self.textUpdateReason = nil
        }
        
        self.needsUpdate = false
    }

    private func isInsertionAtEndOfLine(_ textView: NSTextView) -> Bool {
        let nsString = textView.string as NSString
        let sel = textView.selectedRange()
        // Only consider a single insertion point as eligible
        guard sel.length == 0 else { return false }
        var contentsEnd = 0
        nsString.getLineStart(nil, end: nil, contentsEnd: &contentsEnd, for: sel)
        return sel.location == contentsEnd
    }
    
    private func lineStartLocation(of lineIndex: Int, in nsText: NSString) -> Int {
        var pos = 0
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        for _ in 0...lineIndex {
            nsText.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: pos, length: 0))
            pos = lineEnd
        }
        return lineStart
    }
    
    @discardableResult
    private func moveSelectedLine(delta: Int) -> Bool {
        guard let currentIndex = self.selectedPageIndex else { return false }
        let targetIndex = currentIndex + delta
        guard targetIndex >= 0 && targetIndex < self.pagesState.parsedPages.count else { return false }
        
        var pagesState = self.pagesState
        pagesState.parsedPages.swapAt(currentIndex, targetIndex)
        self.pagesState = pagesState
        
        // Update UI
        self.updateWebViews()
        self.textUpdateReason = .modelChanged
        self.urlsTextView.textStorage!.update(from: self.pagesState)
        
        // Place caret at start of moved line
        let nsText = self.urlsTextView.string as NSString
        let newLoc = self.lineStartLocation(of: targetIndex, in: nsText)
        self.urlsTextView.setSelectedRange(NSRange(location: newLoc, length: 0))
        self.textUpdateReason = nil
        
        return true
    }
    
	func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Option-Up/Down: move current line up/down (VS Code behavior)
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.option) {
            if commandSelector == #selector(NSResponder.moveToBeginningOfParagraph(_:)) || commandSelector == #selector(NSResponder.moveUp(_:)) {
                if moveSelectedLine(delta: -1) { return true }
            } else if commandSelector == #selector(NSResponder.moveToEndOfParagraph(_:)) || commandSelector == #selector(NSResponder.moveDown(_:)) {
                if moveSelectedLine(delta: 1) { return true }
            }
        }
        
        // Shift-Return inserts a newline anywhere
        if commandSelector == #selector(NSTextView.insertLineBreak(_:)) {
            return false // allow newline insertion
        }
        
        // Plain Return: if caret is at end-of-line, insert newline; otherwise commit
        if commandSelector == #selector(NSTextView.insertNewline(_:)) {
            if isInsertionAtEndOfLine(textView) {
                return false // allow newline insertion at end-of-line
            } else {
                self.needsUpdate = true
                self.updatePagesFromText(commitSearches: true)
                return true // handled: prevent newline insertion (commit instead)
            }
        }
        
        // Focus the selected web view on Tab
        if commandSelector == #selector(NSTextView.insertTab(_:)) {
            guard let pageIndex = self.selectedPageIndex else { return true }
            guard let webIndex = self.webViewPageIndices.firstIndex(of: pageIndex) else { return true }
            
            let views = webStackView.arrangedSubviews
            guard webIndex < views.count else { return true }
            if let webView = views[webIndex] as? WKWebView {
                webView.scrollToVisible(webView.bounds)
                self.view.window?.makeFirstResponder(webView)
            } else {
                let view = views[webIndex]
                view.scrollToVisible(view.bounds)
                self.view.window?.makeFirstResponder(view)
            }
            
            return true // handled: prevent a tab character from being inserted
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
        if textUpdateReason != nil { return }
        
        self.updatePagesFromText(commitSearches: self.needsUpdate)
	}
	
	func textViewDidChangeSelection(_ notification: Notification) {
        guard let pageIndex = self.selectedPageIndex else { return }
        guard let webIndex = self.webViewPageIndices.firstIndex(of: pageIndex) else { return }
        
        let views = webStackView.arrangedSubviews
        guard webIndex < views.count else { return }
        let view = views[webIndex]
        view.scrollToVisible(view.bounds)
	}
}

