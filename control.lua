-- UPS-Optimized JohnnyTreeSeed Control.lua
local MOD_NAME = "JohnnyTreeSeed"

-- Performance tracking with better throttling
local player_data = {}
local last_plant_tick = {}
local mod_tick_counter = 0

-- Reduced update frequency for better UPS
local SETTINGS_UPDATE_INTERVAL = 600 -- 10 seconds instead of 5
local GLOBAL_THROTTLE_INTERVAL = 5   -- Process every 5th tick

-- Simplified planet configuration - Nauvis only
local nauvis_config = {
    seed_items = {"tree-seed"},
    suitable_tiles = {
        ["grass-1"] = true, ["grass-2"] = true, ["grass-3"] = true, ["grass-4"] = true,
        ["dirt-1"] = true, ["dirt-2"] = true, ["dirt-3"] = true, ["dirt-4"] = true,
        ["dirt-5"] = true, ["dirt-6"] = true, ["dirt-7"] = true
    }
}

-- Initialize player data
local function initialize_player_data(player_index)
    player_data[player_index] = {
        enabled = true,
        radius = 2,
        cooldown = 30,
        mode = "conservative",
        last_settings_update = 0
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
end

-- Check if current surface is Nauvis
local function is_nauvis(surface_name)
    return string.find(surface_name, "nauvis") ~= nil
end

-- Optimized position validation (combine checks)
local function is_valid_planting_position(surface, position)
    -- Check tile first (fastest)
    local tile = surface.get_tile(position)
    if not tile or not tile.valid then return false end
    
    local tile_name = tile.name
    if not nauvis_config.suitable_tiles[tile_name] then return false end
    
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
local function get_available_seed(player)
    local main_inventory = player.get_main_inventory()
    if not main_inventory then return nil end
    
    -- Only check for tree-seed on Nauvis
    if main_inventory.get_item_count("tree-seed") > 0 then
        return "tree-seed"
    end
    return nil
end

-- Plant tree at position
local function plant_tree(player, position)
    local surface = player.surface
    
    -- Validate position
    if not is_valid_planting_position(surface, position) then
        return false
    end
    
    -- Create tree plant (sapling) - this is what manual planting creates
    local tree_plant = surface.create_entity{
        name = "tree-plant",
        position = position,
        force = "neutral"
    }
    
    if tree_plant then
        -- Remove seed from inventory
        local main_inventory = player.get_main_inventory()
        main_inventory.remove({name = "tree-seed", count = 1})
        
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
    else -- planet-adaptive (same as conservative on Nauvis)
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
    
    -- Only work on Nauvis
    if not is_nauvis(surface.name) then
        return
    end
    
    -- Early exit if no seeds
    local seed_item = get_available_seed(player)
    if not seed_item then return end
    
    -- Get positions to check
    local positions = get_planting_positions(player_position, data)
    
    -- Try to plant (limit attempts for UPS)
    for i = 1, math.min(#positions, 5) do -- Max 5 attempts
        if plant_tree(player, positions[i]) then
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