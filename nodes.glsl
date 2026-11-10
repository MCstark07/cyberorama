// nodes.glsl
// main.cpp already puts #version, FragColor, u_camera and u_time above this,
// so don't redeclare any of that here. also: a function has to sit above
// anything that calls it, so the order of this file matters.

const float PI  = 3.14159265359;
const float TAU = 6.28318530718;


// pixelate: snaps (screen pixel + camera) onto a grid of pixelSize, so
// everything built from it comes out as square blocks. pixelSize is in real
// screen pixels: 4.0 = 4x4 blocks. <= 1.0 leaves it smooth.
vec2 pixelate(vec2 fragCoord, vec2 camera, float pixelSize) {
    vec2 p = fragCoord + camera;
    if (pixelSize <= 1.0) return p;
    return floor(p / pixelSize) * pixelSize;
}

// mapping: the Blender Mapping node (point mode). same order as Blender:
// scale first, then rotate (radians, counter-clockwise), then move by location.
// scale = vec2(1.0 / 80.0) means "one unit = 80 pixels".
vec2 mapping(vec2 p, vec2 location, float rotation, vec2 scale) {
    float c = cos(rotation), s = sin(rotation);
    return mat2(c, s, -s, c) * (p * scale) + location;
}


// math node helpers

// map range with clamp on: v in [a, b] -> [c, d]
float mapRange(float v, float a, float b, float c, float d) {
    float w = b - a;
    if (abs(w) < 1e-6) return c;
    return mix(c, d, clamp((v - a) / w, 0.0, 1.0));
}

// bounces x back and forth between 0 and s, like a triangle wave. great for mirrored scrolling
float mathPingPong(float x, float s) {
    if (s == 0.0) return 0.0;
    return abs(fract((x - s) / (s * 2.0)) * s * 2.0 - s);
}

// floors x down to a multiple of inc (this is what Blender's Snap does).
// good for stair-stepped values
float mathSnap(float x, float inc) {
    if (inc == 0.0) return 0.0;
    return floor(x / inc) * inc;
}

// loops x so it always stays between lo and hi
float mathWrap(float x, float lo, float hi) {
    float r = hi - lo;
    return r != 0.0 ? x - r * floor((x - lo) / r) : lo;
}

// min() but the corner is rounded off. k = how wide the rounding is, 0 = normal min
float mathSmoothMin(float a, float b, float k) {
    if (k == 0.0) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
}

float mathSmoothMax(float a, float b, float k) {
    return -mathSmoothMin(-a, -b, k);
}


// color ramp
//
// the core one takes 8 slots plus a count n, and the colorRamp2/3/4/5/8
// versions below just pad their stops into it. so there's only one real
// implementation to trust.
//
// mode: 0 = constant (hard bands, no blending, pixel art steps)
//       1 = linear
//       2 = ease (smoothstep s-curve between each pair of stops)
//       3 = cardinal (catmull-rom curve that flows through every stop, extra smooth)
// pos[] has to be increasing, 0.0 to 1.0

// catmull-rom spline through b..c, using a and d as the neighbours
vec3 catmull(vec3 a, vec3 b, vec3 c, vec3 d, float t) {
    float t2 = t * t, t3 = t2 * t;
    return 0.5 * (2.0 * b
                + (c - a) * t
                + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2
                + (3.0 * b - a - 3.0 * c + d) * t3);
}

vec3 colorRampN(float fac, float pos[8], vec3 col[8], int n, int mode) {
    n = clamp(n, 2, 8);
    if (fac <= pos[0]) return col[0];
    if (fac >= pos[n - 1]) return col[n - 1];

    // find the segment: last stop whose position is <= fac
    int i = 0;
    for (int j = 1; j < 8; j++) {
        if (j >= n) break;
        if (fac >= pos[j]) i = j;
    }

    if (mode == 0) return col[i];

    float w = max(pos[i + 1] - pos[i], 1e-5);
    float k = clamp((fac - pos[i]) / w, 0.0, 1.0);

    if (mode == 2) k = smoothstep(0.0, 1.0, k);
    if (mode == 3) {
        vec3 a = col[max(i - 1, 0)];
        vec3 d = col[min(i + 2, n - 1)];
        return clamp(catmull(a, col[i], col[i + 1], d, k), 0.0, 1.0);
    }
    return mix(col[i], col[i + 1], k);
}

// quick 2-stop ramp, everything inline
vec3 colorRamp2(float fac, float pos0, vec3 col0, float pos1, vec3 col1, int mode) {
    float p[8] = float[8](pos0, pos1, pos1, pos1, pos1, pos1, pos1, pos1);
    vec3  c[8] = vec3[8](col0, col1, col1, col1, col1, col1, col1, col1);
    return colorRampN(fac, p, c, 2, mode);
}

vec3 colorRamp3(float fac, float pos[3], vec3 col[3], int mode) {
    float p[8]; vec3 c[8];
    for (int i = 0; i < 8; i++) { int j = min(i, 2); p[i] = pos[j]; c[i] = col[j]; }
    return colorRampN(fac, p, c, 3, mode);
}

vec3 colorRamp4(float fac, float pos[4], vec3 col[4], int mode) {
    float p[8]; vec3 c[8];
    for (int i = 0; i < 8; i++) { int j = min(i, 3); p[i] = pos[j]; c[i] = col[j]; }
    return colorRampN(fac, p, c, 4, mode);
}

vec3 colorRamp5(float fac, float pos[5], vec3 col[5], int mode) {
    float p[8]; vec3 c[8];
    for (int i = 0; i < 8; i++) { int j = min(i, 4); p[i] = pos[j]; c[i] = col[j]; }
    return colorRampN(fac, p, c, 5, mode);
}

vec3 colorRamp8(float fac, float pos[8], vec3 col[8], int mode) {
    return colorRampN(fac, pos, col, 8, mode);
}

// a black-to-white ramp in one line, for crunching contrast on grayscale.
// pushes everything <= low to 0 and everything >= high to 1.
// mode 0 = hard cut at high (low is ignored), 1 = linear, 2 = smoothstep, 3 = extra-smooth quintic.
// keep low < high
float rampMask(float fac, float low, float high, int mode) {
    if (mode == 0) return step(high, fac);
    float t = clamp((fac - low) / max(high - low, 1e-5), 0.0, 1.0);
    if (mode == 2) return t * t * (3.0 - 2.0 * t);
    if (mode == 3) return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
    return t;
}

// cosine palette (iq). a = base, b = how far it swings, c = how many cycles, d = phase shift.
// t keeps looping past 1.0, so you can scroll it with u_time.
// try: palette(t, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67))
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(TAU * (c * t + d));
}


// mix color node. a = base color, b = the color you blend in, f = fac (0 = just a, 1 = full effect)

vec3 mixBlend(vec3 a, vec3 b, float f)    { return mix(a, b, f); }
vec3 mixAdd(vec3 a, vec3 b, float f)      { return mix(a, a + b, f); }
vec3 mixMultiply(vec3 a, vec3 b, float f) { return mix(a, a * b, f); }
vec3 mixSubtract(vec3 a, vec3 b, float f) { return mix(a, a - b, f); }
vec3 mixDifference(vec3 a, vec3 b, float f) { return mix(a, abs(a - b), f); }
vec3 mixDarken(vec3 a, vec3 b, float f)   { return mix(a, min(a, b), f); }
vec3 mixLighten(vec3 a, vec3 b, float f)  { return mix(a, max(a, b), f); }

// screen is the glow one: it can only brighten, and black does nothing
vec3 mixScreen(vec3 a, vec3 b, float f) {
    return mix(a, 1.0 - (1.0 - a) * (1.0 - b), f);
}

// overlay: multiply in the darks, screen in the lights, so contrast goes up
vec3 mixOverlay(vec3 a, vec3 b, float f) {
    vec3 o = mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
    return mix(a, o, f);
}

// divide: a / b, with b clamped so you don't get infinity
vec3 mixDivide(vec3 a, vec3 b, float f) {
    return mix(a, a / max(b, vec3(1e-4)), f);
}

// dodge brightens a hard, burn darkens it hard
vec3 mixColorDodge(vec3 a, vec3 b, float f) {
    vec3 o = clamp(a / max(1.0 - b, vec3(1e-4)), 0.0, 1.0);
    return mix(a, o, f);
}

vec3 mixColorBurn(vec3 a, vec3 b, float f) {
    vec3 o = 1.0 - clamp((1.0 - a) / max(b, vec3(1e-4)), 0.0, 1.0);
    return mix(a, o, f);
}

// soft light: a gentler overlay, same formula Blender uses
vec3 mixSoftLight(vec3 a, vec3 b, float f) {
    vec3 scr = 1.0 - (1.0 - b) * (1.0 - a);
    return mix(a, (1.0 - a) * b * a + a * scr, f);
}

// linear light: just shifts a up or down by how far b is from gray
vec3 mixLinearLight(vec3 a, vec3 b, float f) {
    return a + f * (2.0 * b - 1.0);
}


// white noise: pure hash, same input = same output, no smoothing at all.
// whiteNoise1 gives 1 random number 0..1, whiteNoise2 gives 2, whiteNoise3 gives 3.
// feed them floor()ed coordinates to get random blocks.
// (these are the dave hoskins hashes, no sin() so they behave on every gpu)

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

vec3 whiteNoise3(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// the s-curve used by perlin/value noise, flatter at the corners than smoothstep
vec2 quintic(vec2 f) {
    return f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
}

// value noise: random value at each grid corner, blended smoothly. cheap, a bit blobby/boxy
float valueNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = quintic(f);
    float a = whiteNoise1(i);
    float b = whiteNoise1(i + vec2(1.0, 0.0));
    float c = whiteNoise1(i + vec2(0.0, 1.0));
    float d = whiteNoise1(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// random unit direction for a grid corner
vec2 grad2(vec2 c) {
    float a = whiteNoise1(c) * TAU;
    return vec2(cos(a), sin(a));
}

// perlin noise: each corner has a random direction instead of a random value, and
// you blend how much the pixel lines up with those directions. smoother and less
// boxy than value noise. this is what Blender's Noise Texture is built on. returns ~0..1
float perlinNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = quintic(f);
    float a = dot(grad2(i), f);
    float b = dot(grad2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(grad2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(grad2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
    float n = mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    return n * 0.7071 + 0.5;
}

// simplex noise: same idea as perlin but on a triangle grid, so there are fewer
// visible grid directions and diagonals look natural. returns ~0..1
float simplexNoise(vec2 p) {
    const float K1 = 0.366025404;   // (sqrt(3) - 1) / 2
    const float K2 = 0.211324865;   // (3 - sqrt(3)) / 6
    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - i + (i.x + i.y) * K2;
    float m = step(a.y, a.x);
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;
    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, grad2(i)), dot(b, grad2(i + o)), dot(c, grad2(i + 1.0)));
    return clamp(dot(n, vec3(99.2)) * 0.5 + 0.5, 0.0, 1.0);
}

// curl noise: a swirly vector field (returns a vec2 direction, roughly -1..1).
// it's the "rotated slope" of perlin noise, which can't have sources or sinks,
// so it looks like flowing smoke. use it to warp coordinates:  uv += curlNoise(uv * 2.0) * 0.3
vec2 curlNoise(vec2 p) {
    float e = 0.01;
    float dx = perlinNoise(p + vec2(e, 0.0)) - perlinNoise(p - vec2(e, 0.0));
    float dy = perlinNoise(p + vec2(0.0, e)) - perlinNoise(p - vec2(0.0, e));
    return vec2(dy, -dx) / (2.0 * e);
}

// plain layered perlin, lacunarity fixed at 2. used internally (wave texture etc)
float fbmPerlin(vec2 p, int detail, float rough) {
    float sum = 0.0, amp = 1.0, norm = 0.0;
    int n = clamp(detail, 1, 12);
    for (int i = 0; i < n; i++) {
        sum += amp * perlinNoise(p);
        norm += amp;
        amp *= rough;
        p *= 2.0;
    }
    return sum / norm;
}


// noise texture: Blender's Noise Texture on top of perlinNoise.
//   scale       bigger = smaller features
//   detail      how many octaves (layers of finer noise), 1..12
//   roughness   how loud each finer layer is (0.5 is the default look)
//   lacunarity  how much smaller each layer is than the last (2.0 default)
//   distortion  warps the coords with another noise first, 0 = off
//   type        0 fBm (the classic cloudy one)
//               1 multifractal (layers multiply: peaky, lots of dark, bright spots)
//               2 ridged multifractal (sharp bright ridges, great for veins/lightning)
//               3 hybrid multifractal (detail only shows up where it's already bright)
//               4 hetero terrain (smooth valleys, rough mountains)
// returns about 0..1. multifractal and hetero can poke a little over 1 sometimes,
// which is fine since the color ramps clamp.
float noiseTexture(vec2 p, float scale, int detail, float roughness, float lacunarity, float distortion, int type) {
    p *= scale;
    if (distortion != 0.0) {
        vec2 w = vec2(perlinNoise(p + vec2(31.7, 11.3)), perlinNoise(p + vec2(7.9, 53.1)));
        p += distortion * (w * 2.0 - 1.0);
    }
    int n = clamp(detail, 1, 12);

    if (type == 1) {
        float v = 1.0, amp = 1.0;
        for (int i = 0; i < n; i++) {
            v *= amp * (perlinNoise(p) * 2.0 - 1.0) + 1.0;
            amp *= roughness;
            p *= lacunarity;
        }
        return v * 0.5;
    }

    if (type == 2) {
        float s = 1.0 - abs(perlinNoise(p) * 2.0 - 1.0);
        s *= s;
        float v = s, amp = 1.0, norm = 1.0;
        for (int i = 1; i < n; i++) {
            p *= lacunarity;
            amp *= roughness;
            float w = clamp(s * 2.0, 0.0, 1.0);
            s = 1.0 - abs(perlinNoise(p) * 2.0 - 1.0);
            s = s * s * w;
            v += s * amp;
            norm += amp;
        }
        return v / norm;
    }

    if (type == 3) {
        float v = perlinNoise(p);
        float w = v, amp = 1.0, norm = 1.0;
        for (int i = 1; i < n; i++) {
            p *= lacunarity;
            amp *= roughness;
            w = min(w, 1.0);
            float sig = perlinNoise(p) * amp;
            v += w * sig;
            w *= sig;
            norm += amp;
        }
        return v / norm;
    }

    if (type == 4) {
        float v = perlinNoise(p), amp = 1.0;
        for (int i = 1; i < n; i++) {
            p *= lacunarity;
            amp *= roughness;
            v += perlinNoise(p) * amp * v;
        }
        return v;
    }

    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < n; i++) {
        sum += amp * perlinNoise(p);
        norm += amp;
        amp *= roughness;
        p *= lacunarity;
    }
    return sum / norm;
}


// voronoi: Blender's Voronoi Texture, 2D. scatter one random point per grid cell,
// then every pixel asks "which points are closest to me?"
//
// outputs (all in the struct):
//   distance   the main value, depends on feature (see below)
//   edge       F2 - F1, about 0 on cell borders. quick outlines. (in feature 3 it's the true edge distance)
//   color      one random 0..1 number per cell
//   cellColor  one random rgb per cell
//   position   the cell's point, in your original (unscaled) coordinates
//   radius     only filled for feature 4
struct VoronoiOut {
    float distance;
    float edge;
    float color;
    vec3  cellColor;
    vec2  position;
    float radius;
};

// the distance metric. this is the one-number switch for cell shape:
// 0 euclidean (round), 1 manhattan (diamond), 2 chebyshev (square), 3 minkowski (in between, set by expP)
float vDist(vec2 d, int metric, float expP) {
    if (metric == 1) return abs(d.x) + abs(d.y);
    if (metric == 2) return max(abs(d.x), abs(d.y));
    if (metric == 3) {
        float e = max(expP, 0.01);
        return pow(pow(max(abs(d.x), 1e-6), e) + pow(max(abs(d.y), 1e-6), e), 1.0 / e);
    }
    return length(d);
}

// the random point inside a cell (0..1 offset, shrunk toward the corner by randomness)
vec2 vPoint(vec2 cell, float rnd) {
    return whiteNoise2(cell) * rnd;
}

// extra hash for the 1d per-cell color, shifted so it isn't tied to the point position
float vColor(vec2 cell) {
    return whiteNoise1(cell + vec2(31.7, 17.3));
}

// feature: 0 = F1  (distance to the nearest point, the classic cell look)
//          1 = F2  (distance to the second nearest point)
//          2 = smooth F1 (F1 with blobby merged cells, smoothness 0..1 controls it)
//          3 = distance to edge (constant-width borders, always euclidean, metric ignored)
//          4 = n-sphere radius (half the gap to the neighbour point, always euclidean, metric ignored)
// randomness: 0 = points sit on a regular grid, 1 = fully random
// expP only matters when metric = 3
VoronoiOut voronoi(vec2 p, float scale, float randomness, int metric, float expP, int feature, float smoothness) {
    scale = max(scale, 1e-5);
    p *= scale;
    vec2 cp = floor(p);
    vec2 lp = p - cp;
    float rnd = clamp(randomness, 0.0, 1.0);

    VoronoiOut o;
    o.distance = 0.0;
    o.edge = 0.0;
    o.color = 0.0;
    o.cellColor = vec3(0.0);
    o.position = vec2(0.0);
    o.radius = 0.0;

    if (feature == 3) {
        // pass 1: find the closest point. pass 2: for every point, how far is the
        // border between it and the closest one? the smallest of those is the edge distance
        vec2 mr = vec2(0.0);
        vec2 mcell = cp;
        float md = 8.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 cell = cp + vec2(float(i), float(j));
                vec2 rv = vec2(float(i), float(j)) + vPoint(cell, rnd) - lp;
                float dd = dot(rv, rv);
                if (dd < md) { md = dd; mr = rv; mcell = cell; }
            }
        }
        md = 8.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 cell = cp + vec2(float(i), float(j));
                vec2 rv = vec2(float(i), float(j)) + vPoint(cell, rnd) - lp;
                vec2 perp = rv - mr;
                if (dot(perp, perp) > 0.0001) {
                    md = min(md, dot(0.5 * (mr + rv), normalize(perp)));
                }
            }
        }
        o.distance = md;
        o.edge = md;
        o.color = vColor(mcell);
        o.cellColor = whiteNoise3(mcell);
        o.position = (p + mr) / scale;
        return o;
    }

    if (feature == 4) {
        // find the closest point, then the closest point to THAT one. radius is half the gap
        vec2 cpt = vec2(0.0);
        vec2 coff = vec2(0.0);
        vec2 ccell = cp;
        float md = 8.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 off = vec2(float(i), float(j));
                vec2 cell = cp + off;
                vec2 pt = off + vPoint(cell, rnd);
                float dd = length(pt - lp);
                if (dd < md) { md = dd; cpt = pt; coff = off; ccell = cell; }
            }
        }
        md = 8.0;
        for (int j = -2; j <= 2; j++) {
            for (int i = -2; i <= 2; i++) {
                vec2 off = vec2(float(i), float(j));
                if (off == coff) continue;
                vec2 pt = off + vPoint(cp + off, rnd);
                md = min(md, length(cpt - pt));
            }
        }
        o.radius = md * 0.5;
        o.distance = o.radius;
        o.color = vColor(ccell);
        o.cellColor = whiteNoise3(ccell);
        o.position = (cp + cpt) / scale;
        return o;
    }

    // features 0, 1, 2. smooth F1 looks at a 5x5 block, the others a 3x3
    int rad = (feature == 2) ? 2 : 1;
    float sm = clamp(smoothness, 0.0001, 1.0);

    float f1 = 8.0, f2 = 8.0;
    vec2 c1 = cp, c2 = cp;
    vec2 pt1 = vec2(0.0), pt2 = vec2(0.0);

    float sd = 8.0;
    float sc = 0.0;
    vec3 sc3 = vec3(0.0);
    vec2 sp = vec2(0.0);

    for (int j = -rad; j <= rad; j++) {
        for (int i = -rad; i <= rad; i++) {
            vec2 off = vec2(float(i), float(j));
            vec2 cell = cp + off;
            vec2 pt = off + vPoint(cell, rnd);
            float d = vDist(pt - lp, metric, expP);

            if (d < f1) {
                f2 = f1; c2 = c1; pt2 = pt1;
                f1 = d;  c1 = cell; pt1 = pt;
            } else if (d < f2) {
                f2 = d; c2 = cell; pt2 = pt;
            }

            if (feature == 2) {
                // blend each new point in with a smooth weight h, then subtract a
                // little correction so the blended value doesn't dip below the true min
                float h = smoothstep(0.0, 1.0, 0.5 + 0.5 * (sd - d) / sm);
                float corr = sm * h * (1.0 - h);
                sd = mix(sd, d, h) - corr;
                corr /= 1.0 + 3.0 * sm;
                sc3 = mix(sc3, whiteNoise3(cell), h) - corr;
                sc  = mix(sc, vColor(cell), h) - corr;
                sp  = mix(sp, pt, h) - corr;
            }
        }
    }

    o.edge = f2 - f1;
    if (feature == 1) {
        o.distance = f2;
        o.color = vColor(c2);
        o.cellColor = whiteNoise3(c2);
        o.position = (cp + pt2) / scale;
    } else if (feature == 2) {
        o.distance = sd;
        o.color = sc;
        o.cellColor = sc3;
        o.position = (cp + sp) / scale;
    } else {
        o.distance = f1;
        o.color = vColor(c1);
        o.cellColor = whiteNoise3(c1);
        o.position = (cp + pt1) / scale;
    }
    return o;
}

// shortcut for the usual case: F1 with a metric and nothing else to think about
VoronoiOut voronoiF1(vec2 p, float scale, float randomness, int metric) {
    return voronoi(p, scale, randomness, metric, 1.5, 0, 0.0);
}

// voronoi stacked in octaves, like the fractal option on the Blender node.
// each octave is smaller (lacunarity) and quieter (roughness). everything gets
// averaged at the end so the outputs stay in a normal range.
VoronoiOut voronoiFractal(vec2 p, float scale, float randomness, int metric, float expP, int feature, float smoothness, int detail, float roughness, float lacunarity) {
    VoronoiOut o;
    o.distance = 0.0;
    o.edge = 0.0;
    o.color = 0.0;
    o.cellColor = vec3(0.0);
    o.position = vec2(0.0);
    o.radius = 0.0;

    int n = clamp(detail, 1, 8);
    float amp = 1.0, norm = 0.0, s = scale;
    for (int i = 0; i < n; i++) {
        // little shift per octave so the octaves don't share the same origin point
        VoronoiOut v = voronoi(p + float(i) * vec2(17.3, 9.1), s, randomness, metric, expP, feature, smoothness);
        o.distance  += amp * v.distance;
        o.edge      += amp * v.edge;
        o.color     += amp * v.color;
        o.cellColor += amp * v.cellColor;
        o.position  += amp * v.position;
        o.radius    += amp * v.radius;
        norm += amp;
        amp *= roughness;
        s *= lacunarity;
    }
    o.distance  /= norm;
    o.edge      /= norm;
    o.color     /= norm;
    o.cellColor /= norm;
    o.position  /= norm;
    o.radius    /= norm;
    return o;
}


// wave texture: stripes or rings. returns 0..1.
//   type    0 = bands (stripes running along x, rotate them with the mapping node), 1 = rings (circles around the origin)
//   profile 0 = sine (soft), 1 = saw (ramp then snap back), 2 = triangle (sharp zigzag)
//   scale   frequency. in this setup try 0.05 to 0.5, Blender's 5.0 is way too dense for our units
//   distortion, detail, detailRoughness: wobble the lines with perlin noise. distortion 0 = perfectly clean
//   phase   slides the pattern along (radians). put u_time in here to animate
float waveTexture(vec2 p, int type, int profile, float scale, float distortion, int detail, float detailRoughness, float phase) {
    p *= scale;
    float n = (type == 1) ? length(p) * 20.0 : p.x * 20.0;
    n += phase;
    if (distortion != 0.0) {
        n += distortion * (fbmPerlin(p, max(detail, 1), detailRoughness) * 2.0 - 1.0);
    }
    if (profile == 1) return fract(n / TAU);
    if (profile == 2) {
        float t = n / TAU;
        return abs(t - floor(t + 0.5)) * 2.0;
    }
    return 0.5 + 0.5 * sin(n - 0.5 * PI);
}

// magic texture: those trippy psychedelic color swirls from stacked sin/cos.
// returns an rgb color. (Blender's Fac output is just the average of r, g, b)
//   distortion  how much the swirls fold in on each other
//   depth       how many times it folds, 0..6. more = busier
vec3 magicTexture(vec2 p, float scale, float distortion, int depth) {
    p *= scale;
    float x = sin((p.x + p.y) * 5.0);
    float y = cos((-p.x + p.y) * 5.0);
    float z = -cos((-p.x - p.y) * 5.0);

    if (depth > 0) {
        x *= distortion; y *= distortion; z *= distortion;
        y = -cos(x - y + z); y *= distortion;
        if (depth > 1) {
            x = cos(x - y - z); x *= distortion;
            if (depth > 2) {
                z = sin(-x - y - z); z *= distortion;
                if (depth > 3) {
                    x = -cos(-x + y - z); x *= distortion;
                    if (depth > 4) {
                        y = -sin(-x + y - z); y *= distortion;
                        if (depth > 5) {
                            y = -cos(-x + z - y); y *= distortion;
                        }
                    }
                }
            }
        }
    }

    if (distortion != 0.0) {
        float d = distortion * 2.0;
        x /= d; y /= d; z /= d;
    }
    return vec3(0.5 - x, 0.5 - y, 0.5 - z);
}

// checker texture: 0 or 1 squares. 1.0 - result swaps the two colors
float checkerTexture(vec2 p, float scale) {
    vec2 q = floor(p * scale);
    return mod(q.x + q.y, 2.0);
}

// brick texture: rows of offset bricks with mortar lines between them.
//   scale        overall size
//   mortarSize   thickness of the mortar (0.02 is thin, 0.08 is chunky)
//   mortarSmooth soften the mortar edge, 0 = razor sharp
//   bias         pushes the per-brick random value darker (-1) or brighter (+1)
//   brickWidth   0.5 is Blender's default
//   rowHeight    0.25 is Blender's default
//   offset       how far every other row slides sideways, 0.5 = classic half-brick
// fac is 1 on the brick and 0 on the mortar (flip it with 1.0 - fac if you want the mortar mask).
// color is a random 0..1 per brick, run it through a color ramp. id is the brick's grid number.
struct BrickOut {
    float fac;
    float color;
    vec2  id;
};

BrickOut brickTexture(vec2 p, float scale, float mortarSize, float mortarSmooth, float bias, float brickWidth, float rowHeight, float offset) {
    p *= scale;
    float row = floor(p.y / rowHeight);
    float shift = (mod(row, 2.0) < 0.5) ? brickWidth * offset : 0.0;
    float bx = p.x + shift;
    float bn = floor(bx / brickWidth);
    vec2 q = vec2(bx - brickWidth * bn, p.y - rowHeight * row);

    // how close are we to the nearest brick side?
    float md = min(min(q.x, q.y), min(brickWidth - q.x, rowHeight - q.y));

    float mortar;
    if (mortarSmooth <= 0.0) mortar = (md < mortarSize) ? 1.0 : 0.0;
    else mortar = 1.0 - smoothstep(0.0, mortarSmooth, md - mortarSize);

    BrickOut o;
    o.fac = 1.0 - mortar;
    o.color = clamp(whiteNoise1(vec2(row, bn)) + bias, 0.0, 1.0);
    o.id = vec2(bn, row);
    return o;
}

// gradient texture. feed it coordinates centered around 0 (use mapping with a
// negative location to move the center where you want it).
//   0 linear     p.x
//   1 quadratic  p.x squared (clamped at 0)
//   2 easing     smoothstep(p.x) between 0 and 1
//   3 diagonal   (p.x + p.y) / 2
//   4 spherical  1 at the center, fades to 0 at distance 1
//   5 radial     angle around the center, wraps 0..1 (like a color wheel / sweep)
float gradientTexture(vec2 p, int type) {
    if (type == 1) { float t = max(p.x, 0.0); return t * t; }
    if (type == 2) { float t = clamp(p.x, 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
    if (type == 3) return (p.x + p.y) * 0.5;
    if (type == 4) return max(1.0 - length(p), 0.0);
    if (type == 5) {
        if (dot(p, p) < 1e-12) return 0.5;
        return atan(p.y, p.x) / TAU + 0.5;
    }
    return p.x;
}

// gabor noise: lots of little wavy ripples (a gaussian times a cosine) scattered
// around, each pointing in some direction. looks like wood grain, brushed metal,
// or wind on water depending on the settings.
//   scale       how dense the ripples are
//   frequency   how many waves fit in one ripple (wavy-ness), try 1 to 4
//   anisotropy  0 = every ripple points a random way (blotchy), 1 = they all follow orientation (streaky)
//   orientation direction in radians when anisotropy > 0
// returns about 0..1, centered on 0.5
float gaborNoise(vec2 p, float scale, float frequency, float anisotropy, float orientation) {
    p *= scale;
    vec2 ip = floor(p), fp = fract(p);
    float sum = 0.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = vec2(float(x), float(y));
            vec2 cell = ip + off;
            for (int k = 0; k < 3; k++) {
                vec2 sk = vec2(37.1, 17.9) * float(k);
                vec3 h = whiteNoise3(cell + sk);
                float ang = mix(whiteNoise1(cell + sk + 5.5) * TAU, orientation, anisotropy);
                vec2 d = off + h.xy - fp;
                vec2 dir = vec2(cos(ang), sin(ang));
                float g = exp(-4.0 * dot(d, d)) * cos(TAU * frequency * dot(d, dir));
                sum += (h.z * 2.0 - 1.0) * g;
            }
        }
    }
    return clamp(0.5 + 0.55 * sum, 0.0, 1.0);
}
