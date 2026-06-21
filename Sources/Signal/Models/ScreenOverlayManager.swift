import Cocoa
import SwiftUI

class OverlayWindow: NSPanel {
    init(screen: NSScreen, viewModel: ScreenOverlayViewModel) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Signal Screen Overlay"
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingView = NSHostingView(rootView: OverlayContentView(viewModel: viewModel))
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        self.contentView = hostingView
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class ScreenOverlayManager: NSObject {
    static let shared = ScreenOverlayManager()
    
    let viewModel = ScreenOverlayViewModel()
    private var windows: [OverlayWindow] = []
    private var rebuildWorkItem: DispatchWorkItem?
    
    override init() {
        super.init()
        
        viewModel.onAnimationStart = { [weak self] in
            self?.showWindows()
        }
        viewModel.onAnimationEnd = { [weak self] in
            self?.hideWindows()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    func start() {
        rebuildWindows()
    }
    
    @objc private func screensDidChange() {
        rebuildWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuildWindows()
        }
        rebuildWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    private func rebuildWindows() {
        // Close existing windows
        for window in windows {
            window.close()
        }
        windows.removeAll()
        
        // Create new window for each screen
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen, viewModel: viewModel)
            // If currently active/showing, order it front
            if viewModel.opacity > 0 {
                window.orderFrontRegardless()
            }
            windows.append(window)
        }
    }
    
    private func showWindows() {
        for window in windows {
            window.orderFrontRegardless()
        }
    }
    
    private func hideWindows() {
        for window in windows {
            window.orderOut(nil)
        }
    }
    
    func triggerFlash(color: LightColor, mode: FlashMode) {
        viewModel.triggerFlash(color: color, mode: mode)
    }
}
