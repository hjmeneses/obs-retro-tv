// Túnel del tiempo: anillos que se hunden sin fin hacia un punto y el viajero (la fuente) cae
// girando y encogiéndose hacia el fondo, estilo series de ciencia ficción de los 60. Para OBS
// Studio (plugin obs-shaderfilter, modo "User-defined shader").
//
// Secuencia (Progreso 0 → 100), modo "Caer al túnel":
//   0–12   El túnel aparece detrás de la fuente (donde la fuente es transparente)
//   12–90  El viajero gira y se encoge hacia el centro del túnel
//   90–100 Solo el túnel
// Con "Salir del túnel" la secuencia va al revés: el viajero llega desde el fondo y al final el
// túnel se desvanece y queda la fuente tal cual (con su transparencia).
//
// El viajero se ve mejor con transparencia (cámara con quitado de fondo, chroma key o un PNG);
// sin ella cae el rectángulo completo, como un recorte.
// Con "Reproducir en bucle" se repite solo; para dispararlo una vez usa retro-control.lua.

uniform bool auto_play<
    string label = "Reproducir en bucle (ignora Progreso)";
> = true;

uniform float duration<
    string label = "Duracion de la secuencia (s)";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 30.0; float step = 0.5;
> = 8.0;

uniform float progress<
    string label = "Progreso (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform bool reverse<
    string label = "Salir del tunel (al reves: el viajero llega desde el fondo)";
> = false;

uniform float center_x<
    string label = "Centro del tunel X (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float center_y<
    string label = "Centro del tunel Y (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float tunnel_wobble<
    string label = "Bamboleo del tunel (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 150.0; float step = 1.0;
> = 30.0;

uniform float ring_density<
    string label = "Densidad de anillos";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 8.0; float step = 0.05;
> = 2.5;

// 0 = anillos concéntricos; 1 o más = brazos de espiral
uniform float arms<
    string label = "Espiral (brazos, 0 = anillos)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 8.0; float step = 1.0;
> = 1.0;

uniform float tunnel_speed<
    string label = "Velocidad del tunel";
    string widget_type = "slider";
    float minimum = -3.0; float maximum = 3.0; float step = 0.01;
> = 0.8;

uniform float sharpness<
    string label = "Contraste de los anillos";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.6;

uniform float pulse<
    string label = "Pulsacion de luz";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.35;

uniform float4 tint<
    string label = "Color del tunel";
> = {1.0, 1.0, 1.0, 1.0};

uniform float turns<
    string label = "Vueltas del viajero";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 8.0; float step = 0.25;
> = 2.5;

uniform float drift<
    string label = "Vaiven del viajero (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 200.0; float step = 1.0;
> = 60.0;

uniform float grain<
    string label = "Grano de pelicula";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.5; float step = 0.01;
> = 0.12;

uniform float flicker<
    string label = "Parpadeo";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.5; float step = 0.01;
> = 0.08;

// Hash sin sin(): sin() pierde precisión con argumentos grandes y deja patrones visibles.
float hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float hash12(float2 p)
{
    float3 p3 = frac(float3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float seg(float p, float a, float b)
{
    return saturate((p - a) / (b - a));
}

float ease(float t)
{
    return t * t * (3.0 - 2.0 * t);
}

// Túnel visto desde adentro: con log(r) cada anillo tiene el mismo ancho aparente y moverlos
// en log(r) da el avance infinito hacia el fondo. Los anillos se apagan hacia el centro (lejos)
// y hay un resplandor en el punto de fuga.
float3 tunnelColor(float2 d, float H, float t)
{
    float r = max(length(d), 0.5);
    float lr = log(r / H);                                     // ~0 en la orilla, negativo adentro
    float ang = atan2(d.y, d.x) * 0.15915494;                  // en vueltas
    float n = floor(arms + 0.5);

    float v = lr * ring_density - t * tunnel_speed + n * ang;
    float band = 0.5 + 0.5 * cos(6.2831853 * v);
    float k = lerp(0.5, 0.02, sharpness);
    band = smoothstep(0.5 - k, 0.5 + k, band);

    // Ondas de luz que viajan hacia el fondo
    float wave = 1.0 + pulse * sin(6.2831853 * (lr * 0.6 - t * 0.7));
    float depth = saturate((lr + 4.2) / 3.0);                  // 0 al fondo, 1 cerca
    float core = exp(-r / (H * 0.035));                        // punto de fuga brillante

    float lum = band * wave * lerp(0.15, 1.0, depth) + core * 1.2;
    return tint.rgb * lum;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 pos = uv * uv_size;
    float H = uv_size.y;
    float t = elapsed_time;

    float p = auto_play ? frac(t / max(duration, 0.5)) : saturate(progress * 0.01);
    if (reverse)
        p = 1.0 - p;

    float tf = ease(seg(p, 0.0, 0.12));                        // aparición del túnel
    float pp = seg(p, 0.12, 0.90);                             // caída del viajero
    float fall = pp * pp;                                      // acelera al caer

    // El punto de fuga describe una órbita lenta: el túnel se siente vivo y no como una diana
    float2 C = float2(center_x, center_y) * 0.01 * uv_size
             + tunnel_wobble * float2(cos(t * 0.7), 0.6 * sin(t * 0.9 + 1.0));
    float2 mid = uv_size * 0.5;

    // Viajero: escala, giro y trayectoria del centro de la pantalla al punto de fuga con vaivén
    float s = 1.0 - fall;
    float ang = turns * 6.2831853 * pow(pp, 1.5);
    float sway = sin(pp * 9.0) * drift * (1.0 - pp) * pp * 4.0;
    float2 P = lerp(mid, C, ease(pp)) + float2(sway, sway * 0.4);

    float4 trav = float4(0.0, 0.0, 0.0, 0.0);
    if (s > 0.002) {
        float2 q = pos - P;
        float cs = cos(ang);
        float sn = sin(ang);
        q = float2(cs * q.x + sn * q.y, -sn * q.x + cs * q.y) / s;
        float2 tuv = (q + mid) / uv_size;
        if (tuv.x >= 0.0 && tuv.x <= 1.0 && tuv.y >= 0.0 && tuv.y <= 1.0) {
            trav = image.Sample(textureSampler, tuv);
            trav.a *= smoothstep(0.002, 0.04, s);              // se desvanece al llegar al fondo
        }
    }

    // Película: parpadeo por cuadro (24 fps) y grano
    float frame = floor(t * 24.0);
    float fl = 1.0 - flicker * hash11(frame * 1.7);
    float3 tun = tunnelColor(pos - C, H, t) * fl;
    tun += (hash12(pos + frame * 37.0) - 0.5) * grain;
    tun = saturate(tun);

    // Fondo = túnel con opacidad tf; encima el viajero (alfa normal, no premultiplicado)
    float a = trav.a + tf * (1.0 - trav.a);
    float3 rgb = trav.rgb * trav.a + tun * tf * (1.0 - trav.a);
    rgb /= max(a, 1e-4);
    return float4(rgb, a);
}
