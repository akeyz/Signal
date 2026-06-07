import SwiftUI

struct StatusControlView: View {
    @ObservedObject var viewModel: AppViewModel
    
    // Grid configuration for 2x2 layout
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Section 1: Color Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("Signal – Status Light", comment: ""))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(LightColor.allCases, id: \.self) { color in
                                ColorGridButton(
                                    color: color,
                                    isSelected: viewModel.currentColor == color,
                                    action: { viewModel.selectColor(color) }
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section 2: Preferences
                    VStack(alignment: .leading, spacing: 14) {
                        // Breathing Animation Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Breathing Effect", comment: ""))
                                    .font(.system(size: 13, weight: .medium))
                                if viewModel.currentColor.breathes {
                                    Text(String(format: NSLocalizedString("Breathes every %.1fs", comment: ""), viewModel.currentColor.period))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(NSLocalizedString("Only Red and Yellow breathe", comment: ""))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Toggle(isOn: Binding(
                                get: { viewModel.breathingEnabled },
                                set: { _ in viewModel.toggleBreathing() }
                            )) {
                                EmptyView()
                            }
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(!viewModel.currentColor.breathes && viewModel.currentColor != .black) // Disable if color doesn't breathe, except when Off
                        }
                        
                        // Start at Login Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Start at Login", comment: ""))
                                    .font(.system(size: 13, weight: .medium))
                                Text(NSLocalizedString("Launch automatically on startup", comment: ""))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle(isOn: Binding(
                                get: { viewModel.startAtLogin },
                                set: { _ in viewModel.toggleStartAtLogin() }
                            )) {
                                EmptyView()
                            }
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
                }
                .padding(.all, 16)
            }
            
            Spacer(minLength: 12)
            
            // Section 3: Quit Button at bottom
            Divider()
            
            Button(action: {
                viewModel.quit()
            }) {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 13, weight: .bold))
                    Text(NSLocalizedString("Quit Signal", comment: ""))
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.underPageBackgroundColor).opacity(0.3))
        }
        .onAppear {
            viewModel.refreshStartAtLogin()
        }
    }
}

struct ColorGridButton: View {
    let color: LightColor
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Colored Circle (LED representation)
                Circle()
                    .fill(swiftColor(for: color))
                    .frame(width: 14, height: 14)
                    .shadow(color: swiftColor(for: color).opacity(isSelected ? 0.8 : 0.2), radius: isSelected ? 4 : 1)
                
                Text(cleanLabel(for: color))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.15)
                          : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func cleanLabel(for color: LightColor) -> String {
        // Strip out the leading emoji from the color label for cleaner grid display
        let rawLabel = color.label
        if rawLabel.contains("🔴") { return NSLocalizedString("Red", comment: "") }
        if rawLabel.contains("🟡") { return NSLocalizedString("Yellow", comment: "") }
        if rawLabel.contains("🟢") { return NSLocalizedString("Green", comment: "") }
        if rawLabel.contains("⚪") || rawLabel.contains("⚫") { return NSLocalizedString("Off", comment: "") }
        return rawLabel
    }
    
    private func swiftColor(for color: LightColor) -> Color {
        switch color {
        case .black:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? Color(white: 0.8) : Color(white: 0.2)
        case .red:
            return Color(red: 0.88, green: 0.23, blue: 0.17)
        case .yellow:
            return Color(red: 0.99, green: 0.75, blue: 0.08)
        case .green:
            return Color(red: 0.19, green: 0.64, blue: 0.31)
        }
    }
}
