import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import SwiftUI

let logURL = URL(fileURLWithPath: NSHomeDirectory())
  .appendingPathComponent("Desktop/Projects/clean-screen/helper.log")

func log(_ message: String) {
  let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
  let data = Data(line.utf8)

  if FileManager.default.fileExists(atPath: logURL.path) {
    if let handle = try? FileHandle(forWritingTo: logURL) {
      try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
      try? handle.close()
    }
  } else {
    try? data.write(to: logURL, options: .atomic)
  }
}

@MainActor
final class SessionController: ObservableObject {
  static let shared = SessionController()

  @Published var permissionGranted: Bool
  @Published var awaitingPermission: Bool
  @Published var permissionPromptRequested = false
  @Published var continueTemporarilyDisabled = false

  init() {
    let trusted = AXIsProcessTrusted()
    self.permissionGranted = trusted
    self.awaitingPermission = !trusted
  }

  func stop() {
    log("SessionController stop requested")
    NSApp.terminate(nil)
  }
}

final class KeyboardBlocker {
  private var pendingControlKeyDown = false
  private var pendingEscapeKeyDown = false
  private let onEmergencyExit: @MainActor () -> Void

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?

  init(onEmergencyExit: @escaping @MainActor () -> Void) {
    self.onEmergencyExit = onEmergencyExit
  }

  func start() throws {
    if eventTap != nil {
      return
    }

    let events = (
      (1 << CGEventType.keyDown.rawValue) |
      (1 << CGEventType.keyUp.rawValue) |
      (1 << CGEventType.flagsChanged.rawValue)
    )

    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo else {
        return Unmanaged.passRetained(event)
      }

      let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue()
      return blocker.handle(type: type, event: event)
    }

    let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(events),
      callback: callback,
      userInfo: opaqueSelf
    ) else {
      throw HelperError.eventTapUnavailable
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    self.eventTap = tap
    self.runLoopSource = source
    log("Keyboard blocker started")
  }

  func stop() {
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }

    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    }

    eventTap = nil
    runLoopSource = nil
    log("Keyboard blocker stopped")
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
        log("Keyboard tap re-enabled after timeout/user input")
      }
      return nil
    }

    if type == .flagsChanged {
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

      if keyCode == Int64(kVK_Control) || keyCode == Int64(kVK_RightControl) {
        pendingControlKeyDown = event.flags.contains(.maskControl)
      }

      return Unmanaged.passRetained(event)
    }

    if keyCode(for: event) == Int64(kVK_Escape) {
      pendingEscapeKeyDown = type == .keyDown
    }

    if shouldAllow(event: event) {
      log("Allowed emergency shortcut keycode=\(keyCode(for: event)) flags=\(event.flags.rawValue)")
      pendingControlKeyDown = false
      let exit = onEmergencyExit
      DispatchQueue.main.async {
        exit()
      }
      return nil
    }

    return nil
  }

  private func keyCode(for event: CGEvent) -> Int64 {
    event.getIntegerValueField(.keyboardEventKeycode)
  }

  private func shouldAllow(event: CGEvent) -> Bool {
    let flags = event.flags
    let keyCode = keyCode(for: event)

    let allowsEmergencyShortcut =
      (flags.contains(.maskControl) || pendingControlKeyDown) &&
      !flags.contains(.maskCommand) &&
      !flags.contains(.maskAlternate) &&
      keyCode == Int64(kVK_ANSI_U)

    let allowsDoubleEscape = pendingEscapeKeyDown && keyCode == Int64(kVK_Escape)

    return allowsEmergencyShortcut || allowsDoubleEscape
  }
}

enum HelperError: LocalizedError {
  case eventTapUnavailable

  var errorDescription: String? {
    switch self {
    case .eventTapUnavailable:
      return "Unable to create the keyboard event tap."
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  static weak var shared: AppDelegate?
  private let session = SessionController.shared
  private lazy var blocker = KeyboardBlocker { [weak self] in
    self?.terminate()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.shared = self
    log("Application launched")
    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    NSApp.activate(ignoringOtherApps: true)

    Task { @MainActor in
      do {
        try beginAccessibilityFlow()
      } catch {
        log("Startup failed: \(error.localizedDescription)")
        presentFailureAndExit(message: error.localizedDescription)
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    blocker.stop()
  }

  private func beginAccessibilityFlow() throws {
    if AXIsProcessTrusted() {
      log("Accessibility permission confirmed")
      session.awaitingPermission = false
      session.permissionGranted = true
      try activateCleaningMode()
      return
    }

    session.awaitingPermission = true
    configureSetupWindowWhenReady()
    log("Waiting for user to request Accessibility permission")
  }

  func requestAccessibilityPrompt() {
    guard session.awaitingPermission else { return }
    guard !session.permissionPromptRequested else { return }

    session.permissionPromptRequested = true
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    log("Requested native Accessibility prompt")
    startPermissionPolling()
  }

  private func startPermissionPolling() {
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }

      if AXIsProcessTrusted() {
        timer.invalidate()
        log("Accessibility permission confirmed")
        self.session.permissionPromptRequested = false
      }
    }
  }

  func continueAfterPermissionGrant() {
    guard session.awaitingPermission else { return }
    session.permissionPromptRequested = false

    guard AXIsProcessTrusted() else {
      session.continueTemporarilyDisabled = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        SessionController.shared.continueTemporarilyDisabled = false
      }
      return
    }

    do {
      try activateCleaningMode()
    } catch {
      log("Failed to activate cleaning mode: \(error.localizedDescription)")
      presentFailureAndExit(message: error.localizedDescription)
    }
  }

  private func activateCleaningMode() throws {
    try blocker.start()
    session.awaitingPermission = false
    session.permissionGranted = true
    session.permissionPromptRequested = false
    session.continueTemporarilyDisabled = false
    configureWindowWhenReady()
    scheduleFailsafeShutdown()
  }

  private func configureSetupWindowWhenReady() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let window = NSApp.windows.first else {
        self.configureSetupWindowWhenReady()
        return
      }

      self.configureSetup(window: window)
    }
  }

  private func configureSetup(window: NSWindow) {
    let size = NSSize(width: 552, height: 292)
    let screenFrame = (NSScreen.main ?? window.screen ?? NSScreen.screens.first)?.visibleFrame ?? .zero
    let origin = NSPoint(
      x: screenFrame.midX - size.width / 2,
      y: screenFrame.midY - size.height / 2
    )

    window.title = ""
    window.styleMask = [.borderless, .fullSizeContentView]
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = true
    window.level = .normal
    window.collectionBehavior = [.moveToActiveSpace]
    window.isMovableByWindowBackground = true
    window.setContentSize(size)
    window.setFrameOrigin(origin)
    window.center()
    window.alphaValue = 1
    window.makeMain()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    NSApp.presentationOptions = []
    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    NSApp.activate(ignoringOtherApps: true)
    log("Configured setup window")
  }

  private func configureWindowWhenReady() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let window = NSApp.windows.first else {
        log("No SwiftUI window found yet")
        self.configureWindowWhenReady()
        return
      }

      self.configure(window: window)
    }
  }

  private func configure(window: NSWindow) {
    guard let screen = NSScreen.main ?? window.screen ?? NSScreen.screens.first else {
      log("No screen available for SwiftUI window")
      return
    }

    let frame = screen.frame
    log("Configuring SwiftUI window frame=\(NSStringFromRect(frame))")

    window.title = ""
    window.styleMask = [.borderless, .fullSizeContentView]
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.backgroundColor = .black
    window.isOpaque = true
    window.hasShadow = false
    window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
    window.collectionBehavior = [.canJoinAllSpaces]
    window.isMovableByWindowBackground = false
    window.setFrame(frame, display: true)
    window.setFrameOrigin(frame.origin)
    window.alphaValue = 1
    window.makeMain()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    NSApp.presentationOptions = [.hideDock, .hideMenuBar]
    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    NSApp.activate(ignoringOtherApps: true)
    log("Configured and presented SwiftUI window")
  }

  private func scheduleFailsafeShutdown() {
    Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
      log("Failsafe timer triggered")
      Task { @MainActor in
        self?.terminate()
      }
    }
  }

  private func presentFailureAndExit(message: String) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Clean Screen Could Not Start"
    alert.informativeText = message
    alert.addButton(withTitle: "Close")
    alert.runModal()
    terminate()
  }

  func openAccessibilitySettings() {
    let urls = [
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
      "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility",
    ]

    for value in urls {
      if let url = URL(string: value), NSWorkspace.shared.open(url) {
        log("Opened Accessibility settings using \(value)")
        return
      }
    }

    log("Failed to open Accessibility settings URL")
  }

  private func terminate() {
    log("Terminating application")
    blocker.stop()
    NSApp.presentationOptions = []
    NSApp.terminate(nil)
  }
}

struct WindowAccessor: NSViewRepresentable {
  let onResolve: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      onResolve(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      onResolve(nsView.window)
    }
  }
}

struct CleaningView: View {
  @ObservedObject private var session = SessionController.shared

  var body: some View {
    Group {
      if session.permissionGranted {
        ZStack {
          Color.black
            .ignoresSafeArea()

          VStack(spacing: 24) {
            Text("Clean Screen")
              .font(.system(size: 34, weight: .bold))
              .foregroundStyle(.white)

            Button("End Cleaning Session") {
              session.stop()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Mouse still works. Emergency shortcut: Control-U")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.white.opacity(0.75))
          }
          .padding(32)
        }
      } else {
        ZStack {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
              RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

          VStack(spacing: 0) {
            VStack(spacing: 14) {
              Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.black)
                .frame(width: 66, height: 66)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)

              Text("Prepare Clean Screen")
                .font(.system(size: 26, weight: .semibold))

              Text("Allow Accessibility access to start cleaning mode.")
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
            }

            Text("If it is not listed in Accessibility, add `CleanScreenHelper.app` with the system `+` button, then come back here.")
              .font(.system(size: 12, weight: .medium))
              .multilineTextAlignment(.center)
              .foregroundStyle(.tertiary)
              .frame(maxWidth: 400)
              .padding(.top, 18)

            HStack(spacing: 12) {
              Button(session.permissionPromptRequested ? "Waiting For Access..." : "Request Accessibility Access") {
                AppDelegate.shared?.requestAccessibilityPrompt()
              }
              .buttonStyle(.borderedProminent)
              .controlSize(.large)
              .disabled(session.permissionPromptRequested)

              Button("Continue") {
                AppDelegate.shared?.continueAfterPermissionGrant()
              }
              .buttonStyle(.bordered)
              .controlSize(.large)
              .disabled(session.continueTemporarilyDisabled)

              Button("Cancel") {
                SessionController.shared.stop()
              }
              .buttonStyle(.bordered)
              .controlSize(.large)
            }
            .padding(.top, 24)

            if session.permissionPromptRequested {
              Text("Waiting for macOS to confirm access.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
            }
          }
          .padding(26)
          .frame(width: 520, height: 248)
        }
      }
    }
    .background(
      WindowAccessor { window in
        guard let window else { return }
        log("WindowAccessor resolved window")
        window.isReleasedWhenClosed = false
        if window.alphaValue != 0 {
          window.alphaValue = 0
        }
      }
    )
  }
}

@main
struct CleanScreenHelperApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      CleaningView()
        .frame(width: 552, height: 292)
    }
    .windowStyle(.titleBar)
    .commands {
      CommandGroup(replacing: .appTermination) {
        Button("Quit Clean Screen") {
          SessionController.shared.stop()
        }
        .keyboardShortcut("q")
      }
    }
  }
}
