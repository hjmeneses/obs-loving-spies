// Títulos con siluetas: fondo de tinta líquida psicodélica con la fuente convertida en
// silueta, estilo secuencia de créditos de películas clásicas de espías, para OBS Studio
// (plugin obs-shaderfilter, modo "User-defined shader").
//
// La silueta sale de la transparencia de la fuente (ideal: cámara con quitado de fondo,
// chroma key o un PNG). Si la fuente no tiene transparencia, activa "Silueta por brillo".

uniform bool use_luma<
    string label = "Silueta por brillo (fuente sin transparencia)";
> = false;

uniform float luma_threshold<
    string label = "Umbral de brillo";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.5;

uniform bool luma_invert<
    string label = "Invertir silueta (lo oscuro es la figura)";
> = false;

uniform float4 color_dark = {0.02, 0.02, 0.05, 1.0};
uniform float4 color_gold = {0.85, 0.62, 0.20, 1.0};
uniform float4 color_red = {0.60, 0.02, 0.05, 1.0};

uniform float pattern_scale<
    string label = "Escala del fondo";
    string widget_type = "slider";
    float minimum = 0.3; float maximum = 6.0; float step = 0.05;
> = 1.6;

uniform float flow_speed<
    string label = "Velocidad del fondo";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 2.0; float step = 0.01;
> = 0.3;

// 0 = sin caleidoscopio; 2 o más = número de gajos espejados alrededor del centro.
uniform float kaleido<
    string label = "Caleidoscopio (gajos, 0 = apagado)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 16.0; float step = 1.0;
> = 0.0;

uniform float kaleido_spin<
    string label = "Giro del caleidoscopio (grados/s)";
    string widget_type = "slider";
    float minimum = -60.0; float maximum = 60.0; float step = 0.5;
> = 6.0;

uniform float4 silhouette_color = {0.0, 0.0, 0.0, 1.0};

// 0 = silueta de color sólido; 1 = la silueta muestra el fondo en negativo (rojo↔dorado).
uniform float silhouette_pattern<
    string label = "Relleno de silueta: solido / patron";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.0;

uniform float4 glow_color = {1.0, 0.75, 0.3, 1.0};

uniform float glow_strength<
    string label = "Resplandor del contorno";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 2.0; float step = 0.01;
> = 0.8;

uniform float glow_size<
    string label = "Ancho del resplandor (px)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 60.0; float step = 0.5;
> = 14.0;

uniform float source_mix<
    string label = "Mezcla con la fuente original";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.0;

float hash12(float2 p)
{
    float3 p3 = frac(float3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float vnoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + float2(1.0, 0.0));
    float c = hash12(i + float2(0.0, 1.0));
    float d = hash12(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
}

float fbm(float2 p)
{
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        s += a * vnoise(p);
        p = p * 2.03 + float2(1.7, 9.2);
        a *= 0.5;
    }
    return s;
}

// Tinta líquida: ruido deformado dos veces por sí mismo (domain warping), que da remolinos
// como de pintura en agua. Devuelve el color y, en w, la intensidad del remolino.
float4 inkColor(float2 p, float t)
{
    float2 q = float2(fbm(p + float2(0.0, t * 0.10)),
                      fbm(p + float2(5.2, 1.3) - t * 0.08));
    float2 r = float2(fbm(p + 4.0 * q + float2(1.7, 9.2) + t * 0.15),
                      fbm(p + 4.0 * q + float2(8.3, 2.8) - t * 0.12));
    float v = fbm(p + 4.0 * r);

    float3 col = lerp(color_dark.rgb, color_red.rgb, saturate(v * 2.2 - 0.45));
    col = lerp(col, color_gold.rgb, saturate(length(q) * 1.4 - 0.55) * saturate(r.x * 1.6 - 0.2));
    col *= 0.6 + 0.6 * v;
    return float4(col, v);
}

float silMask(float2 uv)
{
    float4 s = image.Sample(textureSampler, uv);
    if (!use_luma)
        return s.a;
    float l = dot(s.rgb, float3(0.2126, 0.7152, 0.0722));
    float m = smoothstep(luma_threshold - 0.05, luma_threshold + 0.05, l);
    return luma_invert ? 1.0 - m : m;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float t = elapsed_time * flow_speed;
    float aspect = uv_size.x / uv_size.y;

    // Coordenadas centradas con proporción correcta, opcionalmente plegadas en caleidoscopio
    float2 k = (uv - 0.5) * float2(aspect, 1.0);
    float segs = floor(kaleido + 0.5);
    if (segs >= 2.0) {
        float ang = atan2(k.y, k.x) + radians(kaleido_spin) * elapsed_time;
        float rad = length(k);
        float w = 6.2831853 / segs;
        ang = ang - w * floor(ang / w);
        ang = abs(ang - w * 0.5);
        k = rad * float2(cos(ang), sin(ang));
    }
    float4 ink = inkColor(k * pattern_scale + 10.0, t);

    float4 src = image.Sample(textureSampler, uv);
    float m = silMask(uv);

    // Resplandor exterior: máscara promediada en dos anillos, solo fuera de la figura
    float blurred = 0.0;
    float fi = 0.0;
    for (int i = 0; i < 12; i++) {
        float a = fi * 0.5235988;
        float rr = (fmod(fi, 2.0) < 0.5) ? 0.5 : 1.0;
        float2 o = float2(cos(a), sin(a)) * glow_size * rr * uv_pixel_interval;
        blurred += silMask(uv + o);
        fi += 1.0;
    }
    blurred /= 12.0;
    float glow = blurred * (1.0 - m) * glow_strength;

    // Negativo del fondo para el relleno con patrón: intercambia rojo y dorado
    float3 neg = lerp(color_gold.rgb, color_red.rgb, saturate(ink.w * 2.2 - 0.45)) * (0.5 + 0.7 * ink.w);
    float3 fill = lerp(silhouette_color.rgb, neg, silhouette_pattern);

    float3 col = lerp(ink.rgb, fill, m);
    col += glow_color.rgb * glow;
    col = lerp(col, src.rgb, source_mix * src.a);
    return float4(col, 1.0);
}
