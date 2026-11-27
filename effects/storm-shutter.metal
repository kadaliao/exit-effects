// @name Storm Shutter
// @name.zh 雷暴快门
// @author ymxfl
// @description An electric cage charges a metal iris, then releases a shockwave and sparks.
// @description.zh 蓝紫电弧在窗外接通快门，叶片锁紧后放出冲击波与飞火。
// @duration 1.12
// @padding 168
// @events close, quit, minimize

float stormClosure(float t) {
    return 0.76 * smoothstep(0.015, 0.73, t) + 0.24 * smoothstep(0.48, 0.94, t);
}

float4 stormShutter(float2 p, constant Exit& u, texture2d<float> tex, float t) {
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    const float s = u.scale;
    const float2 local = p - windowCenter(u);
    const float outline = windowSDF(u, p);
    if (outline > 3.0 * s) return float4(0.0);

    const float radius = length(local);
    const float halfDiagonal = 0.5 * length(windowSize(u));
    const float close = stormClosure(t);
    const float rotation = mix(-0.18, 0.54, smoothstep(0.04, 0.86, t));
    const float bladeAngle = TAU / 6.0;
    const float angle = atan2(local.y, local.x) - rotation;
    const float sector = angle / bladeAngle;
    const float sectorAngle = (fract(sector + 0.5) - 0.5) * bladeAngle;
    const float aperture = mix(halfDiagonal + 4.0 * s, -1.5 * s, close);
    const float front = radius * cos(sectorAngle) - aperture;

    const float opening = 1.0 - smoothstep(-0.8 * s, 0.85 * s, front);
    const float4 image = sampleWindowSharp(tex, u, p) * opening;

    // Just behind the moving opening, bent seams and bevels reveal six overlapping leaves.
    const float2 size = windowSize(u);
    const float width = clamp(0.13 * min(size.x, size.y), 22.0 * s, 72.0 * s);
    const float depth = clamp(front / width, 0.0, 1.0);
    const float leaf = fract(sector + 0.5 + depth * (0.59 + 0.18 * depth));
    const float seam = 1.0 - smoothstep(0.006, 0.027, min(leaf, 1.0 - leaf));
    const float bevel = 1.0 - smoothstep(0.012, 0.17, abs(leaf - 0.075));
    const float lip = 1.0 - smoothstep(0.9 * s, 3.7 * s, abs(front - 2.5 * s));
    const float2 incident = float2(-0.64, -0.77);
    const float facing = dot(local / max(radius, s), incident);
    const float highlight = smoothstep(0.12, 0.95, facing);
    const float brushed = 0.013 * sin((radius + 0.13 * local.x) / (1.65 * s));
    const float tone = 0.15 + 0.11 * highlight + 0.075 * bevel + brushed - 0.07 * seam;
    const float3 tint = float3(0.80, 0.94, 1.16);
    const float3 rim = mix(float3(0.35, 0.52, 0.64), float3(0.86, 0.95, 1.0), highlight);
    const float3 steel = tone * tint + rim * (0.52 * lip + 0.22 * bevel * highlight);

    const float band = smoothstep(-0.65 * s, 2.3 * s, front)
                     * (1.0 - smoothstep(0.63, 1.0, depth));
    const float surround = 1.0 - smoothstep(-0.5 * s, 2.0 * s, outline);
    const float leafLife = smoothstep(0.02, 0.20, t) * (1.0 - smoothstep(0.77, 0.98, t));
    const float4 iris = premul(steel, band * surround * leafLife);

    const float snap = smoothstep(0.82, 0.89, t) * (1.0 - smoothstep(0.89, 0.98, t));
    const float pin = (1.0 - smoothstep(1.2 * s, 7.0 * s, radius)) * snap;
    const float4 reflection = premul(float3(0.66, 0.88, 1.0), 0.82 * pin);
    return over(reflection, over(iris, image));
}

float stormKnot(float index, float segments, float pulse, float amplitude) {
    const float weight = sin(PI * index / segments);
    const float random = hash11(index * 17.71 + pulse * 3.63) * 2.0 - 1.0;
    return amplitude * random * weight;
}

float stormBolt(float2 p, float2 start, float2 end, float pulse, float amplitude, float scale) {
    const float2 direction = end - start;
    const float lengthPx = length(direction);
    const float2 along = direction / lengthPx;
    const float2 across = float2(-along.y, along.x);
    const float2 local = p - start;
    const float2 q = float2(dot(local, along), dot(local, across));
    const float glowReach = 19.0 * scale;
    if (q.x < -glowReach || q.x > lengthPx + glowReach || abs(q.y) > amplitude + glowReach) {
        return 1e6;
    }

    const float count = clamp(ceil(lengthPx / (12.0 * scale)), 4.0, 24.0);
    const float stride = lengthPx / count;
    const float near = clamp(floor(q.x / stride), 0.0, count - 1.0);
    float distance = 1e6;
    for (int neighbor = -1; neighbor <= 1; ++neighbor) {
        const float i = clamp(near + float(neighbor), 0.0, count - 1.0);
        const float2 a = float2(i * stride, stormKnot(i, count, pulse, amplitude));
        const float2 b = float2((i + 1.0) * stride, stormKnot(i + 1.0, count, pulse, amplitude));
        distance = min(distance, sdSegment(q, a, b));
    }
    return distance / scale;
}

float4 stormElectric(float distance, float power, float hue) {
    const float core = 1.0 - smoothstep(0.38, 1.65, distance);
    const float inner = 1.0 - smoothstep(0.8, 5.6, distance);
    const float haze = 1.0 - smoothstep(1.5, 18.0, distance);
    const float3 tint = mix(float3(0.12, 0.51, 1.0), float3(0.40, 0.24, 1.0), hue);
    const float3 source = mix(float3(0.65, 0.91, 1.0), float3(0.92, 0.78, 1.0), hue);
    return over(premul(source, power * core),
                premul(tint, power * (0.58 * inner + 0.25 * haze)));
}

float4 stormCage(float2 p, constant Exit& u, float power, float shutterProgress) {
    if (power <= 0.0) return float4(0.0);
    const float s = u.scale;
    const float2 q = p - windowCenter(u);
    const float2 halfWindow = 0.5 * windowSize(u);
    const float2 cage = halfWindow + float2(29.0, 24.0) * s;
    const float2 side = float2(q.x >= 0.0 ? 1.0 : -1.0, q.y >= 0.0 ? 1.0 : -1.0);
    const float2 node = side * cage;
    const float nodeNoise = 11.0 * (side.x + 2.0 * side.y + 3.0) + u.seed * 17.0;
    const float tick = floor(u.progress * 35.0);
    const float tension = 0.73 + 0.27 * hash11(tick * 1.78 + nodeNoise);
    const float travel = TAU * (u.progress * 2.0 + 0.08 * side.y);

    const float horizontal = stormBolt(q, float2(-cage.x, node.y), float2(cage.x, node.y),
                                       tick + 19.0 * side.y, 16.0 * s, s);
    const float vertical = stormBolt(q, float2(node.x, -cage.y), float2(node.x, cage.y),
                                     tick + 23.0 * side.x, 13.0 * s, s);
    const float cageLight = 0.86 + 0.14 * sin(travel + (q.x + q.y) / (48.0 * s));
    float4 output = stormElectric(min(horizontal, vertical), power * tension * cageLight, 0.06);

    const float2 foot = side * (halfWindow - float2(13.0, 11.0) * s);
    const float contact = stormBolt(q, node, foot, tick + nodeNoise, 11.0 * s, s);
    output = over(stormElectric(contact, power * 0.88, 0.0), output);

    // As the shutter closes, extra arcs bridge the gap from the cage to the moving metal.
    const float transfer = smoothstep(0.23, 0.37, u.progress)
                         * (1.0 - smoothstep(0.61, 0.77, u.progress));
    if (transfer > 0.0) {
        const float aperture = length(halfWindow) * (1.0 - stormClosure(shutterProgress));
        const float2 target = rot(0.16 * shutterProgress) * normalize(node) * (aperture + 9.0 * s);
        const float feeder = stormBolt(q, node, target, tick + 43.0 + nodeNoise, 17.0 * s, s);
        output = over(stormElectric(feeder, transfer * power * 0.88 * tension, 0.28), output);
    }

    // Two branches kick outward beyond each corner and die off toward their ends.
    const float forkPower = power * (0.45 + 0.46 * hash11(tick + nodeNoise));
    const float forkA = stormBolt(q, node, node + side * float2(91.0, 56.0) * s,
                                  tick + 3.0 + nodeNoise, 20.0 * s, s);
    const float forkB = stormBolt(q, node, node + side * float2(62.0, 91.0) * s,
                                  tick + 9.0 + nodeNoise, 15.0 * s, s);
    const float outerFade = 1.0 - smoothstep(33.0, 112.0, length(q - node) / s);
    output = over(stormElectric(min(forkA, forkB), forkPower * outerFade, 0.56), output);

    const float reach = length(q - node) / s;
    const float dotGlow = 1.0 - smoothstep(2.0, 11.5, reach);
    const float rim = 1.0 - smoothstep(0.70, 1.65, abs(reach - 9.2));
    const float3 ice = float3(0.41, 0.82, 1.0);
    return over(premul(ice, power * (0.62 * dotGlow + 0.37 * rim)), output);
}

float4 stormRelease(float2 p, constant Exit& u) {
    const float age = remap01(u.progress, 0.59, 0.99);
    if (age <= 0.0 || age >= 1.0) return float4(0.0);

    const float s = u.scale;
    const float2 radial = (p - windowCenter(u)) / s;
    const float radius = length(radial);
    const float halfDiagonal = 0.5 * length(windowSize(u)) / s;
    const float travel = halfDiagonal + 116.0;
    const float theta = atan2(radial.y, radial.x);
    const float waveFront = mix(12.0, travel, easeOutQuad(age));
    const float oval = length(radial * float2(1.0, 1.16));
    const float ripple = sin(theta * 5.0 + age * 7.0) * mix(1.6, 5.4, age);
    const float distance = abs(oval + ripple - waveFront);
    const float strength = smoothstep(0.0, 0.14, age) * (1.0 - smoothstep(0.51, 0.99, age));
    const float weave = 0.54 + 0.46 * pow(0.5 + 0.5 * cos(theta * 7.0 - age * 6.0), 0.65);
    const float rim = 1.0 - smoothstep(0.8, 2.4 + age * 5.0, distance);
    const float halo = 1.0 - smoothstep(2.0, 25.0, distance);
    const float echo = 1.0 - smoothstep(0.85, 3.5, abs(oval - (waveFront - 17.0 - age * 21.0)));
    float4 output = over(premul(float3(0.51, 0.82, 1.0), 0.81 * rim * strength * weave),
                         premul(float3(0.30, 0.28, 0.94),
                                clamp(strength * (0.35 * halo + 0.40 * echo), 0.0, 1.0)));

    if (radius < 2.0 || radius > travel + 30.0) return output;
    // Each pixel checks the three neighboring sectors for ballistic spark streaks.
    const float sectorCount = 64.0;
    const float sector = theta / TAU * sectorCount;
    const float root = floor(sector);
    float light = 0.0;
    float haloLight = 0.0;
    for (int neighbor = -1; neighbor <= 1; ++neighbor) {
        const float id = fmod(root + float(neighbor) + sectorCount, sectorCount);
        const float3 random = hash32(id * 2.31 + u.seed * 31.0);
        const float born = 0.01 + 0.18 * random.x;
        const float life = remap01(age, born, min(1.0, born + 0.55 + 0.36 * random.y));
        if (life <= 0.0 || life >= 1.0) continue;
        const float alpha = smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.50, 1.0, life));
        const float angle = ((id + 0.10 + 0.80 * random.z) / sectorCount) * TAU;
        const float2 launch = float2(cos(angle), sin(angle));
        const float advance = 12.0 + travel * mix(0.32, 1.17, random.y) * easeOutQuad(life);
        const float tail = min(32.0, 4.5 + advance * 0.09) * (1.0 - 0.58 * life);
        const float d = sdSegment(radial, launch * advance, launch * (advance - tail));
        light = max(light, alpha * (1.0 - smoothstep(0.46, 1.68, d)));
        haloLight = max(haloLight, alpha * (1.0 - smoothstep(1.0, 6.0, d)));
    }
    output = over(premul(float3(0.22, 0.50, 1.0), 0.60 * haloLight), output);
    return over(premul(float3(0.87, 0.97, 1.0), 0.92 * light), output);
}

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    const float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    const float progress = remap01(t, 0.10, 0.87);
    const float4 shutter = stormShutter(p, u, tex, progress);
    const float power = smoothstep(0.025, 0.17, t) * (1.0 - smoothstep(0.60, 0.77, t));
    const float4 charge = stormCage(p, u, power, progress);
    const float4 release = stormRelease(p, u);
    const float4 energy = over(release, charge) * canvasEdgeFade(u, p, 16.0 * u.scale);
    return over(energy, shutter);
}
