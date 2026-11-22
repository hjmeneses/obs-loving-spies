// Gun barrel: classic spy-film intro for OBS Studio
// (obs-shaderfilter plugin, "User-defined shader" mode).
//
// Full sequence (Progress 0 → 100):
//   0–24   A white dot (the size of the closed aperture) crosses the screen from left to
//          right, leaving fixed shadows that go out one after another.
//   24–32  When it touches the right edge it widens to the Aperture radius: the source shows
//          inside, the rifled barrel outside.
//   30–55  The barrel glides to the center, as if following the source.
//   32–60  The barrel spins and sways.
//   60–76  Blood drips down from the top and covers the screen.
//   76–88  The barrel drops and shakes; the aperture closes to a small circle with the source clean.
//   88–97  The circle opens to full screen. 97–100: source only.
//
// With "Loop playback" the sequence repeats on its own. To trigger it once with a hotkey,
// turn the loop off and use the intro-control.lua script, which drives Progress.
//
// If the source has transparency (for example, a camera with background removal), inside the
// aperture it shows over "Background inside the aperture" (white by default, as in the classic).

uniform bool auto_play<
    string label = "Loop playback (ignores Progress)";
> = true;

uniform float duration<
    string label = "Sequence duration (s)";
    string widget_type = "slider";
    float minimum = 3.0; float maximum = 30.0; float step = 0.5;
> = 10.0;

uniform float progress<
    string label = "Progress (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 45.0;

uniform float center_x<
    string label = "Center X (%) (where the barrel ends up)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float center_y<
    string label = "Center Y (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float aperture<
    string label = "Aperture radius (% of height)";
    string widget_type = "slider";
    float minimum = 5.0; float maximum = 45.0; float step = 0.1;
> = 17.0;

uniform float4 inner_bg<
    string label = "Background inside the aperture (source with transparency)";
> = {1.0, 1.0, 1.0, 1.0};

// One size for the opening dot and the closed aperture at the end
uniform float small_size<
    string label = "Dot and closed aperture size (% of radius)";
    string widget_type = "slider";
    float minimum = 10.0; float maximum = 100.0; float step = 1.0;
> = 40.0;

uniform bool show_dots<
    string label = "White dot at the start";
> = true;

uniform float dot_trail<
    string label = "Dot shadows";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 6.0; float step = 1.0;
> = 5.0;

uniform float grooves<
    string label = "Barrel grooves";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 16.0; float step = 1.0;
> = 6.0;

// How much the grooves twist toward the aperture. 0 = straight rays; ±1 = strong spiral.
uniform float twist<
    string label = "Groove twist";
    string widget_type = "slider";
    float minimum = -1.5; float maximum = 1.5; float step = 0.01;
> = 0.9;

uniform float spin<
    string label = "Barrel spin (degrees/s)";
    string widget_type = "slider";
    float minimum = -90.0; float maximum = 90.0; float step = 0.5;
> = 10.0;

// Contrast of the machining rings and how fast the barrel darkens outward.
uniform float depth<
    string label = "Depth";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.6;

uniform float4 metal_color<
    string label = "Metal color";
> = {0.62, 0.64, 0.68, 1.0};

uniform float wobble<
    string label = "Sway (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 1.0;
> = 18.0;

uniform bool show_blood<
    string label = "Blood";
> = true;

uniform float4 blood_color<
    string label = "Blood color";
> = {0.55, 0.0, 0.02, 1.0};

uniform float blood_opacity<
    string label = "Blood opacity";
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

uniform float blood_motion<
    string label = "Blood motion (0 = still)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 1.0;

uniform bool end_reveal<
    string label = "Open to full screen at the end (otherwise fade to black)";
> = true;

// Hash without sin(): sin() loses precision with large arguments and leaves visible patterns.
float hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float seg(float p, float a, float b)
{
    return saturate((p - a) / (b - a));
}

float ease(float t)
{
    return t * t * (3.0 - 2.0 * t);
}

// ---- Same section as in blood.shader ---------------------------------------------------------

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

// How much the grooves and the highlights twist relative to the "Twist" slider. The grooves
// combine depth (they tighten toward the aperture) with log r (they keep turning away from it).
#define TWIST_DARK  2.0
#define TWIST_LOG   0.8
#define TWIST_LIGHT 3.5
// Grooves: brightness (0 = black) and extra edge softness, as a fraction of a groove
#define GROOVE_DARK 0.18
#define GROOVE_SOFT 0.03
// How close the highlight gets to white (0 = same color as the metal, 1 = white)
#define SPEC_WHITE  0.6

// Inside of the barrel seen from the chamber: spiral grooves, machining rings and light coming
// in through the aperture (brighter next to it, dark toward the edge of the screen).
float3 barrelColor(float2 d, float r, float R, float t)
{
    float ang = atan2(d.y, d.x) * 0.15915494;       // in turns, -0.5..0.5
    float z = R / max(r, 1.0);                       // perspective depth: 1 at the aperture, ->0 outside
    float lr = log(max(r, 1.0) / max(R, 1.0));       // 0 at the aperture, grows outward (light falloff)
    float n = max(floor(grooves + 0.5), 1.0);
    float rot = spin * t / 360.0;

    // 1. Dark grooves: they turn with the barrel and coil. Depth z tightens the spiral toward
    //    the aperture, like a tube in perspective; log r (with the opposite sign, since it grows
    //    outward) keeps it turning away from it, where z barely changes.
    float g_dark = frac((ang + rot) * n + twist * (TWIST_DARK * z - TWIST_LOG * lr));
    float fw_d = min(fwidth(g_dark) * 1.5, 0.08) + GROOVE_SOFT;
    float groove = smoothstep(0.20 - fw_d, 0.20 + fw_d, g_dark)
                 * (1.0 - smoothstep(0.50 - fw_d, 0.50 + fw_d, g_dark));

    // 2. Specular highlight: turns with the barrel (same rot as the grooves, so it does not
    //    slide off the metal) and coils hard toward the aperture
    float g_light = frac((ang + rot) * n + twist * TWIST_LIGHT * z);
    float fw_l = min(fwidth(g_light) * 1.5, 0.08);
    float spec_band = smoothstep(0.42 - fw_l, 0.48 + fw_l, g_light)
                    * (1.0 - smoothstep(0.52 - fw_l, 0.58 + fw_l, g_light));

    // Fixed scene light: two opposite lobes, like the reflection inside a tube. No rot: the
    // light stays still and the barrel turns under it. Next to the aperture it evens out.
    float tube_lobe = 0.35 + 0.65 * pow(abs(cos((ang + twist * 0.25 * z) * 6.28318531)), 1.5);
    tube_lobe = lerp(tube_lobe, 1.0, z * z * z);

    // 3. Composition: the highlight goes over lands and grooves alike
    float base_metal = lerp(0.85, GROOVE_DARK, groove);  // bright land vs dark groove
    float light_curve = spec_band * 0.7;

    // Machined-metal texture along the grooves (±4 %)
    float brush = 0.96 + 0.08 * hash11(floor(g_dark * 96.0));

    // Turning rings evenly spaced in depth (closer together at the back) and light falloff
    float rings = 0.5 + 0.5 * cos(z * 56.5486678);   // 9 rings from the edge to the aperture
    float ring_shade = lerp(1.0, 0.88 + 0.12 * rings, depth);
    float fall = exp(-max(lr, 0.0) * lerp(0.5, 1.6, depth));

    float3 col = metal_color.rgb * (base_metal * tube_lobe * brush)
               + lerp(metal_color.rgb, float3(1.0, 1.0, 1.0), SPEC_WHITE) * light_curve;
    col *= ring_shade * fall;

    // Dither: avoids banding in dark gradients (8 bits + stream compression)
    col += (hash11(dot(floor(d), float2(1.0, 157.0))) - 0.5) / 255.0;

    float rim = exp(-max(r - R, 0.0) / max(R * 0.035, 1.0)) * 0.65;
    return col + rim;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 pos = uv * uv_size;
    float H = uv_size.y;
    float t = elapsed_time;
    float aa = 1.5;

    float p = auto_play ? frac(t / max(duration, 0.5)) : saturate(progress * 0.01);

    float pd = seg(p, 0.00, 0.24);   // dots
    float po = seg(p, 0.24, 0.32);   // opening
    float pb = seg(p, 0.60, 0.76);   // blood
    float pc = seg(p, 0.76, 0.88);   // closing
    float pr = seg(p, 0.88, 0.97);   // final reveal
    if (!show_dots) {
        pd = 1.0;
        po = 1.0;
    }

    float R0 = aperture * 0.01 * H;
    float Rs = R0 * small_size * 0.01;   // dot size = closed size
    float2 C0 = float2(center_x, center_y) * 0.01 * uv_size;
    // The aperture opens where the dot stopped (touching the right edge) and glides to the center
    float2 Copen = show_dots ? float2(uv_size.x - Rs, C0.y) : C0;
    float2 Ctrack = lerp(Copen, C0, ease(seg(p, 0.30, 0.55)));

    // Motion: sway while the barrel follows the source, drop and shake when closing
    float cl = ease(pc);
    float settle = 1.0 - pr;
    float2 wob = wobble * po * settle * float2(
        sin(t * 0.9) + 0.5 * sin(t * 2.3 + 1.0),
        0.6 * sin(t * 1.3 + 2.0) + 0.3 * sin(t * 3.1));
    float2 shake = cl * settle * 6.0 * float2(sin(t * 37.0), sin(t * 43.0 + 1.0));
    float2 C = Ctrack + wob + shake + float2(0.0, cl * H * 0.06);

    float R = lerp(lerp(Rs, R0, ease(po)), Rs, cl);
    if (end_reveal)
        R = lerp(R, length(uv_size) * 1.2, ease(pr) * pr);

    float2 d = pos - C;
    float r = length(d);
    float inside = 1.0 - smoothstep(R - aa, R + aa, r);

    float4 src = image.Sample(textureSampler, uv);
    float3 inner = lerp(inner_bg.rgb, src.rgb, src.a);

    // The white dot becomes a window; the barrel fades in from black and dims when closing
    float o = ease(po);
    float3 insideCol = lerp(float3(1.0, 1.0, 1.0), inner, o);
    float3 outside = barrelColor(d, r, R, t) * o * lerp(1.0, 0.25, cl) * settle;
    float3 col = lerp(outside, insideCol, inside);

    // Blood: covers everything; inside the aperture it pulls back when closing so the final
    // window is clean, and outside it fades during the final reveal
    if (show_blood && pb > 0.0) {
        float cell = max(drip_width * 0.01 * H, 4.0);
        float e = bloodField(pos, pb, H, cell, drip_length * 0.01 * H, 3.7, t, blood_motion);
        float m = saturate(e / 1.5 + 0.5);
        float a = blood_opacity * m * lerp(1.0, 1.0 - cl, inside) * settle;
        col = lerp(col, blendBlood(col, bloodShade(e, pos, t, blood_motion, cell), blend_mode), a);
    }

    // White dot on black: enters from the left at constant speed. Once fully inside it leaves a
    // fixed shadow identical to itself; each shadow goes out in 50 ms when the dot leaves the
    // next one, and the last one when it touches the right edge, where it widens and opens.
    if (show_dots && po < 1.0) {
        float W = uv_size.x;
        float tp = p / 0.24;                              // dot progress, unclamped
        float fade = 0.05 / max(duration * 0.24, 0.01);   // 50 ms in tp units
        float n = floor(dot_trail + 0.5);
        float span = W - 2.0 * Rs;
        float dots = 0.0;
        if (po <= 0.0) {
            float x = lerp(-Rs, W - Rs, saturate(tp));
            dots = 1.0 - smoothstep(Rs - aa, Rs + aa, length(pos - float2(x, C0.y)));
        }
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            if (fi < n) {
                float sx = Rs + span * fi / n;
                float t_on = (sx + Rs) / W;                       // when it is left
                float t_off = (Rs + span * (fi + 1.0) / n + Rs) / W; // when the next one is left
                float b = step(t_on, tp) * (1.0 - saturate((tp - t_off) / fade));
                float dd = length(pos - float2(sx, C0.y));
                dots = max(dots, b * (1.0 - smoothstep(Rs - aa, Rs + aa, dd)));
            }
        }
        col = (po <= 0.0) ? float3(dots, dots, dots) : lerp(col, float3(1.0, 1.0, 1.0), dots);
    }

    if (!end_reveal)
        col *= 1.0 - pr;

    return float4(col, 1.0);
}
