-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

local portrait = "desc:Lenovo Group Limited LEN T25d-10 VKDX1960"
local samsung = "desc:Samsung Electric Company U32R59x H1AK500000"
-- The built-in panel is matched by connector: desc matching silently fails to apply for it.
local laptop = "eDP-1"

-- Left to right: Lenovo T25d-10 in portrait, Samsung 32 inch, laptop panel.
hl.monitor({ output = portrait, mode = "1920x1200@59.95", position = "0x0", scale = 1, transform = 3 })
hl.monitor({ output = samsung, mode = "3840x2160@60", position = "1200x96", scale = 1.25 })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "4272x460", scale = 1.2 })

-- Persistent so all nine stay in the bar instead of appearing only once used.
for _, workspace in ipairs({ "1", "2", "3" }) do
  hl.workspace_rule({ workspace = workspace, monitor = portrait, persistent = true })
end

for _, workspace in ipairs({ "4", "5", "6" }) do
  hl.workspace_rule({ workspace = workspace, monitor = samsung, persistent = true })
end

for _, workspace in ipairs({ "7", "8", "9" }) do
  hl.workspace_rule({ workspace = workspace, monitor = laptop, persistent = true })
end
