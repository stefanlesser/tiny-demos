import Cocoa
//import MachO
import MetalKit

func loadEmbeddedResource(segment: String, section: String) -> Data {
	guard let header = _dyld_get_image_header(0) else {  // Image 0 is usually the main executable
		fatalError("Could not get executable header")
	}

	var size: UInt = 0
	guard
		let ptr = getsectiondata(
			UnsafePointer<mach_header_64>(OpaquePointer(header)),
			segment,
			section,
			&size
		)
	else {
		fatalError("Embedded Metal library section not found")
	}

	return Data(bytes: ptr, count: Int(size))
}

struct Uniforms {
	var time: Float
	var resolution: SIMD2<Float>
}

class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {
	var window: NSWindow!
	let device = MTLCreateSystemDefaultDevice()!
	lazy var commandQueue = device.makeCommandQueue()!
	var pipelineState: MTLRenderPipelineState!
	let startTime = CACurrentMediaTime()

	func applicationDidFinishLaunching(_ notification: Notification) {
		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered, defer: false)
		window.center()
		window.title = "Embedded Library Cube"

		let mtkView = MTKView(frame: window.contentView!.frame)
		mtkView.device = device
		mtkView.delegate = self

		// --- LOADING THE EMBEDDED SHADER LIBRARY (Modern API) ---
		do {
			let metalLib = loadEmbeddedResource(segment: "__TEXT", section: "__metallib")
			let dispatchData = metalLib.withUnsafeBytes { unsafeRawBufferPointer in
				DispatchData(bytes: unsafeRawBufferPointer)
			}
			let library = try device.makeLibrary(data: dispatchData)

			let desc = MTLRenderPipelineDescriptor()
			desc.vertexFunction = library.makeFunction(name: "vertexShader")
			desc.fragmentFunction = library.makeFunction(name: "fragmentShader")
			desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
			pipelineState = try device.makeRenderPipelineState(descriptor: desc)
		} catch {
			fatalError("Error: \(error)")
		}

		window.contentView = mtkView
		window.makeKeyAndOrderFront(nil)
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
	}

	func draw(in view: MTKView) {
		guard let b = commandQueue.makeCommandBuffer(),
			let d = view.currentRenderPassDescriptor,
			let e = b.makeRenderCommandEncoder(descriptor: d)
		else { return }

		var uniforms = Uniforms(
			time: Float(CACurrentMediaTime() - startTime),
			resolution: SIMD2<Float>(
				Float(view.drawableSize.width), Float(view.drawableSize.height)))

		e.setRenderPipelineState(pipelineState)
		e.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
		e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

		e.endEncoding()
		b.present(view.currentDrawable!)
		b.commit()
	}

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
