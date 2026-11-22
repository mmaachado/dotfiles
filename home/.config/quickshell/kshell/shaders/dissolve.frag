#version 440

// Noise dissolve: the new wallpaper burns through in patches, with a faint
// glowing edge along the front.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 resolution;
    vec2 fromSize;
    vec2 toSize;
    float fillMode;
    float blurFill;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

// Sample an image the way Plasma fills the screen with it. fillMode is a Qt
// Image.FillMode, as Plasma stores it: 0 stretch, 1 fit, 2 crop (Plasma's
// default), 3 tile, 6 center. Fit and center leave empty space, which
// gets a blurred, cropped copy of the image (blurFill) or black.
vec2 cover(vec2 uv, vec2 s) {
    float scale = max(resolution.x / s.x, resolution.y / s.y);
    return (uv - 0.5) * resolution / (s * scale) + 0.5;
}

vec4 place(sampler2D tex, vec2 uv, vec2 size) {
    vec2 s = max(size, vec2(1.0));
    int mode = int(fillMode + 0.5);
    vec2 p;
    if (mode == 0) {
        p = uv;
    } else if (mode == 1) {
        float scale = min(resolution.x / s.x, resolution.y / s.y);
        p = (uv - 0.5) * resolution / (s * scale) + 0.5;
    } else if (mode == 3) {
        return texture(tex, fract(uv * resolution / s));
    } else if (mode == 6) {
        p = (uv - 0.5) * resolution / s + 0.5;
    } else {
        return texture(tex, cover(uv, s));
    }
    if (all(greaterThanEqual(p, vec2(0.0))) && all(lessThanEqual(p, vec2(1.0))))
        return texture(tex, p);
    if (blurFill < 0.5)
        return vec4(0.0, 0.0, 0.0, 1.0);
    // Cheap blur: a ring of taps around the cropped image, enough for the
    // few seconds the transition is on screen.
    vec2 c = cover(uv, s);
    vec4 sum = texture(tex, c);
    for (int i = 0; i < 12; i++) {
        float a = float(i) * 0.5236;
        vec2 o = vec2(cos(a), sin(a));
        sum += texture(tex, c + o * 0.02) + texture(tex, c + o * 0.045);
    }
    return vec4(sum.rgb / 25.0 * 0.8, 1.0);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

void main() {
    const float edge = 0.05;
    vec2 uv = qt_TexCoord0;
    float n = fbm(uv * vec2(resolution.x / resolution.y, 1.0) * 4.0);
    // fbm sits roughly in 0.2..0.8; stretch the threshold past both ends.
    float front = mix(0.1 - edge, 0.9 + edge, progress);
    float t = 1.0 - smoothstep(front - edge, front, n);
    float glow = (1.0 - abs(n - front + edge * 0.5) / edge);
    glow = clamp(glow, 0.0, 1.0) * sin(progress * 3.14159265);

    vec4 from = place(fromTex, uv, fromSize);
    vec4 to = place(toTex, uv, toSize);
    vec4 col = mix(from, to, t);
    col.rgb += vec3(1.0, 0.85, 0.6) * 0.45 * glow * glow;
    fragColor = vec4(col.rgb, 1.0) * qt_Opacity;
}
