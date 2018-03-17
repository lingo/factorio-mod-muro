
data:extend({
  {
    type = "selection-tool",
    name = "muro-wall-builder",
    icon = "__muro__/graphics/muro.png",
    icon_size = 32,
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[muro-wall-builder]",
    flags = {"goes-to-quickbar"},
    selection_color = {r = 0.2, g = 0.8, b = 0.2, a = 0.2},
    alt_selection_color = {r = 0.2, g = 0.2, b = 0.8, a = 0.2},
    selection_mode = {"items-to-place"},
    always_include_tiles = true,
    alt_selection_mode = {"items-to-place"},
    selection_cursor_box_type = "entity",
    alt_selection_cursor_box_type = "entity"
  },
  {
    type = "recipe",
    name = "muro-wall-builder",
    enabled = true,
    energy_required = 0.5,
    ingredients =
    {
        {'stone-wall',4},
        {'electronic-circuit', 1}
    },
    result = "muro-wall-builder"
  },
})

data:extend{
  {
    type = "custom-input",
    name = "muro-wall-builder",
    key_sequence = "CONTROL + W",
  },
}


