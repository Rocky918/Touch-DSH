import AppKit
import Darwin
import TouchDSHShared

if CommandLine.arguments.contains("--self-test-resources") {
    exit(DeepSeekLogo.image(size: 18) == nil ? EXIT_FAILURE : EXIT_SUCCESS)
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate(applicationName: "Touch DSH Menu") }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
