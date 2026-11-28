// @name Ground Zero
// @name.zh 蘑菇云
// @author kadaliao
// @description A bomb drops in, a blinding flash, then a mushroom cloud rises as the blast wipes the window away.
// @description.zh 一颗原子弹落下，白光一闪，蘑菇云腾空而起，冲击波把窗口炸得一干二净。
// @duration 2.8
// @padding 260
// @events close, minimize, quit

float nuke_smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Signed distance (in cloud-height units, y up, ground at 0) to the smooth mushroom silhouette.
float nuke_shape(float2 q, float hc, float rc, float grow, float skirt) {
    float ax = abs(q.x);
    // Cap: dome on top, flattened underneath.
    float2 d = float2(ax, q.y - hc);
    d.y *= d.y > 0.0 ? 1.2 : 2.0;
    float m = length(d) - rc;
    // Rolled-under rim.
    float roll = length(float2(ax - rc * 0.70, q.y - hc + rc * 0.24)) - rc * 0.36;
    m = nuke_smin(m, roll, 0.05);
    // Stem, flared at the ground and under the cap.
    float w = 0.045 + 0.035 * grow + 0.12 * grow * exp(-max(q.y, 0.0) * 13.0)
            + 0.05 * smoothstep(hc - 0.30, hc, q.y);
    float stem = max(ax - w, max(q.y - hc, -q.y - 0.02));
    m = nuke_smin(m, stem, 0.04);
    // Collar ring halfway up.
    float collar = length(float2(ax, (q.y - hc * 0.55) * 3.4)) - rc * 0.60 * skirt;
    m = nuke_smin(m, collar, 0.03);
    // Base surge hugging the ground.
    float bh = 0.045 + 0.03 * grow;
    float br = 0.10 + 0.36 * grow;
    float base = (length(float2(ax / br, (q.y - 0.015) / bh)) - 1.0) * bh;
    m = nuke_smin(m, base, 0.04);
    return m;
}

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    if (t <= 0.0) return sampleWindow(tex, u, p);
    if (t >= 1.0) return float4(0.0);

    float s = u.scale;
    const float ti = 0.15;                                  // moment of impact

    float2 W = windowSize(u);
    float2 G = float2(u.win.x + W.x * (0.5 + (fract(u.seed * 7.31) - 0.5) * 0.18),
                      u.win.y + W.y * 0.92);                // ground zero
    float H = clamp(W.y * 0.95, 180.0 * s, 600.0 * s);      // cloud height
    H = min(H, max(G.y * 0.94, 90.0 * s));                  // keep the cap on the canvas

    float2 gd = p - G;
    float d = length(gd);
    float2 gdir = gd / max(d, 0.001);
    float hit = step(ti, t);
    float border = min(min(p.x, p.y), min(u.size.x - p.x, u.size.y - p.y));
    float edgeFade = smoothstep(0.0, 48.0 * s, border);
    float fallK = pow(remap01(t, 0.0, ti), 1.6);

    // Flash envelope.
    float F = smoothstep(ti - 0.006, ti, t) * exp(-max(t - ti, 0.0) / 0.055);

    // Blast front radius: destroys the window, then keeps going as a pressure wave.
    float2 fc = max(abs(u.win.xy - G), abs(u.win.xy + W - G));
    float maxR = length(fc) + 70.0 * s;
    float Rend = max(maxR * 1.5, 1.2 * H);
    float R = Rend * easeOutCubic(remap01(t, ti, ti + 0.40));

    float4 res = float4(0.0);

    // ---------------------------------------------------------------- window
    if (t < ti + 0.21) {
        float rag = clamp(R / (120.0 * s), 0.0, 1.0);
        float e = -d;                                       // > 0: already vaporised
        if (hit > 0.5) {
            float nb = fbm(p / (55.0 * s) + u.seed * 31.0, 3);
            float nf = noise(p / (8.0 * s) + 7.0);
            e = R - d - ((nb - 0.5) * 68.0 + (nf - 0.5) * 9.0) * s * rag;
        }
        float post = max(t - ti, 0.0);
        float2 shake = hit * exp(-post * 16.0) * 7.0 * s
                     * float2(sin(u.time * 85.0), cos(u.time * 67.0));
        float pz = min(e, 0.0) / (46.0 * s);
        float push = hit * rag * 16.0 * s * exp(-pz * pz);  // bulge ahead of the front
        float4 win = sampleWindow(tex, u, p - shake - gdir * push);
        float wa = win.a;

        // Shadow of the falling bomb tightening on the target.
        float shr = mix(70.0, 18.0, fallK) * s;
        float sh = (1.0 - smoothstep(0.0, shr, length(gd * float2(1.0, 2.4)))) * fallK * (1.0 - hit);
        win.rgb *= 1.0 - 0.36 * sh;

        // Incandescent heat ahead of the front, whiteout from the flash.
        float hk = hit * remap01(e, -80.0 * s, 0.0);
        win.rgb = mix(win.rgb, wa * float3(1.0, 0.80, 0.52), hk * hk * 0.85);
        win.rgb = mix(win.rgb, float3(wa), F * 0.9);

        if (hit > 0.5 && e > 0.0) {
            // Charred rim crumbling to nothing.
            float ck = remap01(e, 2.0 * s, 30.0 * s);
            float al = wa * (1.0 - smoothstep(0.35, 1.0, ck));
            float crumble = step(0.30 + 0.65 * ck, noise(p / (2.6 * s) + 3.1));
            al *= mix(1.0, crumble, smoothstep(0.15, 0.6, ck));
            float3 charCol = mix(float3(0.16, 0.07, 0.03), float3(0.02, 0.015, 0.01), ck);
            win = premul(charCol, al);
        }

        // Glowing edge where the blast is eating the window.
        float rim = hit * rag * exp(-abs(e - 1.5 * s) / (3.0 * s)) * wa;
        float3 rimCol = mix(float3(1.0, 0.40, 0.06), float3(1.0, 0.92, 0.70),
                            exp(-abs(e - 1.0 * s) / (1.6 * s)));
        win.rgb += rimCol * rim * 1.6;
        win.a = clamp(win.a + rim * 0.5, 0.0, 1.0);
        res = win;
    }

    // ------------------------------------------------------------- explosion
    if (hit > 0.5) {
        // Pressure wave.
        float pz = (d - R) / (4.0 * s + 0.012 * R);
        float pw = exp(-pz * pz) * (1.0 - remap01(t, ti + 0.10, ti + 0.40)) * edgeFade;
        res.rgb += float3(1.0, 0.96, 0.90) * pw * 0.45;
        res.a = clamp(res.a + pw * 0.25, 0.0, 1.0);

        // Dust ring racing along the ground (flattened ellipse).
        float gt = remap01(t, ti, ti + 0.48);
        float Rg = 1.25 * H * easeOutCubic(gt);
        float de = length(float2(gd.x, gd.y * 4.5));
        float dz = (de - Rg) / (0.03 * H + 0.06 * Rg);
        float dust = exp(-dz * dz) * remap01(gt, 0.0, 0.08) * (1.0 - remap01(gt, 0.3, 1.0));
        dust *= (0.55 + 0.7 * noise(p / (16.0 * s) + float2(u.seed * 5.0, t * 8.0))) * edgeFade;
        res = over(float4(float3(1.0, 0.86, 0.66) * dust * 0.6, dust * 0.42), res);

        // Mushroom cloud.
        float2 q = float2(gd.x, -gd.y) / H;                 // y up, ground at 0
        float birth = easeOutCubic(remap01(t, ti, ti + 0.05));
        float fadeT = remap01(t, 0.68, 1.0);
        float grow = easeOutQuad(remap01(t, ti, 0.68));
        float rise = 1.0 - pow(1.0 - remap01(t, ti + 0.02, 0.72), 2.2);
        float hc = mix(0.09, 0.67, rise) + 0.05 * fadeT;    // cap height
        float rc = mix(0.09, 0.29, grow) + 0.03 * fadeT;    // cap radius
        float heat0 = 1.0 - remap01(t, ti + 0.04, 0.66);
        float bsc = max(birth, 0.05);

        // Fireball glow behind the cloud.
        float gl = heat0 * heat0 * birth
                 * exp(-length(q - float2(0.0, hc * bsc)) / (rc * 1.7 + 0.02)) * edgeFade;
        res.rgb += float3(1.0, 0.50, 0.14) * gl * 0.6;
        res.a = clamp(res.a + gl * 0.22, 0.0, 1.0);

        if (abs(q.x) < 0.85 && q.y > -0.12 && q.y < 1.3) {
            float2 qq = q / bsc;
            float sd = nuke_shape(qq, hc, rc, grow, smoothstep(0.35, 0.8, rise)) * bsc;
            if (sd < 0.27) {
                // Billows: texture rides up with the cap and swells with it.
                float2 nq = float2(q.x, q.y - hc * 0.85) / (0.55 + 0.45 * grow) * 6.5;
                nq += float2(u.seed * 17.0, u.seed * 9.0) + 40.0;
                nq += 0.10 * float2(sin(u.time * 1.7 + q.y * 8.0), cos(u.time * 1.4 + q.x * 8.0));
                float2 L = float2(-0.45, 0.80);             // toward the light
                float n = fbm(nq, 4);
                float n2 = fbm(nq + L * 0.24, 4);

                float capZone = smoothstep(hc - rc * 1.3, hc - rc * 0.2, qq.y);
                float baseZone = 1.0 - smoothstep(0.02, 0.14, qq.y);
                float amp = mix(0.034, 0.075, max(capZone, baseZone * 0.7))
                          * (0.45 + 0.55 * grow) * (1.0 + 1.6 * fadeT) * bsc;
                float dn = sd - (n - 0.42) * amp * 2.0 + 0.34 * pow(fadeT, 1.5);
                float soft = max(1.5 * s / H, 0.008 + 0.03 * fadeT);
                float ca = smoothstep(soft, -soft, dn);
                ca *= smoothstep(-0.085, -0.02, q.y);
                ca *= 1.0 - easeInOutQuad(remap01(t, 0.78, 0.99));
                ca *= edgeFade;

                if (ca > 0.0) {
                    // Smoke lighting: bump from the noise slope plus a rough form light.
                    float bump = clamp(0.5 + (n - n2) * 3.2, 0.0, 1.0);
                    float2 cr = (qq - float2(0.0, hc)) / rc;
                    float formCap = clamp(0.5 + 0.42 * dot(cr, L), 0.0, 1.0);
                    float formStem = clamp(0.5 - 0.4 * qq.x / 0.09, 0.1, 0.9)
                                   * (1.0 - 0.4 * smoothstep(hc - 0.32, hc - 0.04, qq.y));
                    float form = mix(formStem, formCap, capZone);
                    float lit = clamp(form * 0.6 + bump * 0.62 - 0.12, 0.0, 1.0)
                              * (0.6 + 0.4 * smoothstep(0.25, 0.6, n));
                    float3 smoke = mix(float3(0.085, 0.07, 0.065), float3(0.72, 0.64, 0.57), lit);
                    smoke += float3(0.50, 0.19, 0.04) * heat0 * (1.0 - lit) * 0.8;

                    // Fire: everything at first, then only deep in the creases.
                    float crease = smoothstep(0.58, 0.30, n);
                    float core = smoothstep(0.0, -0.12, sd);
                    float h = heat0 * heat0 * heat0 * 1.5 + crease * heat0 * (0.7 + 0.6 * core);
                    float3 fire = float3(clamp(h * 2.4, 0.0, 1.0),
                                         clamp(h * 1.7 - 0.38, 0.0, 1.0),
                                         clamp(h * 2.2 - 1.3, 0.0, 1.0));
                    float3 col = mix(smoke, fire, clamp(h * 1.6, 0.0, 1.0)) + fire * h * 0.4;
                    res = over(float4(col * ca, ca), res);
                }
            }
        }

        // Hot ejecta: one angular sector lookup, shared gravity undone up front.
        float tau = remap01(t, ti, 1.0);
        float ed = 1.0 - exp(-4.0 * tau);
        float2 pe = gd - float2(0.0, 0.30 * H * tau * tau);
        if (length(pe) < 1.6 * H) {
            const float N = 40.0;
            float base = floor((atan2(pe.y, pe.x) / TAU + 0.5) * N);
            float3 ember = float3(0.0);
            for (int di = -1; di <= 1; di++) {
                float idx = base + float(di);
                float wid = fmod(idx + N, N);
                for (int j = 0; j < 2; j++) {
                    float3 r = hash32(float2(wid * 1.618 + 0.5 + float(j) * 37.0, u.seed * 91.3 + 3.0));
                    float ang = ((idx + 0.15 + 0.7 * r.x) / N - 0.5) * TAU;
                    float2 dir = float2(cos(ang), sin(ang));
                    float speed = (0.30 + 1.05 * r.y * r.y) * (1.0 - 0.4 * dir.y) * H;
                    float2 pp = dir * speed * ed;
                    float tl = speed * 0.10 * exp(-4.0 * tau) + 1.0 * s;
                    float ds = sdSegment(pe, pp, pp - dir * tl);
                    float pr = (0.8 + 1.2 * r.z) * s;
                    float life = 1.0 - remap01(tau, 0.22 + 0.35 * r.z, 0.45 + 0.5 * r.z);
                    float tw = 0.7 + 0.3 * sin(u.time * 28.0 + r.x * 90.0);
                    float I = (smoothstep(pr * 1.6, 0.0, ds) + 0.35 * exp(-ds / (pr * 2.5))) * life * tw;
                    ember += mix(float3(1.0, 0.42, 0.08), float3(1.0, 0.88, 0.50), r.y) * I;
                }
            }
            ember *= smoothstep(0.0, 0.03, tau) * edgeFade;
            res.rgb += ember;
            res.a = clamp(res.a + luminance(ember) * 0.6, 0.0, 1.0);
        }
    }

    // ----------------------------------------------------------------- flash
    if (F > 0.0) {
        float fl = F * (1.25 * exp(-d / (0.75 * H)) + 0.9 * exp(-d / (0.16 * H)));
        fl += F * 0.8 * exp(-abs(gd.y) / (2.5 * s)) * exp(-abs(gd.x) / (1.1 * H));   // lens streak
        float fa = clamp(fl * edgeFade, 0.0, 1.0);
        res = over(float4(float3(1.0, 0.97, 0.90) * fa, fa), res);
    }

    // ------------------------------------------------------------------ bomb
    if (t < ti) {
        float bsz = clamp(min(W.x, W.y) * 0.03, 7.0 * s, 13.0 * s);
        float side = fract(u.seed * 3.71) < 0.5 ? -1.0 : 1.0;
        float2 P0 = float2(G.x + side * 0.20 * G.y, -5.0 * bsz);     // starts above the canvas
        float2 v = normalize(G - P0);
        float2 nose = mix(P0, G, fallK);
        float2 rel = p - (nose - v * 2.0 * bsz);
        float a = dot(rel, v);                                       // along the body, nose forward
        float bx = dot(rel, float2(-v.y, v.x));                      // across, lit side positive

        float body = (length(float2(a / (2.0 * bsz), bx / (0.95 * bsz))) - 1.0) * 0.95 * bsz;
        float tailc = sdBox(float2(a + 2.3 * bsz, bx), float2(0.8 * bsz, 0.34 * bsz));
        float fins = sdBox(float2(a + 3.0 * bsz, bx), float2(0.48 * bsz, 0.95 * bsz));
        float sdB = min(body, min(tailc, fins));
        float cov = 1.0 - smoothstep(-0.6 * s, 0.6 * s, sdB);

        float cyl = clamp(bx / (0.95 * bsz), -1.0, 1.0);
        float onBody = step(body, 0.0);
        float3 bc = float3(0.34, 0.38, 0.35) * (0.62 + 0.38 * cyl);
        float band = smoothstep(0.70 * bsz, 0.82 * bsz, a) * (1.0 - smoothstep(1.12 * bsz, 1.24 * bsz, a));
        bc = mix(bc, float3(0.96, 0.74, 0.10) * (0.70 + 0.30 * cyl), band * onBody);
        bc *= fins < min(body, tailc) ? 0.72 : 1.0;
        float sz = (cyl - 0.45) / 0.20;
        bc += exp(-sz * sz) * 0.42 * onBody;                         // specular stripe
        bc *= 0.55 + 0.45 * smoothstep(0.0, -1.6 * s, sdB);

        // Vapor trail behind the fins.
        float la = -(a + 3.5 * bsz);
        float trailL = max(length(nose - P0) * 0.6, 1.0);
        float fr = clamp(la / trailL, 0.0, 1.0);
        float wob = (noise(float2(la / (16.0 * s), u.seed * 9.0)) - 0.5) * 6.0 * s * fr;
        float tr = (1.0 - smoothstep(0.0, mix(1.4, 5.5, fr) * s, abs(bx + wob)))
                 * step(0.0, la) * (1.0 - fr) * 0.30;
        float halo = exp(-max(sdB, 0.0) / (3.0 * s)) * 0.22 * (1.0 - cov);

        float4 bl = premul(float3(1.0), tr);
        bl = over(premul(float3(0.0), halo), bl);
        bl = over(premul(bc, cov), bl);
        res = over(bl * smoothstep(0.0, 0.02, t), res);
    }

    return res * (1.0 - remap01(t, 0.95, 1.0));
}
