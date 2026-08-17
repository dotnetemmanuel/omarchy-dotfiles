-- Extra autostart processes.

local home = os.getenv("HOME")

o.launch_on_start(home .. "/.local/bin/jetbrains-toolbox-positioner")

-- omacal's own XDG autostart entry is masked in systemd so this can replace it.
o.launch_on_start(home .. "/.local/bin/omacal-tray-start")
