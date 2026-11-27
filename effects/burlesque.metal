// @name Burlesque
// @name.zh 性感女郎
// @author kadaliao
// @description A pin-up silhouette sashays in, slips off her bra, flings it over the window, bundles it up and struts away.
// @description.zh 性感女郎剪影扭着腰走来，解下胸罩甩向窗口，把窗口一兜，提着就扭腰走了。
// @duration 2.8
// @padding 320
// @events close, minimize, quit

// ---------- helpers (prefix sx_) ----------

float sx_smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float2 sx_rot(float2 v, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float sx_ellipse(float2 q, float2 r) {
    float k0 = length(q / r);
    float k1 = length(q / (r * r));
    return k1 > 1e-5 ? k0 * (k0 - 1.0) / k1 : -min(r.x, r.y);
}

// Tapered capsule with an optional mid bulge.
float sx_limb(float2 p, float2 a, float2 b, float ra, float rb, float bulge) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h) - (mix(ra, rb, h) + bulge * sin(PI * h));
}

float2 sx_toC(float2 lp, float fx, float gy, float m, float H) {
    return float2(fx + m * lp.x * H, gy - lp.y * H);
}

float2 sx_path(float2 a, float2 b, float f, float s) {
    float arc = (0.25 * length(b - a) + 40.0 * s) * sin(PI * f);
    return mix(a, b, easeInOutCubic(f)) - float2(0.0, arc);
}

float sx_glint(float2 d, float r) {
    if (r <= 0.05) return 0.0;
    float ax = abs(d.x), ay = abs(d.y);
    float core = exp(-length(d) / (0.18 * r));
    float rays = exp(-ax / (0.05 * r)) * exp(-ay / r) + exp(-ay / (0.05 * r)) * exp(-ax / r);
    return core + rays * 0.7;
}

float sx_heart(float2 p) {
    p.x = abs(p.x);
    if (p.y + p.x > 1.0) return length(p - float2(0.25, 0.75)) - 0.35355;
    float2 a = p - float2(0.0, 1.0);
    float2 b = p - 0.5 * max(p.x + p.y, 0.0);
    return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

// Hourglass half-width of the torso at height y (figure units, y up).
float sx_torsoW(float y) {
    float w = 0.098;
    w = mix(w, 0.122, smoothstep(0.42, 0.50, y));
    w = mix(w, 0.062, smoothstep(0.50, 0.615, y));
    w = mix(w, 0.096, smoothstep(0.615, 0.70, y));
    w = mix(w, 0.088, smoothstep(0.70, 0.755, y));
    w = mix(w, 0.106, smoothstep(0.755, 0.795, y));
    w = mix(w, 0.028, smoothstep(0.795, 0.84, y));
    return w;
}

void sx_armR(float t, thread float2 &E, thread float2 &Hd) {
    E = float2(0.18, 0.665); Hd = float2(0.125, 0.545);                       // hand on hip
    float k;
    k = smoothstep(0.18, 0.26, t);   E = mix(E, float2(0.195, 0.715), k); Hd = mix(Hd, float2(0.05, 0.725), k);  // unhook
    k = smoothstep(0.29, 0.345, t);  E = mix(E, float2(0.225, 0.745), k); Hd = mix(Hd, float2(0.345, 0.735), k); // pull out
    k = smoothstep(0.345, 0.40, t);  E = mix(E, float2(0.165, 0.925), k); Hd = mix(Hd, float2(0.12, 1.06), k);   // overhead
    k = smoothstep(0.475, 0.515, t); E = mix(E, float2(0.24, 0.85), k);   Hd = mix(Hd, float2(0.375, 0.885), k); // throw
    k = smoothstep(0.70, 0.78, t);   E = mix(E, float2(0.195, 0.915), k); Hd = mix(Hd, float2(0.255, 1.035), k); // catch
}

void sx_armL(float t, thread float2 &E, thread float2 &Hd) {
    E = float2(-0.18, 0.665); Hd = float2(-0.125, 0.545);
    float k;
    k = smoothstep(0.19, 0.27, t); E = mix(E, float2(-0.195, 0.715), k); Hd = mix(Hd, float2(-0.05, 0.725), k);
    k = smoothstep(0.30, 0.35, t); E = mix(E, float2(-0.13, 0.66), k);   Hd = mix(Hd, float2(0.025, 0.722), k); // cover
}

float sx_leg(float2 l, float2 hip, float2 knee, float2 ankle, float2 toe) {
    float d = sx_limb(l, hip, knee, 0.052, 0.030, 0.006);
    d = sx_smin(d, sx_limb(l, knee, ankle, 0.030, 0.012, 0.009), 0.01);
    d = sx_smin(d, sx_limb(l, ankle, toe, 0.013, 0.004, 0.0), 0.008);
    return d;
}

// Signed distance (figure units) to the pin-up silhouette. Local +x faces the window.
float sx_figure(float2 l, float sway, float walkW, float ph, float wdir,
                float2 eR, float2 hR, float2 eL, float2 hL, float flip, float tilt) {
    float cx = sway * (1.0 - smoothstep(0.47, 0.75, l.y));
    float w = sx_torsoW(l.y);
    float g = (sx_torsoW(l.y + 0.004) - sx_torsoW(l.y - 0.004)) * 125.0;
    float d = (abs(l.x - cx) - w) * rsqrt(1.0 + g * g);
    d = max(d, max(0.40 - l.y, l.y - 0.84));
    d = sx_smin(d, sx_limb(l, float2(0.006, 0.80), float2(0.014, 0.875), 0.026, 0.021, 0.0), 0.012);

    // Legs: contrapposto when standing, crossing catwalk steps when walking.
    float2 hipA = float2(0.05 + sway, 0.46), hipB = float2(-0.05 + sway, 0.46);
    float2 kA = float2(0.05 + 0.5 * sway, 0.255), aA = float2(0.035, 0.045);
    float2 kB = float2(0.005, 0.27), aB = float2(-0.02, 0.07);
    float2 tA = aA + float2(0.010, -0.045), tB = aB + float2(0.008, -0.058);
    if (walkW > 0.0) {
        float lA = max(0.0, sin(ph)), lB = max(0.0, -sin(ph));
        float cA = cos(ph), cB = -cA;
        float2 wkA = float2(0.03 + wdir * (0.03 * lA - 0.012 * cA), 0.255 + 0.03 * lA);
        float2 wkB = float2(-0.03 + wdir * (0.03 * lB - 0.012 * cB), 0.255 + 0.03 * lB);
        float2 waA = float2(0.012 - wdir * 0.045 * cA, 0.045 + 0.05 * lA);
        float2 waB = float2(-0.012 - wdir * 0.045 * cB, 0.045 + 0.05 * lB);
        kA = mix(kA, wkA, walkW); kB = mix(kB, wkB, walkW);
        aA = mix(aA, waA, walkW); aB = mix(aB, waB, walkW);
        tA = mix(tA, waA + float2(0.008 * wdir, -0.045), walkW);
        tB = mix(tB, waB + float2(0.008 * wdir, -0.045), walkW);
    }
    float dLeg = min(sx_leg(l, hipA, kA, aA, tA), sx_leg(l, hipB, kB, aB, tB));
    d = sx_smin(d, dLeg, 0.02);

    // Arms.
    float2 sR = float2(0.103, 0.785), sL = float2(-0.103, 0.785);
    float da = sx_limb(l, sR, eR, 0.027, 0.019, 0.0);
    da = sx_smin(da, sx_limb(l, eR, hR, 0.019, 0.012, 0.0), 0.008);
    da = sx_smin(da, sx_ellipse(l - hR, float2(0.016, 0.019)), 0.008);
    float db = sx_limb(l, sL, eL, 0.027, 0.019, 0.0);
    db = sx_smin(db, sx_limb(l, eL, hL, 0.019, 0.012, 0.0), 0.008);
    db = sx_smin(db, sx_ellipse(l - hL, float2(0.016, 0.019)), 0.008);
    d = sx_smin(d, min(da, db), 0.01);

    // Head in profile with glamour waves.
    float2 piv = float2(0.01, 0.84);
    float2 hq = piv + sx_rot(l - piv, -tilt);
    float dh = sx_ellipse(hq - float2(0.012, 0.903), float2(0.044, 0.058));
    dh = sx_smin(dh, length(hq - float2(0.054, 0.902)) - 0.011, 0.012);            // nose
    dh = sx_smin(dh, length(hq - float2(0.050, 0.878)) - 0.009, 0.008);            // lips
    dh = sx_smin(dh, sx_ellipse(hq - float2(0.03, 0.862), float2(0.022, 0.014)), 0.01);
    dh = min(dh, sdSegment(hq, float2(0.042, 0.913), float2(0.063, 0.923)) - 0.0028); // lashes
    float dhair = sx_ellipse(hq - float2(-0.008, 0.928), float2(0.060, 0.056));
    float2 tip = float2(-0.07 - 0.045 * flip, 0.80 + 0.05 * flip + 0.008 * sin(ph) * walkW);
    dhair = sx_smin(dhair, sx_limb(hq, float2(-0.03, 0.905), tip, 0.046, 0.026, 0.008), 0.02);
    dhair = sx_smin(dhair, length(hq - (tip + float2(0.012, -0.004))) - 0.026, 0.015);
    dhair = sx_smin(dhair, length(hq - float2(0.032, 0.955)) - 0.028, 0.012);
    d = sx_smin(d, sx_smin(dh, dhair, 0.01), 0.01);
    return d;
}

// Bra in its own units (width ~1.2, y up). k = bundled into a pouch.
float sx_bra(float2 q, float2 se, float k, float wing,
             thread float &dl, thread float &along, thread float &bowD) {
    float2 a = float2(abs(q.x), q.y);
    float2 cc = float2(mix(0.27, 0.14, k), mix(-0.02, -0.07, k));
    float cr = mix(0.23, 0.27, k);
    float dc = length(a - cc) - cr;
    float2 la = float2(0.035, mix(0.0, 0.05, k));
    float2 lb = float2(0.47, mix(0.19, 0.12, k));
    float2 ld = normalize(lb - la);
    float2 ln = float2(-ld.y, ld.x);
    along = dot(a - la, ld);
    dl = dot(a - la, ln);
    float cup = max(dc, dl - 0.012 * abs(sin(along * 44.0)));     // scalloped lace edge
    float gore = sx_limb(a, float2(0.0, 0.0), float2(0.0, -0.15), 0.02, 0.026, 0.0);
    float band = sx_limb(a, float2(0.0, -0.17), float2(mix(wing, 0.30, k), mix(-0.075, -0.13, k)), 0.03, 0.022, 0.0);
    float d = sx_smin(cup, gore, 0.03);
    d = sx_smin(d, band, 0.02);
    float2 peak = mix(float2(0.40, 0.155), float2(0.33, 0.10), k);
    d = min(d, sx_limb(a, peak, se, 0.012, 0.009, 0.0));
    bowD = min(length(a - float2(0.026, 0.005)) - 0.022, length(a - float2(0.0, -0.035)) - 0.012);
    return d;
}

// ---------- effect ----------

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);
    float s = u.scale;
    float2 W = windowSize(u);
    float2 wc = windowCenter(u);

    // Figure size and placement beside the window.
    float H = min(clamp(W.y * 0.92, 230.0 * s, 560.0 * s), u.size.y * 0.92);
    float gyHi = u.size.y - 3.0 * s;
    float gy = clamp(u.win.y + u.win.w + 0.03 * H, min(H * 1.1, gyHi), gyHi);
    float roomL = u.win.x;
    float roomR = u.size.x - (u.win.x + u.win.z);
    float need = 0.3 * H;
    bool right = u.seed > 0.5;
    if (right && roomR < need && roomL > roomR) right = false;
    else if (!right && roomL < need && roomR > roomL) right = true;
    float side = right ? 1.0 : -1.0;
    float m = -side;                                    // local +x -> toward the window
    float edge = right ? (u.win.x + u.win.z) : u.win.x;
    float fxStand = clamp(edge + side * 0.10 * H, 0.2 * H, max(u.size.x - 0.2 * H, 0.2 * H));

    // Strut in, strut out.
    float eIn = easeOutCubic(remap01(t, 0.0, 0.15));
    float eOut = easeInQuad(remap01(t, 0.83, 1.0));
    float figX = fxStand - m * ((1.0 - eIn) * 0.6 + eOut * 0.9) * H;
    float ph = (0.6 * eIn + 0.9 * eOut) * 17.0;
    float walkW = (1.0 - smoothstep(0.11, 0.17, t)) + smoothstep(0.82, 0.87, t);
    float wdir = t < 0.5 ? 1.0 : -1.0;
    float figA = remap01(t, 0.0, 0.07) * (1.0 - remap01(t, 0.88, 0.97));
    float idle = 0.022 * smoothstep(0.12, 0.20, t) + 0.010 * sin(TAU * remap01(t, 0.19, 0.30));
    float sway = mix(idle, -0.024 * sin(ph), walkW);
    float flip = sin(PI * remap01(t, 0.14, 0.27));
    float tilt = 0.12 * sin(PI * remap01(t, 0.36, 0.52)) - 0.05 * flip + 0.06 * smoothstep(0.84, 0.90, t);

    float2 eR, hR, eL, hL;
    sx_armR(t, eR, hR);
    sx_armL(t, eL, hL);
    float aWhirl = m * 0.5 * sin(PI * remap01(t, 0.30, 0.42)) - m * 2.0 * TAU * easeInQuad(remap01(t, 0.40, 0.48));
    float wEnv = sin(PI * remap01(t, 0.40, 0.48));
    float2 wOff = -sx_rot(float2(0.0, 0.022 * H), aWhirl) * wEnv;
    float2 wOffL = float2(m * wOff.x, -wOff.y) / H;
    hR += wOffL;
    eR += 0.4 * wOffL;

    // ---- Bra state ----
    float Bh = 0.19 * H, Bp = 0.21 * H, Bend = 0.27 * H;
    float Bland = max(max(W.x, W.y * 1.5), Bp * 1.2);
    float pull = smoothstep(0.29, 0.35, t);
    float k = smoothstep(0.68, 0.745, t);
    float wing = mix(0.46, 0.62, pull);
    float2 seLoose = float2(0.44 + 0.04 * sin(u.time * 13.0), 0.50 + 0.03 * cos(u.time * 11.0));
    float2 se = mix(float2(0.37, 0.40), float2(0.035, 0.58), pull);
    se = mix(se, seLoose, smoothstep(0.48, 0.56, t));
    se = mix(se, float2(0.035, 0.58), smoothstep(0.68, 0.76, t));

    float2 e0, h0; sx_armR(0.48, e0, h0);
    float2 P0 = sx_toC(h0, fxStand, gy, m, H) + float2(0.0, 0.58 * Bp);
    float2 Pl = wc - float2(0.0, 0.05 * Bland);
    float2 e1, h1; sx_armR(0.82, e1, h1);
    float2 Pc = sx_toC(h1, fxStand, gy, m, H) + float2(0.0, 0.58 * Bend);
    float fs = remap01(t, 0.48, 0.58);
    float rs = remap01(t, 0.72, 0.82);

    float2 Cb; float B; float a = 0.0;
    float sqx = 1.0, sqy = 1.0, flutter = 0.0;
    if (t < 0.48) {
        a = aWhirl;
        B = mix(Bh, Bp, pull);
        float2 chest = sx_toC(float2(0.07 * sway, 0.712), figX, gy, m, H);
        float2 hang = sx_toC(hR, figX, gy, m, H) + sx_rot(float2(0.0, 0.58 * B), a);
        Cb = mix(chest, hang, pull);
    } else if (t < 0.72) {
        B = mix(Bp, Bland, easeInOutQuad(fs));
        Cb = sx_path(P0, Pl, fs, s);
        a = -m * 2.0 * TAU - m * TAU * easeOutCubic(fs);
        float lt = remap01(t, 0.575, 0.72);
        float wob = sin(lt * 20.0) * exp(-lt * 6.0) * step(0.575, t);
        sqy = 1.0 - 0.10 * wob; sqx = 1.0 + 0.05 * wob;
        flutter = sin(PI * fs) * 0.9 + (t > 0.575 ? 0.5 * (1.0 - lt) : 0.0);
    } else if (t < 0.82) {
        float re = easeInOutCubic(rs);
        B = mix(Bland, Bend, re);
        Cb = sx_path(Pl, Pc, rs, s);
        a = m * TAU * re;
        flutter = 0.4 * sin(PI * rs);
    } else {
        float dT = (t - 0.82) * u.duration;
        B = Bend;
        a = m * (0.5 * sin(dT * 15.0) * exp(-dT * 4.5) + 0.2 * sin(ph * 0.5) * walkW);
        Cb = sx_toC(hR, figX, gy, m, H) + sx_rot(float2(0.0, 0.58 * B), a);
        float j = exp(-dT * 7.0) * sin(dT * 25.0);
        sqy = 1.0 + 0.12 * j; sqx = 1.0 - 0.06 * j;
    }

    // ---- Window: swallowed into the cups ----
    float sw = 1.0 - easeInCubic(remap01(t, 0.585, 0.69));
    float4 col = float4(0.0);
    if (sw > 0.002) {
        col = sampleWindow(tex, u, wc + (p - wc) / sw);
        col.rgb *= 1.0 - 0.4 * (1.0 - sw);
    }

    float2 l = float2((p.x - figX) * m, gy - p.y) / H;
    float3 pink = float3(1.0, 0.40, 0.64);

    // Stage spotlight behind her.
    float spotEnv = remap01(t, 0.03, 0.18) * (1.0 - remap01(t, 0.80, 0.96));
    if (spotEnv > 0.0) {
        float2 sd = (l - float2(0.0, 0.58)) / float2(0.45, 0.62);
        float2 fd = l / float2(0.38, 0.05);
        float gl = exp(-dot(sd, sd) * 2.0) * 0.13 + exp(-dot(fd, fd) * 1.6) * 0.20;
        float3 light = float3(1.0, 0.36, 0.56) * gl * spotEnv;
        col.rgb += light;
        col.a = saturate(col.a + luminance(light) * 0.4);
    }

    // Soft shadow of the bra on the window.
    float shEnv = smoothstep(0.49, 0.58, t) * (1.0 - smoothstep(0.69, 0.80, t));
    if (shEnv > 0.0) {
        float off = mix(60.0, 14.0, remap01(t, 0.50, 0.58)) * s;
        float2 dq2 = sx_rot(p - Cb - float2(off * 0.4, off), -a);
        float2 q2 = float2(dq2.x, -dq2.y) / B / float2(sqx, sqy);
        if (abs(q2.x) < 1.0 && abs(q2.y) < 1.0) {
            float x0, x1, x2;
            float ds = sx_bra(q2, se, k, wing, x0, x1, x2) * B;
            float sh = (1.0 - smoothstep(-10.0 * s, 24.0 * s, ds)) * 0.42 * shEnv;
            col = over(float4(0.0, 0.0, 0.0, sh), col);
        }
    }

    float3 add = float3(0.0);

    // ---- The silhouette ----
    if (figA > 0.0 && l.x > -0.5 && l.x < 0.6 && l.y > -0.12 && l.y < 1.25) {
        float d = sx_figure(l, sway, saturate(walkW), ph, wdir, eR, hR, eL, hL, flip, tilt);
        float dpx = d * H;
        float cov = 1.0 - smoothstep(-0.7, 0.7, dpx);
        float rim = exp(min(dpx, 0.0) / (1.8 * s)) * cov * (0.6 + 0.4 * smoothstep(0.3, 1.0, l.y));
        float3 rgb = float3(0.03, 0.018, 0.035) * cov + pink * rim * 0.75;
        col = over(float4(rgb, cov) * figA, col);
        float halo = exp(-max(dpx, 0.0) / (16.0 * s)) * (1.0 - cov) * figA;
        add += pink * halo * 0.16;
    }

    // ---- The bra ----
    {
        float2 dq = sx_rot(p - Cb, -a);
        float2 q = float2(dq.x, -dq.y) / B / float2(sqx, sqy);
        q.y += flutter * 0.03 * sin(q.x * 9.0 + u.time * 14.0);
        if (figA > 0.0 && abs(q.x) < 0.9 && q.y > -0.6 && q.y < 0.75) {
            float bdl, balong, bowD;
            float db = sx_bra(q, se, k, wing, bdl, balong, bowD);
            float dpx = db * B * min(sqx, sqy);
            float cov = 1.0 - smoothstep(-0.7, 0.7, dpx);
            if (cov > 0.0) {
                float2 qa = float2(abs(q.x), q.y);
                float3 fill = float3(0.17, 0.03, 0.09);
                float lm = smoothstep(140.0 * s, 320.0 * s, B) * smoothstep(-0.10, -0.06, bdl) * (1.0 - k);
                float holes = smoothstep(0.34, 0.2, length(fract(float2(balong, bdl) * 52.0) - 0.5));
                fill *= 1.0 - 0.55 * holes * lm;
                float2 sh = qa - float2(0.22, -0.06);
                fill += float3(0.45, 0.12, 0.26) * exp(-dot(sh, sh) * 40.0) * 0.5;
                float rim = exp(min(dpx, 0.0) / (1.6 * s));
                float3 rgb = fill + float3(1.0, 0.45, 0.68) * rim * 0.8;
                float bow = 1.0 - smoothstep(-0.7, 0.7, bowD * B);
                rgb = mix(rgb, float3(1.0, 0.42, 0.62), bow * 0.9);
                col = over(float4(rgb * cov, cov) * figA, col);
            }
        }
    }

    // "Ting" as the clasp comes undone.
    float ut = remap01(t, 0.27, 0.34);
    if (ut > 0.0 && ut < 1.0) {
        float2 gp = sx_toC(float2(0.0, 0.715), figX, gy, m, H);
        float env = sin(PI * ut);
        add += float3(1.0, 0.85, 0.92) * sx_glint(p - gp, 12.0 * s * env) * env;
    }

    // Sparkle trail behind the flying bra.
    if (t > 0.48 && t < 0.64) {
        float fsu = (t - 0.48) / 0.10;
        float fade = 1.0 - remap01(t, 0.58, 0.64);
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            float ft = min(fsu - 0.03 * (fi + 1.0), 1.0);
            if (ft <= 0.0) continue;
            float2 tp = sx_path(P0, Pl, ft, s)
                      + (hash22(float2(fi, u.seed * 13.0)) - 0.5) * 0.25 * mix(Bp, Bland, ft);
            float r = (6.0 + 5.0 * hash11(fi * 3.1 + u.seed)) * s;
            float2 dd = p - tp;
            if (dot(dd, dd) > 9.0 * r * r) continue;
            float tw = 0.7 + 0.3 * sin(u.time * 40.0 + fi * 2.0);
            add += float3(1.0, 0.6, 0.8) * sx_glint(dd, r) * (1.0 - fi / 6.0) * fade * tw;
        }
    }

    // Glints as it lands over the window.
    float gt = remap01(t, 0.575, 0.70);
    if (gt > 0.0 && gt < 1.0) {
        for (int i = 0; i < 7; i++) {
            float fi = float(i);
            float ang = fi * TAU / 7.0 + u.seed * 6.0;
            float2 gp = wc + float2(cos(ang) * 0.55, sin(ang) * 0.30) * Bland * (0.85 + 0.35 * gt);
            float r = (9.0 + 6.0 * hash11(fi + u.seed * 7.0)) * s;
            float2 dd = p - gp;
            if (dot(dd, dd) > 9.0 * r * r) continue;
            float life = sin(PI * remap01(gt, 0.05 * fi, 0.55 + 0.06 * fi));
            if (life <= 0.01) continue;
            add += float3(1.0, 0.85, 0.92) * sx_glint(dd, r * life) * life;
        }
    }

    // A little heart floats off as she struts away.
    float hsT = remap01(t, 0.835, 0.985);
    if (hsT > 0.0 && hsT < 1.0) {
        float2 hp = sx_toC(float2(0.075 + 0.10 * hsT + 0.015 * sin(hsT * 14.0), 0.895 + 0.22 * hsT),
                           fxStand, gy, m, H);
        float hsz = 0.03 * H * (0.4 + 0.6 * easeOutBack(remap01(hsT, 0.0, 0.25)));
        float2 hq = (p - hp) / hsz;
        hq.y = -hq.y + 0.5;
        if (dot(hq, hq) < 9.0) {
            float hd = sx_heart(hq) * hsz;
            float ha = smoothstep(0.0, 0.08, hsT) * (1.0 - smoothstep(0.55, 1.0, hsT));
            float hc = 1.0 - smoothstep(-0.7, 0.7, hd);
            float3 hcol = mix(float3(1.0, 0.30, 0.52), float3(1.0, 0.75, 0.85), exp(-length(hq - float2(-0.25, 0.75)) * 5.0));
            col = over(float4(hcol * hc, hc) * ha, col);
            add += float3(1.0, 0.32, 0.55) * exp(-max(hd, 0.0) / (6.0 * s)) * 0.45 * ha * (1.0 - hc);
        }
    }

    col.rgb += add;
    col.a = saturate(col.a + luminance(add) * 0.5);
    return col;
}
