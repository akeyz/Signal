import SwiftUI
import ServiceManagement

class AppViewModel: ObservableObject {
    @Published var currentColor: LightColor = .black
    @Published var breathingEnabled: Bool = false
    @Published var startAtLogin: Bool = false
    @Published var selectedTool: ToolType = .claude
    @Published var historySessions: [ToolType: [HistorySession]] = [:]
    @Published var isLoadingSessions: Bool = false
    @Published var screenFlashMode: FlashMode = .alertThree {
        didSet {
            UserDefaults.standard.set(screenFlashMode.rawValue, forKey: "screenFlashMode")
            if screenFlashMode != .off {
                ScreenOverlayManager.shared.triggerFlash(color: currentColor, mode: screenFlashMode)
            } else {
                ScreenOverlayManager.shared.triggerFlash(color: .black, mode: .off)
            }
        }
    }
    private var hasLoadedSessions = false
    
    init() {
        if let savedValue = UserDefaults.standard.string(forKey: "screenFlashMode"),
           let mode = FlashMode(rawValue: savedValue) {
            self.screenFlashMode = mode
        } else {
            self.screenFlashMode = .alertThree
        }
    }
    
    var claudeSessions: [HistorySession] {
        return historySessions[selectedTool] ?? []
    }
    
    func loadClaudeSessions(forceReload: Bool = false) {
        if hasLoadedSessions && !forceReload { return }
        isLoadingSessions = true
        
        let group = DispatchGroup()
        var loadedHistory: [ToolType: [HistorySession]] = [:]
        
        // Load Claude
        group.enter()
        ClaudeHistoryLoader.loadHistory { sessions in
            loadedHistory[.claude] = sessions
            group.leave()
        }
        
        // Load OpenCode
        group.enter()
        ClaudeHistoryLoader.loadOpenCodeHistory { sessions in
            loadedHistory[.openCode] = sessions
            group.leave()
        }
        
        // Load Pi
        group.enter()
        ClaudeHistoryLoader.loadPiHistory { sessions in
            loadedHistory[.pi] = sessions
            group.leave()
        }
        
        // Load Trae
        group.enter()
        ClaudeHistoryLoader.loadTraeHistory { sessions in
            loadedHistory[.trae] = sessions
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.historySessions = loadedHistory
            self?.isLoadingSessions = false
            self?.hasLoadedSessions = true
        }
    }
    
    // Callback handlers to notify AppDelegate
    var onColorChange: ((LightColor) -> Void)?
    var onBreathingChange: ((Bool) -> Void)?
    var onStartAtLoginChange: ((Bool) -> Void)?
    var onInstallCLI: (() -> Void)?
    var onQuit: (() -> Void)?
    
    func selectColor(_ color: LightColor) {
        currentColor = color
        onColorChange?(color)
    }
    
    func toggleBreathing() {
        breathingEnabled.toggle()
        onBreathingChange?(breathingEnabled)
    }
    
    func toggleStartAtLogin() {
        startAtLogin.toggle()
        onStartAtLoginChange?(startAtLogin)
    }
    
    func refreshStartAtLogin() {
        startAtLogin = (SMAppService.mainApp.status == .enabled)
    }
    
    func installCLI() {
        onInstallCLI?()
    }
    
    func quit() {
        onQuit?()
    }
}
