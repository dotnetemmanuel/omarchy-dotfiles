-- Extra autostart processes.

local home = os.getenv("HOME")

o.launch_on_start(home .. "/.local/bin/jetbrains-toolbox-positioner")
