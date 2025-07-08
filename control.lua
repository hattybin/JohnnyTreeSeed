-- UPS-Optimized JonnyTreeSeed Control.lua
local MOD_NAME = "JonnyTreeSeed"

-- Performance tracking with better throttling
local player_data = {}
local last_plant_tick = {}
local mod_tick_counter = 0

-- Reduced update frequency for better UPS
local SETTINGS_UPDATE_INTERVAL = 600 -- 10 seconds instead of 5
local GLOBAL_THROTTLE_INTERVAL = 5   -- Process every 5th tick

-- Planet-specific configurations (unchanged)
local planet_configs = {
    ["nauvis"] = {
        seed_items = {"tree-seed"},
        tree_entities = {"tree-01", "tree-02", "tree-03", "tree-04", "tree-05"},
        suitable_tiles = {
            ["grass-1"] = true, ["grass-2"] = true, ["grass-3"] = true, ["grass-4"] = true,
            ["dirt-1"] = true, ["dirt-2"] = true, ["dirt-3"] = true, ["dirt-4"] = true,
            ["dirt-5"] = true, ["dirt-6"] = true, ["dirt-7"] = true
        }
    },
    ["gleba"] = {
        seed_items = {"yumako-seed", "jellynut-seed"},
        tree_entities = {"yumako-tree", "jellynut-tree"},
        suitable_tiles = {
            ["natural-yumako-soil"] = true,
            ["artificial-yumako-soil"] = true,
            ["natural-jellynut-soil"] = true,
            ["artificial-jellynut-soil"] = true,
            ["overgrowth-yumako-soil"] = true,
            ["overgrowth-jellynut-soil"] = true
        }
    },
    ["vulcanus"] = {
        seed_items = {"tree-seed"},
        tree_entities = {"tree-01"},
        suitable_tiles = {
            ["volcanic-ash-light"] = true,
            ["volcanic-ash-dark"] = true
        }
    },
    ["fulgora"] = {
        seed_items = {"tree-seed"},
        tree_entities = {"tree-01"},
        suitable_tiles = {}
    },
    ["aquilo"] = {
        seed_items = {"tree-seed"},
        tree_entities = {"tree-01"},
        suitable_tiles = {}
    }
}

-- Initialize player data
local function initialize_player_data(player_index)
    player_data[player_index] = {
        enabled = true,
        radius = 2,
        cooldown = 30,
        mode = "conservative",
        last_settings_update = 0,
        surface_config = nil -- Cache surface config
    }
    last_plant_tick[player_index] = 0
end

-- Update player settings cache (less frequent)
local function update_player_settings(player_index)
    local player = game.get_player(player_index)
    if not player then return end
    
    local settings = player.mod_settings
    local data = player_data[player_index]
    
    data.enabled = settings["johnny-tree-seed-enabled"].value
    data.radius = settings["johnny-tree-seed-radius"].value
    data.cooldown = settings["johnny-tree-seed-cooldown"].value
    data.mode = settings["johnny-tree-seed-mode"].value
    data.last_settings_update = game.tick
    
    -- Clear surface config cache when settings change
    data.surface_config = nil
end

-- Cached planet configuration lookup
local function get_planet_config(player_index, surface_name)
    local data = player_data[player_index]
    if not data.surface_config then
        local planet_name = surface_name
        for planet, config in pairs(planet_configs) do
            if string.find(surface_name, planet) then
                planet_name = planet
                break
            end
        end
        data.surface_config = planet_configs[planet_name] or planet_configs["nauvis"]
    end
    return data.surface_config
end

-- Optimized position validation (combine checks)
local function is_valid_planting_position(surface, position, config)
    -- Check tile first (fastest)
    local tile = surface.get_tile(position)
    if not tile or not tile.valid then return false end
    
    local tile_name = tile.name
    if not config.suitable_tiles[tile_name] then return false end
    
    -- Then check for blocking entities
    local entities = surface.find_entities_filtered{
        position = position,
        radius = 0.6,
        type = {"tree", "rock", "simple-entity", "cliff"},
        limit = 1 -- Stop after finding one
    }
    return #entities == 0
end

-- Optimized seed checking with early exit
local function get_available_seed(player, config)
    local main_inventory = player.get_main_inventory()
    if not main_inventory then return nil end
    
    -- Check most common seed first
    for _, seed_item in pairs(config.seed_items) do
        if main_inventory.get_item_count(seed_item) > 0 then
            return seed_item
        end
    end
    return nil
end

-- Optimized tree type selection
local function select_tree_type(seed_item, config)
    if seed_item == "yumako-seed" then
        return "yumako-tree"
    elseif seed_item == "jellynut-seed" then
        return "jellynut-tree"
    else
        return config.tree_entities[math.random(#config.tree_entities)]
    end
end

-- Plant tree at position
local function plant_tree(player, position, seed_item, config)
    local surface = player.surface
    
    -- Validate position
    if not is_suitable_tile(surface, position, config) then
        return false
    end
    
    if not position_is_clear(surface, position) then
        return false
    end
    
    -- Create tree sapling instead of full tree
    local sapling = surface.create_entity{
        name = "tree-seed-sapling",  -- This is the sapling entity
        position = position,
        force = "neutral"
    }
    
    if sapling then
        -- Remove seed from inventory
        local main_inventory = player.get_main_inventory()
        main_inventory.remove({name = seed_item, count = 1})
        
        return true
    end
    
    return false
end

-- Optimized position generation
local function get_planting_positions(player_position, data)
    local positions = {}
    
    if data.mode == "conservative" then
        positions[1] = player_position
    elseif data.mode == "aggressive" then
        -- Limit aggressive mode to 3x3 maximum for better UPS
        local max_radius = math.min(data.radius, 3)
        for x = -max_radius, max_radius do
            for y = -max_radius, max_radius do
                positions[#positions + 1] = {
                    x = player_position.x + x,
                    y = player_position.y + y
                }
            end
        end
    else -- planet-adaptive
        -- More conservative planet-adaptive for better UPS
        positions[1] = player_position
        positions[2] = {x = player_position.x + 1, y = player_position.y}
        positions[3] = {x = player_position.x - 1, y = player_position.y}
        positions[4] = {x = player_position.x, y = player_position.y + 1}
        positions[5] = {x = player_position.x, y = player_position.y - 1}
    end
    
    return positions
end

-- Main optimized tree planting logic
local function attempt_tree_planting(player_index, player_position)
    local player = game.get_player(player_index)
    if not player or not player.valid then return end
    
    local data = player_data[player_index]
    if not data or not data.enabled then return end
    
    local current_tick = game.tick
    
    -- Check cooldown
    if current_tick - last_plant_tick[player_index] < data.cooldown then
        return
    end
    
    local surface = player.surface
    local config = get_planet_config(player_index, surface.name)
    
    -- Early exit if no suitable tiles
    if not next(config.suitable_tiles) then
        return
    end
    
    -- Early exit if no seeds
    local seed_item = get_available_seed(player, config)
    if not seed_item then return end
    
    -- Get positions to check
    local positions = get_planting_positions(player_position, data)
    
    -- Try to plant (limit attempts for UPS)
    for i = 1, math.min(#positions, 5) do -- Max 5 attempts
        if plant_tree(player, positions[i], seed_item, config) then
            last_plant_tick[player_index] = current_tick
            return -- Success, exit early
        end
    end
end

-- Optimized event handler with global throttling
script.on_event(defines.events.on_player_changed_position, function(event)
    -- Global throttle to reduce overall processing
    mod_tick_counter = (mod_tick_counter + 1) % GLOBAL_THROTTLE_INTERVAL
    if mod_tick_counter ~= 0 then return end
    
    local player_index = event.player_index
    local player = game.get_player(player_index)
    
    if not player or player.controller_type ~= defines.controllers.character then
        return
    end
    
    -- Initialize player data if needed
    if not player_data[player_index] then
        initialize_player_data(player_index)
        update_player_settings(player_index)
    end
    
    local data = player_data[player_index]
    
    -- Update settings less frequently
    if game.tick - data.last_settings_update > SETTINGS_UPDATE_INTERVAL then
        update_player_settings(player_index)
    end
    
    attempt_tree_planting(player_index, player.position)
end)

-- Other event handlers (unchanged)
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    if event.setting_type == "runtime-per-user" then
        update_player_settings(event.player_index)
    end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    initialize_player_data(event.player_index)
    update_player_settings(event.player_index)
end)

script.on_event(defines.events.on_player_left_game, function(event)
    local player_index = event.player_index
    player_data[player_index] = nil
    last_plant_tick[player_index] = nil
end)

script.on_init(function()
    for _, player in pairs(game.players) do
        initialize_player_data(player.index)
        update_player_settings(player.index)
    end
end)

script.on_load(function()
    player_data = player_data or {}
    last_plant_tick = last_plant_tick or {}
    mod_tick_counter = mod_tick_counter or 0
end)