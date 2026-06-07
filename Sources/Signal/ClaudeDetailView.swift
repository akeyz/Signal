import SwiftUI

struct ClaudeDetailView: View {
    let session: ClaudeSession
    @Environment(\.dismiss) private var dismiss
    
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
                
                Text(NSLocalizedString("User Prompts", comment: ""))
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
            .background(Color(NSColor.windowBackgroundColor))
            
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
                            Text("Session ID:")
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
                    
                    // Chronological Prompts List
                    ForEach(session.prompts) { prompt in
                        PromptBubbleView(prompt: prompt)
                    }
                }
                .padding(.all, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PromptBubbleView: View {
    let prompt: HistoryLine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Prompt Card
            VStack(alignment: .leading, spacing: 0) {
                Text(prompt.display)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
            }
            .padding(.all, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(10)
            
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
