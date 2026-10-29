#version 440

// Crossfade, with the new wallpaper settling from a slight zoom.

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
    float zoom = mix(1.06, 1.0, progress);
    vec4 from = texture(fromTex, cover(uv, fromSize));
    vec4 to = texture(toTex, cover((uv - 0.5) / zoom + 0.5, toSize));
    fragColor = vec4(mix(from, to, progress).rgb, 1.0) * qt_Opacity;
}
