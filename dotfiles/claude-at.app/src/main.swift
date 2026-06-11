import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else { return }
        // vclaude://file/Users/... → /Users/...
        let pathLine: String
        if urlString.hasPrefix("vclaude://file") {
            pathLine = String(urlString.dropFirst(14))
        } else {
            pathLine = String(urlString.dropFirst(10))
        }
        let task = Process()
        task.launchPath = "/Users/shlomi/bin/claude-at-open"
        task.arguments = [pathLine]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSApplication.shared.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
