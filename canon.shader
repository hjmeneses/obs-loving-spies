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

uniform float4 inner_bg<
    string label = "Fondo dentro de la boca (fuente con transparencia)";
> = {1.0, 1.0, 1.0, 1.0};

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

// Cuánto se tuercen las estrías hacia la boca. 0 = rayos rectos; ±1 = espiral marcada.
uniform float twist<
    string label = "Torsion de las estrias";
    string widget_type = "slider";
    float minimum = -1.5; float maximum = 1.5; float step = 0.01;
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

uniform float4 metal_color<
    string label = "Color del metal";
> = {0.62, 0.64, 0.68, 1.0};

uniform float wobble<
    string label = "Bamboleo (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 1.0;
> = 18.0;

uniform bool show_blood<
    string label = "Sangre";
> = true;

uniform float4 blood_color<
    string label = "Color de la sangre";
> = {0.55, 0.0, 0.02, 1.0};

uniform float blood_opacity<
    string label = "Opacidad de la sangre";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

uniform int blend_mode<
    string label = "Fusion de la sangre";
    string widget_type = "select";
    int    option_0_value = 0; string option_0_label = "Normal";
    int    option_1_value = 1; string option_1_label = "Multiplicar";
    int    option_2_value = 2; string option_2_label = "Oscurecer";
    int    option_3_value = 3; string option_3_label = "Subexponer color";
    int    option_4_value = 4; string option_4_label = "Superponer";
    int    option_5_value = 5; string option_5_label = "Luz suave";
    int    option_6_value = 6; string option_6_label = "Luz fuerte";
    int    option_7_value = 7; string option_7_label = "Color";
    int    option_8_value = 8; string option_8_label = "Trama (Screen)";
> = 0;

uniform float drip_length<
    string label = "Largo de los chorros (% del alto)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 0.5;
> = 35.0;

uniform float blood_motion<
    string label = "Movimiento de la sangre (0 = quieta)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 1.0;

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

// ---- Misma sección que en sangre.shader ------------------------------------------------------

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
    // Margen fuera de pantalla: la orilla ondula hasta 0.535 celdas + 6 % del largo de los chorros
    // y la gota de la punta mide hasta 0.175 celdas, así que con level 0 no asoma nada y con
    // level 1 cubre hasta el último píxel.
    float mg = cell * 0.8 + drip_len * 0.06 + 4.0;
    float front = lerp(-drip_len - mg, H + mg, level);
    front += sin(x * 0.006 + sd * 1.7) * (cell * 0.3 + drip_len * 0.06)
           + sin(x * 0.013 + sd) * cell * 0.15
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
        float nk = max(rb * 0.75, cell * 0.08);               // cuello: nunca una varilla fina
        float len = max(tip - top, hw - nk + 1.0);

        float dc = unevenCapsule(float2(x - cx, pos.y - top), hw, nk, len);
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
// Las vetas tienen periodo irregular (x deformada) y poco contraste, y se desvanecen lejos de la
// orilla: con periodo fijo y mucho contraste la cortina parecía tela.
float3 bloodShade(float e, float2 pos, float t, float mv, float cell)
{
    float3 c = blood_color.rgb * lerp(0.55, 1.0, smoothstep(0.0, 5.0, e));

    float wx = pos.x + 18.0 * sin(pos.x * 0.017 + 1.3) + 11.0 * sin(pos.x * 0.041 + 4.0);
    float flow = 0.5 + 0.5 * sin(wx * 0.07 + 2.0 * sin(pos.y * 0.012 - t * 0.9 * mv + pos.x * 0.01));
    float streak = smoothstep(6.0, 20.0, e) * lerp(0.5, 1.0, 1.0 - smoothstep(cell * 1.5, cell * 5.0, e));
    c *= lerp(1.0, lerp(0.86, 1.05, flow), streak);

    float2 gr = float2(ddx(e), ddy(e));
    float2 n = -gr / max(length(gr), 1e-4);
    float spec = pow(saturate(dot(n, float2(-0.6, -0.8))), 6.0);
    float band = smoothstep(1.0, 3.0, e) * (1.0 - smoothstep(4.0, 10.0, e));
    c += band * (0.06 + 0.4 * spec) * float3(1.0, 0.75, 0.75);
    return c;
}

// Métodos de fusión (fórmulas de Photoshop / W3C): b = lo que hay debajo, s = la sangre
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
    if (mode == 1) return b * s;                                        // Multiplicar
    if (mode == 2) return min(b, s);                                    // Oscurecer
    if (mode == 8) return 1.0 - (1.0 - b) * (1.0 - s);                  // Trama (Screen)
    if (mode == 3) return 1.0 - min((1.0 - b) / max(s, 0.001), 1.0);   // Subexponer color
    if (mode == 4)                                                      // Superponer
        return lerp(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b));
    if (mode == 5)                                                      // Luz suave
        return lerp(b - (1.0 - 2.0 * s) * b * (1.0 - b),
                    b + (2.0 * s - 1.0) * (softLightD(b) - b), step(0.5, s));
    if (mode == 6)                                                      // Luz fuerte
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

// Cuánto se tuercen las ranuras y los reflejos respecto al slider "Torsión". Las ranuras
// combinan la profundidad (se aprietan hacia la boca) con log r (siguen girando lejos de ella).
#define TWIST_DARK  2.0
#define TWIST_LOG   0.8
#define TWIST_LIGHT 3.5
// Ranuras: brillo (0 = negro) y suavidad extra del borde, en fracción de estría
#define GROOVE_DARK 0.18
#define GROOVE_SOFT 0.03
// Qué tanto se acerca el reflejo al blanco (0 = mismo color que el metal, 1 = blanco)
#define SPEC_WHITE  0.6

// Interior del cañón visto desde la recámara: estrías en espiral, anillos de maquinado y luz
// que entra por la boca (más claro junto a ella, oscuro hacia la orilla de la pantalla).
float3 barrelColor(float2 d, float r, float R, float t)
{
    float ang = atan2(d.y, d.x) * 0.15915494;       // en vueltas, -0.5..0.5
    float z = R / max(r, 1.0);                       // profundidad en perspectiva: 1 en la boca, ->0 afuera
    float lr = log(max(r, 1.0) / max(R, 1.0));       // 0 en la boca, crece afuera (caída de luz)
    float n = max(floor(grooves + 0.5), 1.0);
    float rot = spin * t / 360.0;

    // 1. Ranuras oscuras: giran con el cañón y se enroscan. La profundidad z aprieta la espiral
    //    hacia la boca, como un tubo en perspectiva; log r (con signo contrario, porque crece
    //    hacia afuera) mantiene el giro lejos de ella, donde z ya casi no cambia.
    float g_dark = frac((ang + rot) * n + twist * (TWIST_DARK * z - TWIST_LOG * lr));
    float fw_d = min(fwidth(g_dark) * 1.5, 0.08) + GROOVE_SOFT;
    float groove = smoothstep(0.20 - fw_d, 0.20 + fw_d, g_dark)
                 * (1.0 - smoothstep(0.50 - fw_d, 0.50 + fw_d, g_dark));

    // 2. Reflejo especular: gira con el cañón (mismo rot que las ranuras, para que no se
    //    despegue del metal) y se enrosca con fuerza hacia la boca
    float g_light = frac((ang + rot) * n + twist * TWIST_LIGHT * z);
    float fw_l = min(fwidth(g_light) * 1.5, 0.08);
    float spec_band = smoothstep(0.42 - fw_l, 0.48 + fw_l, g_light)
                    * (1.0 - smoothstep(0.52 - fw_l, 0.58 + fw_l, g_light));

    // Luz fija de la escena: dos lóbulos opuestos, como el reflejo dentro de un tubo. No lleva
    // rot: la luz se queda quieta y el cañón gira debajo. Junto a la boca se vuelve pareja.
    float tube_lobe = 0.35 + 0.65 * pow(abs(cos((ang + twist * 0.25 * z) * 6.28318531)), 1.5);
    tube_lobe = lerp(tube_lobe, 1.0, z * z * z);

    // 3. Composición: el reflejo pasa por encima de mesetas y ranuras por igual
    float base_metal = lerp(0.85, GROOVE_DARK, groove);  // meseta clara vs ranura oscura
    float light_curve = spec_band * 0.7;

    // Textura de metal maquinado a lo largo de las estrías (±4 %)
    float brush = 0.96 + 0.08 * hash11(floor(g_dark * 96.0));

    // Anillos de torneado parejos en profundidad (más juntos al fondo) y caída de luz
    float rings = 0.5 + 0.5 * cos(z * 56.5486678);   // 9 anillos de la orilla a la boca
    float ring_shade = lerp(1.0, 0.88 + 0.12 * rings, depth);
    float fall = exp(-max(lr, 0.0) * lerp(0.5, 1.6, depth));

    float3 col = metal_color.rgb * (base_metal * tube_lobe * brush)
               + lerp(metal_color.rgb, float3(1.0, 1.0, 1.0), SPEC_WHITE) * light_curve;
    col *= ring_shade * fall;

    // Dither: evita escalones en los degradados oscuros (8 bits + compresión del stream)
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
        float e = bloodField(pos, pb, H, cell, drip_length * 0.01 * H, 3.7, t, blood_motion);
        float m = saturate(e / 1.5 + 0.5);
        float a = blood_opacity * m * lerp(1.0, 1.0 - cl, inside) * settle;
        col = lerp(col, blendBlood(col, bloodShade(e, pos, t, blood_motion, cell), blend_mode), a);
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
