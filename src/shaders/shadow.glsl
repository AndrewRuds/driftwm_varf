// shadow.glsl — ERF-based analytical Gaussian shadow
precision mediump float;
varying vec2 v_coords;
uniform float alpha;
uniform vec2 size;        // element size in shader-logical units
uniform vec4 u_window_rect; // (x, y, w, h) window rect within element
uniform float u_radius; // shadow extent (= 3σ)
uniform vec4 u_color;
uniform float u_corner_radius;

// Squircle exponent: 2.0 = circular corners, higher = squarer. Matches
// corner_clip.glsl and border.glsl.
const float n = 4.0;

vec2 erf_approx(vec2 v) {
    vec2 s = sign(v);
    vec2 a = abs(v);
    vec2 r1 = 1.0 + (0.278393 + (0.230389 + (0.000972 + 0.078108 * a) * a) * a) * a;
    vec2 r2 = r1 * r1;
    return s - s / (r2 * r2);
}

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * 3.14159265) * sigma);
}

float blur_along_x(float x, float y, float sigma, float corner, vec2 half_size) {
    float delta = min(half_size.y - corner - abs(y), 0.0);
    float curved = half_size.x;
    if (corner > 0.0) {
        curved = half_size.x - corner
            + corner * pow(max(0.0, 1.0 - pow(abs(delta) / corner, n)), 1.0 / n);
    }
    vec2 integral = 0.5 + 0.5 * erf_approx((x + vec2(-curved, curved)) * (sqrt(0.5) / sigma));
    return integral.y - integral.x;
}

float sd_squircle(vec2 p, vec2 half_size, float r, float n) {
    vec2 d = abs(p) - half_size + vec2(r);
    if (r <= 0.0) {
        return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
    }
    vec2 q = max(d, vec2(0.0)) / r;
    float se = r * (pow(pow(q.x, n) + pow(q.y, n), 1.0 / n)) - r;
    return max(se, min(max(d.x, d.y), 0.0));
}

void main() {
    vec2 pixel = v_coords * size;

    // Window center and half-size
    vec2 center = u_window_rect.xy + u_window_rect.zw * 0.5;
    vec2 half_size = u_window_rect.zw * 0.5;
    vec2 p = pixel - center; // center-relative position

    float sigma = u_radius / 3.0;
    float corner = u_corner_radius;

    // Clamp Y integration range to where signal is non-zero
    float low = p.y - half_size.y;
    float high = p.y + half_size.y;
    float start = clamp(-3.0 * sigma, low, high);
    float end = clamp(3.0 * sigma, low, high);

    // 4-sample midpoint quadrature
    float step_size = (end - start) / 4.0;
    float y = start + step_size * 0.5;
    float shadow = 0.0;
    for (int i = 0; i < 4; i++) {
        shadow += blur_along_x(p.x, p.y - y, sigma, corner, half_size)
                * gaussian(y, sigma) * step_size;
        y += step_size;
    }

    // Mask interior (shadow is behind the window). The full SDF, not just its
    // exterior term: with a square corner that term is 0 across the whole
    // interior, so step() would leave the body unmasked.
    float dist = sd_squircle(p, half_size, corner, n);
    float outside = step(0.0, dist);

    gl_FragColor = u_color * shadow * outside * alpha;
}
