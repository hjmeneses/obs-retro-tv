// Emblema giratorio: transición de escena estilo series de superhéroes de los 60, para usar
// como stinger. Para volver a los valores estándar usa el botón de retro-control.lua (el botón
// Predeterminados de OBS también borra el archivo del shader). La escena se acerca, gira cada vez más rápido con desenfoque circular, en el
// giro más rápido cambia a la escena nueva, frena y vuelve a su tamaño. Mientras tanto una
// silueta (murciélago, estrella o tu PNG) se acerca a la cámara sin girar.
// Para OBS Studio (plugin obs-shaderfilter) como TRANSICIÓN, no como filtro:
//   Transiciones de escena → + → User-defined shader → Load shader text from file.
//
// Secuencia (tiempo de la transición 0 → 100 %, con acercamiento de 10 %):
//   0–10   La escena actual se acerca hasta cubrir la pantalla en cualquier ángulo
//   10–90  Gira acelerando y luego frenando; el desenfoque sigue a la velocidad
//   47–53  En el giro más rápido cambia a la escena nueva
//   90–100 La escena nueva, ya quieta y nítida, vuelve a su tamaño normal
//   0–100  La silueta crece hasta el alto de la pantalla a la mitad y regresa a su tamaño

uniform texture2d image_a;
uniform texture2d image_b;
uniform float transition_time = 0.5;
uniform bool convert_linear = true;

uniform int shape<
    string label = "Silueta";
    string widget_type = "select";
    int    option_0_value = 0;
    string option_0_label = "Murcielago";
    int    option_1_value = 1;
    string option_1_label = "Estrella";
    int    option_2_value = 2;
    string option_2_label = "Imagen (PNG)";
> = 0;

// Solo se usa con Silueta = Imagen; sin archivo cae al murciélago
uniform texture2d emblem_image<
    string label = "Imagen de la silueta (PNG cuadrado con transparencia)";
>;

uniform float4 emblem_color<
    string label = "Color de la silueta";
> = {0.02, 0.02, 0.03, 1.0};

uniform float emblem_size<
    string label = "Tamano inicial y final de la silueta (% de la altura)";
    string widget_type = "slider";
    float minimum = 5.0; float maximum = 100.0; float step = 1.0;
> = 30.0;

uniform float peak_size<
    string label = "Tamano a media transicion (% de la altura)";
    string widget_type = "slider";
    float minimum = 20.0; float maximum = 200.0; float step = 1.0;
> = 100.0;

uniform float spin_turns<
    string label = "Vueltas de la escena (negativo = al reves)";
    string widget_type = "slider";
    float minimum = -20.0; float maximum = 20.0; float step = 1.0;
> = 3.0;

uniform float blur_deg<
    string label = "Desenfoque circular maximo (grados)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 180.0; float step = 1.0;
> = 25.0;

uniform float zoom_part<
    string label = "Duracion del acercamiento (% del tiempo)";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 30.0; float step = 1.0;
> = 10.0;

uniform float points<
    string label = "Puntas de la estrella";
    string widget_type = "slider";
    float minimum = 3.0; float maximum = 12.0; float step = 1.0;
> = 5.0;

uniform float star_depth<
    string label = "Picos de la estrella (bajo = mas puntiaguda)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.35;

#define BLUR_SAMPLES 48

float seg(float p, float a, float b)
{
    return saturate((p - a) / (b - a));
}

float ease(float t)
{
    return t * t * (3.0 - 2.0 * t);
}

float2 rot(float2 p, float a)
{
    float c = cos(a);
    float s = sin(a);
    return float2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

float hash12(float2 p)
{
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

// Repite la imagen en espejo fuera de 0–1: si algún borde se asomara, se ve imagen y no negro
float2 mirrorUV(float2 t)
{
    float2 f = t - 2.0 * floor(t * 0.5);
    return 1.0 - abs(1.0 - f);
}

// Estrella de n puntas y radio 1 (SDF de Inigo Quilez). m va de 2 (muy puntiaguda) a n (polígono).
float starSD(float2 p, float n, float m)
{
    float an = 3.14159265 / n;
    float en = 3.14159265 / m;
    float2 acs = float2(cos(an), sin(an));
    float2 ecs = float2(cos(en), sin(en));
    float w = 2.0 * an;
    float bn = atan2(p.x, p.y);
    bn = bn - w * floor(bn / w) - an;
    p = length(p) * float2(cos(bn), abs(sin(bn)));
    p -= acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, acs.y / ecs.y);
    return length(p) * sign(p.x);
}

// Murciélago genérico, mide 1 de alto (y de -0.5 a 0.5) y ~2.4 de ancho. < 0 = dentro.
float batSD(float2 p)
{
    float ax = abs(p.x);
    float y = p.y;

    // Alas: borde de arriba que sube hacia la punta, borde de abajo con tres festones que se
    // achican hacia la punta, donde ambos bordes se juntan
    float t = saturate((ax - 0.08) / 1.12);
    float top = 0.10 + 0.36 * t + 0.08 * sin(3.14159265 * t);
    float s = frac(t * 3.0);
    float bottom = lerp(-0.30, 0.46, t) + 0.36 * sqrt(saturate(s * (1.0 - s))) * (1.0 - t);
    float wing = max(max(y - top, bottom - y), ax - 1.20);

    // Cuerpo (elipse), cabeza y orejas
    float2 br = float2(0.12, 0.34);
    float2 bp = p - float2(0.0, -0.04);
    float k0 = length(bp / br);
    float k1 = length(bp / (br * br));
    float body = k0 * (k0 - 1.0) / max(k1, 1e-4);
    float head = length(p - float2(0.0, 0.22)) - 0.11;
    float ear = max((y - (0.45 - 3.6 * abs(ax - 0.07))) * 0.27, 0.20 - y);

    return min(min(wing, body), min(head, ear));
}

// ¿Hay imagen? Sin archivo la textura lee 0 en todas partes, así que basta con sondear
// 9 puntos: cualquier PNG con algo visible en ellos cuenta como imagen.
bool hasImage()
{
    float s = 0.0;
    for (int j = 1; j <= 3; j++) {
        for (int i = 1; i <= 3; i++) {
            s += emblem_image.SampleLevel(textureSampler, float2(i, j) * 0.25, 0.0).a;
        }
    }
    return s > 0.001;
}

// Silueta en coordenadas propias: q en alturas de la silueta (alto total = 1, y hacia arriba).
// rgb = color, a = cobertura.
float4 silhouetteAt(float2 q, float aa)
{
    if (shape == 2 && hasImage()) {
        float2 euv = float2(q.x, -q.y) + 0.5;
        if (euv.x < 0.0 || euv.x > 1.0 || euv.y < 0.0 || euv.y > 1.0)
            return float4(0.0, 0.0, 0.0, 0.0);
        // obs-shaderfilter carga la imagen con alfa premultiplicado: se deshace aquí
        float4 e = emblem_image.Sample(textureSampler, euv);
        return float4(e.rgb / max(e.a, 0.0001), e.a);
    }
    float d;
    if (shape == 1) {
        float n = floor(points + 0.5);
        d = starSD(q * 2.0, n, lerp(2.0, n, star_depth)) * 0.5;
    } else {
        d = batSD(q);
    }
    return float4(emblem_color.rgb, 1.0 - smoothstep(-aa, aa, d));
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float H = uv_size.y;
    float aspect = uv_size.x / H;
    float2 c = (uv - 0.5) * float2(aspect, 1.0);                // en alturas, centrado
    float T = saturate(transition_time);
    float z = zoom_part * 0.01;

    // Acercamiento: la altura de la escena llega a la diagonal de la pantalla, así el
    // rectángulo cubre la pantalla en cualquier ángulo de giro
    float zFull = length(float2(aspect, 1.0)) * 1.01;
    float zin = ease(seg(T, 0.0, z));
    float zout = ease(seg(T, 1.0 - z, 1.0));
    float zoom = 1.0 + (zFull - 1.0) * zin * (1.0 - zout);

    // Giro: ángulo con forma de smoothstep → velocidad en campana, máxima a la mitad
    float u = seg(T, z, 1.0 - z);
    float ang = spin_turns * 6.2831853 * ease(u);
    float vel = 4.0 * u * (1.0 - u);                             // 0 → 1 → 0
    float blurAng = radians(blur_deg) * vel * sign(spin_turns);
    float swap = ease(seg(T, 0.47, 0.53));

    // Desenfoque circular: promedia muestras a lo largo del arco que recorre cada punto.
    // El ruido por pixel convierte el escalonado de las muestras en grano fino.
    float jit = hash12(uv * uv_size + T * 61.0);
    float4 accA = float4(0.0, 0.0, 0.0, 0.0);
    float4 accB = float4(0.0, 0.0, 0.0, 0.0);
    for (int i = 0; i < BLUR_SAMPLES; i++) {
        float o = ((float(i) + jit) / float(BLUR_SAMPLES) - 0.5) * blurAng;
        float2 p = rot(c, ang - o) / zoom;
        float2 suv = mirrorUV(p * float2(1.0 / aspect, 1.0) + 0.5);
        if (swap < 1.0)
            accA += image_a.SampleLevel(textureSampler, suv, 0.0);
        if (swap > 0.0)
            accB += image_b.SampleLevel(textureSampler, suv, 0.0);
    }
    float4 rgba = lerp(accA, accB, swap) / float(BLUR_SAMPLES);

    // Silueta: no gira; crece hasta el pico a la mitad y regresa a su tamaño
    float S = lerp(emblem_size, peak_size, sin(3.14159265 * T)) * 0.01;
    float show = ease(seg(T, 0.0, 0.05)) * (1.0 - ease(seg(T, 0.95, 1.0)));
    if (show > 0.0) {
        float2 q = float2(c.x, -c.y) / S;
        float4 e = silhouetteAt(q, 1.5 / (H * S));
        float a = e.a * show * emblem_color.a;
        rgba.rgb = lerp(rgba.rgb, e.rgb, a);
        rgba.a = lerp(rgba.a, 1.0, a);
    }

    if (convert_linear)
        rgba.rgb = srgb_nonlinear_to_linear(rgba.rgb);
    return rgba;
}
