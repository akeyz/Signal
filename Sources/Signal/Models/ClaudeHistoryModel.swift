import Foundation

struct HistoryLine: Codable, Identifiable, Hashable {
    var id: String { sessionId + "-\(timestamp)" }
    let display: String
    let timestamp: Int64
    let project: String
    let sessionId: String
}

enum ToolType: String, Codable, CaseIterable, Identifiable {
    case claude = "Claude"
    case openCode = "OpenCode"
    case pi = "Pi"
    case trae = "Trae"
    
    var id: String { self.rawValue }
}

struct HistorySession: Identifiable, Hashable {
    var id: String { sessionId }
    let toolType: ToolType
    let sessionId: String
    let projectPath: String
    let projectName: String
    let lastTimestamp: Int64
    let prompts: [HistoryLine]
}

typealias ClaudeSession = HistorySession

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
    static func loadPiHistory(completion: @escaping ([HistorySession]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let sessionsURL = home.appendingPathComponent(".pi/agent/sessions")
            
            guard FileManager.default.fileExists(atPath: sessionsURL.path) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            var sessions: [HistorySession] = []
            let fileManager = FileManager.default
            let decoder = JSONDecoder()
            
            struct PiSessionStart: Codable {
                let type: String
                let id: String
                let timestamp: String
                let cwd: String
            }
            
            struct PiLine: Codable {
                let type: String
                let message: PiMessage?
            }
            
            struct PiMessage: Codable {
                let role: String
                let content: SessionContent?
                let timestamp: Int64?
            }
            
            if let projectDirs = try? fileManager.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: nil) {
                for projectDir in projectDirs {
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue {
                        if let files = try? fileManager.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil) {
                            for file in files where file.pathExtension == "jsonl" {
                                do {
                                    let content = try String(contentsOf: file, encoding: .utf8)
                                    let lines = content.components(separatedBy: .newlines)
                                    
                                    guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                                          !firstLine.isEmpty,
                                          let firstData = firstLine.data(using: .utf8),
                                          let sessionStart = try? decoder.decode(PiSessionStart.self, from: firstData) else {
                                        continue
                                    }
                                    
                                    let sessionId = sessionStart.id
                                    let projectPath = sessionStart.cwd
                                    let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                                    
                                    var prompts: [HistoryLine] = []
                                    
                                    for line in lines.dropFirst() {
                                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if trimmed.isEmpty { continue }
                                        
                                        guard let lineData = trimmed.data(using: .utf8),
                                              let parsedLine = try? decoder.decode(PiLine.self, from: lineData) else {
                                            continue
                                        }
                                        
                                        if parsedLine.type == "message", let msg = parsedLine.message, msg.role == "user" {
                                            var text = ""
                                            if let content = msg.content {
                                                switch content {
                                                case .string(let str):
                                                    text = str
                                                case .array(let blocks):
                                                    text = blocks.compactMap { $0.text }.joined(separator: "\n")
                                                }
                                            }
                                            
                                            let timestamp: Int64
                                            if let ts = msg.timestamp {
                                                timestamp = ts
                                            } else {
                                                let attrs = try? fileManager.attributesOfItem(atPath: file.path)
                                                let creationDate = attrs?[.creationDate] as? Date ?? Date()
                                                timestamp = Int64(creationDate.timeIntervalSince1970 * 1000)
                                            }
                                            
                                            let historyLine = HistoryLine(
                                                display: text,
                                                timestamp: timestamp,
                                                project: projectPath,
                                                sessionId: sessionId
                                            )
                                            prompts.append(historyLine)
                                        }
                                    }
                                    
                                    if !prompts.isEmpty {
                                        let lastTimestamp = prompts.last?.timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
                                        let session = HistorySession(
                                            toolType: .pi,
                                            sessionId: sessionId,
                                            projectPath: projectPath,
                                            projectName: projectName,
                                            lastTimestamp: lastTimestamp,
                                            prompts: prompts
                                        )
                                        sessions.append(session)
                                    }
                                } catch {
                                    // Ignore individual file parse errors
                                }
                            }
                        }
                    }
                }
            }
            
            sessions.sort(by: { $0.lastTimestamp > $1.lastTimestamp })
            DispatchQueue.main.async {
                completion(sessions)
            }
        }
    }
    
    static func loadPiReplies(projectPath: String, sessionId: String, completion: @escaping ([Int64: AssistantResponse]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let fm = FileManager.default
            let escapedProject = projectPath
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .replacingOccurrences(of: "/", with: "-")
            let projectDir = home.appendingPathComponent(".pi/agent/sessions/--\(escapedProject)--")
            
            guard fm.fileExists(atPath: projectDir.path) else {
                DispatchQueue.main.async { completion([:]) }
                return
            }
            
            var replies: [Int64: AssistantResponse] = [:]
            
            if let files = try? fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "jsonl" && file.lastPathComponent.contains(sessionId) {
                    do {
                        let content = try String(contentsOf: file, encoding: .utf8)
                        let lines = content.components(separatedBy: .newlines)
                        
                        let decoder = JSONDecoder()
                        
                        struct PiLine: Codable {
                            let type: String
                            let message: PiMessage?
                        }
                        
                        struct PiMessage: Codable {
                            let role: String
                            let content: SessionContent?
                            let timestamp: Int64?
                        }
                        
                        var currentPromptTimestamp: Int64? = nil
                        var accumulatedText: [String] = []
                        var accumulatedThinking: [String] = []
                        
                        for line in lines.dropFirst() {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty { continue }
                            
                            guard let lineData = trimmed.data(using: .utf8),
                                  let parsedLine = try? decoder.decode(PiLine.self, from: lineData) else {
                                continue
                            }
                            
                            if parsedLine.type == "message", let msg = parsedLine.message {
                                if msg.role == "user" {
                                    if let prevTimestamp = currentPromptTimestamp {
                                        let text = accumulatedText.joined(separator: "\n")
                                        let thinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking.joined(separator: "\n")
                                        replies[prevTimestamp] = AssistantResponse(thinking: thinking, text: text)
                                    }
                                    
                                    accumulatedText = []
                                    accumulatedThinking = []
                                    
                                    if let ts = msg.timestamp {
                                        currentPromptTimestamp = ts
                                    } else {
                                        currentPromptTimestamp = nil
                                    }
                                } else if msg.role == "assistant" {
                                    if let content = msg.content {
                                        switch content {
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
                        }
                        
                        if let prevTimestamp = currentPromptTimestamp {
                            let text = accumulatedText.joined(separator: "\n")
                            let thinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking.joined(separator: "\n")
                            replies[prevTimestamp] = AssistantResponse(thinking: thinking, text: text)
                        }
                    } catch {
                        // ignore
                    }
                    break
                }
            }
            
            DispatchQueue.main.async {
                completion(replies)
            }
        }
    }

    static func loadOpenCodeHistory(completion: @escaping ([HistorySession]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dbPath = home.appendingPathComponent(".local/share/opencode/opencode.db").path
            
            guard FileManager.default.fileExists(atPath: dbPath),
                  let db = SQLiteDatabase(path: dbPath) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            var sessions: [HistorySession] = []
            
            let sessionsQuery = "select id, title, directory, time_created from session order by time_created desc"
            let sessionRows = db.query(sql: sessionsQuery)
            
            for row in sessionRows {
                guard let id = row["id"], !id.isEmpty,
                      let directory = row["directory"],
                      let timeCreatedStr = row["time_created"],
                      let timeCreated = Int64(timeCreatedStr) else {
                    continue
                }
                
                let projectName = URL(fileURLWithPath: directory).lastPathComponent
                
                let promptsQuery = """
                select part.id, part.data, part.time_created 
                from part 
                join message on part.message_id = message.id 
                where part.session_id = ? 
                  and json_extract(message.data, '$.role') = 'user' 
                  and json_extract(part.data, '$.type') = 'text' 
                order by part.time_created
                """
                let promptRows = db.query(sql: promptsQuery, parameters: [id])
                
                var prompts: [HistoryLine] = []
                for pRow in promptRows {
                    guard let partDataStr = pRow["data"],
                          let timeCreatedStr = pRow["time_created"],
                          let timeCreated = Int64(timeCreatedStr) else {
                        continue
                    }
                    
                    struct OpenCodePartData: Codable {
                        let text: String?
                    }
                    if let data = partDataStr.data(using: .utf8),
                       let partData = try? JSONDecoder().decode(OpenCodePartData.self, from: data),
                       let text = partData.text {
                        let line = HistoryLine(
                            display: text,
                            timestamp: timeCreated,
                            project: directory,
                            sessionId: id
                        )
                        prompts.append(line)
                    }
                }
                
                if !prompts.isEmpty {
                    let lastTimestamp = prompts.last?.timestamp ?? timeCreated
                    let session = HistorySession(
                        toolType: .openCode,
                        sessionId: id,
                        projectPath: directory,
                        projectName: projectName,
                        lastTimestamp: lastTimestamp,
                        prompts: prompts
                    )
                    sessions.append(session)
                }
            }
            
            sessions.sort(by: { $0.lastTimestamp > $1.lastTimestamp })
            DispatchQueue.main.async {
                completion(sessions)
            }
        }
    }

    static func loadOpenCodeReplies(sessionId: String, completion: @escaping ([Int64: AssistantResponse]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dbPath = home.appendingPathComponent(".local/share/opencode/opencode.db").path
            
            guard FileManager.default.fileExists(atPath: dbPath),
                  let db = SQLiteDatabase(path: dbPath) else {
                DispatchQueue.main.async { completion([:]) }
                return
            }
            
            var replies: [Int64: AssistantResponse] = [:]
            
            let querySql = """
            select message.id as msg_id, 
                   json_extract(message.data, '$.role') as role, 
                   json_extract(part.data, '$.type') as part_type,
                   json_extract(part.data, '$.text') as part_text, 
                   part.time_created 
            from part 
            join message on part.message_id = message.id 
            where part.session_id = ? 
              and (part_type = 'text' or part_type = 'reasoning') 
            order by part.time_created
            """
            let rows = db.query(sql: querySql, parameters: [sessionId])
            
            var currentPromptTimestamp: Int64? = nil
            var accumulatedText: [String] = []
            var accumulatedThinking: [String] = []
            
            for row in rows {
                guard let role = row["role"],
                      let partType = row["part_type"],
                      let partText = row["part_text"],
                      let timeCreatedStr = row["time_created"],
                      let timeCreated = Int64(timeCreatedStr) else {
                    continue
                }
                
                if role == "user" {
                    if let prevTimestamp = currentPromptTimestamp {
                        let text = accumulatedText.joined(separator: "\n")
                        let thinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking.joined(separator: "\n")
                        replies[prevTimestamp] = AssistantResponse(thinking: thinking, text: text)
                    }
                    
                    accumulatedText = []
                    accumulatedThinking = []
                    currentPromptTimestamp = timeCreated
                } else if role == "assistant" {
                    if partType == "text" {
                        accumulatedText.append(partText)
                    } else if partType == "reasoning" {
                        accumulatedThinking.append(partText)
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
        }
    }

    static func loadTraeHistory(completion: @escaping ([HistorySession]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let base = home.appendingPathComponent("Library/Application Support/Trae/User/workspaceStorage")
            
            guard FileManager.default.fileExists(atPath: base.path) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            var sessions: [HistorySession] = []
            let fm = FileManager.default
            let decoder = JSONDecoder()
            
            struct TraeInputHistoryEntry: Codable {
                let inputText: String
            }
            
            if let subdirs = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) {
                for dir in subdirs {
                    let dbPath = dir.appendingPathComponent("state.vscdb").path
                    let workspaceJsonPath = dir.appendingPathComponent("workspace.json").path
                    
                    guard fm.fileExists(atPath: dbPath) && fm.fileExists(atPath: workspaceJsonPath) else {
                        continue
                    }
                    
                    var projectPath = ""
                    if let wsData = try? Data(contentsOf: URL(fileURLWithPath: workspaceJsonPath)),
                       let json = try? JSONSerialization.jsonObject(with: wsData) as? [String: Any] {
                        if let folder = json["folder"] as? String {
                            if let url = URL(string: folder) {
                                projectPath = url.path
                            }
                        } else if let configuration = json["configuration"] as? String {
                            if let url = URL(string: configuration) {
                                projectPath = url.path
                            }
                        } else if let workspace = json["workspace"] as? String {
                            if let url = URL(string: workspace) {
                                projectPath = url.path
                            }
                        }
                    }
                    
                    let projectName: String
                    if !projectPath.isEmpty {
                        var name = URL(fileURLWithPath: projectPath).lastPathComponent
                        if name.hasSuffix(".code-workspace") {
                            name = String(name.dropLast(".code-workspace".count))
                        }
                        projectName = name
                    } else {
                        projectName = dir.lastPathComponent
                        projectPath = dir.path
                    }
                    
                    let sessionId = dir.lastPathComponent
                    
                    guard let db = SQLiteDatabase(path: dbPath) else { continue }
                    let rows = db.query(sql: "select value from ItemTable where key = 'icube-ai-agent-storage-input-history'")
                    
                    if let row = rows.first, let value = row["value"],
                       let data = value.data(using: .utf8),
                       let entries = try? decoder.decode([TraeInputHistoryEntry].self, from: data) {
                        
                        var prompts: [HistoryLine] = []
                        let attrs = try? fm.attributesOfItem(atPath: dbPath)
                        let modDate = attrs?[.modificationDate] as? Date ?? Date()
                        var timestamp = Int64(modDate.timeIntervalSince1970 * 1000)
                        
                        for entry in entries {
                            let cleanText = entry.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if cleanText.isEmpty { continue }
                            
                            let line = HistoryLine(
                                display: cleanText,
                                timestamp: timestamp,
                                project: projectPath,
                                sessionId: sessionId
                            )
                            prompts.append(line)
                            timestamp -= 1000
                        }
                        
                        if !prompts.isEmpty {
                            let session = HistorySession(
                                toolType: .trae,
                                sessionId: sessionId,
                                projectPath: projectPath,
                                projectName: projectName,
                                lastTimestamp: prompts.first?.timestamp ?? Int64(modDate.timeIntervalSince1970 * 1000),
                                prompts: prompts
                            )
                            sessions.append(session)
                        }
                    }
                }
            }
            
            sessions.sort(by: { $0.lastTimestamp > $1.lastTimestamp })
            DispatchQueue.main.async {
                completion(sessions)
            }
        }
    }

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

    static func loadHistory(completion: @escaping ([HistorySession]) -> Void) {
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
                
                var sessions: [HistorySession] = []
                for (sessionId, lines) in grouped {
                    let sortedLines = lines.sorted(by: { $0.timestamp < $1.timestamp })
                    guard let lastLine = sortedLines.last else { continue }
                    let projectPath = lastLine.project
                    let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                    
                    let session = HistorySession(
                        toolType: .claude,
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
