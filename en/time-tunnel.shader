// Time tunnel: rings that sink endlessly toward a point while the traveler (the source) falls
// spinning and shrinking toward the bottom, in the style of 60s science-fiction series. For OBS
// Studio (obs-shaderfilter plugin, "User-defined shader" mode).
//
// Sequence (Progress 0 → 100), "Fall into the tunnel" mode:
//   0–12   The tunnel appears behind the source (where the source is transparent)
//   12–90  The traveler spins and shrinks toward the center of the tunnel
//   90–100 Only the tunnel
// With "Exit the tunnel" the sequence runs backwards: the traveler arrives from the bottom and
// at the end the tunnel fades and the source is left as is (with its transparency).
//
// The traveler looks best with transparency (camera with background removal, chroma key or a
// PNG); without it the whole rectangle falls, like a cutout.
// With "Loop playback" it repeats on its own; to trigger it once use retro-control.lua.

uniform bool auto_play<
    string label = "Loop playback (ignores Progress)";
> = true;

uniform float duration<
    string label = "Sequence duration (s)";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 30.0; float step = 0.5;
> = 8.0;

uniform float progress<
    string label = "Progress (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform bool reverse<
    string label = "Exit the tunnel (reverse: the traveler arrives from the bottom)";
> = false;

uniform float center_x<
    string label = "Tunnel center X (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float center_y<
    string label = "Tunnel center Y (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 50.0;

uniform float tunnel_wobble<
    string label = "Tunnel sway (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 150.0; float step = 1.0;
> = 30.0;

uniform float ring_density<
    string label = "Ring density";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 8.0; float step = 0.05;
> = 2.5;

// 0 = concentric rings; 1 or more = spiral arms
uniform float arms<
    string label = "Spiral (arms, 0 = rings)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 8.0; float step = 1.0;
> = 1.0;

uniform float tunnel_speed<
    string label = "Tunnel speed";
    string widget_type = "slider";
    float minimum = -3.0; float maximum = 3.0; float step = 0.01;
> = 0.8;

uniform float sharpness<
    string label = "Ring contrast";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.6;

uniform float pulse<
    string label = "Light pulse";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.35;

uniform float4 tint<
    string label = "Tunnel color";
> = {1.0, 1.0, 1.0, 1.0};

uniform float turns<
    string label = "Traveler turns";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 8.0; float step = 0.25;
> = 2.5;

uniform float drift<
    string label = "Traveler drift (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 200.0; float step = 1.0;
> = 60.0;

uniform float grain<
    string label = "Film grain";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.5; float step = 0.01;
> = 0.12;

uniform float flicker<
    string label = "Flicker";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.5; float step = 0.01;
> = 0.08;

// Hash without sin(): sin() loses precision with large arguments and leaves visible patterns.
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

// Tunnel seen from inside: with log(r) every ring has the same apparent width, and moving
// them in log(r) gives the endless advance toward the bottom. The rings fade toward the center
// (far away) and there is a glow at the vanishing point.
float3 tunnelColor(float2 d, float H, float t)
{
    float r = max(length(d), 0.5);
    float lr = log(r / H);                                     // ~0 at the edge, negative inside
    float ang = atan2(d.y, d.x) * 0.15915494;                  // in turns
    float n = floor(arms + 0.5);

    float v = lr * ring_density - t * tunnel_speed + n * ang;
    float band = 0.5 + 0.5 * cos(6.2831853 * v);
    float k = lerp(0.5, 0.02, sharpness);
    band = smoothstep(0.5 - k, 0.5 + k, band);

    // Light waves traveling toward the bottom
    float wave = 1.0 + pulse * sin(6.2831853 * (lr * 0.6 - t * 0.7));
    float depth = saturate((lr + 4.2) / 3.0);                  // 0 at the bottom, 1 near
    float core = exp(-r / (H * 0.035));                        // bright vanishing point

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

    float tf = ease(seg(p, 0.0, 0.12));                        // tunnel appears
    float pp = seg(p, 0.12, 0.90);                             // traveler falls
    float fall = pp * pp;                                      // speeds up as it falls

    // The vanishing point follows a slow orbit: the tunnel feels alive and not like a target
    float2 C = float2(center_x, center_y) * 0.01 * uv_size
             + tunnel_wobble * float2(cos(t * 0.7), 0.6 * sin(t * 0.9 + 1.0));
    float2 mid = uv_size * 0.5;

    // Traveler: scale, spin and path from the center of the screen to the vanishing point, drifting
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
            trav.a *= smoothstep(0.002, 0.04, s);              // fades out on reaching the bottom
        }
    }

    // Film: per-frame flicker (24 fps) and grain
    float frame = floor(t * 24.0);
    float fl = 1.0 - flicker * hash11(frame * 1.7);
    float3 tun = tunnelColor(pos - C, H, t) * fl;
    tun += (hash12(pos + frame * 37.0) - 0.5) * grain;
    tun = saturate(tun);

    // Background = tunnel with opacity tf; the traveler on top (straight alpha, not premultiplied)
    float a = trav.a + tf * (1.0 - trav.a);
    float3 rgb = trav.rgb * trav.a + tun * tf * (1.0 - trav.a);
    rgb /= max(a, 1e-4);
    return float4(rgb, a);
}
