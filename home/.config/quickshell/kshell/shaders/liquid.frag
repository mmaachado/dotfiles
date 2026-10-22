#version 440

// Liquid wipe between two wallpapers: the new one rises from the bottom
// behind a wavy, refracting surface. Compile with:
//   /usr/lib/qt6/bin/qsb --qt6 -o liquid.frag.qsb liquid.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 resolution;
    vec2 fromSize;
    vec2 toSize;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

// Map screen uv to image uv like Image.PreserveAspectCrop (Plasma's default).
vec2 cover(vec2 uv, vec2 size) {
    vec2 s = max(size, vec2(1.0));
    float scale = max(resolution.x / s.x, resolution.y / s.y);
    return (uv - 0.5) * resolution / (s * scale) + 0.5;
}

float wave(float x, float t) {
    return sin(x * 5.1 + t * 2.3) * 0.50
         + sin(x * 11.7 - t * 3.4) * 0.30
         + sin(x * 23.3 + t * 5.9) * 0.20;
}

void main() {
    const float amp = 0.045;
    const float rim = 0.05;
    vec2 uv = qt_TexCoord0;
    float px = 1.5 / resolution.y;

    float t = progress * 6.0;
    float x = uv.x * resolution.x / resolution.y;
    // Calmer at the start and end so the screen begins and finishes clean.
    float env = sin(progress * 3.14159265);
    float surface = mix(-amp - rim, 1.0 + amp, progress) + amp * env * wave(x, t);
    float depth = surface - (1.0 - uv.y); // > 0 below the liquid surface

    // Slope of the surface, used to bend the image near the edge.
    float slope = amp * env * (wave(x + 0.01, t) - wave(x - 0.01, t)) / 0.02;
    float edge = 1.0 - smoothstep(0.0, rim, depth);
    vec2 bend = vec2(slope * 0.04, 0.035) * edge * edge * env * step(0.0, depth);

    vec4 from = texture(fromTex, cover(uv, fromSize));
    vec4 to = texture(toTex, cover(uv + bend, toSize));

    // Bright meniscus line on the surface, faint shadow just above it.
    float line = exp(-abs(depth) / (2.5 * px)) * env;
    float shade = (1.0 - smoothstep(0.0, 0.06, -depth)) * step(depth, 0.0) * env;
    from.rgb *= 1.0 - 0.25 * shade;
    to.rgb += 0.18 * edge * edge * env * step(0.0, depth);

    vec4 col = mix(from, to, smoothstep(-px, px, depth));
    col.rgb += 0.5 * line;
    fragColor = vec4(col.rgb, 1.0) * qt_Opacity;
}
