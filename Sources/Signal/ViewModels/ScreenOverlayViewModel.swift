import SwiftUI

class ScreenOverlayViewModel: ObservableObject {
    @Published var overlayColor: Color = .clear
    @Published var opacity: Double = 0.0
    
    var onAnimationStart: (() -> Void)?
    var onAnimationEnd: (() -> Void)?
    
    private var currentAnimationId: UUID?
    
    func triggerFlash(color: LightColor, mode: FlashMode) {
        let animationId = UUID()
        self.currentAnimationId = animationId
        
        guard mode != .off, color != .black else {
            // Cancel current overlay animation and fade out
            withAnimation(.easeOut(duration: 0.3)) {
                self.opacity = 0.0
            }
            // After fade out, notify that animation ended to hide windows
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, animationId == self.currentAnimationId else { return }
                self.onAnimationEnd?()
            }
            return
        }
        
        let swiftUIColor = Color(color.color)
        self.overlayColor = swiftUIColor
        self.opacity = 0.0
        
        // Notify animation started (which will order Front the windows)
        onAnimationStart?()
        
        runAnimation(id: animationId, mode: mode, period: color.period)
    }
    
    private func runAnimation(id: UUID, mode: FlashMode, period: Double) {
        guard id == currentAnimationId else { return }
        
        switch mode {
        case .alertOnce:
            withAnimation(.easeOut(duration: 0.3)) {
                self.opacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self = self, id == self.currentAnimationId else { return }
                withAnimation(.easeIn(duration: 0.4)) {
                    self.opacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self = self, id == self.currentAnimationId else { return }
                    self.onAnimationEnd?()
                }
            }
            
        case .alertThree:
            flashSequence(id: id, current: 1, total: 3)
            
        case .continuous:
            // Continuous breathing/pulsing
            pulseLoop(id: id, duration: period > 0 ? period / 2.0 : 1.2, targetHigh: true)
            
        case .off:
            break
        }
    }
    
    private func flashSequence(id: UUID, current: Int, total: Int) {
        guard id == currentAnimationId else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            self.opacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, id == self.currentAnimationId else { return }
            withAnimation(.easeIn(duration: 0.3)) {
                self.opacity = 0.0
            }
            
            if current < total {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let self = self, id == self.currentAnimationId else { return }
                    self.flashSequence(id: id, current: current + 1, total: total)
                }
            } else {
                // Done with all flashes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self, id == self.currentAnimationId else { return }
                    self.onAnimationEnd?()
                }
            }
        }
    }
    
    private func pulseLoop(id: UUID, duration: Double, targetHigh: Bool) {
        guard id == currentAnimationId else { return }
        withAnimation(.easeInOut(duration: duration)) {
            self.opacity = targetHigh ? 0.75 : 0.15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, id == self.currentAnimationId else { return }
            self.pulseLoop(id: id, duration: duration, targetHigh: !targetHigh)
        }
    }
}
