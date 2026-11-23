// Dripping blood: transition in the style of classic spy-film intros for OBS Studio
// (obs-shaderfilter plugin, "User-defined shader" mode).
//
// Blood runs down from the top in drips that each grow at their own pace, with a drop at the
// tip, a rippling edge and drops that break off, until it covers the source. With
// "Drain at the end" the curtain keeps going down and leaves through the bottom, leaving the
// source clean. Works looping or with the Progress slider (or with intro-control.lua and a hotkey).

uniform bool auto_play<
    string label = "Loop playback (ignores Progress)";
> = true;

uniform float duration<
    string label = "Duration (s)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 20.0; float step = 0.5;
> = 4.0;

uniform float progress<
    string label = "Progress (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float4 blood_color<
    string label = "Blood color";
> = {0.55, 0.0, 0.02, 1.0};

uniform float blood_opacity<
    string label = "Opacity";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

uniform int blend_mode<
    string label = "Blood blend mode";
    string widget_type = "select";
    int    option_0_value = 0; string option_0_label = "Normal";
    int    option_1_value = 1; string option_1_label = "Multiply";
    int    option_2_value = 2; string option_2_label = "Darken";
    int    option_3_value = 3; string option_3_label = "Color burn";
    int    option_4_value = 4; string option_4_label = "Overlay";
    int    option_5_value = 5; string option_5_label = "Soft light";
    int    option_6_value = 6; string option_6_label = "Hard light";
    int    option_7_value = 7; string option_7_label = "Color";
    int    option_8_value = 8; string option_8_label = "Screen";
> = 0;

uniform float drip_length<
    string label = "Drip length (% of height)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 0.5;
> = 35.0;

uniform float drip_width<
    string label = "Drip width (% of height)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 20.0; float step = 0.1;
> = 5.5;

uniform float seed<
    string label = "Variation (seed)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 1.0;
> = 3.0;

uniform bool drain<
    string label = "Drain at the end (the blood leaves through the bottom)";
> = false;

uniform float motion<
    string label = "Motion (0 = still; ripples, drips and crawls)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 1.0;

uniform float flow_angle<
    string label = "Direction (0 = falls, 90 = to the right, 180 = rises, 270 = to the left)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 360.0; float step = 1.0;
> = 0.0;

float hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

// ---- Same section as in gun-barrel.shader ----------------------------------------------------

// Smooth union of two distances (<0 inside): blends drip, drop and curtain like a liquid
float smin(float a, float b, float k)
{
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// Vertical capsule with radius r1 at the top and r2 at the bottom, axis of length h toward +y
float unevenCapsule(float2 p, float r1, float r2, float h)
{
    p.x = abs(p.x);
    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float k = dot(p, float2(-b, a));
    if (k < 0.0) return length(p) - r1;
    if (k > a * h) return length(p - float2(0.0, h)) - r2;
    return dot(p, float2(a, b)) - r1;
}

// Distance in px into the blood (>0 inside). level 0 = nothing, 1 = covers everything.
// Each cell has one drip: a neck that thins out and a fat drop at the tip. Each one starts at
// its own time and accelerates as if under gravity, so some get ahead of others. With t (real
// time) the edge ripples, the tips crawl and some drops break off and fall.
float bloodField(float2 pos, float level, float H, float cell, float drip_len, float sd, float t, float mv)
{
    float x = pos.x;
    // Off-screen margin: the edge ripples up to 0.535 cells + 6 % of the drip length and the tip
    // drop is up to 0.175 cells, so with level 0 nothing shows and with level 1 it covers the
    // last pixel.
    float mg = cell * 0.8 + drip_len * 0.06 + 4.0;
    float front = lerp(-drip_len - mg, H + mg, level);
    front += sin(x * 0.006 + sd * 1.7) * (cell * 0.3 + drip_len * 0.06)
           + sin(x * 0.013 + sd) * cell * 0.15
           + sin(x * 0.031 + sd * 2.0 + t * 1.1 * mv) * cell * (0.03 + 0.03 * mv)
           + sin(x * 0.071 - t * 1.9 + sd) * cell * 0.025 * mv;
    float d = pos.y - front;

    float ci = floor(x / cell);
    float kf = -1.0;
    for (int k = 0; k < 3; k++) {
        float c = ci + kf;
        float h1 = hash11(c * 1.37 + sd);
        float h2 = hash11(c * 7.91 + sd + 11.0);
        float h3 = hash11(c * 3.17 + sd + 27.0);
        float h4 = hash11(c * 5.53 + sd + 41.0);
        float h5 = hash11(c * 2.29 + sd + 63.0);
        float hw = cell * (0.18 + 0.32 * h2);
        float cx = (c + 0.2 + 0.6 * h1) * cell + sin(t * (0.5 + h4) + h1 * 6.28) * hw * 0.12 * mv;

        float g = saturate((level - h4 * 0.3) / (0.3 + 0.4 * h5));
        float ext = drip_len * h3 * h3 * g * g
                  + (0.5 + 0.5 * sin(t * (0.6 + 0.8 * h5) + h2 * 6.28)) * hw * 0.6 * g * mv;
        float rb = hw * lerp(0.35, 0.62, g);
        float tip = front + max(ext - rb, 0.0);
        float top = front - hw;
        float nk = max(rb * 0.75, cell * 0.08);               // neck: never a thin rod
        float len = max(tip - top, hw - nk + 1.0);

        float dc = unevenCapsule(float2(x - cx, pos.y - top), hw, nk, len);
        dc = smin(dc, length(float2(x - cx, pos.y - tip)) - rb, rb * 0.6);
        d = smin(d, dc, cell * 0.12);

        // Drop that breaks off the tip and falls, accelerating
        if (mv > 0.01 && h5 > 0.5 && g > 0.85) {
            float tau = frac(t * mv * (0.3 + 0.35 * h4) + h1);
            float dy = rb + tau * tau * H * 0.7;
            float rr = rb * 0.6 * smoothstep(0.0, 0.12, tau);
            d = min(d, length(float2(x - cx, (pos.y - tip - dy) * 0.75)) - rr);
        }
        kf += 1.0;
    }
    return -d;
}

// Value noise without sin() (see hash11)
float hash21(float2 p)
{
    float3 p3 = frac(float3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float vnoise(float2 p)
{
    float2 i = floor(p);
    float2 f = p - i;
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
}

// Relief of the blood layer (0–1, high = thicker): noise stretched vertically that moves down
// over time and meanders a little, like liquid running. No fixed period, so it does not look
// like fabric.
float bloodHeight(float2 pos, float t, float mv, float cell)
{
    float y = pos.y - t * mv * cell * 0.9;
    float x = pos.x + cell * 1.2 * (vnoise(float2(pos.x, y) / (cell * 6.0)) - 0.5);
    float2 q = float2(x / (cell * 1.3), y / (cell * 7.0));
    return 0.6 * vnoise(q) + 0.3 * vnoise(q * 2.03 + float2(17.0, 5.0))
         + 0.1 * vnoise(q * 4.1 + float2(41.0, 23.0));
}

// Color from e (px inward): dark edge, a wet highlight that follows the shape of each drip
// (light from the top left) and, inside, a layer of uneven thickness: darker where it is thick
// and with soft highlights where the relief faces the light.
float3 bloodShade(float e, float2 pos, float t, float mv, float cell)
{
    float deep = smoothstep(4.0, 24.0, e);                    // the relief shows away from the edge
    float h = bloodHeight(pos, t, mv, cell);
    float hx = bloodHeight(pos + float2(1.0, 0.0), t, mv, cell) - h;
    float hy = bloodHeight(pos + float2(0.0, 1.0), t, mv, cell) - h;

    float3 c = blood_color.rgb * lerp(0.55, 1.0, smoothstep(0.0, 5.0, e))
             * lerp(1.0, lerp(1.06, 0.8, h), deep);

    float k = cell * deep;
    float3 nrm = normalize(float3(-hx * k, -hy * k, 1.0));
    float3 hv = normalize(normalize(float3(-0.35, -0.6, 0.72)) + float3(0.0, 0.0, 1.0));
    c += pow(saturate(dot(nrm, hv)), 24.0) * 0.15 * deep * float3(1.0, 0.8, 0.8);

    float2 gr = float2(ddx(e), ddy(e));
    float2 n = -gr / max(length(gr), 1e-4);
    float spec = pow(saturate(dot(n, float2(-0.6, -0.8))), 6.0);
    float band = smoothstep(1.0, 3.0, e) * (1.0 - smoothstep(4.0, 10.0, e));
    c += band * (0.06 + 0.4 * spec) * float3(1.0, 0.75, 0.75);
    return c;
}

// Blend modes (Photoshop / W3C formulas): b = what is underneath, s = the blood
float lum(float3 c)
{
    return dot(c, float3(0.3, 0.59, 0.11));
}

float3 softLightD(float3 b)
{
    float3 poly = ((16.0 * b - 12.0) * b + 4.0) * b;
    return lerp(poly, sqrt(b), step(0.25, b));
}

float3 blendBlood(float3 b, float3 s, int mode)
{
    b = saturate(b);
    s = saturate(s);
    if (mode == 1) return b * s;                                        // Multiply
    if (mode == 2) return min(b, s);                                    // Darken
    if (mode == 8) return 1.0 - (1.0 - b) * (1.0 - s);                  // Screen
    if (mode == 3) return 1.0 - min((1.0 - b) / max(s, 0.001), 1.0);   // Color burn
    if (mode == 4)                                                      // Overlay
        return lerp(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b));
    if (mode == 5)                                                      // Soft light
        return lerp(b - (1.0 - 2.0 * s) * b * (1.0 - b),
                    b + (2.0 * s - 1.0) * (softLightD(b) - b), step(0.5, s));
    if (mode == 6)                                                      // Hard light
        return lerp(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, s));
    if (mode == 7) {                                                    // Color
        float3 c = s + (lum(b) - lum(s));
        float l = lum(c);
        float n = min(min(c.r, c.g), c.b);
        float x = max(max(c.r, c.g), c.b);
        if (n < 0.0) c = l + (c - l) * l / max(l - n, 1e-4);
        if (x > 1.0) c = l + (c - l) * (1.0 - l) / max(x - l, 1e-4);
        return c;
    }
    return s;                                                           // Normal
}

// ---------------------------------------------------------------------------------------------

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    // Liquid space: the screen is rotated so the flow always goes towards +y; F is the rotated
    // box that contains it, so at level 1 it covers up to the corners at any angle.
    float fa = radians(flow_angle);
    float ca = cos(fa);
    float sa = sin(fa);
    float2 S = uv_size;
    float2 F = float2(abs(S.x * ca) + abs(S.y * sa), abs(S.x * sa) + abs(S.y * ca));
    float2 dp = uv * S - S * 0.5;
    float2 pos = float2(ca * dp.x - sa * dp.y, sa * dp.x + ca * dp.y) + F * 0.5;
    float H = F.y;
    float t = elapsed_time;
    float4 src = image.Sample(textureSampler, uv);

    float p = auto_play ? frac(t / max(duration, 0.5)) : saturate(progress * 0.01);
    float cell = max(drip_width * 0.01 * S.y, 4.0);
    float dl = drip_length * 0.01 * H;

    // Without draining: 0–90% comes down, 90–100% covered. Draining: 0–50% comes down, 50–100%
    // the top edge (with its own drip pattern) comes down behind it and reveals the source.
    float fill = drain ? saturate(p * 2.0) : saturate(p / 0.9);
    float e = bloodField(pos, fill, H, cell, dl, seed, t, motion);
    float m = saturate(e / 1.5 + 0.5);
    if (drain) {
        float tail = saturate(p * 2.0 - 1.0);
        float et = bloodField(pos, tail, H, cell, dl, seed + 41.0, t, motion);
        m *= 1.0 - saturate(et / 1.5 + 0.5);
        e = min(e, -et);
    }

    float3 bc = blendBlood(src.rgb, bloodShade(e, pos, t, motion, cell), blend_mode);
    float a = m * blood_opacity;
    // "Over" compositing: the blood (alpha a) on top of the source (alpha src.a)
    float oa = a + src.a * (1.0 - a);
    float3 rgb = (bc * a + src.rgb * src.a * (1.0 - a)) / max(oa, 1e-4);
    return float4(rgb, oa);
}
