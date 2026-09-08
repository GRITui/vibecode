import Foundation

/// A roadmap item parsed from a markdown table row in `BACKLOG.md`.
public struct RoadmapItem: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let status: String
    public let notes: String

    public init(id: String, title: String, status: String, notes: String) {
        self.id = id
        self.title = title
        self.status = status
        self.notes = notes
    }
}

/// A named backlog section containing roadmap items.
public struct RoadmapSection: Codable, Equatable, Sendable {
    public let name: String
    public let items: [RoadmapItem]

    public init(name: String, items: [RoadmapItem]) {
        self.name = name
        self.items = items
    }
}

/// Pure, dependency-free parser for the `BACKLOG.md` roadmap format.
///
/// Parses every `| ... | ... |` table found under markdown `##` sections and
/// normalizes status emojis/text to `done`, `in_progress`, or `todo`.
public enum BacklogParser {
    public static func parse(_ markdown: String) -> [RoadmapSection] {
        let lines = markdown.components(separatedBy: .newlines)
        var sections: [String: [RoadmapItem]] = [:]
        var sectionOrder: [String] = []
        var currentSection = "Uncategorized"

        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("## ") {
                currentSection = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if !sectionOrder.contains(currentSection) {
                    sectionOrder.append(currentSection)
                }
                index += 1
                continue
            }

            if trimmed.hasPrefix("|") {
                var tableLines: [String] = []
                while index < lines.count {
                    let tableLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if tableLine.hasPrefix("|") {
                        tableLines.append(tableLine)
                        index += 1
                    } else {
                        break
                    }
                }

                if tableLines.count >= 2 {
                    let rows = tableLines.map(splitCells)
                    let header = rows[0].map { $0.lowercased() }
                    let dataRows = rows.dropFirst(2)

                    for row in dataRows {
                        if let item = parseRow(row, header: header) {
                            sections[currentSection, default: []].append(item)
                        }
                    }
                }
                continue
            }

            index += 1
        }

        return sectionOrder.compactMap { name in
            guard let items = sections[name], !items.isEmpty else { return nil }
            return RoadmapSection(name: name, items: items)
        }
    }

    // MARK: - Internal helpers

    static func splitCells(_ line: String) -> [String] {
        var cells = line
            .components(separatedBy: "|")
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.last?.isEmpty == true {
            cells.removeLast()
        }
        return Array(cells)
    }

    static func parseRow(_ row: [String], header: [String]) -> RoadmapItem? {
        guard let statusIndex = header.firstIndex(of: "status") else { return nil }

        let titleCandidates = [
            "feature", "check", "action", "endpoint", "command",
            "issue", "item", "config", "strategy"
        ]
        guard let titleIndex = header.firstIndex(where: { titleCandidates.contains($0) }) else {
            return nil
        }

        let idIndex = header.firstIndex(of: "id")
        let notesIndex = header.firstIndex(where: { $0 == "notes" || $0 == "description" })
        let methodIndex = header.firstIndex(of: "method")

        let rawTitle = row[titleIndex]
        let title: String
        if let methodIndex = methodIndex, row.count > methodIndex {
            title = "\(row[methodIndex]) \(rawTitle)"
        } else {
            title = rawTitle
        }

        let id = idIndex.map { row.count > $0 ? row[$0] : "" } ?? ""
        let status = normalizeStatus(row.count > statusIndex ? row[statusIndex] : "")
        let notes = notesIndex.map { row.count > $0 ? row[$0] : "" } ?? ""

        return RoadmapItem(id: id, title: title, status: status, notes: notes)
    }

    static func normalizeStatus(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("✅") || lower.contains("done") || lower.contains("implemented") || lower.contains("available") || lower.contains("closed") {
            return "done"
        }
        if lower.contains("🚧") || lower.contains("in progress") || lower.contains("partially") {
            return "in_progress"
        }
        return "todo"
    }
}
