import Cocoa
import MetalKit

// 1. The Renderer: Handles the Metal draw loop
class Renderer: NSObject, MTKViewDelegate {
	let device: MTLDevice
	let commandQueue: MTLCommandQueue

	init?(metalView: MTKView) {
		guard let device = MTLCreateSystemDefaultDevice(),
			let queue = device.makeCommandQueue()
		else { return nil }

		self.device = device
		self.commandQueue = queue
		super.init()

		metalView.device = device
		metalView.delegate = self
		metalView.clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 0.8, alpha: 1.0)
	}

	// Called every frame (60fps by default)
	func draw(in view: MTKView) {
		guard let descriptor = view.currentRenderPassDescriptor,
			let drawable = view.currentDrawable,
			let commandBuffer = commandQueue.makeCommandBuffer(),
			let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
		else { return }

		// --- Draw commands go here ---

		encoder.endEncoding()
		commandBuffer.present(drawable)
		commandBuffer.commit()
	}

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

// 2. The App Delegate: Sets up the Window
class AppDelegate: NSObject, NSApplicationDelegate {
	var window: NSWindow!
	var renderer: Renderer!

	func applicationDidFinishLaunching(_ notification: Notification) {
		let windowSize = NSMakeRect(0, 0, 800, 600)

		// Create the window
		window = NSWindow(
			contentRect: windowSize,
			styleMask: [.titled, .closable, .resizable, .miniaturizable],
			backing: .buffered,
			defer: false)
		window.title = "Minimal Metal"
		window.center()

		// Create the Metal View
		let mtkView = MTKView(frame: windowSize)
		renderer = Renderer(metalView: mtkView)

		window.contentView = mtkView
		window.makeKeyAndOrderFront(nil)

		// Ensure app activates smoothly
		NSApp.activate(ignoringOtherApps: true)
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
}

// 3. Execution Entry Point
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
