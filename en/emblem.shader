// Spinning emblem: scene transition in the style of 60s superhero series, to use as a
// stinger. To go back to the standard values use the retro-control.lua button (the OBS
// Defaults button also clears the shader file). The scene zooms in, spins faster and faster
// with circular blur, switches to the new scene at the fastest point, slows down and returns
// to its size. Meanwhile a silhouette (bat, star or your PNG) comes toward the camera without
// spinning.
// For OBS Studio (obs-shaderfilter plugin) as a TRANSITION, not as a filter:
//   Scene Transitions → + → User-defined shader → Load shader text from file.
//
// Sequence (transition time 0 → 100 %, with a 10 % zoom):
//   0–10   The current scene zooms in until it covers the screen at any angle
//   10–90  It spins, speeding up and then slowing down; the blur follows the speed
//   47–53  At the fastest point it switches to the new scene
//   90–100 The new scene, now still and sharp, returns to its normal size
//   0–100  The silhouette grows to the screen height at the midpoint and returns to its size

uniform texture2d image_a;
uniform texture2d image_b;
uniform float transition_time = 0.5;
uniform bool convert_linear = true;

uniform int shape<
    string label = "Silhouette";
    string widget_type = "select";
    int    option_0_value = 0;
    string option_0_label = "Bat";
    int    option_1_value = 1;
    string option_1_label = "Star";
    int    option_2_value = 2;
    string option_2_label = "Image (PNG)";
> = 0;

// Only used with Silhouette = Image; without a file it falls back to the bat
uniform texture2d emblem_image<
    string label = "Silhouette image (square PNG with transparency)";
>;

uniform float4 emblem_color<
    string label = "Silhouette color";
> = {0.02, 0.02, 0.03, 1.0};

uniform float emblem_size<
    string label = "Silhouette start and end size (% of height)";
    string widget_type = "slider";
    float minimum = 5.0; float maximum = 100.0; float step = 1.0;
> = 30.0;

uniform float peak_size<
    string label = "Size at mid-transition (% of height)";
    string widget_type = "slider";
    float minimum = 20.0; float maximum = 200.0; float step = 1.0;
> = 100.0;

uniform float spin_turns<
    string label = "Scene turns (negative = reverse)";
    string widget_type = "slider";
    float minimum = -20.0; float maximum = 20.0; float step = 1.0;
> = 3.0;

uniform float blur_deg<
    string label = "Maximum circular blur (degrees)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 180.0; float step = 1.0;
> = 25.0;

uniform float zoom_part<
    string label = "Zoom duration (% of the time)";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 30.0; float step = 1.0;
> = 10.0;

uniform float points<
    string label = "Star points";
    string widget_type = "slider";
    float minimum = 3.0; float maximum = 12.0; float step = 1.0;
> = 5.0;

uniform float star_depth<
    string label = "Star spikes (low = sharper)";
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

// Mirrors the image outside 0–1: if an edge ever showed, you would see image and not black
float2 mirrorUV(float2 t)
{
    float2 f = t - 2.0 * floor(t * 0.5);
    return 1.0 - abs(1.0 - f);
}

// Star with n points and radius 1 (Inigo Quilez SDF). m goes from 2 (very sharp) to n (polygon).
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

// Generic bat, 1 tall (y from -0.5 to 0.5) and ~2.4 wide. < 0 = inside.
float batSD(float2 p)
{
    float ax = abs(p.x);
    float y = p.y;

    // Wings: top edge rising toward the tip, bottom edge with three scallops that get smaller
    // toward the tip, where both edges meet
    float t = saturate((ax - 0.08) / 1.12);
    float top = 0.10 + 0.36 * t + 0.08 * sin(3.14159265 * t);
    float s = frac(t * 3.0);
    float bottom = lerp(-0.30, 0.46, t) + 0.36 * sqrt(saturate(s * (1.0 - s))) * (1.0 - t);
    float wing = max(max(y - top, bottom - y), ax - 1.20);

    // Body (ellipse), head and ears
    float2 br = float2(0.12, 0.34);
    float2 bp = p - float2(0.0, -0.04);
    float k0 = length(bp / br);
    float k1 = length(bp / (br * br));
    float body = k0 * (k0 - 1.0) / max(k1, 1e-4);
    float head = length(p - float2(0.0, 0.22)) - 0.11;
    float ear = max((y - (0.45 - 3.6 * abs(ax - 0.07))) * 0.27, 0.20 - y);

    return min(min(wing, body), min(head, ear));
}

// Is there an image? Without a file the texture reads 0 everywhere, so probing 9 points is
// enough: any PNG with something visible at them counts as an image.
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

// Silhouette in its own coordinates: q in silhouette heights (total height = 1, y up).
// rgb = color, a = coverage.
float4 silhouetteAt(float2 q, float aa)
{
    if (shape == 2 && hasImage()) {
        float2 euv = float2(q.x, -q.y) + 0.5;
        if (euv.x < 0.0 || euv.x > 1.0 || euv.y < 0.0 || euv.y > 1.0)
            return float4(0.0, 0.0, 0.0, 0.0);
        // obs-shaderfilter loads the image with premultiplied alpha: undo it here
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
    float2 c = (uv - 0.5) * float2(aspect, 1.0);                // in heights, centered
    float T = saturate(transition_time);
    float z = zoom_part * 0.01;

    // Zoom: the scene height reaches the screen diagonal, so the rectangle covers the screen
    // at any rotation angle
    float zFull = length(float2(aspect, 1.0)) * 1.01;
    float zin = ease(seg(T, 0.0, z));
    float zout = ease(seg(T, 1.0 - z, 1.0));
    float zoom = 1.0 + (zFull - 1.0) * zin * (1.0 - zout);

    // Spin: smoothstep-shaped angle → bell-shaped speed, maximum at the midpoint
    float u = seg(T, z, 1.0 - z);
    float ang = spin_turns * 6.2831853 * ease(u);
    float vel = 4.0 * u * (1.0 - u);                             // 0 → 1 → 0
    float blurAng = radians(blur_deg) * vel * sign(spin_turns);
    float swap = ease(seg(T, 0.47, 0.53));

    // Circular blur: averages samples along the arc each point travels.
    // Per-pixel noise turns the sample stepping into fine grain.
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

    // Silhouette: does not spin; grows to the peak at the midpoint and returns to its size
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
