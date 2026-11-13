// Sangre que escurre: transición estilo intro de películas clásicas de espías para OBS Studio
// (plugin obs-shaderfilter, modo "User-defined shader").
//
// La sangre baja desde arriba en chorros que crecen cada uno a su ritmo, con gota en la punta,
// orilla que ondula y gotas que se desprenden, hasta cubrir la fuente. Con
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

uniform float motion<
    string label = "Movimiento (0 = quieta; ondula, gotea y se arrastra)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 1.0;

float hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

// ---- Misma sección que en canon.shader -------------------------------------------------------

// Unión suave de dos distancias (<0 adentro): funde chorro, gota y cortina como líquido
float smin(float a, float b, float k)
{
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// Cápsula vertical de radio r1 arriba y r2 abajo, con el eje de largo h hacia +y
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

// Distancia en px hacia adentro de la sangre (>0 adentro). level 0 = nada, 1 = cubre todo.
// Cada celda tiene un chorro: cuello que se adelgaza y una gota gorda en la punta. Cada uno
// arranca a su tiempo y acelera como con gravedad, así que unos se adelantan a otros. Con t
// (tiempo real) la orilla ondula, las puntas se arrastran y algunas gotas se desprenden y caen.
float bloodField(float2 pos, float level, float H, float cell, float drip_len, float sd, float t, float mv)
{
    float x = pos.x;
    float front = lerp(-drip_len - 4.0, H + 4.0, level);
    front += sin(x * 0.013 + sd) * cell * 0.15
           + sin(x * 0.031 + sd * 2.0 + t * 1.1) * cell * (0.03 + 0.03 * mv)
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
        float len = max(tip - top, hw - rb * 0.6 + 1.0);

        float dc = unevenCapsule(float2(x - cx, pos.y - top), hw, rb * 0.6, len);
        dc = smin(dc, length(float2(x - cx, pos.y - tip)) - rb, rb * 0.6);
        d = smin(d, dc, cell * 0.12);

        // Gota que se desprende de la punta y cae acelerando
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

// Color según e (px hacia adentro): orilla oscura, brillo húmedo que sigue la forma de cada
// chorro (luz desde arriba a la izquierda) y vetas que fluyen hacia abajo por dentro.
float3 bloodShade(float e, float2 pos, float t, float mv)
{
    float3 c = blood_color.rgb * lerp(0.55, 1.0, smoothstep(0.0, 5.0, e));

    float flow = 0.5 + 0.5 * sin(pos.x * 0.09 + 2.0 * sin(pos.y * 0.012 - t * 0.9 * mv + pos.x * 0.01));
    c *= lerp(1.0, lerp(0.82, 1.08, flow), smoothstep(6.0, 20.0, e));

    float2 gr = float2(ddx(e), ddy(e));
    float2 n = -gr / max(length(gr), 1e-4);
    float spec = pow(saturate(dot(n, float2(-0.6, -0.8))), 6.0);
    float band = smoothstep(1.0, 3.0, e) * (1.0 - smoothstep(4.0, 10.0, e));
    c += band * (0.06 + 0.4 * spec) * float3(1.0, 0.75, 0.75);
    return c;
}

// ---------------------------------------------------------------------------------------------

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 pos = uv * uv_size;
    float H = uv_size.y;
    float t = elapsed_time;
    float4 src = image.Sample(textureSampler, uv);

    float p = auto_play ? frac(t / max(duration, 0.5)) : saturate(progress * 0.01);
    float cell = max(drip_width * 0.01 * H, 4.0);
    float dl = drip_length * 0.01 * H;

    // Sin escurrir: 0–90% baja, 90–100% cubierta. Escurriendo: 0–50% baja, 50–100% la orilla
    // superior (con su propio dibujo de chorros) baja detrás y deja ver la fuente.
    float fill = drain ? saturate(p * 2.0) : saturate(p / 0.9);
    float e = bloodField(pos, fill, H, cell, dl, seed, t, motion);
    float m = saturate(e / 1.5 + 0.5);
    if (drain) {
        float tail = saturate(p * 2.0 - 1.0);
        float et = bloodField(pos, tail, H, cell, dl, seed + 41.0, t, motion);
        m *= 1.0 - saturate(et / 1.5 + 0.5);
        e = min(e, -et);
    }

    float3 bc = bloodShade(e, pos, t, motion);
    float a = m * blood_opacity;
    return float4(lerp(src.rgb, bc, a), max(src.a, a));
}
