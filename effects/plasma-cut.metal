// @name Plasma Cut
// @name.zh 等离子贯穿
// @author ymxfl
// @description A hot plasma pulse slices across the window from outside and leaves a trail of sparks.
// @description.zh 白热等离子束从窗外斜向穿过，留下两道熔亮断面与漂散的火花。
// @duration 1.16
// @padding 178
// @events close, quit, minimize

float plasmaPath(float travel, float scale) {
    return -12.0 * scale * sin(PI * clamp(travel, 0.0, 1.0));
}

float4 plasmaStream(float2 q, float head, float headSide, float travel, constant Exit& u) {
    const float s = u.scale;
    const float fire = smoothstep(0.02, 0.135, u.progress)
                     * (1.0 - smoothstep(0.77, 0.98, u.progress));
    const float lengthPt = clamp(0.21 * length(windowSize(u)) / s + 84.0, 160.0, 275.0);
    const float behind = (head - q.x) / s;
    const float cross = (q.y - headSide) / s;
    if (fire <= 0.0 || behind < -42.0 || behind > lengthPt || abs(cross) > 57.0) {
        return float4(0.0);
    }

    const float distance = length(float2(behind * (behind < 0.0 ? 1.15 : 0.69), cross));
    const float compression = 0.5 + 0.5 * sin(9.0 * travel);
    const float headCore = 1.0 - smoothstep(4.6, 14.0 + compression * 2.0, distance);
    const float headHalo = 1.0 - smoothstep(9.0, 43.0, distance);
    const float arcRadius = length(float2((behind + 5.0) * 1.13, cross));
    const float leadingArc = (1.0 - smoothstep(0.7, 2.5, abs(arcRadius - 17.0)))
                             * (1.0 - smoothstep(-19.0, 5.0, behind));

    const float t = clamp(behind / lengthPt, 0.0, 1.0);
    const float wake = smoothstep(-3.0, 15.0, behind) * (1.0 - smoothstep(0.58, 1.0, t));
    const float bend = 14.0 * t * sin(6.0 * t + travel * 5.0);
    const float channel = cross - bend;
    const float grain = noise(float2(behind / 21.0 - u.progress * 18.0, cross / 11.0));
    const float outerWidth = mix(11.0, 50.0, pow(t, 0.65));
    const float outer = (1.0 - smoothstep(0.26, 1.0, abs(channel) / outerWidth))
                        * wake * (0.48 + 0.52 * grain);
    const float helix = (6.0 + 19.0 * t) * sin(behind * 0.056 - u.progress * 14.0);
    const float spunA = 1.0 - smoothstep(0.75, 4.8, abs(channel - helix));
    const float spunB = 1.0 - smoothstep(0.75, 4.8, abs(channel + helix * 0.83));
    const float filament = max(spunA, 0.62 * spunB) * wake;
    const float hot = (1.0 - smoothstep(1.0, mix(12.0, 3.8, t), abs(channel)))
                      * wake * (1.0 - 0.56 * t);
    const float3 violet = float3(0.48, 0.15, 0.79);
    const float3 red = float3(0.99, 0.23, 0.075);
    const float3 plasma = float3(1.0, 0.66, 0.29);
    const float3 white = float3(1.0, 0.96, 0.76);

    float4 output = premul(violet, 0.77 * outer * fire);
    output = over(premul(red, fire * max(0.76 * headHalo, 0.68 * filament)), output);
    output = over(premul(plasma, fire * max(0.78 * hot, 0.74 * leadingArc)), output);
    return over(premul(white, fire * max(headCore, 0.52 * hot)), output);
}

float4 plasmaEmbers(float2 q, float head, float reach, constant Exit& u) {
    const float s = u.scale;
    const float2 pixel = q / s;
    if (abs(pixel.y) > 172.0 || q.x > head + 16.0 * s || u.progress < 0.12) {
        return float4(0.0);
    }

    const float span = reach / s;
    const float spacing = max(21.0, span / 21.0);
    const float cell = floor(pixel.x / spacing);
    float4 output = float4(0.0);
    for (int j = -1; j <= 1; ++j) {
        const float origin = (cell + float(j)) * spacing;
        for (int lane = 0; lane < 2; ++lane) {
            const float ident = cell + float(j) + 103.0 * float(lane);
            const float3 random = hash32(ident * 11.83 + u.seed * 39.0);
            const float birth = origin + spacing * (0.17 + 0.69 * random.x);
            const float travel = 0.5 + 0.5 * birth / span;
            if (travel <= 0.07 || travel >= 0.95) continue;

            const float start = 0.045 + 0.70 * travel + 0.015 * random.y;
            const float end = min(0.995, start + 0.13 + 0.23 * random.z);
            const float age = remap01(u.progress, start, end);
            if (age <= 0.0 || age >= 1.0) continue;

            const float spread = mix(22.0, 124.0, random.y);
            const float side = lane == 0 ? -1.0 : 1.0;
            const float2 drift = float2(spacing * (random.z * 0.82 - 0.30), side * spread);
            const float2 ember = float2(birth, plasmaPath(travel, 1.0)) + drift * easeOutQuad(age)
                                 + float2(0.0, 25.0 * age * age);
            const float2 tail = normalize(drift) * (4.0 + 21.0 * random.y) * (1.0 - 0.64 * age);
            const float distance = sdSegment(pixel, ember, ember - tail);
            const float visible = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.42, 1.0, age));
            const float flame = (1.0 - smoothstep(0.54, 1.8, distance)) * visible;
            const float halo = (1.0 - smoothstep(0.7, 6.5, distance)) * visible;
            const float3 heat = mix(float3(1.0, 0.95, 0.61), float3(1.0, 0.28, 0.10), age);
            const float4 glow = premul(float3(1.0, 0.25, 0.15), 0.54 * halo);
            output = over(over(premul(heat, 0.96 * flame), glow), output);
        }
    }
    return output;
}

float4 plasmaWindow(float2 q, float head, float2 axis, float2 normal,
                    constant Exit& u, texture2d<float> tex) {
    const float s = u.scale;
    const float t = u.progress;
    const float side = q.y < 0.0 ? -1.0 : 1.0;
    const float behind = (head - q.x) / s;
    const float crossed = smoothstep(-2.0, 39.0, behind);
    const float spread = crossed * smoothstep(0.21, 0.77, t);
    const float gap = 34.0 * s * spread;
    const float scale = 1.0 - 0.21 * spread;
    const float2 source = windowCenter(u) + axis * (q.x - side * 23.0 * s * spread)
                           + normal * ((q.y - side * gap) / scale);
    const float opacity = 1.0 - smoothstep(0.56, 0.94, t);
    const float edge = abs(q.y) - gap;
    const float split = mix(1.0, smoothstep(-0.72 * s, 0.72 * s, edge), crossed);
    float4 face = sampleWindowSharp(tex, u, source) * opacity * split;
    const float heat = crossed * (1.0 - smoothstep(0.66, 0.92, t));
    const float light = (1.0 - smoothstep(0.7, 4.3, abs(edge) / s)) * heat;
    const float wave = 0.66 + 0.34 * sin(q.x / (8.0 * s) - 17.0 * t);
    face.rgb = mix(face.rgb * (1.0 - 0.13 * spread),
                   face.a * float3(1.0, 0.49 + 0.28 * wave, 0.17), light * 0.92);
    return face;
}

float4 plasmaImpact(float2 q, float reach, constant Exit& u) {
    const float age = remap01(u.progress, 0.36, 0.71);
    if (age <= 0.0 || age >= 1.0) return float4(0.0);

    const float s = u.scale;
    const float2 center = float2(-0.10 * reach, plasmaPath(0.45, s));
    const float2 d = (q - center) / s;
    const float radius = length(d * float2(2.45, 1.0));
    const float advance = mix(6.0, 158.0, easeOutQuad(age));
    const float life = smoothstep(0.0, 0.13, age) * (1.0 - smoothstep(0.22, 1.0, age));
    const float front = abs(radius - advance);
    const float core = 1.0 - smoothstep(0.62, 2.5, front);
    const float glow = 1.0 - smoothstep(1.9, 19.0, front);
    const float echo = 1.0 - smoothstep(0.74, 2.9, abs(radius - 0.71 * advance));
    const float direction = smoothstep(0.0, 35.0, abs(d.y));
    const float4 halo = premul(float3(0.80, 0.16, 0.71),
                               life * (0.36 * glow + 0.24 * echo));
    return over(premul(float3(1.0, 0.59, 0.32), life * core * (0.54 + 0.35 * direction)), halo);
}

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    const float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    const float s = u.scale;
    const float2 size = windowSize(u);
    const float2 axis = normalize(float2(size.x, -size.y));
    const float2 normal = float2(-axis.y, axis.x);
    const float2 local = p - windowCenter(u);
    const float2 q = float2(dot(local, axis), dot(local, normal));
    const float reach = 0.5 * length(size) + 112.0 * s;
    const float travel = (t - 0.045) / 0.70;
    const float head = mix(-reach, reach, travel);
    const float4 image = plasmaWindow(q, head, axis, normal, u, tex);
    const float4 stream = plasmaStream(q, head, plasmaPath(travel, s), travel, u);
    const float4 embers = plasmaEmbers(q, head, reach, u);
    const float4 impact = plasmaImpact(q, reach, u);
    const float4 energy = over(stream, over(embers, impact)) * canvasEdgeFade(u, p, 15.0 * s);
    return over(energy, image);
}
