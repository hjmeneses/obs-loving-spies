// Cañón de pistola: intro estilo películas clásicas de espías para OBS Studio
// (plugin obs-shaderfilter, modo "User-defined shader").
//
// Secuencia completa (Progreso 0 → 100):
//   0–24   Puntos blancos aparecen uno tras otro sobre negro, de izquierda a derecha.
//   24–32  El último punto se abre: adentro aparece la fuente, afuera el cañón estriado.
//   32–60  El cañón gira y se bambolea siguiendo a la fuente.
//   60–76  Escurre sangre desde arriba y cubre la pantalla.
//   76–88  El cañón cae y tiembla; la boca se cierra a un círculo chico con la fuente limpia.
//   88–97  El círculo se abre a pantalla completa. 97–100: fuente sola.
//
// Con "Reproducir en bucle" la secuencia se repite sola. Para dispararla una vez con un
// hotkey, desactiva el bucle y usa el script intro-control.lua, que mueve el Progreso.
//
// Si la fuente tiene transparencia (por ejemplo, una cámara con quitado de fondo), dentro de
// la boca se ve sobre "Fondo dentro de la boca" (blanco por defecto, como en el clásico).

uniform bool auto_play<
    string label = "Reproducir en bucle (ignora Progreso)";
> = true;

uniform float duration<
    string label = "Duracion de la secuencia (s)";
    string widget_type = "slider";
    float minimum = 3.0; float maximum = 30.0; float step = 0.5;
> = 10.0;

uniform float progress<
    string label = "Progreso (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 45.0;

uniform float center_x<
    string label = "Centro X (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float center_y<
    string label = "Centro Y (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float aperture<
    string label = "Radio de la boca (% del alto)";
    string widget_type = "slider";
    float minimum = 5.0; float maximum = 45.0; float step = 0.1;
> = 17.0;

uniform float4 inner_bg = {1.0, 1.0, 1.0, 1.0};

uniform bool show_dots<
    string label = "Puntos blancos al inicio";
> = true;

uniform float dot_count<
    string label = "Cantidad de puntos";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 6.0; float step = 1.0;
> = 3.0;

uniform float grooves<
    string label = "Estrias del canon";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 16.0; float step = 1.0;
> = 6.0;

// Cuánto se tuercen las estrías hacia afuera. 0 = rayos rectos; ±1 = espiral marcada.
uniform float twist<
    string label = "Torsion de las estrias";
    string widget_type = "slider";
    float minimum = -3.0; float maximum = 3.0; float step = 0.01;
> = 0.9;

uniform float spin<
    string label = "Giro del canon (grados/s)";
    string widget_type = "slider";
    float minimum = -90.0; float maximum = 90.0; float step = 0.5;
> = 10.0;

// Contraste de los anillos de maquinado y qué tan rápido se oscurece el cañón hacia afuera.
uniform float depth<
    string label = "Profundidad";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.6;

uniform float4 metal_color = {0.62, 0.64, 0.68, 1.0};

uniform float wobble<
    string label = "Bamboleo (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 1.0;
> = 18.0;

uniform bool show_blood<
    string label = "Sangre";
> = true;

uniform float4 blood_color = {0.55, 0.0, 0.02, 1.0};

uniform float blood_opacity<
    string label = "Opacidad de la sangre";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.85;

uniform float drip_length<
    string label = "Largo de los chorros (% del alto)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 0.5;
> = 35.0;

uniform bool end_reveal<
    string label = "Al final abrir a pantalla completa (si no, funde a negro)";
> = true;

// Hash sin sin(): sin() pierde precisión con argumentos grandes y deja patrones visibles.
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

// Altura (px desde arriba) hasta donde llega la sangre en la columna x.
// level 0 = nada visible, 1 = cubre toda la pantalla. Cada celda tiene un chorro con forma de
// media elipse (punta redondeada) de ancho y largo aleatorios; los largos usan h*h para que
// haya pocos chorros largos y muchos cortos. Se revisan las celdas vecinas para que un chorro
// ancho no se corte en la orilla de su celda.
float bloodFront(float x, float level, float H, float cell, float drip_len, float seed)
{
    float front = lerp(-drip_len - 4.0, H + 4.0, level);
    front += sin(x * 0.013 + seed) * cell * 0.15 + sin(x * 0.031 + seed * 2.0) * cell * 0.08;

    float ci = floor(x / cell);
    float best = 0.0;
    float kf = -1.0;
    for (int k = 0; k < 3; k++) {
        float c = ci + kf;
        float h1 = hash11(c * 1.37 + seed);
        float h2 = hash11(c * 7.91 + seed + 11.0);
        float h3 = hash11(c * 3.17 + seed + 27.0);
        float cx = (c + 0.2 + 0.6 * h1) * cell;
        float hw = cell * (0.18 + 0.32 * h2);
        float u = (x - cx) / hw;
        best = max(best, drip_len * h3 * h3 * sqrt(saturate(1.0 - u * u)));
        kf += 1.0;
    }
    return front + best;
}

// Color de la sangre según la distancia e (px) al frente: orilla más oscura y un brillo
// húmedo angosto un poco adentro.
float3 bloodShade(float e)
{
    float3 c = blood_color.rgb * lerp(0.55, 1.0, smoothstep(0.0, 5.0, e));
    c += smoothstep(3.0, 7.0, e) * (1.0 - smoothstep(9.0, 15.0, e)) * 0.12;
    return c;
}

// Interior del cañón visto desde la recámara: estrías en espiral, anillos de maquinado y luz
// que entra por la boca (más claro junto a ella, oscuro hacia la orilla de la pantalla).
float3 barrelColor(float2 d, float r, float R, float t)
{
    float ang = atan2(d.y, d.x) * 0.15915494;                 // en vueltas, -0.5..0.5
    float lr = log(max(r, 1.0) / max(R, 1.0));                 // 0 en la boca, crece afuera
    float n = max(floor(grooves + 0.5), 1.0);
    float g = frac((ang + spin * t / 360.0) * n + twist * lr);

    // Perfil de una estría: meseta, flanco iluminado, ranura oscura
    float land = smoothstep(0.02, 0.10, g) * (1.0 - smoothstep(0.50, 0.58, g));
    float lit = smoothstep(0.50, 0.55, g) * (1.0 - smoothstep(0.58, 0.66, g));
    float shade = lerp(0.35, 0.9, land) + 0.45 * lit;

    float rings = 0.5 + 0.5 * cos(lr * 22.0);
    shade *= lerp(1.0, 0.8 + 0.2 * rings, depth);

    float fall = exp(-max(lr, 0.0) * lerp(0.6, 1.8, depth));
    float rim = exp(-max(r - R, 0.0) / max(R * 0.05, 1.0)) * 0.5;
    return metal_color.rgb * shade * fall + rim;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 pos = uv * uv_size;
    float H = uv_size.y;
    float t = elapsed_time;
    float aa = 1.5;

    float p = auto_play ? frac(t / max(duration, 0.5)) : saturate(progress * 0.01);

    float pd = seg(p, 0.00, 0.24);   // puntos
    float po = seg(p, 0.24, 0.32);   // apertura
    float pb = seg(p, 0.60, 0.76);   // sangre
    float pc = seg(p, 0.76, 0.88);   // cierre
    float pr = seg(p, 0.88, 0.97);   // apertura final
    if (!show_dots) {
        pd = 1.0;
        po = 1.0;
    }

    float R0 = aperture * 0.01 * H;
    float2 C0 = float2(center_x, center_y) * 0.01 * uv_size;

    // Movimiento: bamboleo mientras el cañón sigue a la fuente, caída y temblor al cerrar
    float cl = ease(pc);
    float settle = 1.0 - pr;
    float2 wob = wobble * po * settle * float2(
        sin(t * 0.9) + 0.5 * sin(t * 2.3 + 1.0),
        0.6 * sin(t * 1.3 + 2.0) + 0.3 * sin(t * 3.1));
    float2 shake = cl * settle * 6.0 * float2(sin(t * 37.0), sin(t * 43.0 + 1.0));
    float2 C = C0 + wob + shake + float2(0.0, cl * H * 0.06);

    float R = lerp(R0, R0 * 0.4, cl);
    if (end_reveal)
        R = lerp(R, length(uv_size) * 1.2, ease(pr) * pr);

    float2 d = pos - C;
    float r = length(d);
    float inside = 1.0 - smoothstep(R - aa, R + aa, r);

    float4 src = image.Sample(textureSampler, uv);
    float3 inner = lerp(inner_bg.rgb, src.rgb, src.a);

    // El punto blanco se vuelve ventana; el cañón aparece desde negro y se apaga al cerrar
    float o = ease(po);
    float3 insideCol = lerp(float3(1.0, 1.0, 1.0), inner, o);
    float3 outside = barrelColor(d, r, R, t) * o * lerp(1.0, 0.25, cl) * settle;
    float3 col = lerp(outside, insideCol, inside);

    // Sangre: cubre todo; dentro de la boca se retira al cerrar para que la ventana final
    // quede limpia, y afuera se apaga durante la apertura final
    if (show_blood && pb > 0.0) {
        float cell = H * 0.055;
        float e = bloodFront(pos.x, pb, H, cell, drip_length * 0.01 * H, 3.7) - pos.y;
        float m = saturate(e / 1.5 + 0.5);
        float a = blood_opacity * m * lerp(1.0, 1.0 - cl, inside) * settle;
        col = lerp(col, bloodShade(e), a);
    }

    // Puntos blancos sobre negro (antes de abrir la boca)
    if (po <= 0.0) {
        float n = max(floor(dot_count + 0.5), 1.0);
        float spacing = 2.4 * R0;
        float dots = 0.0;
        float fi = 0.0;
        for (int i = 0; i < 6; i++) {
            if (fi < n) {
                float appear = fi / n;
                float vis = smoothstep(appear, appear + 0.03, pd);
                if (fi < n - 1.0) {
                    float gone = (fi + 1.0) / n;
                    vis *= 1.0 - smoothstep(gone + 0.02, gone + 0.06, pd);
                }
                float2 dc = float2(C0.x - (n - 1.0 - fi) * spacing, C0.y);
                float dd = length(pos - dc);
                dots = max(dots, vis * (1.0 - smoothstep(R0 - aa, R0 + aa, dd)));
            }
            fi += 1.0;
        }
        col = float3(dots, dots, dots);
    }

    if (!end_reveal)
        col *= 1.0 - pr;

    return float4(col, 1.0);
}
