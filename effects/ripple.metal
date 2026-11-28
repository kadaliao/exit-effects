// @name Ripple
// @name.zh 涟漪
// @author Kada Liao
// @description A ripple spreads from where you clicked and washes the window away.
// @description.zh 涟漪从点击处荡开，把窗口一圈圈冲散。
// @duration 0.9
// @padding 40
// @events close, quit, minimize

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    float s = u.scale;
    float2 W = windowSize(u);

    // Start at the click when it's on the window, else at the center.
    float2 o = u.cursor;
    if (o.x < u.win.x || o.y < u.win.y || o.x > u.win.x + W.x || o.y > u.win.y + W.y) o = windowCenter(u);
    float2 far = max(abs(u.win.xy - o), abs(u.win.xy + W - o));
    float reach = length(far);

    float2 d = p - o;
    float r = length(d);
    float2 dir = r > 0.0 ? d / r : float2(0);

    float band = 150.0 * s;                              // width of the fading wake
    float R = easeInQuad(t) * (reach + band * 1.3);     // the wave front
    float behind = R - r;                               // > 0 once the front has passed
    if (behind > band) return float4(0);

    // Rings behind the front push the picture outward and in, dying off with distance.
    float k = TAU / (30.0 * s);
    float env = smoothstep(-10.0 * s, 6.0 * s, behind) * exp(-max(behind, 0.0) / (band * 0.6));
    float wave = sin(behind * k) * env;
    float amp = 16.0 * s * sin(PI * min(t * 1.6, 1.0));
    float4 col = sampleWindow(tex, u, p - dir * wave * amp);

    float fade = 1.0 - smoothstep(0.15 * band, band, behind);
    float crest = max(wave, 0.0) * env * 0.22 * col.a;
    return float4(col.rgb * fade + crest * fade, col.a * fade);
}
