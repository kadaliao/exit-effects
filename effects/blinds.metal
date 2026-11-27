// @name Blinds
// @name.zh 百叶窗
// @author Kada Liao
// @description The window turns into slats that flip shut one after another, top to bottom.
// @description.zh 窗口变成一排百叶，从上到下依次翻转合上。
// @duration 0.75
// @padding 24
// @events close, quit, minimize

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    float2 W = windowSize(u);
    float2 q = p - u.win.xy;
    if (q.x < 0.0 || q.x > W.x || q.y < 0.0 || q.y > W.y) return float4(0);

    // About 34 pt per slat, at least six of them.
    float count = max(6.0, floor(W.y / (34.0 * u.scale)));
    float h = W.y / count;
    float i = min(floor(q.y / h), count - 1.0);
    float cy = (i + 0.5) * h;

    // Each slat turns a quarter turn; later slats start later.
    float lag = 0.45;
    float start = lag * i / max(count - 1.0, 1.0);
    float k = easeInOutCubic(remap01(t, start, start + 1.0 - lag));
    float c = cos(k * PI * 0.5);
    if (c < 0.002) return float4(0);

    // Inverse map: a slat seen at angle k shows its full height squeezed into h * c.
    float dy = q.y - cy;
    if (abs(dy) > 0.5 * h * c) return float4(0);
    float2 src = float2(p.x, u.win.y + cy + dy / c);
    float4 col = sampleWindowSharp(tex, u, src);

    // Turning away from the light: darker as it closes, a bright lip on the leading edge.
    float side = dy / max(0.5 * h * c, 1e-3);           // -1 top edge .. 1 bottom edge
    float shade = mix(1.0, 0.55, k) * (1.0 - 0.18 * k * side);
    float lip = smoothstep(0.75, 1.0, -side) * sin(k * PI) * 0.35;
    float3 rgb = col.rgb * shade + lip * col.a;
    float fade = 1.0 - smoothstep(0.85, 1.0, t);
    return float4(rgb, col.a) * fade;
}
