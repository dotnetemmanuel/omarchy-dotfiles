-- Personal look and feel. Blur is left at Omarchy's default (on).

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 6,
    border_size = 2,
  },

  decoration = {
    rounding = 2,
  },
})

-- Fully opaque windows: Omarchy's defaults dip these slightly.
o.window({ tag = "default-opacity" }, { opacity = "1.0 override 1.0 override" })
o.window({ tag = "terminal" }, { opacity = "1.0 override 1.0 override" })
