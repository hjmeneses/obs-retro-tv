// Emblema giratorio: transición de escena estilo series de superhéroes de los 60. Un emblema
// sale girando del centro sobre un fondo de rayos, se queda girando un instante y luego se
// lanza contra la cámara: por dentro del emblema ya se ve la escena nueva.
// Para OBS Studio (plugin obs-shaderfilter) como TRANSICIÓN, no como filtro:
//   Transiciones de escena → + → User-defined shader → Load shader text from file.
//
// Secuencia (tiempo de la transición 0 → 100 %):
//   0–35   Un círculo de rayos se abre desde el centro sobre la escena actual
//   3–40   El emblema aparece girando y crece
//   40–55  El emblema gira sobre los rayos
//   55–100 El emblema se lanza contra la cámara; por dentro se ve la escena nueva
//   90–100 Fundido final a la escena nueva (por si el emblema tiene huecos)
//
// Emblema: una estrella por defecto, o tu propio PNG cuadrado con transparencia.

uniform texture2d image_a;
uniform texture2d image_b;
uniform float transition_time = 0.5;
uniform bool convert_linear = true;

// Si eliges una imagen se usa sola; sin imagen se dibuja la estrella
uniform texture2d emblem_image<
    string label = "Imagen del emblema (PNG cuadrado con transparencia; vacio = estrella)";
>;

uniform float emblem_size<
    string label = "Tamano del emblema (% de la altura)";
    string widget_type = "slider";
    float minimum = 10.0; float maximum = 100.0; float step = 1.0;
> = 70.0;

uniform float spin_turns<
    string label = "Vueltas del emblema";
    string widget_type = "slider";
    float minimum = -10.0; float maximum = 10.0; float step = 0.25;
> = 3.0;

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

uniform float4 emblem_color<
    string label = "Color del emblema";
> = {1.0, 0.82, 0.08, 1.0};

uniform float4 outline_color<
    string label = "Color del contorno";
> = {0.05, 0.05, 0.08, 1.0};

uniform float rays<
    string label = "Rayos del fondo";
    string widget_type = "slider";
    float minimum = 4.0; float maximum = 40.0; float step = 1.0;
> = 14.0;

uniform float ray_turns<
    string label = "Giro de los rayos (vueltas)";
    string widget_type = "slider";
    float minimum = -3.0; float maximum = 3.0; float step = 0.05;
> = -0.5;

uniform float4 ray_color_a<
    string label = "Color de rayos 1";
> = {0.80, 0.08, 0.10, 1.0};

uniform float4 ray_color_b<
    string label = "Color de rayos 2";
> = {0.10, 0.18, 0.62, 1.0};

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

// Emblema en coordenadas propias (radio 1, y hacia arriba). rgb = color, a = forma.
float4 emblemAt(float2 q, float aa, float ow, bool img)
{
    if (img) {
        float2 euv = float2(q.x, -q.y) * 0.5 + 0.5;
        if (euv.x < 0.0 || euv.x > 1.0 || euv.y < 0.0 || euv.y > 1.0)
            return float4(0.0, 0.0, 0.0, 0.0);
        // obs-shaderfilter carga la imagen con alfa premultiplicado: se deshace aquí
        float4 e = emblem_image.Sample(textureSampler, euv);
        return float4(e.rgb / max(e.a, 0.0001), e.a);
    }
    float n = floor(points + 0.5);
    float m = lerp(2.0, n, star_depth);
    float d = starSD(q, n, m);
    float shape = 1.0 - smoothstep(-aa, aa, d);
    float inner = 1.0 - smoothstep(-aa, aa, d + ow);
    return float4(lerp(outline_color.rgb, emblem_color.rgb, inner), shape);
}

float3 raysColor(float2 c, float T, float H)
{
    float r = length(c);
    float n = floor(rays + 0.5);
    float a = atan2(c.y, c.x) + T * ray_turns * 6.2831853;
    float w = 1.5 * n / max(r * H, 1.0);                       // antialias del borde de cada rayo
    float s = smoothstep(-w, w, sin(a * n));
    float3 col = lerp(ray_color_a.rgb, ray_color_b.rgb, s);
    col *= 1.0 - 0.35 * saturate(r * r);                       // viñeta
    col += float3(1.0, 0.95, 0.8) * 0.5 * exp(-r * 6.0);       // brillo al centro
    return col;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float H = uv_size.y;
    float2 c = (uv - 0.5) * uv_size / H;                       // en alturas, centrado
    c.y = -c.y;
    float T = saturate(transition_time);

    float4 A = image_a.Sample(textureSampler, uv);
    float4 B = image_b.Sample(textureSampler, uv);

    // Círculo de rayos que se abre desde el centro
    float diag = length(uv_size) * 0.5 / H;
    float iris = ease(seg(T, 0.0, 0.35)) * (diag + 0.02);
    float px = 1.0 / H;
    float inIris = 1.0 - smoothstep(iris - 2.0 * px, iris, length(c));
    float3 col = lerp(A.rgb, raysColor(c, T, H), inIris);
    float alpha = lerp(A.a, 1.0, inIris);

    // Emblema: crece con rebote, gira y al final se lanza contra la cámara
    float u1 = ease(seg(T, 0.03, 0.40));
    float u2 = seg(T, 0.55, 1.0);
    float S = emblem_size * 0.005 * u1 * (1.0 + 0.18 * sin(3.14159265 * u1)) * pow(60.0, u2 * u2);
    float phi = spin_turns * 6.2831853 * T;
    float k = ease(seg(T, 0.55, 0.72));                        // relleno → escena nueva

    if (S > 1e-4) {
        float aa = 1.5 * px / S;
        float ow = 0.09 * (1.0 - k);
        bool img = hasImage();

        // Sombra desplazada, solo mientras el emblema es sólido
        float4 sh = emblemAt(rot(c - float2(0.025, -0.035), phi) / S, aa * 4.0, ow, img);
        col *= 1.0 - sh.a * 0.45 * (1.0 - k) * inIris;

        float4 e = emblemAt(rot(c, phi) / S, aa, ow, img);
        float3 fill = lerp(e.rgb, B.rgb, k);
        col = lerp(col, fill, e.a);
        alpha = lerp(alpha, lerp(1.0, B.a, k), e.a);
    }

    float4 rgba = lerp(float4(col, alpha), B, ease(seg(T, 0.90, 1.0)));
    if (convert_linear)
        rgba.rgb = srgb_nonlinear_to_linear(rgba.rgb);
    return rgba;
}
