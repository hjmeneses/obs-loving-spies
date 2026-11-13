// Sangre que escurre: transición estilo intro de películas clásicas de espías para OBS Studio
// (plugin obs-shaderfilter, modo "User-defined shader").
//
// La sangre baja desde arriba en chorros de largo irregular hasta cubrir la fuente. Con
// "Escurrir al final" la cortina sigue bajando y sale por abajo, dejando la fuente limpia.
// Funciona en bucle o con el slider Progreso (o con intro-control.lua y un hotkey).

uniform bool auto_play<
    string label = "Reproducir en bucle (ignora Progreso)";
> = true;

uniform float duration<
    string label = "Duracion (s)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 20.0; float step = 0.5;
> = 4.0;

uniform float progress<
    string label = "Progreso (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float4 blood_color = {0.55, 0.0, 0.02, 1.0};

uniform float blood_opacity<
    string label = "Opacidad";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.9;

uniform float drip_length<
    string label = "Largo de los chorros (% del alto)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 0.5;
> = 35.0;

uniform float drip_width<
    string label = "Ancho de los chorros (% del alto)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 20.0; float step = 0.1;
> = 5.5;

uniform float seed<
    string label = "Variacion (semilla)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 1.0;
> = 3.0;

uniform bool drain<
    string label = "Escurrir al final (la sangre sale por abajo)";
> = false;

float hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

// Misma función que en canon.shader: borde inferior de la sangre en la columna x.
float bloodFront(float x, float level, float H, float cell, float drip_len, float sd)
{
    float front = lerp(-drip_len - 4.0, H + 4.0, level);
    front += sin(x * 0.013 + sd) * cell * 0.15 + sin(x * 0.031 + sd * 2.0) * cell * 0.08;

    float ci = floor(x / cell);
    float best = 0.0;
    float kf = -1.0;
    for (int k = 0; k < 3; k++) {
        float c = ci + kf;
        float h1 = hash11(c * 1.37 + sd);
        float h2 = hash11(c * 7.91 + sd + 11.0);
        float h3 = hash11(c * 3.17 + sd + 27.0);
        float cx = (c + 0.2 + 0.6 * h1) * cell;
        float hw = cell * (0.18 + 0.32 * h2);
        float u = (x - cx) / hw;
        best = max(best, drip_len * h3 * h3 * sqrt(saturate(1.0 - u * u)));
        kf += 1.0;
    }
    return front + best;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 pos = uv * uv_size;
    float H = uv_size.y;
    float4 src = image.Sample(textureSampler, uv);

    float p = auto_play ? frac(elapsed_time / max(duration, 0.5)) : saturate(progress * 0.01);
    float cell = max(drip_width * 0.01 * H, 4.0);
    float dl = drip_length * 0.01 * H;

    // Sin escurrir: 0–90% baja, 90–100% cubierta. Escurriendo: 0–50% baja, 50–100% la orilla
    // superior (con su propio dibujo de chorros) baja detrás y deja ver la fuente.
    float fill = drain ? saturate(p * 2.0) : saturate(p / 0.9);
    float e = bloodFront(pos.x, fill, H, cell, dl, seed) - pos.y;
    float m = saturate(e / 1.5 + 0.5);
    if (drain) {
        float tail = saturate(p * 2.0 - 1.0);
        float et = bloodFront(pos.x, tail, H, cell, dl, seed + 41.0) - pos.y;
        m *= 1.0 - saturate(et / 1.5 + 0.5);
        e = min(e, -et);
    }

    float3 bc = blood_color.rgb * lerp(0.55, 1.0, smoothstep(0.0, 5.0, e));
    bc += smoothstep(3.0, 7.0, e) * (1.0 - smoothstep(9.0, 15.0, e)) * 0.12;

    float a = m * blood_opacity;
    return float4(lerp(src.rgb, bc, a), max(src.a, a));
}
