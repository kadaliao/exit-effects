// @name Gate Jump
// @name.zh 六边跃迁
// @author ymxfl
// @description A green transit gate opens and pulls the window through.
// @description.zh 翠绿六边传送门展开，窗口压缩滑入，门框收成一道光。
// @duration 1.24
// @padding 154
// @events close, quit, minimize

float gateHex(float2 p, float2 extent) {
    const float2 a = abs(p);
    const float2 slope = float2(0.5, 1.0) / extent;
    return max(a.x - extent.x, (dot(a, slope) - 1.0) / length(slope));
}

float gateLine(float distance, float width) {
    return 1.0 - smoothstep(0.42 * width, width, abs(distance));
}

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    const float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    const float2 h = 0.5 * windowSize(u) / u.scale;
    const float2 q = (p - windowCenter(u)) / u.scale;
    const float start = smoothstep(0.035, 0.27, t);
    const float flow = easeInOutQuad(remap01(t, 0.24, 0.77));
    const float fold = smoothstep(0.72, 0.98, t);
    const float gateX = mix(h.x + 55.0, h.x * 0.46 + 20.0, start);
    const float2 g = q - float2(gateX, 0.0);

    const float sx = mix(1.0, 0.47, flow);
    const float sy = mix(1.0, 0.67, flow);
    const float flex = 9.5 * sin(q.y / 27.0 - 18.0 * t) * exp(-abs(g.x) / 28.0)
                       * sin(PI * flow);
    const float2 source = float2((q.x - flow * (h.x * 1.83 + 40.0) + flex) / sx, q.y / sy);
    float4 image = sampleWindowSharp(tex, u, windowCenter(u) + source * u.scale);
    const float boundary = 1.0 - smoothstep(-2.5, 3.0, g.x);
    image *= mix(1.0, boundary, smoothstep(0.19, 0.28, t));
    const float heat = exp(-abs(g.x) / 8.0) * start;
    image.rgb = mix(image.rgb, image.a * float3(0.56, 1.0, 0.76), 0.6 * heat);

    const float glow = start * (1.0 - smoothstep(0.85, 1.0, t));
    if (glow <= 0.0) return image;
    const float gateW = mix(5.0, 43.0 + min(20.0, 0.10 * h.y), start) * mix(1.0, 0.07, fold);
    const float gateH = (h.y + 26.0) * mix(0.58, 1.0, start) * mix(1.0, 0.045, fold);
    const float2 extent = float2(gateW, gateH);
    const float frame = gateHex(g, extent);
    const float outer = gateHex(g, extent + float2(10.0, 13.0) * (1.0 - 0.75 * fold));
    const float route = atan2(g.y / extent.y, g.x / extent.x) / TAU;
    const float decor = smoothstep(0.16, 0.29, fract(route * 10.0 - 0.9 * t));
    const float inside = 1.0 - smoothstep(-5.0, 0.0, frame);
    const float ghost = gateHex(g - float2(19.0, 0.0) * (1.0 - fold), extent * 0.86);
    const float scan = pow(0.5 + 0.5 * cos(g.y * 0.12 - 29.0 * t), 9.0);
    const float lattice = gateLine((fract(g.x / 12.0 + 0.5) - 0.5) * 12.0, 0.7);
    const float arc = 0.68 + 0.32 * cos(route * TAU * 2.0 - 10.0 * t);
    float4 fx = premul(float3(0.015, 0.45, 0.44), glow * (0.31 + 0.14 * scan + 0.12 * lattice) * inside);
    fx = over(premul(float3(0.24, 0.94, 0.65), 0.56 * glow * gateLine(frame, 19.0)), fx);
    fx = over(premul(float3(0.20, 0.82, 0.46),
                     0.54 * glow * gateLine(ghost, 1.65) * (1.0 - fold) * decor), fx);
    fx = over(premul(float3(0.28, 1.0, 0.70), 0.75 * glow * decor * gateLine(outer, 1.75)), fx);
    fx = over(premul(float3(0.73, 1.0, 0.86), 0.97 * glow * arc * gateLine(frame, 2.4)), fx);

    // Sparks leave the far face in narrow, independently timed lanes.
    const float lane = floor(g.y / 10.0);
    const float3 random = hash32(lane * 7.31 + 4.0 * u.seed);
    const float age = remap01(t, 0.31 + 0.36 * random.x, 0.79 + 0.16 * random.y);
    const float sparkX = gateW * 0.35 + easeOutQuad(age) * (28.0 + 95.0 * random.z);
    const float sparkY = (lane + 0.15 + 0.7 * random.y) * 10.0;
    const float spark = gateLine(g.y - sparkY, 0.85 + random.x)
        * gateLine((g.x - sparkX) * 0.17, 0.95 + 1.6 * random.z)
        * smoothstep(0.0, 0.17, age) * (1.0 - smoothstep(0.42, 0.98, age))
        * (1.0 - smoothstep(0.71, 1.05, abs(sparkY) / (h.y + 30.0)));
    fx = over(premul(float3(0.57, 1.0, 0.70), 0.99 * spark), fx);
    return over(fx * canvasEdgeFade(u, p, 13.0 * u.scale), image);
}
