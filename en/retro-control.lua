--[[
  retro-control.lua — plays the obs-retro-tv effects (time-tunnel.shader, dimension.shader,
  teleporter.shader) once, from a button or a hotkey.

  Why it is needed: the shader only knows the time since the filter was created, so on its own
  it can only loop. This script turns the loop off and moves the Progress slider from 0 to 100
  over the duration set in the filter.

  Usage: Tools → Scripts → "+" → pick this file. Choose the filter in the list and press
  "Play". For a hotkey: Settings → Hotkeys → "Play effect (obs-retro-tv)".
]]

obs = obslua

local SHADER_FILTER_ID = "shader_filter"
local SHADER_PATTERN = { "tunel", "tunnel", "dimension", "teletrans", "teleport" }
local TICK_MS = 16

local g_target = ""
local g_first_target = ""
local g_hotkey = obs.OBS_INVALID_HOTKEY_ID
local g_playing = false
local g_play_target = ""   -- filter locked in when playback starts
local g_start_ns = 0
local g_duration = 8.0

local function log(msg)
    obs.script_log(obs.LOG_INFO, msg)
end

-- Only looks at the file name, not the folder (a folder named "tunnel" does not count)
local function is_intro_shader(path)
    local name = path:match("[^/\\]+$") or path
    for _, pat in ipairs(SHADER_PATTERN) do
        if name:find(pat, 1, true) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Filter lookup
---------------------------------------------------------------------------

local function scan_source(src, list, seen)
    local sname = obs.obs_source_get_name(src)
    if sname == nil or seen[sname] then return end
    seen[sname] = true

    local filters = obs.obs_source_enum_filters(src)
    if filters == nil then return end
    for _, f in ipairs(filters) do
        if obs.obs_source_get_unversioned_id(f) == SHADER_FILTER_ID then
            local fs = obs.obs_source_get_settings(f)
            local file = obs.obs_data_get_string(fs, "shader_file_name") or ""
            obs.obs_data_release(fs)
            if is_intro_shader(file:lower()) then
                local fname = obs.obs_source_get_name(f)
                local value = sname .. "\t" .. fname
                obs.obs_property_list_add_string(list, sname .. "  →  " .. fname, value)
                if g_first_target == "" then g_first_target = value end
            end
        end
    end
    obs.source_list_release(filters)
end

local function fill_targets(list)
    obs.obs_property_list_clear(list)
    g_first_target = ""
    local seen = {}

    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, s in ipairs(sources) do scan_source(s, list, seen) end
        obs.source_list_release(sources)
    end

    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
        for _, s in ipairs(scenes) do scan_source(s, list, seen) end
        obs.source_list_release(scenes)
    end
end

-- Returns the chosen filter (release it with obs_source_release) or nil
local function current_target()
    return g_target ~= "" and g_target or g_first_target
end

local function get_filter(target)
    target = target or current_target()
    local sname, fname = target:match("^(.-)\t(.*)$")
    if sname == nil then return nil end
    local src = obs.obs_get_source_by_name(sname)
    if src == nil then return nil end
    local f = obs.obs_source_get_filter_by_name(src, fname)
    obs.obs_source_release(src)
    return f
end

local function set_progress(f, value, stop_loop)
    local s = obs.obs_source_get_settings(f)
    if stop_loop then obs.obs_data_set_bool(s, "auto_play", false) end
    obs.obs_data_set_double(s, "progress", value)
    obs.obs_source_update(f, s)
    obs.obs_data_release(s)
end

---------------------------------------------------------------------------
-- Playback
---------------------------------------------------------------------------

local function tick()
    if not g_playing then
        obs.remove_current_callback()
        return
    end
    local f = get_filter(g_play_target)
    if f == nil then
        g_playing = false
        obs.remove_current_callback()
        return
    end
    local elapsed = (obs.os_gettime_ns() - g_start_ns) / 1e9
    local pct = math.min(elapsed / g_duration * 100.0, 100.0)
    set_progress(f, pct, false)
    obs.obs_source_release(f)
    if pct >= 100.0 then
        g_playing = false
        obs.remove_current_callback()
    end
end

local function play()
    local f = get_filter()
    if f == nil then
        log("No filter selected. Add time-tunnel.shader, dimension.shader or teleporter.shader to a source and press Refresh list.")
        return
    end
    local s = obs.obs_source_get_settings(f)
    local d = obs.obs_data_get_double(s, "duration")
    obs.obs_data_release(s)
    -- obs-shaderfilter registers the shader defaults when it loads it; this only covers the rare
    -- case where the filter has not updated yet and 0 comes back
    g_duration = (d and d > 0) and d or 8.0

    set_progress(f, 0.0, true)
    obs.obs_source_release(f)

    if g_playing then obs.timer_remove(tick) end
    g_playing = true
    g_play_target = current_target()
    g_start_ns = obs.os_gettime_ns()
    obs.timer_add(tick, TICK_MS)
end

---------------------------------------------------------------------------
-- Standard values of emblem.shader (transition)
---------------------------------------------------------------------------

-- Shader parameters that go back to their standard value. The PNG image is not cleared:
-- with Silhouette = Bat (the standard) it is simply not used.
local EMBLEM_KEYS = { "shape", "emblem_color", "emblem_size", "peak_size", "spin_turns",
                      "blur_deg", "zoom_part", "points", "star_depth" }

local function reset_emblem()
    local transitions = obs.obs_frontend_get_transitions()
    if transitions == nil then return end
    local count = 0
    for _, t in ipairs(transitions) do
        local s = obs.obs_source_get_settings(t)
        local file = obs.obs_data_get_string(s, "shader_file_name") or ""
        local name = (file:match("[^/\\]+$") or file):lower()
        if name:find("emblem", 1, true) then
            for _, k in ipairs(EMBLEM_KEYS) do obs.obs_data_unset_user_value(s, k) end
            obs.obs_source_update(t, s)
            count = count + 1
            log("Standard values restored on transition '" .. obs.obs_source_get_name(t) .. "'")
        end
        obs.obs_data_release(s)
    end
    obs.source_list_release(transitions)
    if count == 0 then log("No transitions use emblem.shader.") end
end

local function reset()
    g_playing = false
    local f = get_filter()
    if f ~= nil then
        set_progress(f, 0.0, true)
        obs.obs_source_release(f)
    end
end

---------------------------------------------------------------------------
-- Script UI
---------------------------------------------------------------------------

function script_description()
    return "Plays the <b>obs-retro-tv</b> effects (time-tunnel.shader, dimension.shader, teleporter.shader) once " ..
           "from a button or a hotkey. Turns the filter loop off and animates its Progress from 0 to 100.<br>" ..
           "It also restores the <b>emblem.shader</b> transition to its standard values."
end

function script_properties()
    local props = obs.obs_properties_create()
    local list = obs.obs_properties_add_list(props, "target", "Filter",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    fill_targets(list)

    obs.obs_properties_add_button(props, "refresh", "Refresh list", function(p, _)
        fill_targets(obs.obs_properties_get(p, "target"))
        return true
    end)
    obs.obs_properties_add_button(props, "play", "Play", function() play(); return false end)
    obs.obs_properties_add_button(props, "reset", "Back to start (Progress 0)", function() reset(); return false end)
    obs.obs_properties_add_button(props, "reset_emblem", "Restore emblem standard values (transition)",
        function() reset_emblem(); return false end)
    return props
end

function script_update(settings)
    g_target = obs.obs_data_get_string(settings, "target") or ""
end

function script_load(settings)
    g_target = obs.obs_data_get_string(settings, "target") or ""
    g_hotkey = obs.obs_hotkey_register_frontend("obs_retro_tv_play", "Play effect (obs-retro-tv)",
        function(pressed) if pressed then play() end end)
    local saved = obs.obs_data_get_array(settings, "obs_retro_tv_play")
    obs.obs_hotkey_load(g_hotkey, saved)
    obs.obs_data_array_release(saved)
end

function script_save(settings)
    local saved = obs.obs_hotkey_save(g_hotkey)
    obs.obs_data_set_array(settings, "obs_retro_tv_play", saved)
    obs.obs_data_array_release(saved)
end

function script_unload()
    g_playing = false
end
