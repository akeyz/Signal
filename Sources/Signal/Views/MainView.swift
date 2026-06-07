import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Tab Bar
            HStack(spacing: 0) {
                TabButton(title: NSLocalizedString("Status Control", comment: ""), icon: "circle.grid.2x2", isActive: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(title: NSLocalizedString("Claude History", comment: ""), icon: "bubble.left.and.bubble.right", isActive: selectedTab == 1) {
                    selectedTab = 1
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
                .padding(.top, 8)
            
            // Tab Contents
            Group {
                if selectedTab == 0 {
                    StatusControlView(viewModel: viewModel)
                } else {
                    ClaudeHistoryView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 350, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(isActive ? .accentColor : .secondary)
                
                // Active Underline Indicator
                Rectangle()
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
