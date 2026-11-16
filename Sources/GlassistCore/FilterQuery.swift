import Foundation

public enum FilterQuery {
    // Only split the documented top-level grouping operator. Preserve escaped literal commas.
    public static func groups(_ query: String) throws -> [String] {
        var groups: [String] = [], buffer = "", depth = 0, escaped = false, quoted = false
        for character in query {
            if escaped { buffer.append(character); escaped = false; continue }
            if character == "\\" { buffer.append(character); escaped = true; continue }
            if character == "\"" { quoted.toggle() }
            if !quoted {
                if character == "(" { depth += 1 }
                if character == ")" { depth -= 1 }
                if depth < 0 { throw APIError.invalidFilter }
                if character == ",", depth == 0 {
                    groups.append(buffer.trimmingCharacters(in: .whitespacesAndNewlines)); buffer = ""; continue
                }
            }
            buffer.append(character)
        }
        groups.append(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !quoted, !escaped, depth == 0, !groups.contains(where: \.isEmpty) else { throw APIError.invalidFilter }
        return groups
    }
}
