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

struct AssistantResponse: Codable, Hashable {
    let thinking: String?
    let text: String
}

struct SessionJSONLLine: Codable {
    let type: String
    let timestamp: String?
    let message: SessionMessage?
}

struct SessionMessage: Codable {
    let id: String?
    let role: String?
    let content: SessionContent?
}

enum SessionContent: Codable {
    case string(String)
    case array([SessionContentBlock])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let arr = try? container.decode([SessionContentBlock].self) {
            self = .array(arr)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid content format")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .array(let arr):
            try container.encode(arr)
        }
    }
}

struct SessionContentBlock: Codable {
    let type: String
    let text: String?
    let thinking: String?
}

class ClaudeHistoryLoader {
    static func loadReplies(projectPath: String, sessionId: String, completion: @escaping ([Int64: AssistantResponse]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let escapedProject = projectPath
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ".", with: "-")
            let sessionURL = home.appendingPathComponent(".claude/projects/\(escapedProject)/\(sessionId).jsonl")
            
            guard FileManager.default.fileExists(atPath: sessionURL.path) else {
                DispatchQueue.main.async { completion([:]) }
                return
            }
            
            do {
                let content = try String(contentsOf: sessionURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                
                let decoder = JSONDecoder()
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let isoFormatterFallback = ISO8601DateFormatter()
                isoFormatterFallback.formatOptions = [.withInternetDateTime]
                
                var currentPromptTimestamp: Int64? = nil
                var accumulatedText: [String] = []
                var accumulatedThinking: [String] = []
                var replies: [Int64: AssistantResponse] = [:]
                
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    
                    guard let data = trimmed.data(using: .utf8),
                          let parsedLine = try? decoder.decode(SessionJSONLLine.self, from: data) else {
                        continue
                    }
                    
                    if parsedLine.type == "user" {
                        if let prevTimestamp = currentPromptTimestamp {
                            let text = accumulatedText.joined(separator: "\n")
                            let thinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking.joined(separator: "\n")
                            replies[prevTimestamp] = AssistantResponse(thinking: thinking, text: text)
                        }
                        
                        accumulatedText = []
                        accumulatedThinking = []
                        
                        if let timestampStr = parsedLine.timestamp {
                            let parsedDate = isoFormatter.date(from: timestampStr) ?? isoFormatterFallback.date(from: timestampStr)
                            if let date = parsedDate {
                                currentPromptTimestamp = Int64(date.timeIntervalSince1970 * 1000)
                            } else {
                                currentPromptTimestamp = nil
                            }
                        } else {
                            currentPromptTimestamp = nil
                        }
                    } else if parsedLine.type == "assistant", let message = parsedLine.message {
                        if let contentBlocks = message.content {
                            switch contentBlocks {
                            case .string(let str):
                                accumulatedText.append(str)
                            case .array(let blocks):
                                for block in blocks {
                                    if block.type == "text", let text = block.text {
                                        accumulatedText.append(text)
                                    } else if block.type == "thinking", let thinking = block.thinking {
                                        accumulatedThinking.append(thinking)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let prevTimestamp = currentPromptTimestamp {
                    let text = accumulatedText.joined(separator: "\n")
                    let thinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking.joined(separator: "\n")
                    replies[prevTimestamp] = AssistantResponse(thinking: thinking, text: text)
                }
                
                DispatchQueue.main.async {
                    completion(replies)
                }
            } catch {
                print("Error loading Claude replies: \(error)")
                DispatchQueue.main.async {
                    completion([:])
                }
            }
        }
    }

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
