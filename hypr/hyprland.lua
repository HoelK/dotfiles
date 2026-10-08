-- DOC : https://wiki.hypr.land/configuring/

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/configuring/core/monitors/

-- Most laptops
hl.monitor({
    output		= "eDP-1",
    mode		= "1920x1080@60",
    position	= "0x0",
    scale		= 1,
})

-- Default mirror fallback
hl.monitor({
	output		= "",
	mode		= "preferred",
	position	= "0x0",
	scale		= 1,
	mirror		= "eDP-1"
})

---------------------
------ PROGRAMS -----
---------------------

local terminal		= "kitty"
local browser		= "firefox"
local statusbar		= "waybar"
local WPengine		= "hyprpaper"
local lockscreen	= "hyprlock"
local screenshot	= "hyprshot -m region"
local logmenu		= "wlogout -b 3 -c 20 -T 400 -B 300 -L 300 -R 400"

-------------------
---- AUTOSTART ----
-------------------

-- DOC : https://wiki.hypr.land/configuring/core/autostart/

hl.on("hyprland.start", function () 
  hl.exec_cmd(WPengine)
  hl.exec_cmd(statusbar)
  hl.exec_cmd(terminal)
  hl.exec_cmd("gammastep -m wayland -b 0.6:0.6 -l 0:0")
end)

-------------------------------
------------ ENV --------------
-------------------------------

-- DOC : https://wiki.hypr.land/configuring/core/environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- DOC : https://wiki.hypr.land/configuring/core/config-options/

hl.config({
    general = {
        gaps_in		= 5,
        gaps_out	= 10,
        border_size	= 2,

        col		= {
            active_border	= "rgba(33ccffee)",
            inactive_border	= "rgba(595959aa)",
        },

        resize_on_border	= false,
        allow_tearing		= false,
        layout				= "dwindle",
    },

    decoration	= {
        rounding			= 10,
        rounding_power		= 2,

        active_opacity		= 1.0,
        inactive_opacity	= 1.0,

        shadow	= {
            enabled			= true,
            range			= 4,
            render_power	= 3,
            color			= 0xee1a1a1a,
        },

        blur	= {
            enabled			= true,
            size			= 3,
            passes			= 1,
            vibrancy		= 0.1696,
        },
    },

    animations = { enabled = true, },
})

-- DOC : https://wiki.hypr.land/configuring/core/animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 0.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- DOC : https://wiki.hypr.land/configuring/layouts/dwindle-layout/
hl.config({ dwindle = { preserve_split = true, }, })

-- DOC : https://wiki.hypr.land/configuring/layouts/master-layout/
hl.config({ master = { new_status = "master", }, })

-- DOC : https://wiki.hypr.land/configuring/layouts/scrolling-layout/
hl.config({ scrolling = { fullscreen_on_one_column = true, }, })

----------------
----  MISC  ----
----------------

hl.config({ misc = {
	disable_hyprland_logo = true,
}})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
		-- Keyboard
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

		-- Mouse
        follow_mouse = 1,
        sensitivity = 0,

        touchpad = { natural_scroll = false },
    },
})

---------------------
---- KEYBINDINGS ----
---------------------
-- DOC : https://wiki.hypr.land/configuring/core/binds/

local mainMod = "SUPER"
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lockscreen))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(logmenu))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind("F10", hl.dsp.exec_cmd(screenshot))

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end


----------------------
---- WINDOW RULES ----
----------------------
-- DOC : https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

---------------------
------ LAYERS -------
---------------------

hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })
