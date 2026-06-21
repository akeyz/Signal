import SwiftUI

private enum Timing {
    static let cancelFadeOut: Double = 0.3
    static let alertOnceFadeIn: Double = 0.3
    static let alertOnceHold: Double = 0.45
    static let alertOnceFadeOut: Double = 0.4
    static let alertThreeFadeIn: Double = 0.25
    static let alertThreeHold: Double = 0.3
    static let alertThreeFadeOut: Double = 0.3
    static let alertThreeGap: Double = 0.35
    static let fallbackPulse: Double = 1.2
}

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
            withAnimation(.easeOut(duration: Timing.cancelFadeOut)) {
                self.opacity = 0.0
            }
            // After fade out, notify that animation ended to hide windows
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.cancelFadeOut) { [weak self] in
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
            withAnimation(.easeOut(duration: Timing.alertOnceFadeIn)) {
                self.opacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.alertOnceHold) { [weak self] in
                guard let self = self, id == self.currentAnimationId else { return }
                withAnimation(.easeIn(duration: Timing.alertOnceFadeOut)) {
                    self.opacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.alertOnceFadeOut) { [weak self] in
                    guard let self = self, id == self.currentAnimationId else { return }
                    self.onAnimationEnd?()
                }
            }
            
        case .alertThree:
            flashSequence(id: id, current: 1, total: 3)
            
        case .continuous:
            // Continuous breathing/pulsing
            pulseLoop(id: id, duration: period > 0 ? period / 2.0 : Timing.fallbackPulse, targetHigh: true)
            
        case .off:
            break
        }
    }
    
    private func flashSequence(id: UUID, current: Int, total: Int) {
        guard id == currentAnimationId else { return }
        withAnimation(.easeOut(duration: Timing.alertThreeFadeIn)) {
            self.opacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.alertThreeHold) { [weak self] in
            guard let self = self, id == self.currentAnimationId else { return }
            withAnimation(.easeIn(duration: Timing.alertThreeFadeOut)) {
                self.opacity = 0.0
            }
            
            if current < total {
                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.alertThreeGap) { [weak self] in
                    guard let self = self, id == self.currentAnimationId else { return }
                    self.flashSequence(id: id, current: current + 1, total: total)
                }
            } else {
                // Done with all flashes
                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.alertThreeFadeOut) { [weak self] in
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
