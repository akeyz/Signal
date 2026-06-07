import SwiftUI
import ServiceManagement

class AppViewModel: ObservableObject {
    @Published var currentColor: LightColor = .black
    @Published var breathingEnabled: Bool = false
    @Published var startAtLogin: Bool = false
    @Published var claudeSessions: [ClaudeSession] = []
    @Published var isLoadingSessions: Bool = false
    private var hasLoadedSessions = false
    
    func loadClaudeSessions(forceReload: Bool = false) {
        if hasLoadedSessions && !forceReload { return }
        isLoadingSessions = true
        ClaudeHistoryLoader.loadHistory { [weak self] sessions in
            self?.claudeSessions = sessions
            self?.isLoadingSessions = false
            self?.hasLoadedSessions = true
        }
    }
    
    // Callback handlers to notify AppDelegate
    var onColorChange: ((LightColor) -> Void)?
    var onBreathingChange: ((Bool) -> Void)?
    var onStartAtLoginChange: ((Bool) -> Void)?
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
    
    func quit() {
        onQuit?()
    }
}
