import Cocoa
import MetalKit
import QuartzCore

// --- 1. Shader Source Code (The Raymarcher) ---
let SHADER_SOURCE = """
	#include <metal_stdlib>
	using namespace metal;

	struct VertexOut {
	    float4 position [[position]];
	    float2 uv;
	};

	struct Uniforms {
	    float time;
	    float2 resolution;
	};

	// 1. Raymarching Helpers
	// Rotation matrix for SDF
	float3 rotateY(float3 p, float a) {
	    float c = cos(a), s = sin(a);
	    return float3(p.x * c - p.z * s, p.y, p.x * s + p.z * c);
	}

	float3 rotateX(float3 p, float a) {
	    float c = cos(a), s = sin(a);
	    return float3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
	}

	// Signed Distance Function for a Box
	float sdBox(float3 p, float3 b) {
	    float3 q = abs(p) - b;
	    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
	}

	// Scene definition
	float map(float3 p, float time) {
	    float3 q = rotateY(rotateX(p, time * 0.7), time * 0.5);
	    return sdBox(q, float3(0.5));
	}

	// Simple Normal calculation
	float3 getNormal(float3 p, float time) {
	    float2 e = float2(0.001, 0);
	    return normalize(float3(
	        map(p + e.xyy, time) - map(p - e.xyy, time),
	        map(p + e.yxy, time) - map(p - e.yxy, time),
	        map(p + e.yyx, time) - map(p - e.yyx, time)
	    ));
	}

	// 2. Vertex Shader: Full-screen triangle trick
	// vertexID 0,1,2 generates a triangle covering the whole screen
	vertex VertexOut vertexShader(uint vid [[vertex_id]]) {
	    VertexOut out;
	    out.uv = float2((vid << 1) & 2, vid & 2);
	    out.position = float4(out.uv * 2.0 - 1.0, 0.0, 1.0);
	    out.uv.y = 1.0 - out.uv.y;
	    return out;
	}

	// 3. Fragment Shader: The Raymarcher
	fragment float4 fragmentShader(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
	    // Standardize coordinates (-1 to 1, corrected for aspect ratio)
	    float2 p = (in.position.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);

	    float3 ro = float3(0, 0, -2);          // Ray Origin (Camera)
	    float3 rd = normalize(float3(p, 1.5));  // Ray Direction

	    float t = 0.0; // Distance traveled
	    for(int i = 0; i < 64; i++) {
	        float d = map(ro + rd * t, u.time);
	        if(d < 0.001 || t > 10.0) break;
	        t += d;
	    }

	    float3 col = float3(0.1, 0.1, 0.15); // Background

	    if(t < 10.0) {
	        float3 pos = ro + rd * t;
	        float3 nor = getNormal(pos, u.time);
	        float diff = max(0.0, dot(nor, normalize(float3(1, 2, -1)))); // Simple lighting
	        col = nor * 0.5 + 0.5; // Visualizing normals as colors
	        col *= diff;
	    }

	    return float4(col, 1.0);
	}
	"""

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
		window.title = "Raymarched Cube"

		let mtkView = MTKView(frame: window.contentView!.frame)
		mtkView.device = device
		mtkView.delegate = self

		let library = try! device.makeLibrary(source: SHADER_SOURCE, options: nil)
		let desc = MTLRenderPipelineDescriptor()
		desc.vertexFunction = library.makeFunction(name: "vertexShader")
		desc.fragmentFunction = library.makeFunction(name: "fragmentShader")
		desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
		pipelineState = try! device.makeRenderPipelineState(descriptor: desc)

		window.contentView = mtkView
		window.makeKeyAndOrderFront(nil)
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
	}

	func draw(in view: MTKView) {
		guard let b = commandQueue.makeCommandBuffer(), let d = view.currentRenderPassDescriptor,
			let e = b.makeRenderCommandEncoder(descriptor: d)
		else { return }

		var uniforms = Uniforms(
			time: Float(CACurrentMediaTime() - startTime),
			resolution: SIMD2<Float>(
				Float(view.drawableSize.width), Float(view.drawableSize.height)))

		e.setRenderPipelineState(pipelineState)
		e.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
		e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)  // One big triangle covering screen

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
