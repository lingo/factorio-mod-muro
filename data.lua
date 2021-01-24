
data:extend({
  {
    type = "selection-tool",
    name = "muro-wall-builder",
    icon = "__muro__/graphics/muro.png",
    icon_size = 32,
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[muro-wall-builder]",
    flags = {"hidden", "only-in-cursor"},
    selection_color = {r = 0.2, g = 0.8, b = 0.2, a = 0.2},
    alt_selection_color = {r = 0.2, g = 0.2, b = 0.8, a = 0.2},
    selection_mode = {"any-tile"},
    alt_selection_mode = {"any-tile"},
    always_include_tiles = true,
    selection_cursor_box_type = "entity",
    alt_selection_cursor_box_type = "entity",
    entity_filters = {},
    entity_filter_mode = "whitelist",
    show_in_library = true
  },
  {
    type = "custom-input",
    name = "muro-wall-builder",
    key_sequence = "CONTROL + W",
  },
  {
    type = "shortcut",
    action = "lua",
    name = "muro-wall-builder",
    order = "c[automated-construction]-d[muro-wall-builder]",
    icon = {
      filename = "__muro__/graphics/muro_quickbar.png",
      priority = "extra-high-no-scale",
      size = 24,
      scale = 1,
      flags = {"icon"}
    },
    toggleable = false,
    associated_control_input = "muro-wall-builder",
  },
})

