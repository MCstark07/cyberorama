

void main() {
    vec2 uv = mapping(gl_FragCoord.xy + u_camera, vec2(0.0), 0.0, vec2(1.0 / 80.0));

    float warp = noiseTexture(uv, 0.5, 4, 0.5, 2.0);
    vec2 warpedUV = uv + (warp - 0.5) * 1.5;

    VoronoiOut v = voronoi(warpedUV, 2, 1.0, 0);

    float pos[4] = float[4](0.0, 0.3, 0.65, 1.0);
    vec3  col[4] = vec3[4](
        vec3(0.00, 0.88, 0.98),
        vec3(0.60, 0.10, 0.80),
        vec3(0.15, 0.03, 0.30),
        vec3(0.05, 0.01, 0.10)
    );
    vec3 base = colorRamp4(v.distance, pos, col, 1);

    vec3 cellCol = palette(v.color, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
    vec3 result = mixOverlay(base, cellCol, 0.35);

    vec3 glow = vec3(0.0, 0.88, 0.98) * smoothstep(0.08, 0.0, v.edge);
    result = mixScreen(result, glow, 1.0);

    FragColor = vec4(result, 1.0);
}
