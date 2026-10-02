data:extend({
  {
    type = "selection-tool",
    name = "muro-wall-builder",
    icon = "__muro__/graphics/muro.png",
    icon_size = 32,
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[muro-wall-builder]",
    hidden = true,
    flags = {"only-in-cursor"},
    select = {
      border_color = {r = 0.2, g = 0.8, b = 0.2, a = 0.2},
      cursor_box_type = "entity",
      mode = {"any-tile"},
      entity_filters = {},
      entity_filter_mode = "whitelist",
    },
    alt_select = {
      border_color = {r = 0.2, g = 0.2, b = 0.8, a = 0.2},
      cursor_box_type = "entity",
      mode = {"any-tile"},
      entity_filters = {},
      entity_filter_mode = "whitelist",
    },
    always_include_tiles = true,
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
    icon = "__muro__/graphics/muro_quickbar.png",
    icon_size = 24,
    small_icon = "__muro__/graphics/muro_quickbar.png",
    small_icon_size = 24,
    toggleable = false,
    associated_control_input = "muro-wall-builder",
  },
})

