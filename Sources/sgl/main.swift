import Foundation

// MARK: - sgl – CLI companion for Signal.app
//
// Usage:
//   sgl <black|off|red|yellow|green>
//   sgl breath <on|off>
//   sgl help
//
// Sends a DistributedNotification to the running Signal.app.

let validColors = ["black", "off", "red", "yellow", "green"]

func printUsage() {
    let usage = """
    sgl – control Signal menu-bar status light

    USAGE:
      sgl <color>         Switch LED color
      sgl breath <on|off> Toggle breathing animation (saves CPU when off)
      sgl help            Show this help message

    COLORS:
      black|off  Light off (no glow)
      red        Fastest breathing  (~1.2s cycle)
      yellow     Medium breathing   (~2.4s cycle)
      green      Steady green light (no breathing)

    EXAMPLES:
      sgl red             Switch to red (alert)
      sgl green           Switch to green (all clear)
      sgl off             Turn the light off
      sgl breath off      Disable breathing animation
      sgl breath on       Re-enable breathing animation
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
        fputs("Error: sgl breath requires 'on' or 'off'\n", stderr)
        exit(1)
    }
    let value = args[1].lowercased()
    guard value == "on" || value == "off" else {
        fputs("Error: sgl breath requires 'on' or 'off'\n", stderr)
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
    fputs("Error: unknown command '\(command)'. Run 'sgl help' for usage.\n", stderr)
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
