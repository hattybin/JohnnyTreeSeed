data:extend({
    {
        type = "bool-setting",
        name = "johnny-tree-seed-enabled",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "a"
    },
    {
        type = "int-setting",
        name = "johnny-tree-seed-radius",
        setting_type = "runtime-per-user",
        default_value = 2,
        minimum_value = 1,
        maximum_value = 5,
        order = "b"
    },
    {
        type = "int-setting",
        name = "johnny-tree-seed-cooldown",
        setting_type = "runtime-per-user",
        default_value = 30,
        minimum_value = 10,
        maximum_value = 300,
        order = "c"
    },
    {
        type = "string-setting",
        name = "johnny-tree-seed-mode",
        setting_type = "runtime-per-user",
        default_value = "conservative",
        allowed_values = {"conservative", "aggressive", "planet-adaptive"},
        order = "d"
    }
})