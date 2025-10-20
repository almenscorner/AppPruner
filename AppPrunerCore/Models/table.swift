//
//  table.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-20.
//

import Foundation

struct Table {
	let headers: [String]
	let rows: [[String]]
	
	func render() {
        func visibleWidth(_ s: String) -> Int {
            var count = 0
            var i = s.startIndex
            var inEscape = false
            while i < s.endIndex {
                let ch = s[i]
                if ch == "\u{001B}" { // ESC
                    inEscape = true
                    i = s.index(after: i)
                    continue
                }
                if inEscape {
                    if ch == "m" { inEscape = false }
                    i = s.index(after: i)
                    continue
                }
                count += 1
                i = s.index(after: i)
            }
            return count
        }

        // Clip a string to a maximum visible width, preserving ANSI sequences
        func clipToVisibleWidth(_ s: String, maxWidth: Int) -> String {
            if maxWidth <= 0 { return "" }
            var out = String()
            out.reserveCapacity(s.count)
            var i = s.startIndex
            var visible = 0
            var inEscape = false
            while i < s.endIndex {
                let ch = s[i]
                let next = s.index(after: i)
                if ch == "\u{001B}" {
                    inEscape = true
                    out.append(ch)
                    i = next
                    continue
                }
                if inEscape {
                    out.append(ch)
                    if ch == "m" { inEscape = false }
                    i = next
                    continue
                }
                if visible >= maxWidth { break }
                out.append(ch)
                visible += 1
                i = next
            }
            return out
        }

        // 1. Compute column widths based on headers' visible width
        var colWidths = headers.map { visibleWidth($0) }
        for row in rows {
            for (i, cell) in row.enumerated() {
                if i >= colWidths.count { break }
                let w = visibleWidth(cell)
                if w > colWidths[i] { colWidths[i] = w }
            }
        }

        func line() {
            let segments = colWidths.map { width -> String in
                let count = max(0, width + 2)
                return String(repeating: "-", count: count)
            }
            print("+" + segments.joined(separator: "+") + "+")
        }

        func row(_ values: [String]) {
            var out = "|"
            // Only render up to the number of columns defined by headers
            let limit = min(values.count, colWidths.count)
            for i in 0..<limit {
                // Clip to column width by visible chars, then pad based on visible width
                let clipped = clipToVisibleWidth(values[i], maxWidth: colWidths[i])
                let pad = max(0, colWidths[i] - visibleWidth(clipped))
                out += " " + clipped + String(repeating: " ", count: pad + 1) + "|"
            }
            // If there are fewer values than headers, fill the rest with spaces
            if limit < colWidths.count {
                for i in limit..<colWidths.count {
                    let pad = max(0, colWidths[i])
                    out += " " + String(repeating: " ", count: pad) + "|"
                }
            }
            print(out)
        }

        // 2. Print table
        line()
        let boldHeaders = headers.map { "\u{001B}[1m" + $0 + "\u{001B}[0m" }
        row(boldHeaders)
        line()
        for r in rows { row(r) }
        line()
    }
}
