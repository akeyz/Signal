import SwiftUI

struct ClaudeDetailView: View {
    let session: ClaudeSession
    @Environment(\.dismiss) private var dismiss
    
    @State private var replies: [Int64: AssistantResponse] = [:]
    @State private var expandedPromptIds: Set<String> = []
    @State private var isLoadingReplies: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Header
            HStack(spacing: 8) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text(NSLocalizedString("Back", comment: ""))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(NSLocalizedString("Conversation Details", comment: ""))
                    .font(.system(size: 13, weight: .bold))
                
                Spacer()
                
                // Invisible placeholder to balance the back button
                Text("Back")
                    .font(.system(size: 13))
                    .opacity(0)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Session Details Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(NSLocalizedString("Project", comment: "") + ":")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(session.projectPath)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                        }
                        
                        HStack {
                            Text(NSLocalizedString("Session ID:", comment: ""))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(session.sessionId)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.all, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(6)
                    
                    // Chronological Prompts List (Time reversed, newest first)
                    let sortedPrompts = session.prompts.sorted(by: { $0.timestamp > $1.timestamp })
                    ForEach(sortedPrompts) { prompt in
                        PromptBubbleView(
                            prompt: prompt,
                            isExpanded: expandedPromptIds.contains(prompt.id),
                            isLoadingReplies: isLoadingReplies,
                            reply: findReply(for: prompt.timestamp),
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    if expandedPromptIds.contains(prompt.id) {
                                        expandedPromptIds.remove(prompt.id)
                                    } else {
                                        expandedPromptIds.insert(prompt.id)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.all, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            isLoadingReplies = true
            ClaudeHistoryLoader.loadReplies(projectPath: session.projectPath, sessionId: session.sessionId) { loadedReplies in
                self.replies = loadedReplies
                self.isLoadingReplies = false
            }
        }
    }
    
    private func findReply(for promptTimestamp: Int64) -> AssistantResponse? {
        let maxDiff: Int64 = 5000 // 5 seconds
        var bestKey: Int64? = nil
        var minDiff = maxDiff
        
        for key in replies.keys {
            let diff = abs(key - promptTimestamp)
            if diff < minDiff {
                minDiff = diff
                bestKey = key
            }
        }
        
        if let key = bestKey {
            return replies[key]
        }
        return nil
    }
}

struct PromptBubbleView: View {
    let prompt: HistoryLine
    let isExpanded: Bool
    let isLoadingReplies: Bool
    let reply: AssistantResponse?
    let onTap: () -> Void
    
    @State private var isPromptHovered = false
    @State private var showThinkingExpanded = false
    @State private var isCopySuccess = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Prompt Card
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(prompt.display)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .padding(.top, 3)
                }
            }
            .padding(.all, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(isPromptHovered ? 0.12 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(10)
            .onHover { hovering in
                isPromptHovered = hovering
            }
            .onTapGesture {
                onTap()
            }
            
            // Expanded Reply Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if isLoadingReplies {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(NSLocalizedString("Loading feedback...", comment: ""))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.leading, 12)
                    } else if let reply = reply {
                        // Thinking Process (if available)
                        if let thinking = reply.thinking, !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showThinkingExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.system(size: 10))
                                        Text(NSLocalizedString("Thinking Process", comment: ""))
                                            .font(.system(size: 10, weight: .bold))
                                        Image(systemName: showThinkingExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 7))
                                    }
                                    .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                
                                if showThinkingExpanded {
                                    Text(thinking)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .padding(.all, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.primary.opacity(0.03))
                                        .cornerRadius(6)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Assistant Reply Bubble
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                Text(NSLocalizedString("Assistant Feedback", comment: ""))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.accentColor)
                                Spacer()
                                
                                // Copy Button
                                Button(action: {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.setString(reply.text, forType: .string)
                                    withAnimation {
                                        isCopySuccess = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            isCopySuccess = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: isCopySuccess ? "checkmark.circle.fill" : "doc.on.doc")
                                            .font(.system(size: 9))
                                        Text(isCopySuccess ? NSLocalizedString("Copied", comment: "") : NSLocalizedString("Copy", comment: ""))
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .foregroundColor(isCopySuccess ? .green : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text(reply.text)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.all, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .cornerRadius(10)
                    } else {
                        // No response found
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text(NSLocalizedString("No reply recorded for this prompt.", comment: ""))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.all, 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.leading, 8)
                .padding(.trailing, 4)
            }
            
            // Timestamp below bubble
            HStack {
                Spacer()
                Text(formatDate(prompt.timestamp))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, 4)
        }
    }
    
    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df.string(from: date)
    }
}
