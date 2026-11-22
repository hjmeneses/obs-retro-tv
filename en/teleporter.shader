// Teleporter: the source fills with sparkles that twinkle and rise, lights up with the beam
// color and dissolves into vertical stripes until only the sparks with its silhouette are left,
// which then go out. In the style of 60s science-fiction series. For OBS Studio
// (obs-shaderfilter plugin, "User-defined shader").
//
// Sequence (Progress 0 → 100), normal mode (dematerialize):
//   0–15   The sparkles appear over the figure
//   10–40  The figure lights up with the beam color and glows around
//   30–70  It dissolves into vertical stripes; the sparks keep its shape
//   70–95  The sparks go out
//   95–100 Nothing
// With "Materialize" it runs backwards: the sparks arrive, the figure forms and the glow fades.
//
// Needs a source with transparency (background removal, chroma key or PNG): the sparks follow
// the silhouette. With "Loop playback" it repeats on its own; to trigger it once use
// retro-control.lua.

uniform bool auto_play<
    string label = "Loop playback (ignores Progress)";
> = true;

uniform float duration<
    string label = "Sequence duration (s)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 20.0; float step = 0.5;
> = 5.0;

uniform float progress<
    string label = "Progress (%)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 100.0; float step = 0.1;
> = 45.0;

uniform bool reverse<
    string label = "Materialize (reverse)";
> = false;

uniform float4 beam_color<
    string label = "Beam color";
> = {1.0, 0.85, 0.45, 1.0};

uniform float4 spark_color<
    string label = "Spark color";
> = {1.0, 0.97, 0.85, 1.0};

uniform float spark_density<
    string label = "Amount of sparks";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.7;

uniform float spark_size<
    string label = "Spark size (px)";
    string widget_type = "slider";
    float minimum = 4.0; float maximum = 60.0; float step = 1.0;
> = 22.0;

uniform float spark_rise<
    string label = "Sparks rise (speed)";
    string widget_type = "slider";
    float minimum = -1.0; float maximum = 1.0; float step = 0.01;
> = 0.15;

uniform float twinkle<
    string label = "Twinkle speed";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 20.0; float step = 0.1;
> = 7.0;

uniform float glow_strength<
    string label = "Glow around the figure";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 2.0; float step = 0.01;
> = 0.8;

uniform float glow_size<
    string label = "Glow width (px)";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 60.0; float step = 0.5;
> = 14.0;

uniform float stripe_width<
    string label = "Dissolve stripe width (px)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 20.0; float step = 0.5;
> = 3.0;

uniform float shimmer<
    string label = "Figure shimmer";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.35;

float seg(float p, float a, float b)
{
    return saturate((p - a) / (b - a));
}

float ease(float t)
{
    return t * t * (3.0 - 2.0 * t);
}

// Dave Hoskins hash (no sin(), stable with large numbers)
float hash12(float2 p)
{
    float3 p3 = p.xyx * 0.1031;
    p3 = p3 - floor(p3);
    p3 += dot(p3, p3.yzx + 33.33);
    float h = (p3.x + p3.y) * p3.z;
    return h - floor(h);
}

float alphaAt(float2 tc)
{
    if (tc.x < 0.0 || tc.x > 1.0 || tc.y < 0.0 || tc.y > 1.0)
        return 0.0;
    return image.SampleLevel(textureSampler, tc, 0.0).a;
}

// One layer of sparkles: one spark per cell, with a core and a four-armed cross. It only
// lights up if the silhouette is there (1 read, at the center of the spark).
float sparkLayer(float2 pixel, float cellPx, float amount, float t, float salt)
{
    float2 g = pixel / cellPx;
    g.y += t * spark_rise * 3.0;                                // rise (or fall)
    float2 cell = floor(g);
    float2 f = g - cell;

    float h = hash12(cell + salt);
    if (h > amount)
        return 0.0;
    float h2 = hash12(cell * 1.7 + salt + 3.1);
    float h3 = hash12(cell * 2.3 + salt + 7.9);

    float2 c = 0.25 + 0.5 * float2(h2, h3);                     // spark center within the cell
    float2 cpx = (cell + c);
    cpx.y -= t * spark_rise * 3.0;
    float mask = alphaAt(cpx * cellPx * uv_pixel_interval);
    if (mask < 0.05)
        return 0.0;

    // Twinkle: short pulses with their own phase and rate
    float w = sin(t * twinkle * (0.6 + 0.8 * h2) + h3 * 6.2831853);
    float on = pow(saturate(w), 3.0);

    float2 d = (f - c) * cellPx;                                // in pixels
    float r = cellPx * 0.5;
    float core = exp(-dot(d, d) / (r * r * 0.035));
    float arms = exp(-abs(d.x) / (r * 0.07)) * exp(-abs(d.y) / (r * 0.8))
               + exp(-abs(d.y) / (r * 0.07)) * exp(-abs(d.x) / (r * 0.8));
    return (core + 0.6 * arms) * on * mask;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float t = elapsed_time;
    float2 px = uv_pixel_interval;
    float2 pixel = uv * uv_size;

    float p = auto_play ? frac(t / max(duration, 0.5)) : saturate(progress * 0.01);
    if (reverse)
        p = 1.0 - p;

    // Timeline
    float sparks = ease(seg(p, 0.0, 0.15)) * (1.0 - ease(seg(p, 0.70, 0.95)));
    float burst = 1.0 + 0.6 * sin(3.14159265 * seg(p, 0.25, 0.75));         // and denser
    float glowIn = ease(seg(p, 0.10, 0.40)) * (1.0 - ease(seg(p, 0.45, 0.72)));
    float tint = ease(seg(p, 0.10, 0.40));
    float dissolve = seg(p, 0.30, 0.70);

    // Figure with a horizontal shimmer that grows with the energy
    float wob = shimmer * tint * (1.0 - dissolve * 0.5);
    float2 tc = uv;
    tc.x += sin(uv.y * 90.0 + t * 25.0) * 1.5 * px.x * wob
          + (hash12(float2(floor(pixel.y / 2.0), floor(t * 30.0))) - 0.5) * 2.0 * px.x * wob;
    float4 src = image.Sample(textureSampler, tc);

    // Dissolve into vertical stripes: each stripe has its own threshold and a bit of grain
    float stripe = hash12(float2(floor(pixel.x / stripe_width), 11.0));
    float grain = hash12(floor(pixel / 2.0) + floor(t * 20.0));
    float n = 0.75 * stripe + 0.25 * grain;
    float vis = smoothstep(dissolve - 0.08, dissolve + 0.02, n);
    if (dissolve <= 0.0)
        vis = 1.0;
    if (dissolve >= 1.0)
        vis = 0.0;
    float edge = (dissolve > 0.0 && dissolve < 1.0) ? (1.0 - abs(vis * 2.0 - 1.0)) : 0.0;

    float3 fig = lerp(src.rgb, src.rgb * 0.4 + beam_color.rgb * 0.9, tint * 0.75);
    float figA = src.a * vis;

    // Glow around: alpha averaged over 4 points (also inside the figure)
    float2 go = glow_size * px * 0.7071;
    float m = (alphaAt(uv + go) + alphaAt(uv - go)
             + alphaAt(uv + float2(go.x, -go.y)) + alphaAt(uv + float2(-go.x, go.y))) * 0.25;
    float halo = max(m, src.a) * glowIn * glow_strength * (0.85 + 0.15 * sin(t * 13.0));

    // Sparkles: two layers of different size
    float amt = saturate(spark_density * burst) * saturate(sparks * 2.0);
    float sp = sparkLayer(pixel, spark_size, amt, t, 0.0)
             + 0.7 * sparkLayer(pixel, spark_size * 0.55, amt * 0.8, t * 1.3, 41.0);
    sp *= sparks * (1.0 + 1.5 * sin(3.14159265 * seg(p, 0.25, 0.75)));   // more sparks while dissolving

    // Added light (premultiplied) over the figure
    float3 light = beam_color.rgb * (halo * 0.6 + edge * src.a * 1.5) + spark_color.rgb * sp * 1.6;
    float lightA = saturate(max(light.r, max(light.g, light.b)));

    float3 prem = fig * figA + light;
    float alpha = saturate(figA + lightA * (1.0 - figA));
    return float4(saturate(prem / max(alpha, 0.0001)), alpha);
}
