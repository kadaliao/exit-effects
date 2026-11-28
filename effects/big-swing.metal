// @name Big Swing
// @name.zh 一棒打飞
// @author kadaliao
// @description A cheeky silhouette strolls in, grows something enormous, and bats the window into the sky until it twinkles out.
// @description.zh 一个男人的剪影登场，那话儿越变越大，一甩把窗口抽上天，化作一颗星。
// @duration 1.9
// @padding screen
// @events close, minimize, quit

// Tapered capsule distance.
float bsw_cap(float2 p, float2 a, float2 b, float ra, float rb) {
    float2 ab = b - a;
    float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
    return length(p - a - ab * h) - mix(ra, rb, h);
}

float bsw_smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float2 bsw_unrot(float2 d, float a) {
    float c = cos(a), s = sin(a);
    return float2(d.x * c + d.y * s, -d.x * s + d.y * c);
}

// Swing angle (radians, y-up, 0 = pointing forward) over the timeline.
float bsw_theta(float t) {
    float g = remap01(t, 0.10, 0.34);
    float a = mix(-72.0, -6.0, easeOutCubic(g));
    a += 6.0 * sin(g * 18.0) * (1.0 - g);                         // boing while growing
    a -= 34.0 * easeInOutQuad(remap01(t, 0.34, 0.46));            // wind-up dip
    a += 118.0 * pow(remap01(t, 0.46, 0.53), 1.6);                // the swing
    float x = max(t - 0.53, 0.0);
    a += 14.0 * sin(x * 60.0) * exp(-x * 14.0);                   // follow-through wobble
    a = mix(a, -72.0, easeInOutCubic(remap01(t, 0.66, 0.86)));    // droop back
    return a * PI / 180.0;
}

// Window flight after the hit: xy = center, z = scale, w = rotation.
float4 bsw_flight(float s, float2 c0, float2 T, float sx) {
    float z = 8.0 * s + 8.0 * s * s;
    float sc = 1.0 / (1.0 + z);
    sc *= 1.0 - 0.6 * smoothstep(0.45, 0.95, s);
    float2 pos = T + (c0 - T) * sc;
    float ang = sx * (5.0 * s + 1.5 * (1.0 - exp(-5.0 * s)));
    return float4(pos, sc, ang);
}

// Silhouette distance. m: local coords, feet at origin, y up, body height = 1.
float bsw_man(float2 m, float t) {
    float wu = easeInOutQuad(remap01(t, 0.34, 0.46)) * (1.0 - remap01(t, 0.46, 0.50));
    float th = easeOutBack(remap01(t, 0.46, 0.56)) * (1.0 - 0.75 * easeInOutQuad(remap01(t, 0.60, 0.80)));
    float2 hip = float2(-0.05 * wu + 0.07 * th, 0.50 - 0.035 * wu + 0.012 * th);
    float lean = -0.16 * wu + 0.24 * th;
    float cs = cos(lean), sn = sin(lean);
    float2 ex = float2(cs, sn);
    float2 ey = float2(-sn, cs);

    // Torso, neck, head, nose.
    float d = bsw_cap(m, hip, hip - ex * 0.005 + ey * 0.235, 0.064, 0.078);
    d = bsw_smin(d, bsw_cap(m, hip + ey * 0.26, hip + ex * 0.012 + ey * 0.36, 0.032, 0.030), 0.02);
    float2 hc = hip + ex * 0.024 + ey * 0.41;
    d = bsw_smin(d, length(m - hc) - 0.072, 0.015);
    d = bsw_smin(d, length(m - (hc + ex * 0.07 - ey * 0.008)) - 0.016, 0.012);

    // Arm, hand on hip.
    float2 shd = hip - ex * 0.02 + ey * 0.245;
    float2 elb = hip - ex * 0.15 + ey * 0.12;
    float2 hnd = hip + float2(-0.035, 0.03);
    d = min(d, bsw_cap(m, shd, elb, 0.030, 0.025));
    d = min(d, bsw_cap(m, elb, hnd, 0.025, 0.022));

    // Legs, feet planted.
    float2 a1 = float2(-0.115, 0.04);
    float2 a2 = float2(0.10, 0.04);
    float2 kb = float2(0.03 + 0.04 * wu, 0.0);
    float2 k1 = 0.5 * (hip + a1) + kb;
    float2 k2 = 0.5 * (hip + a2) + kb;
    d = bsw_smin(d, bsw_cap(m, hip + float2(-0.012, -0.01), k1, 0.052, 0.040), 0.02);
    d = bsw_smin(d, bsw_cap(m, hip + float2(0.012, -0.01), k2, 0.052, 0.040), 0.02);
    d = min(d, bsw_cap(m, k1, a1, 0.040, 0.027));
    d = min(d, bsw_cap(m, k2, a2, 0.040, 0.027));
    d = min(d, bsw_cap(m, a1 - float2(0.0, 0.015), a1 + float2(0.08, -0.02), 0.022, 0.018));
    d = min(d, bsw_cap(m, a2 - float2(0.0, 0.015), a2 + float2(0.08, -0.02), 0.022, 0.018));

    // The bat: grows, whips with a lagging tip, shrinks back.
    float g = remap01(t, 0.10, 0.34);
    float shr = easeInOutCubic(remap01(t, 0.66, 0.84));
    float L = mix(mix(0.07, 1.15, easeOutBack(g)), 0.07, shr);
    float r = mix(mix(0.020, 0.062, easeOutCubic(g)), 0.020, shr);
    float sz = (r - 0.020) / 0.042;
    float2 B = hip + float2(0.055, -0.045);
    d = min(d, length(m - (B + float2(-0.01, -0.03 - 0.01 * sz))) - (0.024 + 0.014 * sz));
    float seg = L * 0.25;
    float2 pos = B;
    float2 ldir = float2(1.0, 0.0);
    for (int k = 0; k < 4; k++) {
        float fk = float(k);
        float a = bsw_theta(t - 0.005 * fk) - 0.045 * fk * L;
        ldir = float2(cos(a), sin(a));
        float2 nx = pos + ldir * seg;
        d = min(d, bsw_cap(m, pos, nx, r * (1.0 - 0.05 * fk), r * (0.95 - 0.05 * fk)));
        pos = nx;
    }
    d = min(d, bsw_cap(m, pos, pos + ldir * r * 0.6, r, r * 0.72));
    return d;
}

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    float S = u.scale;
    float2 c0 = windowCenter(u);
    float2 hs = windowSize(u) * 0.5;
    const float ti = 0.505;                                        // moment of impact

    // He stands on the side with more room, facing the window, a little below it.
    float roomL = u.win.x;
    float roomR = u.size.x - (u.win.x + u.win.z);
    float sx = roomL >= roomR ? 1.0 : -1.0;
    float H = clamp(0.5 * u.win.w, 140.0 * S, 380.0 * S);
    H = min(H, 0.45 * u.size.y);
    float2 feet;
    feet.x = clamp(c0.x - sx * (hs.x + 0.30 * H), 0.4 * H, u.size.x - 0.4 * H);
    feet.y = min(u.win.y + u.win.w + 0.60 * H, u.size.y - 0.03 * H);

    // Contact point and the vanishing point in the sky.
    float2 Pc = float2(clamp(feet.x + sx * 0.5 * H, u.win.x + 10.0 * S, u.win.x + u.win.z - 10.0 * S),
                       feet.y - 0.60 * H);
    float mg = 40.0 * S;
    float2 T = float2(clamp(c0.x + sx * 0.22 * u.size.x, mg, u.size.x - mg),
                      clamp(c0.y - 0.42 * u.size.y, mg, u.size.y - mg));

    // ---- Window: nervous tremble, then launched spinning into the distance.
    float s = remap01(t, ti, 1.0);
    float4 f = bsw_flight(s, c0, T, sx);
    float tr = remap01(t, 0.30, 0.46) * (1.0 - step(ti, t));
    float2 wpos = f.xy + float2(sin(u.time * 71.0), cos(u.time * 57.0)) * 1.3 * S * tr;
    float2 q = bsw_unrot(p - wpos, f.w) / f.z;
    float4 win = sampleWindow(tex, u, c0 + q);
    float hf = step(ti, t) * (1.0 - remap01(s, 0.0, 0.07));
    win.rgb = mix(win.rgb, float3(win.a), 0.7 * hf);
    float wf = 1.0 - smoothstep(0.68, 0.88, s);
    win *= wf;

    float4 res = win;

    // Afterimages trailing behind the flying window.
    float trail = wf * (1.0 - smoothstep(0.35, 0.70, s));
    if (s > 0.0 && trail > 0.0) {
        float3 gt = mix(float3(1.0), u.accent.rgb, 0.45);
        float4 gh = float4(0.0);
        for (int k = 1; k <= 4; k++) {
            float sk = s - 0.028 * float(k);
            if (sk <= 0.0) continue;
            float4 g = bsw_flight(sk, c0, T, sx);
            float2 gq = bsw_unrot(p - g.xy, g.w) / g.z;
            float gd = sdRoundBox(gq, hs, u.corner) * g.z;
            float ga = (1.0 - smoothstep(-S, S, gd)) * 0.16 * (1.0 - 0.2 * float(k)) * trail;
            gh = over(gh, premul(gt, ga));
        }
        res = over(win, gh);
    }

    // ---- The man.
    float appear = easeOutCubic(remap01(t, 0.0, 0.10));
    float leave = easeInCubic(remap01(t, 0.86, 0.96));
    float vis = appear * (1.0 - leave);
    float slide = -sx * H * (0.30 * (1.0 - easeOutCubic(remap01(t, 0.0, 0.13))) + 0.25 * leave);
    float2 ml = float2(sx * (p.x - feet.x - slide), feet.y - p.y) / H;
    if (vis > 0.001 && ml.x > -0.6 && ml.x < 1.9 && ml.y > -0.7 && ml.y < 2.1) {
        // Soft contact shadow under the feet.
        float e = length(ml / float2(0.26, 0.035));
        float shadow = (1.0 - smoothstep(0.4, 1.0, e)) * 0.28 * vis;
        res = over(premul(float3(0.0), shadow), res);

        float d = bsw_man(ml, t) * H;
        float fill = 1.0 - smoothstep(-0.7 * S, 0.7 * S, d);
        float line = 1.0 - smoothstep(1.2 * S, 2.6 * S, d);
        float halo = exp(-max(d, 0.0) / (9.0 * S)) * (1.0 - fill);
        float3 ink = float3(0.045, 0.05, 0.075) + 0.035 * clamp(ml.y, 0.0, 1.0);
        ink += u.accent.rgb * 0.30 * smoothstep(-6.0 * S, -0.5 * S, d);   // rim light
        float4 mc = premul(float3(1.0), halo * 0.14);
        mc = over(premul(float3(0.96, 0.97, 1.0), line * 0.6), mc);       // sticker outline
        mc = over(premul(ink, fill), mc);
        res = over(mc * vis, res);
    }

    // ---- Impact: comic star, shock ring, sparks.
    float3 fx = float3(0.0);
    float fxA = 0.0;
    if (t > ti) {
        float2 dv = p - Pc;
        float rr = length(dv) / H;

        float fb = remap01(t, ti, ti + 0.085);
        if (fb < 1.0 && rr < 1.3) {
            float ang = atan2(dv.y, dv.x);
            float spike = 0.5 + 0.5 * cos(ang * 9.0 + u.seed * TAU);
            float Rb = (0.16 + 0.42 * easeOutCubic(fb)) * (0.42 + 0.58 * spike * spike);
            float star = 1.0 - smoothstep(Rb * 0.75, Rb, rr);
            float core = 1.0 - smoothstep(Rb * 0.3, Rb * 0.8, rr);
            float inten = star * (1.0 - fb * fb);
            fx += mix(float3(1.0, 0.82, 0.25), float3(1.0), core) * inten;
            fxA += inten * 0.9;
            float glow = exp(-rr / 0.22) * (1.0 - fb) * 0.6;
            fx += float3(1.0, 0.93, 0.75) * glow;
            fxA += glow * 0.3;
        }

        float fr = remap01(t, ti, ti + 0.17);
        if (fr < 1.0 && rr < 1.5) {
            float Rr = 0.15 + 1.0 * easeOutCubic(fr);
            float ring = exp(-pow((rr - Rr) / 0.035, 2.0)) * (1.0 - fr) * (1.0 - fr) * 0.7;
            fx += float3(1.0) * ring;
            fxA += ring * 0.5;
        }

        float fs = remap01(t, ti, ti + 0.26);
        if (fs < 1.0 && rr < 2.0) {
            float fade = (1.0 - fs) * (1.0 - fs);
            float eo = easeOutCubic(fs);
            for (int i = 0; i < 12; i++) {
                float2 h = hash22(float2(float(i) * 7.31 + 1.7, u.seed * 57.0 + 3.1));
                float a = -PI * 0.5 + (h.x - 0.5) * 2.6 + sx * 0.25;
                float2 dir = float2(cos(a), sin(a));
                float2 sp = Pc + dir * (H * (0.35 + 0.95 * h.y) * eo) + float2(0.0, 0.30 * H * fs * fs);
                float2 tail = sp - dir * H * 0.16 * (1.0 - fs);
                float ds = sdSegment(p, sp, tail);
                float I = exp(-ds / (1.5 * S)) * fade;
                fx += mix(float3(1.0, 0.85, 0.40), float3(1.0), h.y) * I * 1.2;
                fxA += I * 0.7;
            }
        }

        // The far-away twinkle where the window vanished.
        float tw = sin(PI * remap01(s, 0.76, 0.98));
        float2 dT = p - T;
        if (tw > 0.0 && max(abs(dT.x), abs(dT.y)) < 90.0 * S) {
            float2 a0 = abs(dT);
            float2 a1 = abs(float2(dT.x + dT.y, dT.x - dT.y)) * 0.7071;
            float arm = 26.0 * S * tw + S;
            float thin = 1.1 * S;
            float glint = exp(-a0.x / thin) * exp(-a0.y / arm) + exp(-a0.y / thin) * exp(-a0.x / arm);
            glint += 0.5 * (exp(-a1.x / thin) * exp(-a1.y / (arm * 0.45))
                          + exp(-a1.y / thin) * exp(-a1.x / (arm * 0.45)));
            float len = length(dT);
            glint += exp(-len / (3.5 * S)) * 1.2;
            glint *= tw;
            float soft = exp(-len / (11.0 * S)) * 0.5 * tw;
            fx += float3(1.0, 0.98, 0.90) * glint + mix(float3(1.0, 0.9, 0.6), u.accent.rgb, 0.5) * soft;
            fxA += glint * 0.8 + soft * 0.6;
        }
    }

    res.rgb += fx;
    res.a = clamp(res.a + fxA, 0.0, 1.0);
    return res * (1.0 - remap01(t, 0.975, 1.0));
}
