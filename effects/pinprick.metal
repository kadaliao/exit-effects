// @name Pinprick
// @name.zh 戳破气球
// @author kadaliao
// @description The window swells, then snaps into curling scraps and spirals of party ribbon.
// @description.zh 窗口像气球般鼓起，在指尖啪地裂开，卷曲的碎片和彩带向四周飞散。
// @duration 0.98
// @padding 180
// @events close, minimize, quit

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    float s = u.scale;
    float2 size = windowSize(u);
    float2 center = windowCenter(u);
    float2 pin = clamp(u.cursor, center - 0.39 * size, center + 0.39 * size);
    float pressure = smoothstep(0.0, 0.23, t);
    float2 swell = 1.0 + pressure * min(float2(0.055, 0.075), 13.0 * s / size);
    float2 origin = center + (pin - center) * swell;
    float2 d = p - origin;
    float radius = length(d);

    // A broad moving reflection gives the stretched surface a latex sheen.
    float2 source = center + (p - center) / swell;
    float4 film = sampleWindow(tex, u, source);
    float2 uv = toWindowUV(u, source);
    float2 shine = (uv - float2(0.32, 0.19)) * float2(2.8, 5.5);
    shine.y += 0.45 * shine.x;
    float gloss = exp(-dot(shine, shine) * 2.7);
    film.rgb += float3(0.90, 0.95, 1.0) * film.a * gloss * pressure * 0.23;
    if (t <= 0.23) return film;

    float age = remap01(t, 0.23, 1.0);
    float travel = easeOutCubic(age);
    float2 debrisHalf = size * swell * 0.5 + (155.0 * travel + 5.0) * s;
    if (any(abs(p - center) > debrisHalf)) return float4(0.0);

    // Each wedge recoils toward its own outer edge. Inverse mapping preserves
    // the actual window content as the broad wedges contract into little scraps.
    const float count = 15.0;
    float sector = TAU / count;
    float phase = u.seed * TAU;
    float angle = atan2(d.y, d.x + 0.00001 * s);
    float index = floor(fract((angle - phase) / TAU) * count);
    float axisAngle = phase + (index + 0.5) * sector;
    float2 axis = float2(cos(axisAngle), sin(axisAngle));
    float2 side = float2(-axis.y, axis.x);
    float3 rand = hash32(float2(index + 1.7, u.seed * 37.0));
    float along = dot(d, axis);
    float across = dot(d, side);

    float2 halfSize = size * swell * 0.5;
    float2 extent = halfSize - sign(axis) * (origin - center);
    float2 hit = extent / max(abs(axis), float2(0.0001));
    float reach = min(hit.x, hit.y);
    float recoil = easeOutQuad(remap01(age, 0.0, 0.85));
    float anchor = reach * mix(0.62, 0.84, rand.x);
    float axialScale = mix(1.0, 0.085, recoil);
    float fold = cos(age * mix(7.0, 11.0, rand.y));
    float lateralScale = mix(1.0, 0.14 + 0.40 * abs(fold), recoil);
    float push = mix(48.0, 125.0, rand.z) * s * travel;
    float originalAlong = (along - push - anchor * (1.0 - axialScale)) / axialScale;
    float bend = sin(originalAlong / max(reach, s) * 5.0 + age * 7.0 + rand.x * TAU);
    float originalAcross = (across - bend * recoil * min(5.0 * s, max(along, 0.0) * 0.025)) / lateralScale;
    float seam = (originalAlong * tan(sector * 0.5) - abs(originalAcross)) * lateralScale;
    float coverage = smoothstep(-0.55 * s, 0.55 * s, seam);
    float4 scrap = float4(0.0);
    float3 dye = hsv2rgb(float3(fract(u.seed + index * 0.381966), 0.65, 1.0));
    if (coverage > 0.0 && originalAlong >= 0.0) {
        float2 src = pin + (axis * originalAlong + side * originalAcross) / swell;
        scrap = sampleWindowSharp(tex, u, src);
        float roll = smoothstep(0.0, 0.24, age);
        scrap.rgb = mix(scrap.rgb, dye * scrap.a, roll * (0.45 + 0.27 * fold));
        float lip = exp(-abs(seam) / (1.3 * s));
        scrap.rgb += scrap.a * roll * (lip * 0.65 + 0.18 * max(bend, 0.0));
        scrap *= coverage * (1.0 - smoothstep(0.48 + 0.22 * rand.y, 0.99, age));
    }

    // A tear races out from the puncture before the perimeter lets go.
    float tear = easeOutQuad(remap01(age, 0.0, 0.16));
    float farthest = length(halfSize + abs(origin - center));
    float front = tear * (farthest + 5.0 * s);
    float ripped = (1.0 - smoothstep(front - 3.0 * s, front + 3.0 * s, radius))
                 * smoothstep(0.0, 0.012, age);
    float4 col = mix(film, scrap, ripped);

    // One corkscrew per angular lane. Its loose end unspools, catches
    // the light on each half-turn, then follows the tip out of sight.
    float tip = travel * (reach * mix(0.58, 0.95, rand.z) + mix(34.0, 92.0, rand.y) * s);
    float ribbonLength = min(tip * 0.70, mix(26.0, 61.0, rand.x) * s)
                       * (1.0 - 0.80 * smoothstep(0.50, 0.97, age));
    float back = tip - along;
    if (back >= 0.0 && back < ribbonLength && ribbonLength > s) {
        float v = back / ribbonLength;
        float twist = back / (mix(4.0, 6.5, rand.z) * s) + rand.y * TAU - age * 6.0;
        float amp = min(5.5 * s, max(along, 0.0) * 0.09);
        float width = min(mix(0.45, 2.1, abs(cos(twist))) * s, along * 0.045);
        float dist = abs(across - amp * sin(twist)) - width;
        float ink = (1.0 - smoothstep(-0.45 * s, 0.55 * s, dist))
                  * smoothstep(0.0, 0.07, v) * (1.0 - smoothstep(0.82, 1.0, v))
                  * smoothstep(0.015, 0.12, age) * (1.0 - smoothstep(0.58, 0.98, age));
        float3 silk = mix(dye, float3(1.0, 0.96, 0.84), 0.65 * pow(abs(cos(twist)), 8.0));
        col = over(premul(silk * (0.78 + 0.22 * cos(twist)), ink), col);
    }

    float flick = smoothstep(0.0, 0.018, age) * (1.0 - smoothstep(0.02, 0.15, age));
    float ring = exp(-abs(radius - (2.0 + 32.0 * easeOutQuad(remap01(age, 0.0, 0.15))) * s)
                     / (1.4 * s));
    float flash = flick * (0.64 * ring + 0.9 * exp(-radius / (5.0 * s)));
    return over(float4(float3(1.0, 0.90, 0.73) * flash, flash * 0.28), col);
}
