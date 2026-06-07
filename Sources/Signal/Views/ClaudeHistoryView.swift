import SwiftUI

struct ClaudeHistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoadingSessions {
                    VStack {
                        Spacer()
                        ProgressView(NSLocalizedString("Loading...", comment: ""))
                            .progressViewStyle(.circular)
                        Spacer()
                    }
                } else if viewModel.claudeSessions.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(NSLocalizedString("No conversation history", comment: ""))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.claudeSessions) { session in
                                NavigationLink(value: session) {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.all, 12)
                    }
                }
            }
            .navigationDestination(for: ClaudeSession.self) { session in
                ClaudeDetailView(session: session)
            }
            .onAppear {
                viewModel.loadClaudeSessions(forceReload: true)
            }
        }
    }
}

struct SessionRow: View {
    let session: ClaudeSession
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                // Title (first prompt)
                Text(session.prompts.first?.display ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Chevron icon
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.top, 2)
            }
            
            HStack(spacing: 8) {
                // Project Badge
                HStack(spacing: 3) {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                    Text(session.projectName)
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(4)
                
                // Message Count Badge
                HStack(spacing: 3) {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 9))
                    Text("\(session.prompts.count) \(NSLocalizedString("prompts", comment: ""))")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                // Timestamp
                Text(formatTimestamp(session.lastTimestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.all, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let diff = Date().timeIntervalSince(date)
        
        // Relative formatting
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        
        // If it's more than a few days old, format as Date
        if diff > 86400 * 3 {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        return relative
    }
}
