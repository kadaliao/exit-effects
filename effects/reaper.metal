// @name Reaper
// @name.zh 死神收割
// @author kadaliao
// @description The Grim Reaper looms out of smoke, cleaves the window with one sweep of the scythe and draws its soul into the cloak.
// @description.zh 死神自黑烟中现身，一镰刀斩开窗口，把它的魂收进斗篷带走。
// @duration 1.9
// @padding 240
// @events close, minimize, quit

// Rotate v so that its direction angle (atan2(y, x), y down) grows by a.
float2 reaper_rot(float2 v, float a) {
    float c = cos(a);
    float s = sin(a);
    return float2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float reaper_smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Hooded figure in units of its own height. Origin at the hood centre, y down.
float reaper_body(float2 r, float time) {
    float sway = sin(time * 1.7 + r.y * 5.0) * 0.02 * smoothstep(0.25, 0.95, r.y);
    float2 b = float2(r.x - sway, r.y);
    float hood = length(b * float2(1.0, 0.88)) - 0.115;
    float peak = length(b - float2(0.05, -0.095)) - 0.062;
    float yy = clamp(b.y, 0.17, 0.72);
    float k = (yy - 0.17) / 0.55;
    float body = length(b - float2(0.02 * k, yy)) - mix(0.135, 0.235, k);
    float arm = sdSegment(r, float2(-0.08, 0.17), float2(-0.33, 0.295)) - 0.047;
    float cuff = sdSegment(r, float2(-0.31, 0.30), float2(-0.285, 0.40)) - 0.028;
    float d = reaper_smin(hood, peak, 0.04);
    d = reaper_smin(d, body, 0.05);
    d = reaper_smin(d, arm, 0.04);
    d = reaper_smin(d, cuff, 0.035);
    return d;
}

// Cold, drained look while the reaper looms.
float4 reaper_chill(float4 c, float k) {
    float l = luminance(c.rgb);
    c.rgb = mix(c.rgb, float3(0.78, 0.90, 1.0) * l, k) * (1.0 - 0.25 * k);
    return c;
}

// The window turning into a pale spectre.
float4 reaper_ghost(float4 c, float k, float3 soul) {
    float l = luminance(c.rgb);
    float3 g = soul * (mix(l, 0.45 * c.a, 0.65 * k) + 0.14 * c.a);
    c.rgb = mix(c.rgb, g, k);
    return c * (1.0 - 0.4 * k);
}

// Glow along the part of the cut arc the blade has already passed. v is relative to the pivot.
float reaper_cutglow(float2 v, float Rc, float thetaC, float cutRel, float S) {
    float e = abs(length(v) - Rc);
    float2 vr = reaper_rot(v, -thetaC);
    float rel = atan2(vr.y, vr.x);
    float core = exp(-e / (1.6 * S)) + 0.35 * exp(-e / (7.0 * S));
    return core * smoothstep(cutRel - 0.01, cutRel + 0.12, rel);
}

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    float S = u.scale;
    float2 W = windowSize(u);
    float2 ctr = windowCenter(u);
    float3 soul = float3(0.50, 1.0, 0.86);

    // The reaper stands on the side with more room; everything below is designed
    // with it at the upper right and mirrored when needed.
    float spaceL = u.win.x;
    float spaceR = u.size.x - (u.win.x + u.win.z);
    float side = fract(u.seed * 7.31) < 0.5 ? 1.0 : -1.0;
    if (abs(spaceL - spaceR) > 8.0 * S) side = spaceR > spaceL ? 1.0 : -1.0;
    float2 pm = float2(ctr.x + (p.x - ctr.x) * side, p.y);

    // The blade tip travels on a circle of radius Rc around the reaper's hand,
    // and that circle passes through the window centre: the cut is that arc.
    float Rc = clamp(0.3 * length(W), 130.0 * S, 560.0 * S);
    float L = Rc / 0.921;                 // scythe length
    float H = L / 0.8;                    // figure height
    float2 dir = normalize(float2(W.x, -W.y));
    float dy = clamp(min(-dir.y, (ctr.y - 14.0 * S) / Rc - 0.70), -0.35, 0.95);
    dir = float2(sqrt(1.0 - dy * dy), -dy);
    float2 pivot = ctr + dir * Rc;
    float thetaC = atan2(-dir.y, -dir.x); // direction from the hand to the window centre
    if (thetaC < 0.0) thetaC += TAU;
    float2 hood = pivot + float2(0.34, -0.30) * H;
    float2 Gp = hood + float2(-0.04, 0.30) * H;   // where the soul is drawn in

    // Timeline.
    float appear = easeOutCubic(remap01(t, 0.0, 0.20));
    float vanish = easeInOutQuad(remap01(t, 0.80, 0.975));
    float wind = easeInOutQuad(remap01(t, 0.13, 0.27));
    float swing = easeInOutCubic(remap01(t, 0.27, 0.40));
    float settle = easeOutCubic(remap01(t, 0.40, 0.62));
    float restRel = 4.3284 - thetaC;      // raised over the shoulder
    float span = restRel + 0.22 + 2.05;
    float cutRel = restRel + 0.22 - span * swing;
    float tipRel = restRel + 0.22 * wind - span * swing + 0.28 * settle;
    float swingEnv = remap01(t, 0.27, 0.31) * (1.0 - remap01(t, 0.40, 0.52));
    float glowEnv = remap01(t, 0.27, 0.30) * (1.0 - remap01(t, 0.50, 0.74));
    float absorb = remap01(t, 0.64, 0.78) * (1.0 - remap01(t, 0.80, 0.93));
    float visEnv = smoothstep(0.0, 0.6, appear) * (1.0 - smoothstep(0.55, 1.0, vanish));
    float chillK = 0.4 * smoothstep(0.03, 0.34, t);
    float3 glowCol = mix(soul, float3(1.0), 0.6) * 1.5 * glowEnv;

    // ---- Window: intact until the blade is through, then two pieces ----
    float4 win = float4(0.0);
    if (t < 0.36) {
        float4 c = reaper_chill(sampleWindow(tex, u, p), chillK);
        if (glowEnv > 0.0) {
            c.rgb += glowCol * reaper_cutglow(pm - pivot, Rc, thetaC, cutRel, S) * c.a;
        }
        win = c;
    } else {
        for (int i = 1; i >= 0; i--) {                      // outer piece first, inner on top
            float fi = float(i);
            float slide = easeOutCubic(remap01(t, 0.36 + 0.01 * fi, 0.52 + 0.04 * fi));
            float suck = easeInCubic(remap01(t, 0.47 + 0.07 * fi, 0.74 + 0.06 * fi));
            float sc = max(1.0 - suck, 0.001);
            // Undo the spiral into the cloak.
            float2 x1 = Gp + reaper_rot(pm - Gp, (1.5 - 0.5 * fi) * suck) / sc;
            float2 x0;
            if (i == 0) {
                x0 = pivot + reaper_rot(x1 - pivot, 0.07 * slide);       // dragged along the blade
            } else {
                x0 = x1 - (float2(0.0, 0.03) - dir * 0.035) * Rc * slide; // sags away
            }
            float2 wv = float2(sin(x1.y / (17.0 * S) + u.time * 9.0),
                               cos(x1.x / (21.0 * S) - u.time * 7.0));
            x0 += wv * 7.0 * S * suck;

            float dc = length(x0 - pivot) - Rc;
            float inner = 1.0 - smoothstep(-0.75 * S, 0.75 * S, dc);
            float mask = (i == 0) ? inner : 1.0 - inner;
            if (mask <= 0.0) continue;
            float4 c = sampleWindowSharp(tex, u, float2(ctr.x + (x0.x - ctr.x) * side, x0.y)) * mask;
            if (c.a <= 0.0) continue;
            c = reaper_chill(c, chillK);
            c.rgb += glowCol * reaper_cutglow(x0 - pivot, Rc, thetaC, cutRel, S) * c.a;
            float gk = smoothstep(0.0, 0.6, suck);
            c = reaper_ghost(c, gk, soul);
            c.rgb += soul * 0.22 * gk * c.a;
            c *= smoothstep(0.0, 0.22, 1.0 - suck);
            win = over(c, win);
        }
    }

    float3 add = float3(0.0);

    // ---- Soul mist spiralling into the cloak ----
    float suckEnv = remap01(t, 0.46, 0.60) * (1.0 - remap01(t, 0.76, 0.90));
    if (suckEnv > 0.0) {
        float2 gv = (pm - Gp) / H;
        float gr = length(gv);
        if (gr < 1.5 && gr > 0.001) {
            float2 gd = reaper_rot(gv / gr, gr * 2.2 - u.time * 1.2);
            float flow = log(gr + 0.06) * 1.6 + u.time * 2.4;
            float st = fbm(gd * 2.1 + float2(flow, -flow * 0.7) + u.seed * 9.0, 3);
            float m = pow(st, 3.0) * 3.2 * exp(-gr * 2.4) * (1.0 - smoothstep(1.2, 1.5, gr));
            float3 mist = soul * m * suckEnv;
            win.rgb += mist;
            win.a = clamp(win.a + luminance(mist) * 0.5, 0.0, 1.0);
        }
    }

    // ---- The reaper ----
    float bob = sin(u.time * 2.3) * 0.012 * H * appear;
    float2 hoodP = hood + float2(0.0, (1.0 - appear) * 0.10 * H + bob - vanish * 0.06 * H);
    float2 r = (pm - hoodP) / H;
    float4 fig = float4(0.0);
    if (visEnv > 0.0 && abs(r.x + 0.06) < 0.62 && r.y > -0.42 && r.y < 1.30) {
        float d = reaper_body(r, u.time);
        float n = fbm(float2(r.x * 6.0, r.y * 4.0 + u.time * 0.6) + u.seed * 17.0, 4);
        float hem = smoothstep(0.42, 1.0, r.y);
        float erode = max(1.0 - appear, vanish);
        // Tattered hem, smoky edges, and the dissolve in / out.
        float dd = d + (n - 0.38) * (0.025 + 0.30 * hem) + erode * (0.06 + 0.5 * n);
        float aa = 1.5 * S / H + 0.006;
        float cov = 1.0 - smoothstep(-aa, aa, dd);

        float3 cloth = float3(0.028, 0.030, 0.042);
        float fold = noise(float2(r.x * 24.0 + r.y * 2.5, r.y * 1.8 + 3.0));
        cloth += float3(0.022, 0.026, 0.038) * fold * smoothstep(0.08, 0.5, r.y);
        float rimK = smoothstep(-0.045, 0.0, dd) * (1.0 - smoothstep(-0.05, 0.25, r.x));
        cloth += soul * rimK * (0.07 + 0.5 * absorb + 0.3 * swingEnv);
        float face = length((r - float2(-0.022, 0.012)) * float2(1.0, 0.82)) - 0.072;
        cloth = mix(float3(0.004), cloth, smoothstep(-0.012, 0.012, face));

        float auraA = exp(-max(dd, 0.0) / 0.055) * (0.18 + 0.45 * n) * visEnv * (1.0 - cov);
        fig = premul(float3(0.015, 0.016, 0.024), clamp(auraA, 0.0, 0.6));
        fig = over(premul(cloth, cov * visEnv), fig);

        // Spectral outline so the silhouette reads on dark windows too; flares when it feeds.
        float outline = exp(-abs(dd) / 0.010) * (0.14 + 0.75 * absorb);
        float halo = exp(-max(dd, 0.0) / 0.07) * 0.05 * (1.0 - cov);
        add += soul * (outline + halo) * visEnv;

        // Eyes: slanted embers that linger after the cloak is gone.
        float eyeEnv = smoothstep(0.10, 0.24, t) * (1.0 - remap01(t, 0.90, 0.965));
        float2 e1 = r - float2(-0.056, 0.004);
        float2 e2 = r - float2(-0.002, 0.007);
        e1 = float2(e1.x, e1.y * 1.8 - e1.x * 0.6);
        e2 = float2(e2.x, e2.y * 1.8 + e2.x * 0.6);
        float er = 0.011;
        float eyes = exp(-dot(e1, e1) / (er * er)) + exp(-dot(e2, e2) / (er * er));
        float eyeHalo = exp(-length(r - float2(-0.029, 0.006)) / 0.05);
        float flick = 0.85 + 0.15 * sin(u.time * 13.0);
        float eI = eyeEnv * (flick + 1.6 * absorb + 0.8 * swingEnv);
        add += (mix(soul, float3(1.0), 0.55) * eyes * 1.6 + soul * eyeHalo * 0.10) * eI;
    }

    // ---- The scythe ----
    float2 hand = hoodP + float2(-0.34, 0.30) * H;
    float2 sv = pm - hand;
    float4 scy = float4(0.0);
    if (visEnv > 0.0 && dot(sv, sv) < 1.5625 * L * L) {
        float idleAmt = (1.0 - smoothstep(0.16, 0.27, t)) + smoothstep(0.60, 0.72, t);
        float a = thetaC + tipRel + 2.4163 + 0.025 * sin(u.time * 2.1) * idleAmt;
        float2 s = reaper_rot(sv, -a) / L;      // handle along -y, blade toward -x
        float px = S / L;

        float hw = max(0.011, 1.1 * px);
        float dh = sdSegment(s, float2(0.0, 0.32), float2(0.0, -1.0)) - hw;
        float ch = 1.0 - smoothstep(-0.75 * px, 0.75 * px, dh);
        float3 wood = mix(float3(0.09, 0.065, 0.05), float3(0.36, 0.27, 0.19), smoothstep(-hw, hw, -s.x));

        // Crescent blade: between two circles, thickest at the handle, tapering to the tip.
        float l1 = length(s - float2(-0.12, -0.42));
        float l2 = length(s - float2(-0.14, -0.322));
        float db = max(max(l1 - 0.60, 0.62 - l2), s.x - 0.03);
        float cb = 1.0 - smoothstep(-0.75 * px, 0.75 * px, db);
        float edge = 1.0 - smoothstep(0.0, 0.03, l2 - 0.62);
        float along = remap01(-s.x, 0.0, 0.69);
        float3 steel = mix(float3(0.26, 0.30, 0.36), float3(0.80, 0.88, 0.95), edge);
        float g1 = remap01(t, 0.09, 0.25) * 1.4 - 0.2;
        float g2 = remap01(t, 0.58, 0.74) * 1.4 - 0.2;
        float glint = exp(-pow((along - g1) / 0.10, 2.0)) + exp(-pow((along - g2) / 0.10, 2.0));
        steel += float3(0.9, 1.0, 1.0) * glint * (0.3 + 0.7 * edge) * 0.8;
        steel += (soul * 0.5 + 0.3) * swingEnv;

        // Bony grip.
        float dg = length(s * float2(1.0, 0.6)) - (hw + 0.016);
        float cg = 1.0 - smoothstep(-0.75 * px, 0.75 * px, dg);
        float3 bone = float3(0.74, 0.72, 0.64) * (0.78 + 0.22 * cos(s.y * TAU / 0.03));

        float4 sc4 = premul(wood, ch);
        sc4 = over(premul(steel, cb), sc4);
        sc4 = over(premul(bone, cg), sc4);
        scy = sc4 * visEnv;

        add += soul * exp(-max(db, 0.0) * L / (10.0 * S)) * swingEnv * 0.5 * visEnv;
    }

    // ---- Slash: the smear of light the blade leaves behind ----
    if (swingEnv > 0.0) {
        float2 pv = pm - pivot;
        float rr = length(pv) / Rc;
        if (rr > 0.7 && rr < 1.4) {
            float2 pvr = reaper_rot(pv, -thetaC);
            float rel = atan2(pvr.y, pvr.x);
            float back = rel - cutRel;                       // > 0 behind the blade
            float len = clamp(span * swing, 0.001, 1.7);
            float tr = smoothstep(0.0, 0.04, back) * pow(clamp(1.0 - back / len, 0.0, 1.0), 2.0);
            float band = smoothstep(1.0 - 2.0 * S / Rc, 1.0, rr) * (1.0 - smoothstep(1.02, 1.13, rr));
            float edgeLine = exp(-abs(rr - 1.0) * Rc / (2.0 * S));
            float soft = exp(-abs(rr - 1.03) / 0.12) * 0.25;
            float I = tr * (band * 0.55 + edgeLine * 0.9 + soft) * swingEnv;
            add += mix(soul, float3(1.0), 0.5 + 0.5 * tr) * I;
        }
    }

    float4 res = over(fig, win);
    res = over(scy, res);
    res.rgb += add;
    res.a = clamp(res.a + luminance(add) * 0.6, 0.0, 1.0);
    return res * (1.0 - remap01(t, 0.955, 1.0));
}
