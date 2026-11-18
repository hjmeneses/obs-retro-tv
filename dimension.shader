// Dimensión: la fuente pierde el color y flota en un vacío en blanco y negro con estrellas y
// una espiral hipnótica; se aleja dando tumbos en perspectiva y al final se rompe como un
// vidrio. Estilo series de misterio de los 60. Para OBS Studio (plugin obs-shaderfilter,
// "User-defined shader").
//
// Secuencia (Progreso 0 → 100), modo normal:
//   0–15   Aparece el vacío detrás de la fuente y la fuente pierde el color
//   10–75  La fuente se aleja hacia el punto de fuga, girando y ladeándose en 3D
//   50–85  Se rompe en pedazos que se separan, giran y se apagan (o se desvanece, sin romperse)
//   85–100 Solo el vacío
// Con "Aparecer desde la dimension" va al revés: los pedazos se juntan, la fuente llega flotando
// y al final el vacío se desvanece y recupera el color.
//
// Se ve mejor si la fuente tiene transparencia (quitado de fondo, chroma key o PNG).
// Con "Reproducir en bucle" se repite solo; para dispararlo una vez usa retro-control.lua.

uniform bool auto_play<
    string label = "Reproducir en bucle (ignora Progreso)";
> = true;

uniform float duration<
    string label = "Duracion de la secuencia (s)";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 30.0; float step = 0.5;
> = 10.0;

uniform float progress<
    string label = "Progreso (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 40.0;

uniform bool reverse<
    string label = "Aparecer desde la dimension (al reves)";
> = false;

uniform float center_x<
    string label = "Punto de fuga X (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 58.0;

uniform float center_y<
    string label = "Punto de fuga Y (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 42.0;

uniform float far_dist<
    string label = "Que tan lejos se va";
    string widget_type = "slider";
    float minimum = 1.5; float maximum = 20.0; float step = 0.1;
> = 4.0;

uniform float spin<
    string label = "Giro (vueltas)";
    string widget_type = "slider";
    float minimum = -3.0; float maximum = 3.0; float step = 0.05;
> = 0.35;

uniform float tumble<
    string label = "Ladeo en 3D (grados)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 80.0; float step = 1.0;
> = 35.0;

uniform bool shatter<
    string label = "Romperse como vidrio al final";
> = true;

uniform float shard_size<
    string label = "Tamano de los pedazos (px)";
    string widget_type = "slider";
    float minimum = 30.0; float maximum = 400.0; float step = 1.0;
> = 260.0;

uniform float desaturate<
    string label = "Blanco y negro";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

uniform float4 tint<
    string label = "Tono (blanco = blanco y negro puro)";
> = {0.92, 0.95, 1.0, 1.0};

uniform float spiral_strength<
    string label = "Espiral del fondo";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.45;

uniform float spiral_arms<
    string label = "Brazos de la espiral";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 8.0; float step = 1.0;
> = 2.0;

uniform float spiral_speed<
    string label = "Velocidad de la espiral";
    string widget_type = "slider";
    float minimum = -2.0; float maximum = 2.0; float step = 0.01;
> = 0.25;

uniform float star_density<
    string label = "Densidad de estrellas";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 60.0; float step = 1.0;
> = 22.0;

uniform float grain<
    string label = "Grano de pelicula";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.5; float step = 0.01;
> = 0.1;

uniform float flicker<
    string label = "Parpadeo";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.5; float step = 0.01;
> = 0.06;

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

float2 hash22(float2 p)
{
    float3 p3 = frac(float3(p.x, p.y, p.x) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);
}

float seg(float p, float a, float b)
{
    return saturate((p - a) / (b - a));
}

float ease(float t)
{
    return t * t * (3.0 - 2.0 * t);
}

float2 rot2(float2 p, float a)
{
    float c = cos(a);
    float s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float luma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

// Vacío: espiral que gira lento, niebla y estrellas, todo en blanco y negro
float voidLum(float2 pos, float2 V, float H, float t)
{
    float2 d = (pos - V) / H;
    float r = length(d) + 1e-4;
    float a = atan2(d.y, d.x);

    float sp = sin(floor(spiral_arms + 0.5) * a + 7.0 * log(r) - t * spiral_speed * 6.2831853);
    float fog = 0.5 + 0.5 * sin(3.0 * a - 4.0 * log(r) + t * spiral_speed * 2.0 + 1.3);
    float body = smoothstep(0.02, 0.35, r) * (1.0 - 0.5 * smoothstep(0.5, 1.2, r));
    float lum = 0.035 + spiral_strength * body * (0.16 * (0.5 + 0.5 * sp) + 0.07 * fog);
    lum += spiral_strength * 0.25 * exp(-r * 9.0);                  // resplandor al centro

    // Estrellas fijas que rotan muy despacio con la espiral
    if (star_density > 0.5) {
        float2 g = rot2(d, t * 0.02) * star_density;
        float2 cell = floor(g);
        float h = hash12(cell);
        float2 off = hash22(cell + 5.0) - 0.5;
        float2 dp = (frac(g) - 0.5 - off * 0.7) * H / star_density;  // en pixeles
        float sz = 0.8 + 1.4 * h * h;
        float tw = 0.6 + 0.4 * sin(t * 2.5 + h * 80.0);
        lum += step(0.86, h) * exp(-dot(dp, dp) / (sz * sz)) * tw;
    }
    return lum;
}

// Sitio de Voronoi de la celda c (en unidades de celda)
float2 site(float2 c)
{
    return c + 0.15 + 0.7 * hash22(c);
}

float2 nearestCell(float2 g)
{
    float2 b = floor(g);
    float best = 1e9;
    float2 bc = b;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 c = b + float2(i, j);
            float2 d = site(c) - g;
            float dd = dot(d, d);
            if (dd < best) {
                best = dd;
                bc = c;
            }
        }
    }
    return bc;
}

// Lee la fuente en coordenadas del plano (pixeles, origen al centro). Fuera = transparente.
float4 sourceAt(float2 l)
{
    float2 tuv = l / uv_size + 0.5;
    if (tuv.x < 0.0 || tuv.x > 1.0 || tuv.y < 0.0 || tuv.y > 1.0)
        return float4(0.0, 0.0, 0.0, 0.0);
    return image.SampleLevel(textureSampler, tuv, 0.0);
}

// Vidrio roto: cada pedazo (celda de Voronoi) se separa, gira, se encoge y se apaga.
// Para cada pixel se prueban los pedazos cercanos deshaciendo su movimiento.
float4 shardsAt(float2 l, float s)
{
    float cell = shard_size;
    float2 base = floor(l / cell);
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            float2 c = base + float2(i, j);
            float h = hash12(c + 17.0);
            float2 sc = site(c) * cell;
            float2 dir = normalize(sc + float2(0.37, 0.21));
            float2 off = dir * s * cell * 0.55 * (0.6 + 0.8 * h) + float2(0.0, s * s * cell * 0.3);
            float ang = (h - 0.5) * 3.0 * s;
            float sh = 1.0 - 0.6 * s;
            float2 q = rot2(l - sc - off, -ang) / sh + sc;
            if (dot(q - sc, q - sc) > 2.0 * cell * cell)
                continue;
            float2 nc = nearestCell(q / cell);
            if (nc.x == c.x && nc.y == c.y) {
                float4 col = sourceAt(q);
                col.a *= 1.0 - smoothstep(0.45, 1.0, s + (h - 0.5) * 0.3);
                col.rgb *= 0.85 + 0.3 * h;                           // cada pedazo refleja distinto
                return col;
            }
        }
    }
    return float4(0.0, 0.0, 0.0, 0.0);
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 pos = uv * uv_size;
    float H = uv_size.y;
    float t = elapsed_time;
    float2 mid = uv_size * 0.5;

    float p = auto_play ? frac(t / max(duration, 0.5)) : saturate(progress * 0.01);
    if (reverse)
        p = 1.0 - p;

    float tf = ease(seg(p, 0.0, 0.15));                            // aparición del vacío
    float u = ease(seg(p, 0.10, 0.75));                            // viaje
    float s = shatter ? seg(p, 0.50, 0.85) : 0.0;                  // rotura
    float fadeOut = shatter ? 1.0 : 1.0 - ease(seg(p, 0.60, 0.85));

    float2 V = float2(center_x, center_y) * 0.01 * uv_size;

    // Plano de la fuente en 3D: a z = 1 coincide con la pantalla
    float z = pow(max(far_dist, 1.0), u);
    float2 drift = float2(sin(t * 0.37), cos(t * 0.29)) * H * 0.02 * u;
    float2 sc = lerp(mid, V, 1.0 - 1.0 / z) + drift;
    float f = H * 1.5;
    float3 C3 = float3((sc - mid) * z, f * z);

    float yaw = radians(tumble) * sin(u * 2.6 + t * 0.15) * smoothstep(0.0, 0.3, u);
    float rollA = spin * 6.2831853 * u;
    float3 ax = float3(cos(yaw), 0.0, sin(yaw));
    float3 ay = float3(0.0, 1.0, 0.0);
    float3 ux = cos(rollA) * ax + sin(rollA) * ay;
    float3 uy = -sin(rollA) * ax + cos(rollA) * ay;
    float3 n = cross(ux, uy);

    float4 trav = float4(0.0, 0.0, 0.0, 0.0);
    if (fadeOut > 0.0 && s < 1.0) {
        float3 d = float3(pos - mid, f);
        float den = dot(d, n);
        if (abs(den) > 1e-5) {
            float th = dot(C3, n) / den;
            if (th > 0.0) {
                float3 rel = d * th - C3;
                float2 l = float2(dot(rel, ux), dot(rel, uy));
                trav = (s > 0.0) ? shardsAt(l, s) : sourceAt(l);
                trav.rgb *= 0.6 + 0.4 * abs(dot(normalize(d), n));   // se oscurece al ladearse
                trav.a *= fadeOut;
            }
        }
    }

    // Blanco y negro con tono
    float ds = desaturate * tf;
    trav.rgb = lerp(trav.rgb, luma(trav.rgb) * tint.rgb, ds);

    // Película: parpadeo por cuadro (24 fps) y grano
    float frame = floor(t * 24.0);
    float fl = 1.0 - flicker * hash11(frame * 1.7);
    float bgl = voidLum(pos, V, H, t) * fl + (hash12(pos + frame * 37.0) - 0.5) * grain;
    float3 bg = saturate(bgl) * tint.rgb;
    trav.rgb = saturate(trav.rgb * lerp(1.0, fl, tf) + (hash12(pos.yx + frame * 53.0) - 0.5) * grain * tf);

    // Fondo = vacío con opacidad tf; encima la fuente (alfa normal, no premultiplicado)
    float a = trav.a + tf * (1.0 - trav.a);
    float3 rgb = trav.rgb * trav.a + bg * tf * (1.0 - trav.a);
    rgb /= max(a, 1e-4);
    return float4(rgb, a);
}
