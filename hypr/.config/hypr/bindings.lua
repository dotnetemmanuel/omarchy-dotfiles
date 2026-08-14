-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Paths are resolved here: bind actions are single-quoted, so $HOME never expands.
local home = os.getenv("HOME")

hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Editor", { launch = "zeditor" })

hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + SHIFT + D", "Discord", { webapp = "https://discord.com/channels/@me" })

hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Area to clipboard", home .. "/.local/bin/area-to-clipboard")

o.bind("SUPER + SHIFT + J", "jotter", { focus = "^dev.jotter.Jotter$", launch = home .. "/.local/bin/jotter" })

hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Calendar", { focus = "^Omacal$", launch = home .. "/.local/bin/omacal" })
