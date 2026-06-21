import SwiftUI

struct StatusControlView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) var colorScheme
    
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
                            .controlSize(.small)
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
                            .controlSize(.small)
                            .labelsHidden()
                        }
                        
                        // Screen Flash Effect Selector
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Screen Flash Effect", comment: ""))
                                    .font(.system(size: 13, weight: .medium))
                                Text(NSLocalizedString("Gaming-style overlay on color change", comment: ""))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Picker("", selection: $viewModel.screenFlashMode) {
                                ForEach(FlashMode.allCases, id: \.self) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .controlSize(.small)
                            .frame(width: 120)
                        }
                    }
                    
                    Divider()
                    
                    // Section 3: CLI Helper Tool
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("CLI Helper Tool", comment: ""))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(NSLocalizedString("Control Signal directly from your terminal or scripts using the sgnl tool.", comment: ""))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button(action: {
                            viewModel.installCLI()
                        }) {
                            HStack {
                                Image(systemName: "terminal")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(NSLocalizedString("Install 'sgnl' CLI Command", comment: ""))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
            .background(colorScheme == .light ? Color.white : Color(white: 0.15))
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
                // Colored Circle (LED representation using CALayer animation to run on GPU)
                GlowingLEDView(
                    color: color.color,
                    breathes: color.breathes,
                    period: color.period,
                    isSelected: isSelected
                )
                .frame(width: 14, height: 14)
                
                Text(cleanLabel(for: color))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
            }
            .contentShape(Rectangle()) // Fix Point 1: ensures the whole button rect is clickable, not just text
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
}

// NSViewRepresentable wrapper to run breathing animations on the GPU (saving CPU)
struct GlowingLEDView: NSViewRepresentable {
    let color: NSColor
    let breathes: Bool
    let period: Double
    let isSelected: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        updateLayer(view.layer)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        updateLayer(nsView.layer)
    }
    
    private func updateLayer(_ layer: CALayer?) {
        guard let layer = layer else { return }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        let size: CGFloat = 14
        let circleLayer = CAShapeLayer()
        circleLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        circleLayer.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: size, height: size), transform: nil)
        circleLayer.fillColor = color.cgColor
        
        if isSelected {
            circleLayer.shadowColor = color.cgColor
            circleLayer.shadowOpacity = 0.8
            circleLayer.shadowOffset = .zero
            circleLayer.shadowRadius = 4
        } else {
            circleLayer.shadowColor = color.cgColor
            circleLayer.shadowOpacity = 0.2
            circleLayer.shadowOffset = .zero
            circleLayer.shadowRadius = 1
        }
        
        layer.addSublayer(circleLayer)
        
        if breathes && isSelected {
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 0.35
            anim.toValue = 1.0
            anim.duration = period / 2.0
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            circleLayer.add(anim, forKey: "breathe")
        } else {
            circleLayer.opacity = 1.0
            circleLayer.removeAllAnimations()
        }
    }
}
