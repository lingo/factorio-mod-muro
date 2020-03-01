data:extend({
    {
        type          = "int-setting",
        name          = "muro-wall-builder-thickness",
        default_value = 1,
        minimum_value = 1,
        setting_type  = "runtime-per-user",
        order         = 'a[muro-wall-builder-settings]'
    },
    {
        type          = "int-setting",
        name          = "muro-wall-builder-alt-thickness",
        default_value = 2,
        minimum_value = 1,
        setting_type  = "runtime-per-user",
        order         = 'b[muro-wall-builder-settings]'
    },
    {
        type          = "bool-setting",
        name          = "muro-wall-builder-cheat",
        default_value = false,
        setting_type  = "runtime-per-user",
        order         = 'd[muro-wall-builder-settings]'
    },
    {
        type          = "bool-setting",
        name          = "muro-wall-builder-wall-name",
        default_value = 'stone-wall',
        setting_type  = "runtime-per-user",
        order         = 'd[muro-wall-builder-settings]'
    },
    {
        type          = "bool-setting",
        name          = "muro-wall-builder-deconstruct",
        default_value = true,
        setting_type  = "runtime-per-user",
        order         = 'c[muro-wall-builder-settings]'
    },
})
