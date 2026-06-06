import Foundation

// MARK: - sgnl – CLI companion for Signal.app
//
// Usage:
//   sgnl <black|off|red|yellow|green>
//   sgnl breath <on|off>
//   sgnl help
//
// Sends a DistributedNotification to the running Signal.app.

let validColors = ["black", "off", "red", "yellow", "green"]

func printUsage() {
    let usage = """
    sgnl – control Signal menu-bar status light

    USAGE:
      sgnl <color>         Switch LED color
      sgnl breath <on|off> Toggle breathing animation (saves CPU when off)
      sgnl help            Show this help message

    COLORS:
      black|off  Light off (no glow)
      red        Fastest breathing  (~1.2s cycle)
      yellow     Medium breathing   (~2.4s cycle)
      green      Steady green light (no breathing)

    EXAMPLES:
      sgnl red             Switch to red (alert)
      sgnl green           Switch to green (all clear)
      sgnl off             Turn the light off
      sgnl breath off      Disable breathing animation
      sgnl breath on       Re-enable breathing animation
    """
    print(usage)
}

// Parse arguments
let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    printUsage()
    exit(1)
}

let cmd = command.lowercased()

if cmd == "help" || cmd == "--help" || cmd == "-h" {
    printUsage()
    exit(0)
}

// --- Breath toggle ---
if cmd == "breath" {
    guard args.count > 1 else {
        fputs("Error: sgnl breath requires 'on' or 'off'\n", stderr)
        exit(1)
    }
    let value = args[1].lowercased()
    guard value == "on" || value == "off" else {
        fputs("Error: sgnl breath requires 'on' or 'off'\n", stderr)
        exit(1)
    }
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("com.signal-light.toggleBreathing"),
        object: nil,
        userInfo: ["enabled": value],
        deliverImmediately: true
    )
    print("✓ Breathing → \(value)")
    exit(0)
}

// --- Color switch ---
guard validColors.contains(cmd) else {
    fputs("Error: unknown command '\(command)'. Run 'sgnl help' for usage.\n", stderr)
    exit(1)
}

// Normalize "off" → "black"
let color = (cmd == "off") ? "black" : cmd

DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name("com.signal-light.colorChange"),
    object: nil,
    userInfo: ["color": color],
    deliverImmediately: true
)

print("✓ Signal → \(color)")
