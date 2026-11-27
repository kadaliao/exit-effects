// @name Fall
// @name.zh 坠落
// @author Kada Liao
// @description The window tips over the side you clicked and drops out of sight.
// @description.zh 窗口朝你点击的一侧翻倒，然后掉出视野。
// @duration 0.8
// @padding 360
// @events close, quit, minimize

float4 effect(float2 p, constant Exit& u, texture2d<float> tex) {
    float t = u.progress;
    float s = u.scale;
    float2 W = windowSize(u);
    float2 c = windowCenter(u);

    // Tip toward the side of the window that was clicked (the close button: left).
    float side = u.cursor.x > c.x ? 1.0 : -1.0;
    float a = side * 0.55 * easeInQuad(t);
    float drop = easeInQuad(t) * (W.y * 0.9 + 360.0 * s);
    float drift = side * easeInQuad(t) * 60.0 * s;

    // Inverse map: undo the move, then the rotation about the window's center.
    float2 q = p - c - float2(drift, drop);
    float2 src = c + rot(-a) * q;
    float4 col = sampleWindow(tex, u, src);

    float fade = 1.0 - smoothstep(0.7, 1.0, t);
    float shade = 1.0 - 0.15 * t;
    // Soften the canvas edge once it's moving: a window at the screen edge must start intact.
    float edge = mix(1.0, canvasEdgeFade(u, p, 40.0 * s), smoothstep(0.0, 0.2, t));
    return float4(col.rgb * shade, col.a) * fade * edge;
}
