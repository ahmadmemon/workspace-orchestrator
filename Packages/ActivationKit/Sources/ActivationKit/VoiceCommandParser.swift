import Foundation

public enum VoiceCommand: Equatable, Sendable { case runScene(String); case stopCurrent; case cancelCurrent; case showDashboard; case showScenes; case showHistory; case unknown(String) }
public enum SceneMatch: Equatable, Sendable { case exact(String); case suggested(String, score: Double); case ambiguous([String]); case none }
public enum VoiceCommandParser {
    public static func parse(_ transcript: String) -> VoiceCommand {
        let normalized = normalize(transcript)
        if ["stop current workspace", "stop workspace"].contains(normalized) { return .stopCurrent }
        if ["cancel current run", "cancel run"].contains(normalized) { return .cancelCurrent }
        if ["show dashboard", "open dashboard"].contains(normalized) { return .showDashboard }
        if ["show scenes", "open scenes"].contains(normalized) { return .showScenes }
        if ["show history", "open history"].contains(normalized) { return .showHistory }
        for prefix in ["open ", "start ", "run "] where normalized.hasPrefix(prefix) { let name = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces); if !name.isEmpty { return .runScene(name) } }
        return .unknown(transcript)
    }
    public static func match(sceneQuery: String, sceneNames: [String]) -> SceneMatch {
        let query = normalize(sceneQuery); let normalized = sceneNames.map { ($0, normalize($0)) }
        if let exact = normalized.first(where: { $0.1 == query }) { return .exact(exact.0) }
        let scored = normalized.map { ($0.0, similarity(query, $0.1)) }.filter { $0.1 >= 0.62 }.sorted { $0.1 > $1.1 }
        guard let best = scored.first else { return .none }
        if scored.count > 1, best.1 - scored[1].1 < 0.08 { return .ambiguous(scored.prefix(3).map(\.0)) }
        return .suggested(best.0, score: best.1)
    }
    private static func normalize(_ value: String) -> String { value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ") }
    private static func similarity(_ left: String, _ right: String) -> Double { guard !left.isEmpty, !right.isEmpty else { return 0 }; let a = Array(left), b = Array(right); var previous = Array(0...b.count); for (i, x) in a.enumerated() { var current = [i + 1]; for (j, y) in b.enumerated() { current.append(min(current[j] + 1, previous[j + 1] + 1, previous[j] + (x == y ? 0 : 1))) }; previous = current }; return 1 - Double(previous[b.count]) / Double(max(a.count, b.count)) }
}
