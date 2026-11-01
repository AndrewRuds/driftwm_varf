//_DEFINES_
precision highp float;
varying vec2 v_coords;
uniform sampler2D tex;
uniform vec2 u_halfpixel;
uniform float u_offset;
uniform float u_time;
uniform float alpha;
#if defined(DEBUG_FLAGS)
uniform float tint;
#endif

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i),                  hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

void main() {
    vec2 pixel = v_coords / (2.0 * u_halfpixel);
    vec2 flow = u_time * vec2(0.07, 0.05);

    // Blur strength modulation — broad smooth regions, subtle
    float blur_mod = 0.92 + 0.16 * value_noise(pixel * 0.02 + flow * 0.1);
    float offset = u_offset * blur_mod;

    // Global displacement — slow broad warp across the surface
    vec2 global_disp = vec2(
        value_noise(pixel * 0.015 + vec2(5.0, 9.0) + flow) - 0.5,
        value_noise(pixel * 0.015 + vec2(31.0, 53.0) - flow) - 0.5
    ) * 0.02;

    // Dense displacement — fine refraction ripples (rotated dual-octave)
    vec2 rp = mat2(0.8, 0.6, -0.6, 0.8) * pixel;
    vec2 fine_disp = vec2(
        (value_noise(pixel * 2.4 + flow * 2.0) + value_noise(rp * 3.7 - flow) * 0.5) / 1.5 - 0.5,
        (value_noise(pixel * 2.4 + vec2(43.0, 17.0) - flow * 2.0) + value_noise(rp * 3.7 + vec2(71.0, 23.0) + flow) * 0.5) / 1.5 - 0.5
    ) * 0.009;

    // Fade displacement to zero near texture edges — prevents edge artifacts
    float edge_x = min(v_coords.x, 1.0 - v_coords.x);
    float edge_y = min(v_coords.y, 1.0 - v_coords.y);
    float edge_fade = smoothstep(0.0, 0.1, min(edge_x, edge_y));

    vec2 margin = u_halfpixel * 3.0;
    vec2 uv = clamp(v_coords + (global_disp + fine_disp) * edge_fade, margin, 1.0 - margin);

    // Dual-kawase upsample with modulated offset
    vec4 sum = texture2D(tex, uv + vec2(-u_halfpixel.x * 2.0, 0.0) * offset);
    sum += texture2D(tex, uv + vec2(-u_halfpixel.x, u_halfpixel.y) * offset) * 2.0;
    sum += texture2D(tex, uv + vec2(0.0, u_halfpixel.y * 2.0) * offset);
    sum += texture2D(tex, uv + vec2(u_halfpixel.x, u_halfpixel.y) * offset) * 2.0;
    sum += texture2D(tex, uv + vec2(u_halfpixel.x * 2.0, 0.0) * offset);
    sum += texture2D(tex, uv + vec2(u_halfpixel.x, -u_halfpixel.y) * offset) * 2.0;
    sum += texture2D(tex, uv + vec2(0.0, -u_halfpixel.y * 2.0) * offset);
    sum += texture2D(tex, uv + vec2(-u_halfpixel.x, -u_halfpixel.y) * offset) * 2.0;

    gl_FragColor = sum / 12.0;
}
