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

float3 rotateY(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(p.x * c - p.z * s, p.y, p.x * s + p.z * c);
}

float3 rotateX(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

float sdBox(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float map(float3 p, float time) {
    float3 q = rotateY(rotateX(p, time * 0.7), time * 0.5);
    return sdBox(q, float3(0.5));
}

float3 getNormal(float3 p, float time) {
    float2 e = float2(0.001, 0);
    return normalize(float3(
        map(p + e.xyy, time) - map(p - e.xyy, time),
        map(p + e.yxy, time) - map(p - e.yxy, time),
        map(p + e.yyx, time) - map(p - e.yyx, time)
    ));
}

vertex VertexOut vertexShader(uint vid [[vertex_id]]) {
    VertexOut out;
    out.uv = float2((vid << 1) & 2, vid & 2);
    out.position = float4(out.uv * 2.0 - 1.0, 0.0, 1.0);
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p = (in.position.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float3 ro = float3(0, 0, -2);
    float3 rd = normalize(float3(p, 1.5));

    float t = 0.0;
    for(int i = 0; i < 64; i++) {
        float d = map(ro + rd * t, u.time);
        if(d < 0.001 || t > 10.0) break;
        t += d;
    }

    float3 col = float3(0.1, 0.1, 0.15);
    if(t < 10.0) {
        float3 pos = ro + rd * t;
        float3 nor = getNormal(pos, u.time);
        float diff = max(0.0, dot(nor, normalize(float3(1, 2, -1))));
        col = nor * 0.5 + 0.5;
        col *= diff;
    }
    return float4(col, 1.0);
}
