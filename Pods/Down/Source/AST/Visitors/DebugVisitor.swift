//
//  DebugVisitor.swift
//  Down
//
//  Created by John Nguyen on 09.04.19.
//

import Foundation

/// This visitor will generate the debug description of an entire abstract syntax tree,
/// indicating relationships between nodes with indentation.
public class DebugVisitor: Visitor {
    
    private var depth = 0

    private var indent: String {
        return String(repeating: "    ", count: depth)
    }

    public init() {}

    private func report(_ node: Node) -> String {
        return "\(indent)\(node is Document ? "" : "↳ ")\(String(reflecting: node))\n"
    }

    private func reportWithChildren(_ node: Node) -> String {
        let thisNode = report(node)
        depth += 1
        let children = visitChildren(of: node).joined()
        depth -= 1
        return "\(thisNode)\(children)"
    }

    // MARK: - Visitor

    public typealias Result = String

    public func visit(document node: Document) -> String {
        return reportWithChildren(node)
    }

    public func visit(blockQuote node: BlockQuote) -> String {
        return reportWithChildren(node)
    }

    public func visit(list node: List) -> String {
        return reportWithChildren(node)
    }

    public func visit(item node: Item) -> String {
        return reportWithChildren(node)
    }

    public func visit(codeBlock node: CodeBlock) -> String {
        return reportWithChildren(node)
    }

    public func visit(htmlBlock node: HtmlBlock) -> String {
        return reportWithChildren(node)
    }

    public func visit(customBlock node: CustomBlock) -> String {
        return reportWithChildren(node)
    }

    public func visit(paragraph node: Paragraph) -> String {
        return reportWithChildren(node)
    }

    public func visit(heading node: Heading) -> String {
        return reportWithChildren(node)
    }

    public func visit(thematicBreak node: ThematicBreak) -> String {
        return report(node)
    }

    public func visit(text node: Text) -> String {
        return report(node)
    }

    public func visit(softBreak node: SoftBreak) -> String {
        return report(node)
    }

    public func visit(lineBreak node: LineBreak) -> String {
        return report(node)
    }

    public func visit(code node: Code) -> String {
        return report(node)
    }

    public func visit(htmlInline node: HtmlInline) -> String {
        return report(node)
    }

    public func visit(customInline node: CustomInline) -> String {
        return report(node)
    }

    public func visit(emphasis node: Emphasis) -> String {
        return reportWithChildren(node)
    }

    public func visit(strong node: Strong) -> String {
        return reportWithChildren(node)
    }

    public func visit(link node: Link) -> String {
        return reportWithChildren(node)
    }

    public func visit(image node: Image) -> String {
        return reportWithChildren(node)
    }
}

