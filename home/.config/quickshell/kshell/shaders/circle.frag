#version 440

// Iris that opens from the centre of the screen, with a thin soft rim.

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

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / resolution.y;
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
    float dist = length(p);
    float maxR = length(vec2(aspect, 1.0) * 0.5);
    float px = 1.5 / resolution.y;
    float rim = 0.015;
    float r = progress * (maxR + rim * 2.0);
    float env = sin(progress * 3.14159265);

    vec4 from = texture(fromTex, cover(uv, fromSize));
    vec4 to = texture(toTex, cover(uv, toSize));
    vec4 col = mix(to, from, smoothstep(r - px, r + px, dist));
    // Shadow just outside the opening, light line on its edge.
    col.rgb *= 1.0 - 0.3 * env * (1.0 - smoothstep(0.0, 0.08, dist - r)) * step(r, dist);
    col.rgb += 0.35 * env * exp(-abs(dist - r) / (2.0 * px));
    fragColor = vec4(col.rgb, 1.0) * qt_Opacity;
}
