import Cocoa
import MetalKit
import QuartzCore  // Needed for CACurrentMediaTime() for animation

// --- 1. Shader Source Code (Embedded) ---
// We embed the shaders as a multi-line string to avoid a separate .metal file.
let SHADER_SOURCE = """
	#include <metal_stdlib>
	using namespace metal;

	// Vertex data structure (matches CPU side)
	struct Vertex {
	    packed_float3 position;
	    packed_float4 color;
	};

	// Uniforms structure for the transformation matrix (matches CPU side)
	struct Uniforms {
	    float4x4 modelViewProjectionMatrix;
	};

	// Output from Vertex Shader to Fragment Shader
	struct FragmentIn {
	    float4 position [[position]];
	    float4 color;
	};

	// Vertex Shader
	// Inputs are now passed as parameters with their respective attributes:
	// 1. vertexID: The index of the current vertex, automatically provided by the GPU.
	// 2. vertices: The vertex data buffer bound at index 0 on the CPU.
	// 3. uniforms: The uniforms buffer bound at index 1 on the CPU.
	vertex FragmentIn vertexShader(
	    uint vertexID [[vertex_id]],
	    constant Vertex *vertices [[buffer(0)]],
	    constant Uniforms &uniforms [[buffer(1)]])
	{
	    FragmentIn out;
	    // We manually fetch the vertex data using the vertexID index
	    out.position = uniforms.modelViewProjectionMatrix * float4(vertices[vertexID].position, 1.0);
	    out.color = vertices[vertexID].color;
	    return out;
	}

	// Fragment Shader
	fragment float4 fragmentShader(FragmentIn in [[stage_in]])
	{
	    return in.color;
	}
	"""

// --- 2. Matrix Math Helpers (Minimal) ---
// We use simple 4x4 float matrix type to handle transformations.
typealias float4x4 = simd_float4x4
typealias float3 = simd_float3

extension float4x4 {
	// Identity matrix
	static let identity = matrix_identity_float4x4

	// Simple projection matrix (Perspective)
	static func perspective(fovyRadians: Float, aspectRatio: Float, nearZ: Float, farZ: Float)
		-> float4x4
	{
		let f = 1.0 / tan(fovyRadians / 2.0)
		return float4x4(
			SIMD4<Float>(f / aspectRatio, 0, 0, 0),
			SIMD4<Float>(0, f, 0, 0),
			SIMD4<Float>(0, 0, (farZ + nearZ) / (nearZ - farZ), -1),
			SIMD4<Float>(0, 0, (2 * farZ * nearZ) / (nearZ - farZ), 0)
		)
	}

	// Simple rotation matrix around the Y axis
	static func rotation(angle: Float, axis: float3) -> float4x4 {
		let c = cos(angle)
		let s = sin(angle)
		let C = 1 - c

		let x = axis.x
		let y = axis.y
		let z = axis.z

		return float4x4(
			SIMD4<Float>(x * x * C + c, x * y * C - z * s, x * z * C + y * s, 0),
			SIMD4<Float>(y * x * C + z * s, y * y * C + c, y * z * C - x * s, 0),
			SIMD4<Float>(z * x * C - y * s, z * y * C + x * s, z * z * C + c, 0),
			SIMD4<Float>(0, 0, 0, 1)
		)
	}

	// Simple translation matrix
	static func translation(x: Float, y: Float, z: Float) -> float4x4 {
		var matrix = float4x4.identity
		matrix.columns.3 = SIMD4<Float>(x, y, z, 1)
		return matrix
	}
}

// Uniforms structure (must match the struct in the shader)
struct Uniforms {
	var modelViewProjectionMatrix: float4x4
}

// --- 3. The App Delegate (Now also the Renderer) ---
class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {
	var window: NSWindow!

	// Metal properties
	let device: MTLDevice
	let commandQueue: MTLCommandQueue
	var pipelineState: MTLRenderPipelineState!
	var vertexBuffer: MTLBuffer!
	var indexBuffer: MTLBuffer!
	var uniformsBuffer: MTLBuffer!

	// Animation properties
	var startTime: CFTimeInterval = 0
	var rotationAngle: Float = 0
	let vertexData: [Float] = [
		// Position (3 floats), Color (4 floats: R G B A)

		// Front face (Red)
		-0.5, 0.5, 0.5, 1.0, 0.0, 0.0, 1.0,
		-0.5, -0.5, 0.5, 1.0, 0.0, 0.0, 1.0,
		0.5, -0.5, 0.5, 1.0, 0.0, 0.0, 1.0,
		0.5, 0.5, 0.5, 1.0, 0.0, 0.0, 1.0,

		// Back face (Green)
		-0.5, 0.5, -0.5, 0.0, 1.0, 0.0, 1.0,
		-0.5, -0.5, -0.5, 0.0, 1.0, 0.0, 1.0,
		0.5, -0.5, -0.5, 0.0, 1.0, 0.0, 1.0,
		0.5, 0.5, -0.5, 0.0, 1.0, 0.0, 1.0,
	]
	let indexData: [UInt16] = [
		// Front
		0, 1, 2,
		2, 3, 0,

		// Back
		4, 6, 5,
		6, 4, 7,

		// Top
		3, 7, 4,
		4, 0, 3,

		// Bottom
		1, 6, 2,
		6, 1, 5,

		// Right
		2, 7, 3,
		7, 2, 6,

		// Left
		1, 4, 5,
		4, 1, 0,
	]

	override init() {
		// Force unwrap for minimal code (demoscene trick)
		self.device = MTLCreateSystemDefaultDevice()!
		self.commandQueue = self.device.makeCommandQueue()!
		super.init()
	}

	func setupMetal(view: MTKView) {
		view.device = device
		view.delegate = self
		view.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)

		// 1. Compile Shaders from Source String
		do {
			let library = try device.makeLibrary(source: SHADER_SOURCE, options: nil)
			let vertexFunction = library.makeFunction(name: "vertexShader")
			let fragmentFunction = library.makeFunction(name: "fragmentShader")

			// 2. Create Pipeline State
			let pipelineDescriptor = MTLRenderPipelineDescriptor()
			pipelineDescriptor.vertexFunction = vertexFunction
			pipelineDescriptor.fragmentFunction = fragmentFunction
			pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

			self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

		} catch {
			print("Failed to set up Metal pipeline: \(error)")
			return
		}

		// 3. Create Buffers for Geometry (Vertex and Index)
		let vertexDataSize = vertexData.count * MemoryLayout<Float>.size
		self.vertexBuffer = device.makeBuffer(
			bytes: vertexData, length: vertexDataSize, options: .storageModeShared)

		let indexDataSize = indexData.count * MemoryLayout<UInt16>.size
		self.indexBuffer = device.makeBuffer(
			bytes: indexData, length: indexDataSize, options: .storageModeShared)

		// 4. Create Uniforms Buffer (small, frequently updated)
		let uniformSize = MemoryLayout<Uniforms>.size
		self.uniformsBuffer = device.makeBuffer(length: uniformSize, options: .storageModeShared)
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		self.startTime = CACurrentMediaTime()
		let rect = NSMakeRect(0, 0, 800, 600)

		// Use raw StyleMask integer to avoid Swift Set<t> overhead
		let style = NSWindow.StyleMask(rawValue: 15)  // Titled | Closable | Miniaturizable | Resizable

		window = NSWindow(
			contentRect: rect,
			styleMask: style,
			backing: .buffered,
			defer: false)

		window.title = "Spinning Metal Cube"
		window.center()

		let mtkView = MTKView(frame: rect)
		setupMetal(view: mtkView)

		window.contentView = mtkView
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}

	// --- MTKViewDelegate Methods ---

	func updateUniforms(drawableSize: CGSize) {
		let currentTime = Float(CACurrentMediaTime() - startTime)

		// Animate the cube rotation over time
		rotationAngle = currentTime * 0.5  // 0.5 radians per second

		// 1. Create Model (Rotation) Matrix
		let modelMatrix = float4x4.rotation(angle: rotationAngle, axis: float3(0.5, 1.0, 0.0))

		// 2. Create View (Camera) Matrix
		let viewMatrix = float4x4.translation(x: 0, y: 0, z: -3.0)  // Pull camera back 3 units

		// 3. Create Projection Matrix
		let aspect = Float(drawableSize.width / drawableSize.height)
		let projectionMatrix = float4x4.perspective(
			fovyRadians: 1.0472, aspectRatio: aspect, nearZ: 0.01, farZ: 100.0)  // FOV 60 degrees

		// 4. Combine them: Projection * View * Model
		let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix

		// 5. Write the final matrix to the uniforms buffer
		var uniforms = Uniforms(modelViewProjectionMatrix: mvpMatrix)
		memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
	}

	func draw(in view: MTKView) {
		// Update the transformation matrix on the CPU before sending to GPU
		updateUniforms(drawableSize: view.drawableSize)

		guard let descriptor = view.currentRenderPassDescriptor,
			let drawable = view.currentDrawable,
			let commandBuffer = commandQueue.makeCommandBuffer(),
			let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
		else { return }

		// 1. Set the render state
		encoder.setRenderPipelineState(pipelineState)

		// 2. Set the vertex buffer (at index 0)
		encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

		// 3. Set the uniforms buffer (at index 1)
		encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)

		// 4. Draw the indexed cube
		encoder.drawIndexedPrimitives(
			type: .triangle,
			indexCount: indexBuffer.length / MemoryLayout<UInt16>.size,
			indexType: .uint16,
			indexBuffer: indexBuffer,
			indexBufferOffset: 0)

		encoder.endEncoding()
		commandBuffer.present(drawable)
		commandBuffer.commit()
	}

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// Update projection matrix if the window resizes
		// (This is implicitly handled in updateUniforms, but you'd put heavy resize logic here)
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
}

// 4. Execution Entry Point
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
