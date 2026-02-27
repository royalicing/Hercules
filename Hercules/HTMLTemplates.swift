//
//  HTMLTemplates.swift
//  Hercules
//
//  Created by Patrick Smith on 27/3/19.
//  Copyright © 2019 Royal Icing. All rights reserved.
//

import Foundation


struct HTMLPageVariables {
    var textColor: String = "black"
    
    enum TextSize {
        case regular
        case large
    }
    
    enum FontFamily {
        case sansSerif
        case monospace
    }
    
    enum TextAlign {
        case left
        case center
    }
    
    enum FontWeight {
        case normal
        case bold
    }
    
    enum WhiteSpace {
        case normal
        case preWrap
    }
    
    var textSize: TextSize = .large
    var fontFamily: FontFamily = .sansSerif
    var textAlign: TextAlign = .center
    var fontWeight: FontWeight = .bold
    var whiteSpace: WhiteSpace = .normal
    
    // Base font size should be the same across templates
    var baseFontSizePx: Int { 16 }
    
    var headingFontSizeRem: String {
        switch textSize {
        case .regular: return "1rem"
        case .large: return "2rem"
        }
    }
    
    var cssFontFamily: String {
        switch fontFamily {
        case .sansSerif:
            return "-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol"
        case .monospace:
            return "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace"
        }
    }
    
    var cssTextAlign: String {
        switch textAlign {
        case .left: return "left"
        case .center: return "center"
        }
    }
    
    var cssFontWeight: String {
        switch fontWeight {
        case .normal: return "400"
        case .bold: return "700"
        }
    }
    
    var cssWhiteSpace: String {
        switch whiteSpace {
        case .normal: return "normal"
        case .preWrap: return "pre-wrap"
        }
    }
}

extension String {
	func htmlSafe() -> String {
		var htmlSafe = self
		htmlSafe = htmlSafe.replacingOccurrences(of: "<", with: "&lt;")
		htmlSafe = htmlSafe.replacingOccurrences(of: ">", with: "&gt;")
		htmlSafe = htmlSafe.replacingOccurrences(of: "&", with: "&amp;")
		return htmlSafe
	}
}

func generateHTMLPage(content: String, variables: HTMLPageVariables) -> String {
    let html = """
    <!doctype html>
    <head>
    <meta charset=\"utf-8\">
    <style>
    html {
    font-size: \(variables.baseFontSizePx)px;
    }
    * {
    padding: 0;
    margin: 0;
    }
    main {
    height: 100vh; display: flex; align-items: center;
    color: \(variables.textColor.htmlSafe())
    }
    h1 {
    flex-grow: 1;
    text-align: \(variables.cssTextAlign);
    padding: 0.5rem;
    font-family: \(variables.cssFontFamily);
    font-size: \(variables.headingFontSizeRem);
    font-weight: \(variables.cssFontWeight);
    white-space: \(variables.cssWhiteSpace);
    }
    </style>
    </head>
    <html>
    <body>
    <main>
    <h1>\(content.htmlSafe())</h1>
    </main>
    </body>
    </html>
    </div>
    """
    return html
}

enum HTMLTemplate {
    case query(query: String)
    case markdown(content: String)
    case graphQLQuery(query: String)
    case headResult(content: String)
    
    private var textColor: String {
        switch self {
        case .graphQLQuery:
            return "#E10098"
        case .markdown, .headResult:
            return "#111"
        default:
            return "black"
        }
    }
    
    private var textSize: HTMLPageVariables.TextSize {
        switch self {
        case .headResult:
            return .regular
        default:
            return .large
        }
    }
    
    private var fontFamily: HTMLPageVariables.FontFamily {
        switch self {
        case .headResult:
            return .monospace
        default:
            return .sansSerif
        }
    }
    
    private var textAlign: HTMLPageVariables.TextAlign {
        switch self {
        case .headResult:
            return .left
        default:
            return .center
        }
    }
    
    private var fontWeight: HTMLPageVariables.FontWeight {
        switch self {
        case .headResult:
            return .normal
        default:
            return .bold
        }
    }
    
    private var whiteSpace: HTMLPageVariables.WhiteSpace {
        switch self {
        case .headResult:
            return .preWrap
        default:
            return .normal
        }
    }
    
    private var htmlPageVariables: HTMLPageVariables {
        return HTMLPageVariables(
            textColor: self.textColor,
            textSize: self.textSize,
            fontFamily: self.fontFamily,
            textAlign: self.textAlign,
            fontWeight: self.fontWeight,
            whiteSpace: self.whiteSpace
        )
    }
    
    func makeHTML() -> String {
        switch self {
        case let .query(query):
            return generateHTMLPage(content: query, variables: self.htmlPageVariables)
        case let .markdown(markdownContent):
            return generateHTMLPage(content: markdownContent, variables: self.htmlPageVariables)
        case let .graphQLQuery(query):
            return generateHTMLPage(content: query, variables: self.htmlPageVariables)
        case let .headResult(content):
            return generateHTMLPage(content: content, variables: self.htmlPageVariables)
        }
    }
}

