import Foundation

struct HistoryLine: Codable, Identifiable, Hashable {
    var id: String { sessionId + "-\(timestamp)" }
    let display: String
    let timestamp: Int64
    let project: String
    let sessionId: String
}

struct ClaudeSession: Identifiable, Hashable {
    var id: String { sessionId }
    let sessionId: String
    let projectPath: String
    let projectName: String
    let lastTimestamp: Int64
    let prompts: [HistoryLine]
}

class ClaudeHistoryLoader {
    static func loadHistory(completion: @escaping ([ClaudeSession]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let historyURL = home.appendingPathComponent(".claude/history.jsonl")
            
            guard FileManager.default.fileExists(atPath: historyURL.path) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            do {
                let content = try String(contentsOf: historyURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                
                var allLines: [HistoryLine] = []
                let decoder = JSONDecoder()
                
                var uniqueSessionIds = Set<String>()
                let sessionLimit = 80
                
                // Parse lines in reverse order (newest first) to minimize CPU and RAM
                for line in lines.reversed() {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    if let data = trimmed.data(using: .utf8),
                       let historyLine = try? decoder.decode(HistoryLine.self, from: data) {
                        
                        let sid = historyLine.sessionId
                        if uniqueSessionIds.contains(sid) {
                            allLines.append(historyLine)
                        } else if uniqueSessionIds.count < sessionLimit {
                            uniqueSessionIds.insert(sid)
                            allLines.append(historyLine)
                        }
                    }
                }
                
                let grouped = Dictionary(grouping: allLines, by: { $0.sessionId })
                
                var sessions: [ClaudeSession] = []
                for (sessionId, lines) in grouped {
                    let sortedLines = lines.sorted(by: { $0.timestamp < $1.timestamp })
                    guard let lastLine = sortedLines.last else { continue }
                    let projectPath = lastLine.project
                    let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                    
                    let session = ClaudeSession(
                        sessionId: sessionId,
                        projectPath: projectPath,
                        projectName: projectName,
                        lastTimestamp: lastLine.timestamp,
                        prompts: sortedLines
                    )
                    sessions.append(session)
                }
                
                // Sort by lastTimestamp descending
                sessions.sort(by: { $0.lastTimestamp > $1.lastTimestamp })
                
                DispatchQueue.main.async {
                    completion(sessions)
                }
            } catch {
                print("Error loading Claude history: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
}
