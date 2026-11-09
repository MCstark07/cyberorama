



// Mapping node: location, rotation (radians), scale
vec2 mapping(vec2 p, vec2 location, float rotation, vec2 scale) {
    p = p * scale + location;
    float c = cos(rotation), s = sin(rotation);
    return mat2(c, -s, s, c) * p;
}


// Map Range node
float mapRange(float v, float fromMin, float fromMax, float toMin, float toMax) {
    float t = clamp((v - fromMin) / (fromMax - fromMin), 0.0, 1.0);
    return mix(toMin, toMax, t);
}
// Color Ramp node, 4 stops. pos[] must be increasing.
// mode: 0 = Linear, 1 = Ease, 2 = Constant
vec3 colorRamp4(float t, float pos[4], vec3 col[4], int mode) {
    vec3 c = col[0];
    for (int i = 0; i < 3; i++) {
        float k = clamp((t - pos[i]) / (pos[i + 1] - pos[i]), 0.0, 1.0);
        if (mode == 1) k = smoothstep(0.0, 1.0, k);
        if (mode == 2) k = step(1.0, k);
        c = mix(c, col[i + 1], k);
    }
    return c;
}

// Cosine palette (Inigo Quilez): a whole smooth ramp from 4 vec3s
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// ---------- MIX (COLOR) NODE ----------

vec3 mixMix     (vec3 a, vec3 b, float f) { return mix(a, b, f); }
vec3 mixAdd     (vec3 a, vec3 b, float f) { return mix(a, a + b, f); }
vec3 mixMultiply(vec3 a, vec3 b, float f) { return mix(a, a * b, f); }
vec3 mixScreen  (vec3 a, vec3 b, float f) { return mix(a, 1.0 - (1.0 - a) * (1.0 - b), f); }
vec3 mixOverlay (vec3 a, vec3 b, float f) {
    vec3 r = mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
    return mix(a, r, f);
}

// ---------- WHITE NOISE NODE ----------

float whiteNoise1(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
vec2 whiteNoise2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// ---------- NOISE TEXTURE NODE ----------

float gradNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 g00 = whiteNoise2(i) * 2.0 - 1.0;
    vec2 g10 = whiteNoise2(i + vec2(1, 0)) * 2.0 - 1.0;
    vec2 g01 = whiteNoise2(i + vec2(0, 1)) * 2.0 - 1.0;
    vec2 g11 = whiteNoise2(i + vec2(1, 1)) * 2.0 - 1.0;
    float n = mix(mix(dot(g00, f),              dot(g10, f - vec2(1, 0)), u.x),
                  mix(dot(g01, f - vec2(0, 1)), dot(g11, f - vec2(1, 1)), u.x), u.y);
    return n * 0.7 + 0.5;
}

// Noise Texture node: scale, detail, roughness, lacunarity
// (max detail 8 so the loop has a constant bound)
float noiseTexture(vec2 p, float scale, int detail, float roughness, float lacunarity) {
    p *= scale;
    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < 8; i++) {
        if (i >= detail) break;
        sum  += amp * gradNoise(p);
        norm += amp;
        p    *= lacunarity;
        amp  *= roughness;
    }
    return sum / norm;
}

// Ridged variant (Musgrave-style)
float ridgedNoise(vec2 p, float scale, int detail) {
    p *= scale;
    float sum = 0.0, amp = 0.5;
    for (int i = 0; i < 8; i++) {
        if (i >= detail) break;
        float n = 1.0 - abs(gradNoise(p) * 2.0 - 1.0);
        sum += amp * n * n;
        p *= 2.0; amp *= 0.5;
    }
    return sum;
}

// ---------- VORONOI TEXTURE NODE (multiple outputs) ----------

struct VoronoiOut {
    float distance;   // F1
    float edge;       // F2 - F1 (0 on the borders)
    vec2  position;   // position of the nearest cell point
    float color;      // random 0..1 per cell
};

// metric: 0 = Euclidean, 1 = Manhattan, 2 = Chebyshev
VoronoiOut voronoi(vec2 p, float scale, float randomness, int metric) {
    p *= scale;
    vec2 baseCell = floor(p);
    vec2 localPos = fract(p);

    float F1 = 10.0, F2 = 10.0;
    vec2 nearestCell = vec2(0.0);
    vec2 nearestPoint = vec2(0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 nb = vec2(float(x), float(y));
            vec2 cell = baseCell + nb;
            vec2 pt = nb + mix(vec2(0.5), whiteNoise2(cell), randomness);
            vec2 diff = pt - localPos;

            float d;
            if (metric == 0)      d = length(diff);
            else if (metric == 1) d = abs(diff.x) + abs(diff.y);
            else                  d = max(abs(diff.x), abs(diff.y));

            if (d < F1) {
                F2 = F1; F1 = d;
                nearestCell = cell;
                nearestPoint = baseCell + pt;
            } else if (d < F2) {
                F2 = d;
            }
        }
    }

    VoronoiOut o;
    o.distance = F1;
    o.edge = F2 - F1;
    o.position = nearestPoint / scale;
    o.color = whiteNoise1(nearestCell);
    return o;
}
