// @name Dragonfire
// @name.zh 巨龙喷火
// @author kadaliao
// @description A dragon's head slides in from the side and torches the window with a roaring jet of flame, leaving embers and smoke.
// @description.zh 一只巨龙从旁边探出头来，喷出一道咆哮的烈焰，把窗口烧成火星和青烟。
// @duration 2.0
// @padding 260
// @events close, minimize, quit

// ---------- helpers ----------
float dfx_taper(float2 p, float2 a, float2 b, float ra, float rb) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - mix(ra, rb, h);
}

float dfx_smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float3 dfx_fire(float x) {
    x = clamp(x, 0.0, 1.6);
    float3 c = mix(float3(0.45, 0.04, 0.0), float3(1.0, 0.36, 0.04), smoothstep(0.0, 0.45, x));
    c = mix(c, float3(1.0, 0.76, 0.26), smoothstep(0.40, 0.85, x));
    c = mix(c, float3(1.0, 0.96, 0.86), smoothstep(0.85, 1.40, x));
    return c;
}

// Dragon head in points. +x points toward the window (snout tip near x = 0), y down.
float dfx_head(float2 q, float jaw, thread float &teeth) {
    // Upper jaw, skull, brow, neck, nose.
    float d = dfx_taper(q, float2(-108.0, -18.0), float2(-6.0, -9.0), 24.0, 7.0);
    d = dfx_smin(d, sdCircle(q - float2(-120.0, -28.0), 36.0), 10.0);
    d = dfx_smin(d, dfx_taper(q, float2(-112.0, -44.0), float2(-76.0, -31.0), 10.0, 4.0), 6.0);
    d = dfx_smin(d, dfx_taper(q, float2(-135.0, -12.0), float2(-330.0, 64.0), 34.0, 56.0), 14.0);
    d = dfx_smin(d, sdCircle(q - float2(-16.0, -15.0), 8.0), 4.0);

    // Horns and neck spines.
    d = min(d, dfx_taper(q, float2(-132.0, -54.0), float2(-204.0, -98.0), 10.0, 1.2));
    d = min(d, dfx_taper(q, float2(-112.0, -54.0), float2(-152.0, -106.0), 7.0, 0.8));
    d = min(d, dfx_taper(q, float2(-165.0, -36.0), float2(-192.0, -62.0), 6.0, 0.5));
    d = min(d, dfx_taper(q, float2(-205.0, -22.0), float2(-232.0, -48.0), 6.5, 0.5));
    d = min(d, dfx_taper(q, float2(-247.0, -6.0), float2(-274.0, -32.0), 7.0, 0.5));

    // Lower jaw, rotated about its hinge (opens downward).
    float2 hg = float2(-104.0, 2.0);
    float a = jaw * 0.52;
    float cs = cos(a), sn = sin(a);
    float2 r = q - hg;
    float2 jq = hg + float2(r.x * cs + r.y * sn, -r.x * sn + r.y * cs);
    float dj = dfx_taper(jq, float2(-112.0, 6.0), float2(-14.0, 4.0), 16.0, 5.0);
    dj = min(dj, dfx_taper(jq, float2(-96.0, 18.0), float2(-130.0, 46.0), 6.0, 0.5));
    d = dfx_smin(d, dj, 3.0);

    // Teeth.
    float tt = 1e5;
    for (int i = 0; i < 4; i++) {
        float x = -22.0 - 14.0 * float(i);
        float yb = -3.0 - (x + 22.0) * 0.09;
        tt = min(tt, dfx_taper(q, float2(x, yb), float2(x + 2.0, yb + 10.0), 2.6, 0.3));
    }
    for (int i = 0; i < 3; i++) {
        float x = -26.0 - 14.0 * float(i);
        tt = min(tt, dfx_taper(jq, float2(x, 1.0), float2(x + 2.0, -10.0), 2.4, 0.3));
    }
    teeth = tt;
    return d;
}

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    float S = u.scale;
    float T = u.time;
    float2 c = windowCenter(u);
    float2 hs = windowSize(u) * 0.5;

    // ---- Where the dragon sits: the side with more room on screen ----
    float roomL = u.win.x;
    float roomR = u.size.x - (u.win.x + u.win.z);
    float need = 180.0 * S;
    float side = (roomL > need && roomR > need) ? (u.seed < 0.5 ? -1.0 : 1.0)
                                                : (roomL > roomR ? -1.0 : 1.0);
    float2 mouth;
    mouth.x = side < 0.0 ? u.win.x - 60.0 * S : u.win.x + u.win.z + 60.0 * S;
    mouth.y = u.win.y + u.win.w * mix(0.28, 0.55, fract(u.seed * 7.31));
    float2 to = c - mouth;
    float sl = clamp(to.y / max(abs(to.x), 1.0), -0.3, 0.3);
    float2 dir = normalize(float2(-side, sl));
    float2 perp = float2(-dir.y, dir.x);
    if (perp.y < 0.0) perp = -perp;

    // ---- Timeline ----
    float breathOn = remap01(t, 0.16, 0.21) * (1.0 - remap01(t, 0.84, 0.92));
    float glowAmt  = remap01(t, 0.08, 0.18) * (1.0 - remap01(t, 0.84, 0.92));
    float jaw = easeOutBack(remap01(t, 0.09, 0.19)) * (1.0 - easeInOutQuad(remap01(t, 0.80, 0.89)));
    jaw *= 1.0 + 0.06 * sin(T * 21.0) * breathOn;

    // Breath aim sways a little.
    float ang = sin(T * 2.6 + u.seed * 6.0) * 0.07;
    float ca = cos(ang), sa = sin(ang);
    float2 dirS = float2(dir.x * ca - dir.y * sa, dir.x * sa + dir.y * ca);
    float2 perpS = float2(-dirS.y, dirS.x);
    if (perpS.y < 0.0) perpS = -perpS;

    float dmin = max(sdBox(mouth - c, hs), 0.0);
    float dmax = 0.0;
    dmax = max(dmax, length(u.win.xy - mouth));
    dmax = max(dmax, length(u.win.xy + float2(u.win.z, 0.0) - mouth));
    dmax = max(dmax, length(u.win.xy + float2(0.0, u.win.w) - mouth));
    dmax = max(dmax, length(u.win.xy + u.win.zw - mouth));

    float Lmax = dmax + 120.0 * S;
    float L  = Lmax * easeOutCubic(remap01(t, 0.17, 0.32));
    float s0 = Lmax * easeInQuad(remap01(t, 0.74, 0.90));

    float2 dm = p - mouth;
    float lx = dot(dm, dirS), ly = dot(dm, perpS);
    float w = 7.0 * S + max(lx, 0.0) * 0.26;

    // ---- Window layer: heat shimmer, scorch, burn ----
    float prox = lx > 0.0 ? exp(-max(abs(ly) - w, 0.0) / (90.0 * S)) : 0.0;
    float heat = breathOn * prox;
    float2 nq = p / (14.0 * S) + float2(0.0, T * 8.0);
    float2 warp = (float2(noise(nq), noise(nq + 5.2)) - 0.5) * heat * 6.0 * S;
    float4 orig = sampleWindow(tex, u, p + warp);

    float A = 70.0 * S;
    float burnP = easeInOutQuad(remap01(t, 0.24, 0.88));
    float f = mix(dmin - A - 50.0 * S, dmax + A + 50.0 * S, burnP);
    float wsd = windowSDF(u, p);
    float e = -1e5;
    if (wsd < 60.0 * S) {
        float nb = fbm(p / (70.0 * S) + u.seed * 31.0, 4);
        float nb2 = noise(p / (12.0 * S) + 7.0);
        float b = length(dm) + (nb - 0.5) * 2.0 * A + (nb2 - 0.5) * 12.0 * S;
        e = f - b;
    }

    float emberW = 3.5 * S;
    float charW = 12.0 * S;
    float4 col;
    if (e < 0.0) {
        float k = remap01(e, -40.0 * S, 0.0);
        col = orig;
        col.rgb = mix(col.rgb, col.rgb * float3(0.60, 0.38, 0.20), k * k * 0.9);
        col.rgb += float3(1.0, 0.45, 0.12) * 0.32 * heat * col.a;      // firelight
    } else {
        float ck = remap01(e, emberW * 0.4, emberW + charW);
        float alpha = orig.a * (1.0 - smoothstep(0.5, 1.0, ck));
        float crumble = step(0.35 + 0.6 * ck, noise(p / (3.0 * S) + 3.1));
        alpha *= mix(1.0, crumble, smoothstep(0.3, 0.8, ck));
        float3 charCol = mix(float3(0.13, 0.06, 0.03), float3(0.02, 0.015, 0.01), ck);
        col = premul(charCol, alpha);
    }

    // Ember line + halo.
    if (e > -45.0 * S && e < 50.0 * S) {
        float flick = 0.75 + 0.5 * noise(p / (6.0 * S) + float2(T * 9.0, -T * 5.0));
        float gate = smoothstep(-14.0 * S, -6.0 * S, e) * (1.0 - smoothstep(18.0 * S, 28.0 * S, e));
        float ember = exp(-abs(e - 1.2 * S) / (2.4 * S)) * gate * orig.a * flick;
        float3 emberCol = mix(float3(1.0, 0.32, 0.04), float3(1.0, 0.86, 0.50),
                              exp(-abs(e - 0.6 * S) / (1.4 * S)));
        float halo = exp(-abs(e) / (9.0 * S)) * smoothstep(-40.0 * S, -24.0 * S, e)
                   * (1.0 - smoothstep(30.0 * S, 45.0 * S, e)) * orig.a;
        col.rgb += emberCol * ember * 1.5 + float3(1.0, 0.42, 0.08) * halo * 0.45;
        col.a = clamp(col.a + ember * 0.5 + halo * 0.15, 0.0, 1.0);
    }

    float4 res = col;

    // Wall of flame trailing the burn front, inside the old window area.
    float flameEnv = remap01(t, 0.24, 0.32) * (1.0 - remap01(t, 0.86, 0.97));
    if (flameEnv > 0.0 && e > -4.0 * S && e < 100.0 * S) {
        float winMask = smoothstep(2.0 * S, -2.0 * S, wsd);
        float fn = fbm(float2(p.x / (22.0 * S), p.y / (26.0 * S) + T * 3.5) + u.seed * 9.0, 3);
        float reach = 22.0 * S + 80.0 * S * fn * fn;
        float x = e / reach;
        float fl = smoothstep(0.0, 6.0 * S, e) * (1.0 - smoothstep(0.55, 1.0, x)) * winMask * flameEnv;
        float temp = (1.0 - x) * (0.7 + 0.8 * fn);
        float3 fc = dfx_fire(temp) * fl * 1.2;
        res.rgb = res.rgb * (1.0 - fl * 0.3) + fc;
        res.a = res.a + fl * 0.55 * (1.0 - res.a);
    }

    // Smoke drifting up from what's already burnt.
    float smokeEnv = remap01(t, 0.35, 0.6) * (1.0 - remap01(t, 0.72, 1.0));
    if (smokeEnv > 0.0 && e > 30.0 * S) {
        float sm = fbm(p / (55.0 * S) + float2(u.seed * 3.0, T * 0.9), 3);
        float dens = smoothstep(0.45, 0.8, sm) * smoothstep(30.0 * S, 120.0 * S, e)
                   * smoothstep(40.0 * S, -10.0 * S, wsd) * smokeEnv * 0.38;
        res = over(premul(float3(0.13, 0.11, 0.10), dens), res);
    }

    // ---- The breath ----
    if (breathOn > 0.0 && lx > s0 - 20.0 * S && lx < L + 90.0 * S && abs(ly) < w * 1.6 + 20.0 * S) {
        float n  = fbm(float2(lx / (46.0 * S) - T * 6.5, ly / (26.0 * S) + u.seed * 17.0), 4);
        float n2 = noise(float2(lx / (15.0 * S) - T * 13.0, ly / (10.0 * S) - T * 2.0));
        float rr = abs(ly) / w + (n - 0.5) * 1.1;
        float headMask = smoothstep(s0 - 10.0 * S, s0 + 30.0 * S, lx + (n - 0.5) * 60.0 * S);
        float tipMask = 1.0 - smoothstep(L - 90.0 * S, L, lx + (n - 0.5) * 90.0 * S);
        float dens = smoothstep(1.05, 0.25, rr) * headMask * tipMask * breathOn;
        float temp = (1.1 - rr * 0.9) * (0.65 + 0.6 * n2) * mix(1.25, 0.75, saturate(lx / Lmax));
        float core = smoothstep(0.45, 0.0, abs(ly) / w + (n2 - 0.5) * 0.3) * exp(-max(lx, 0.0) / (220.0 * S));
        temp += core * 0.6;
        float3 srgb = dfx_fire(temp) * dens * 1.5;
        float sA = clamp(dens * 0.6, 0.0, 1.0);
        res.rgb = res.rgb * (1.0 - sA * 0.3) + srgb;
        res.a = res.a + sA * (1.0 - res.a);
    }

    // ---- Dragon head ----
    float headA = remap01(t, 0.0, 0.07) * (1.0 - remap01(t, 0.91, 0.99));
    if (headA > 0.0) {
        float hk = S * clamp(u.win.w / (S * 480.0), 0.65, 1.15);
        float headOff = (1.0 - easeOutCubic(remap01(t, 0.0, 0.16))) * 260.0 * S
                      + easeInCubic(remap01(t, 0.84, 0.99)) * 320.0 * S;
        float2 hl = float2(dot(dm, dir), dot(dm, perp));
        hl.x += headOff + 6.0 * S * breathOn;                 // recoil while breathing
        hl.y -= sin(T * 5.0) * 2.0 * S;
        float2 q = hl / hk;

        if (q.x > -360.0 && q.x < 40.0 && q.y > -130.0 && q.y < 140.0) {
            float lightAmt = glowAmt * (0.55 + 0.45 * breathOn) * (0.85 + 0.15 * sin(T * 37.0));
            float teethD;
            float d = dfx_head(q, max(jaw, 0.0), teethD);
            float dAll = min(d, teethD);
            float cov = clamp(0.5 - dAll * hk / S, 0.0, 1.0) * headA;

            float4 headL = float4(0.0);
            if (cov > 0.0) {
                float texN = 0.75 + 0.25 * noise(q * 0.25);
                float ridges = 0.86 + 0.14 * sin(q.x * 0.55 + sin(q.y * 0.45) * 2.0);
                float3 hc = float3(0.075, 0.040, 0.035) * texN * ridges;
                float Lg = lightAmt * exp(min(q.x, 0.0) / 110.0);
                float rim = exp(min(d, 0.0) / 3.0);
                hc += float3(1.0, 0.45, 0.12) * rim * Lg * 0.9
                    + float3(1.0, 0.40, 0.10) * 0.16 * Lg;
                if (teethD < d + 0.5) {
                    hc = float3(0.85, 0.78, 0.62) * (0.22 + 0.9 * Lg);
                }
                // Glowing slit eye.
                float2 eyeC = float2(-90.0, -31.0);
                float ed = length(q - eyeC);
                float eyeMask = smoothstep(5.0, 4.0, ed);
                float slit = smoothstep(0.5, 1.4, abs(q.x - eyeC.x));
                float3 eyeCol = mix(float3(1.0, 0.88, 0.25), float3(1.0, 0.42, 0.05), ed / 5.0) * slit * 1.5;
                hc = mix(hc, eyeCol, eyeMask);
                headL = premul(hc, cov);
            }
            res = over(headL, res);

            // Throat glow between the jaws, and an eye glint halo.
            float mg = exp(-length(q - float2(-22.0, 4.0 + max(jaw, 0.0) * 10.0)) / 14.0) * glowAmt * headA;
            float eg = exp(-length(q - float2(-90.0, -31.0)) / 5.0) * 0.35 * headA;
            float3 add = float3(1.0, 0.6, 0.2) * mg * 1.2 + float3(1.0, 0.7, 0.25) * eg;
            res.rgb += add;
            res.a = clamp(res.a + (mg * 0.4 + eg * 0.2) * (1.0 - res.a), 0.0, 1.0);
        }
    }

    // ---- Sparks blown along the breath ----
    float env = remap01(t, 0.25, 0.33) * (1.0 - remap01(t, 0.85, 0.98));
    if (env > 0.0 && wsd < 160.0 * S) {
        float cell = 26.0 * S;
        float2 v = dir * 230.0 * S + float2(0.0, -80.0 * S);
        float2 qq = p - v * T;
        float2 base = floor(qq / cell);
        float3 spark = float3(0.0);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                float2 cid = base + float2(i, j);
                float h = hash21(cid + 0.37 + u.seed * 13.0);
                if (h < 0.55) continue;
                float2 ps = (cid + 0.15 + 0.7 * hash22(cid * 1.3 + u.seed)) * cell + v * T;
                ps.y += sin(T * 6.0 + h * 40.0) * 4.0 * S;
                float es = f - length(ps - mouth);
                float near = smoothstep(-20.0 * S, 20.0 * S, es) * (1.0 - smoothstep(150.0 * S, 300.0 * S, es));
                float inW = smoothstep(30.0 * S, 0.0, windowSDF(u, ps));
                float dd = length(p - ps);
                float r = (0.8 + 1.2 * hash11(h * 13.0)) * S;
                float tw = 0.6 + 0.4 * sin(T * 30.0 + h * 90.0);
                float I = (smoothstep(r * 1.6, 0.0, dd) + exp(-dd / (r * 2.5)) * 0.35) * near * inW * tw;
                spark += mix(float3(1.0, 0.45, 0.08), float3(1.0, 0.88, 0.50), hash11(h * 7.0)) * I;
            }
        }
        spark *= env;
        res.rgb += spark;
        res.a = clamp(res.a + luminance(spark) * 0.6, 0.0, 1.0);
    }

    return res * (1.0 - remap01(t, 0.97, 1.0));
}
