-- =======================================================================
-- 1. CHARGEMENT DE LA CONFIGURATION DES SONS (JSON)
-- =======================================================================

local modpath = minetest.get_modpath(minetest.get_current_modname())

local file = io.open(modpath .. "/sounds.json", "r")
local json_data = "{}" 
if file then
    json_data = file:read("*all")
    file:close()
end

local block_sounds = minetest.parse_json(json_data) or {}

-- Fonction utilitaire pour récupérer les configs du JSON
local function get_json_config(node_name)
    if not node_name then return nil end
    if block_sounds[node_name] then
        return block_sounds[node_name]
    end
    if node_name == "core:dirt_slab" then
        return block_sounds["core:dirt"]
    end
    if node_name == "core:stone_slab" then
        return block_sounds["core:stone"]
    end
    if node_name == "core:sand" then
        return block_sounds["core:stone"]
    end
    if node_name == "core:snow_block" then
        return block_sounds["core:dirt"]
    end
    if node_name == "core:cactus" then
        return block_sounds["core:stone"]
    end
    if node_name:find("^core:grass_slab") then
        return block_sounds["core:grass"] or block_sounds["core:dirt"]
    end
    if node_name == "core:voltstone" or node_name == "core:gold" or node_name == "core:coat" then
        return block_sounds["core:stone"]
    end
    local base_name = node_name:match("^(.-)_%d+$")
    if base_name and block_sounds[base_name] then
        return block_sounds[base_name]
    end
    return nil
end

-- =======================================================================
-- 2. ENREGISTREMENT DES BLOCS, FLUIDES ET DE LA MAIN
-- =======================================================================

minetest.register_item(":", {
    type = "none",
    wield_image = "hand.png",
    tool_capabilities = {
        full_punch_interval = 0.9,
        max_drop_level = 0,
        groupcaps = {
            crumbly = {times={[2]=0.80, [3]=0.40}, uses=0, maxlevel=1},
            cracky = {times={[3]=1.50}, uses=0, maxlevel=1},
            choppy = {times={[1]=2.50, [2]=1.20, [3]=0.60}, uses=0, maxlevel=1},
            snappy = {times={[1]=1.00, [2]=0.50, [3]=0.20}, uses=0, maxlevel=1},
            oddly_breakable_by_hand = {times={[1]=3.50, [2]=2.00, [3]=0.70}, uses=0, maxlevel=3},
        },
        damage_groups = {fleshy=1},
    },
})

minetest.register_node("core:stone", {
    description = "Pierre de base",
    tiles = {"stone.png"},
    groups = {cracky = 3},
    sounds = {},
})

minetest.register_node("core:dirt", {
    description = "Terre de base",
    tiles = {"dirt.png"},
    groups = {crumbly = 3, soil = 1},
    sounds = {},
})

minetest.register_node("core:grass", {
    description = "Bloc d'herbe",
    tiles = {"grass.png", "dirt.png", "dirt.png^grass_side.png"},
    paramtype2 = "facedir",
    groups = {crumbly = 3, soil = 1},
    sounds = {},
})

-- Nouveaux blocs : Sable et Bloc de Neige (ne tombent pas)
minetest.register_node("core:sand", {
    description = "Sable du désert",
    tiles = {"sand.png"},
    groups = {crumbly = 3, soil = 1},
    sounds = {},
})

minetest.register_node("core:snow_block", {
    description = "Bloc de neige",
    tiles = {"snow.png"},
    groups = {crumbly = 3, snowy = 1},
    sounds = {},
})

-- Cactus (Bloc invisible avec grande image 2D plantlike, inflige des dégâts, incassable à main nue hors créatif, drop cactus.png)
minetest.register_node("core:cactus", {
    description = "Cactus",
    drawtype = "plantlike",
    tiles = {"cactus.png"},
    inventory_image = "cactus.png",
    wield_image = "cactus.png",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = true,
    damage_per_second = 1,
    groups = {choppy = 2, snappy = 2},
    drop = "core:cactus",
    selection_box = {
        type = "fixed",
        fixed = {-0.3, -0.5, -0.3, 0.3, 0.5, 0.3},
    },
    collision_box = {
        type = "fixed",
        fixed = {-0.3, -0.5, -0.3, 0.3, 0.5, 0.3},
    },
    on_place = function(itemstack, placer, pointed_thing)
        if not pointed_thing or pointed_thing.type ~= "node" then
            return itemstack
        end
        local under_node = minetest.get_node(pointed_thing.under)
        local above_node = minetest.get_node(pointed_thing.above)
        
        -- Placement uniquement sur un bloc de sable
        if under_node.name ~= "core:sand" then
            return itemstack
        end
        -- Ne peut pas être placé par-dessus un autre cactus
        if under_node.name == "core:cactus" or above_node.name == "core:cactus" then
            return itemstack
        end
        
        return minetest.item_place(itemstack, placer, pointed_thing)
    end,
    can_dig = function(pos, player)
        if not player or not player:is_player() then return false end
        local name = player:get_player_name()
        local privs = minetest.get_player_privs(name)
        local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative
        if is_creative then return true end
        
        local wielded = player:get_wielded_item()
        if wielded:is_empty() then
            return false
        end
        local def = wielded:get_definition()
        if def and def.tool_capabilities then
            local groupcaps = def.tool_capabilities.groupcaps
            if groupcaps and (groupcaps.choppy or groupcaps.snappy) then
                return true
            end
        end
        return false
    end,
})

-- Eau et Lave
minetest.register_node("core:water_source", {
    description = "Source d'eau",
    drawtype = "liquid",
    tiles = {"water.png"},
    alpha = 160,
    paramtype = "light",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    drop = "",
    liquidtype = "source",
    liquid_alternative_flowing = "core:water_flowing",
    liquid_alternative_source = "core:water_source",
    liquid_viscosity = 1,
    post_effect_color = {a = 103, r = 30, g = 60, b = 90},
    groups = {water = 3, liquid = 3},
})

minetest.register_node("core:water_flowing", {
    description = "Eau courante",
    drawtype = "flowingliquid",
    tiles = {"water.png"},
    alpha = 160,
    paramtype = "light",
    paramtype2 = "flowingliquid",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    drop = "",
    liquidtype = "flowing",
    liquid_alternative_flowing = "core:water_flowing",
    liquid_alternative_source = "core:water_source",
    liquid_viscosity = 1,
    post_effect_color = {a = 103, r = 30, g = 60, b = 90},
    groups = {water = 3, liquid = 3, not_in_creative_inventory = 1},
})

minetest.register_node("core:lava_source", {
    description = "Source de lave",
    drawtype = "liquid",
    tiles = {"lava.png"},
    paramtype = "light",
    light_source = 14,
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    drop = "",
    liquidtype = "source",
    liquid_alternative_flowing = "core:lava_flowing",
    liquid_alternative_source = "core:lava_source",
    liquid_viscosity = 7,
    damage_per_second = 4,
    post_effect_color = {a = 192, r = 255, g = 64, b = 0},
    groups = {lava = 3, liquid = 2, hot = 3},
})

minetest.register_node("core:lava_flowing", {
    description = "Lave courante",
    drawtype = "flowingliquid",
    tiles = {"lava.png"},
    paramtype = "light",
    paramtype2 = "flowingliquid",
    light_source = 14,
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    drop = "",
    liquidtype = "flowing",
    liquid_alternative_flowing = "core:lava_flowing",
    liquid_alternative_source = "core:lava_source",
    liquid_viscosity = 7,
    damage_per_second = 4,
    post_effect_color = {a = 192, r = 255, g = 64, b = 0},
    groups = {lava = 3, liquid = 2, hot = 3, not_in_creative_inventory = 1},
})

-- Dalles
minetest.register_node("core:dirt_slab", {
    description = "Dalle de terre",
    drawtype = "nodebox",
    tiles = {"dirt.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {crumbly = 3, soil = 1, slab = 1},
    sounds = {},
    drop = "core:dirt",
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
    },
})

minetest.register_node("core:stone_slab", {
    description = "Dalle de pierre",
    drawtype = "nodebox",
    tiles = {"stone.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {cracky = 3, slab = 1},
    sounds = {},
    drop = "core:stone",
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
    },
})

-- Minerais et items
minetest.register_node("core:voltstone", {
    description = "Minerai de Voltstone",
    tiles = {"voltstone.png"},
    groups = {cracky = 2},
    sounds = {},
    drop = "core:voltstone_item",
})

minetest.register_node("core:gold", {
    description = "Minerai d'Or",
    tiles = {"gold.png"},
    groups = {cracky = 2},
    sounds = {},
    drop = "core:gold_item",
})

minetest.register_node("core:coat", {
    description = "Minerai de Coat",
    tiles = {"coat.png"},
    groups = {cracky = 3},
    sounds = {},
    drop = "core:coat_item",
})

minetest.register_craftitem("core:voltstone_item", {
    description = "Minerai brut de Voltstone",
    inventory_image = "voltstone_item.png",
})

minetest.register_craftitem("core:gold_item", {
    description = "Minerai brut d'Or",
    inventory_image = "gold_item.png",
})

minetest.register_craftitem("core:coat_item", {
    description = "Minerai brut de Coat",
    inventory_image = "coat_item.png",
})

minetest.register_craftitem("core:stick", {
    description = "Bâton",
    inventory_image = "stick.png",
})

minetest.register_node("core:torch", {
    description = "Torche",
    drawtype = "torchlike",
    tiles = {"torch.png"},
    inventory_image = "torch.png",
    wield_image = "torch.png",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    light_source = 14,
    groups = {choppy = 2, dig_immediate = 3, attached_node = 1},
    sounds = {},
    stack_max = 36,
    drop = "core:torch",
    node_box = {
        type = "wallmounted",
        wall_installed = {-0.1, -0.5, -0.1, 0.1, -0.2, 0.1},
    },
})

-- Recettes de craft
minetest.register_craft({
    output = "core:torch 5",
    recipe = {
        {"core:coat_item"},
        {"core:stick"},
    },
})

minetest.register_craft({
    output = "core:stone_slab 6",
    recipe = {
        {"core:stone", "core:stone", "core:stone"},
    },
})

minetest.register_craft({
    output = "core:dirt_slab 6",
    recipe = {
        {"core:dirt", "core:dirt", "core:dirt"},
    },
})

-- Désactivation du craft en mode créatif
minetest.register_on_craft(function(itemstack, player, old_craft_list, craft_inv)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    local privs = minetest.get_player_privs(name)
    local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative
    if is_creative then
        itemstack:set_count(0)
        return itemstack
    end
end)

minetest.register_craftitem("core:apple", {
    description = "Pomme",
    inventory_image = "apple.png",
    stack_max = 15,
    on_use = function(itemstack, user, pointed_thing)
        if not user or not user:is_player() then return itemstack end
        
        local hp = user:get_hp()
        local max_hp = user:get_properties().hp_max or 20
        local sound_name = (math.random(1, 2) == 1) and "eat_1" or "eat_2"
        minetest.sound_play(sound_name, {object = user, gain = 0.8})
        
        if hp < max_hp then
            user:set_hp(math.min(hp + 2, max_hp))
        end
        
        itemstack:take_item()
        return itemstack
    end,
})

-- Gestion équilibrée des drops de feuilles
local function handle_leaf_drop(pos, digger)
    local is_creative = false
    if digger and digger:is_player() then
        local name = digger:get_player_name()
        local privs = minetest.get_player_privs(name)
        is_creative = minetest.settings:get_bool("creative_mode") or privs.creative
    end

    if not is_creative then
        local r = math.random(1, 100)
        if r <= 20 then
            minetest.handle_node_drops(pos, {ItemStack("core:stick")}, digger)
        elseif r <= 27 then
            minetest.handle_node_drops(pos, {ItemStack("core:apple")}, digger)
        end
    end
end

local function fell_tree(start_pos, digger)
    local is_creative = false
    if digger and digger:is_player() then
        local name = digger:get_player_name()
        local privs = minetest.get_player_privs(name)
        is_creative = minetest.settings:get_bool("creative_mode") or privs.creative
    end

    local queue = {start_pos}
    local visited = {}
    local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
    visited[key(start_pos)] = true

    local head = 1
    while head <= #queue do
        local curr = queue[head]
        head = head + 1

        for dx = -1, 1 do
            for dy = 0, 1 do
                for dz = -1, 1 do
                    if not (dx == 0 and dy == 0 and dz == 0) then
                        local np = {x = curr.x + dx, y = curr.y + dy, z = curr.z + dz}
                        local k = key(np)
                        if not visited[k] then
                            local node = minetest.get_node(np)
                            if node.name == "core:wood" or node.name == "core:leaves" then
                                visited[k] = true
                                table.insert(queue, np)
                            end
                        end
                    end
                end
            end
        end
    end

    for i = 2, #queue do
        local p = queue[i]
        local node = minetest.get_node(p)
        local nname = node.name
        minetest.remove_node(p)

        if not is_creative then
            if nname == "core:wood" then
                minetest.handle_node_drops(p, {ItemStack("core:wood")}, digger)
            elseif nname == "core:leaves" then
                handle_leaf_drop(p, digger)
            end
        end
    end
end

minetest.register_node("core:wood", {
    description = "Tronc d'arbre",
    tiles = {"wood.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2},
    sounds = {},
    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        fell_tree(pos, digger)
    end,
})

minetest.register_node("core:leaves", {
    description = "Feuilles",
    drawtype = "allfaces_optional",
    tiles = {"leaves.png"},
    paramtype = "light",
    use_texture_alpha = "clip",
    groups = {snappy = 3, flammable = 2},
    sounds = {},
    drop = "",
    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        handle_leaf_drop(pos, digger)
    end,
})

minetest.register_alias("mapgen_stone", "core:stone")

-- =======================================================================
-- 2.5 AUTO-DÉTECTION DES VARIANTES D'HERBE ET DALLES
-- =======================================================================
local grass_variants = {}
local textures_dir = modpath .. "/textures"
local files = minetest.get_dir_list(textures_dir, false)

if files then
    for _, file in ipairs(files) do
        local num_str = file:match("^grass_(%d+)%.png$")
        if num_str then
            local num = tonumber(num_str)
            table.insert(grass_variants, {id = "core:grass_" .. num, tex = file, num = num})
        end
    end
end

table.sort(grass_variants, function(a, b) return a.num < b.num end)

if #grass_variants == 0 then
    table.insert(grass_variants, {id = "core:grass_1", tex = "grass.png", num = 1})
end

local grass_slab_nodenames = {}
local slab_variant_cids = {}
local total_slab_weight = 0
local slab_weights = {}

for _, v in ipairs(grass_variants) do
    minetest.register_node(v.id, {
        description = "Bloc d'herbe (Variante " .. v.num .. ")",
        tiles = {v.tex, "dirt.png", "dirt.png^grass_side.png"},
        paramtype2 = "facedir",
        groups = {crumbly = 3, soil = 1, not_in_creative_inventory = 1},
        sounds = {},
        drop = "core:dirt",
    })

    local weight = 1000 / (2 ^ v.num)
    slab_weights[v.num] = weight
    total_slab_weight = total_slab_weight + weight

    for mask = 0, 15 do
        local xp_tex = (math.floor(mask / 1) % 2 == 1) and "dirt.png" or "grass_1.png"
        local xm_tex = (math.floor(mask / 2) % 2 == 1) and "dirt.png" or "grass_1.png"
        local zp_tex = (math.floor(mask / 4) % 2 == 1) and "dirt.png" or "grass_1.png"
        local zm_tex = (math.floor(mask / 8) % 2 == 1) and "dirt.png" or "grass_1.png"

        local slab_id = "core:grass_slab_" .. v.num .. "_" .. mask
        table.insert(grass_slab_nodenames, slab_id)

        local in_creative = (v.num == 1 and mask == 0) and 0 or 1

        minetest.register_node(slab_id, {
            description = "Dalle d'herbe",
            drawtype = "nodebox",
            tiles = {v.tex, "dirt.png", xp_tex, xm_tex, zp_tex, zm_tex},
            paramtype = "light",
            paramtype2 = "facedir",
            groups = {crumbly = 3, soil = 1, slab = 1, not_in_creative_inventory = in_creative},
            sounds = {},
            drop = "core:dirt",
            node_box = {
                type = "fixed",
                fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
            },
        })
    end
end

minetest.register_alias("core:grass_slab", "core:grass_slab_1_0")

function minetest.handle_node_drops(pos, drops, digger)
    if not digger or not digger:is_player() then
        for _, item in ipairs(drops) do
            minetest.add_item(pos, item)
        end
        return
    end

    local name = digger:get_player_name()
    local privs = minetest.get_player_privs(name)
    local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative

    if not is_creative then
        for _, item in ipairs(drops) do
            minetest.add_item(pos, item)
        end
    end
end

-- =======================================================================
-- 2.9 INVENTAIRE CRÉATIF ET FORMSPEC DYNAMIQUE
-- =======================================================================
local creative_inv = nil

local function build_creative_inventory()
    creative_inv = minetest.create_detached_inventory("core_creative", {
        allow_move = function() return 0 end,
        allow_put = function() return 0 end,
        allow_take = function(inv, listname, index, stack, player)
            local name = player:get_player_name()
            local privs = minetest.get_player_privs(name)
            local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative
            if is_creative then
                return stack:get_stack_max()
            end
            return 0
        end,
        on_take = function(inv, listname, index, stack)
            inv:set_stack(listname, index, stack)
        end,
    })

    local items = {}
    for name, def in pairs(minetest.registered_items) do
        if name ~= "" and name ~= ":" and (not def.groups or def.groups.not_in_creative_inventory ~= 1) then
            table.insert(items, name)
        end
    end
    table.sort(items)

    creative_inv:set_size("main", math.max(#items, 32))
    for i, name in ipairs(items) do
        local max_stack = ItemStack(name):get_stack_max()
        creative_inv:set_stack("main", i, ItemStack(name .. " " .. max_stack))
    end
end

local function set_player_inventory(player)
    local name = player:get_player_name()
    local privs = minetest.get_player_privs(name)
    local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative

    if is_creative then
        local formspec = "size[8,9.5]" ..
            "label[0,0.2;Menu Créatif]" ..
            "list[detached:core_creative;main;0,0.7;8,4;]" ..
            "label[0,4.9;Inventaire Joueur]" ..
            "list[current_player;main;0,5.4;8,4;]" ..
            "listring[detached:core_creative;main]" ..
            "listring[current_player;main]"
        player:set_inventory_formspec(formspec)
    else
        local formspec = "size[8,9.5]" ..
            "label[0,0.2;Fabrication]" ..
            "list[current_player;craft;2,0.7;2,2;]" ..
            "list[current_player;craftpreview;6,1.2;1,1;]" ..
            "label[0,4.9;Inventaire Joueur]" ..
            "list[current_player;main;0,5.4;8,4;]" ..
            "listring[current_player;craft]" ..
            "listring[current_player;main]"
        player:set_inventory_formspec(formspec)
    end
end

minetest.register_on_mods_loaded(function()
    build_creative_inventory()
    for _, v in ipairs(grass_variants) do
        slab_variant_cids[v.num] = {}
        for mask = 0, 15 do
            slab_variant_cids[v.num][mask] = minetest.get_content_id("core:grass_slab_" .. v.num .. "_" .. mask)
        end
    end
end)

-- =======================================================================
-- 2.10 ABMs POUR TRANSFORMATION DU DIRT
-- =======================================================================
minetest.register_abm({
    label = "Dirt to Grass Transformation",
    nodenames = {"core:dirt"},
    neighbors = {"air"},
    interval = 3.0,
    chance = 8,
    action = function(pos)
        local pos_above = {x = pos.x, y = pos.y + 1, z = pos.z}
        local node_above = minetest.get_node(pos_above)
        if node_above.name == "air" then
            minetest.set_node(pos, {
                name = "core:grass",
                param2 = math.random(0, 3)
            })
        end
    end,
})

-- =======================================================================
-- 3. MOTEUR JOUEUR (SPRINT, VOL, COLLISIONS, DÉGÂTS FEUILLES/LAVE)
-- =======================================================================
local SPRINT_SPEED = 1.6
local NORMAL_SPEED = 1.0
local DOUBLE_TAP_TIME = 0.3
local JUMP_HEIGHT_2_BLOCKS = 1.4

local player_timers = {}
local players_is_sprinting = {}
local last_keys = {}
local sprint_window_timers = {}
local creative_dig_timers = {}
local last_creative_state = {}

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        if not player or not player:is_player() then goto continue end
        local name = player:get_player_name()
        local privs = minetest.get_player_privs(name)
        local controls = player:get_player_control()
        
        if not player_timers[name] then player_timers[name] = { step = 0, dig = 0 } end
        if not players_is_sprinting[name] then players_is_sprinting[name] = false end
        if not sprint_window_timers[name] then sprint_window_timers[name] = 0 end
        if not last_keys[name] then last_keys[name] = false end
        if not creative_dig_timers[name] then creative_dig_timers[name] = { pos = nil, time = 0 } end
        
        local timers = player_timers[name]
        local physics = player:get_physics_override()
        local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative

        if last_creative_state[name] == nil or last_creative_state[name] ~= is_creative then
            last_creative_state[name] = is_creative
            set_player_inventory(player)
        end

        -- Destruction par collision rapide des feuilles
        local velocity = player:get_velocity()
        if velocity and (velocity.y < -4 or math.abs(velocity.x) > 2.5 or math.abs(velocity.z) > 2.5) then
            local p_pos = player:get_pos()
            if p_pos and p_pos.x and p_pos.y and p_pos.z then
                for dx = -1, 1 do
                    for dy = 0, 2 do
                        for dz = -1, 1 do
                            local check_pos = {
                                x = math.floor(p_pos.x + dx),
                                y = math.floor(p_pos.y + dy),
                                z = math.floor(p_pos.z + dz)
                            }
                            local node = minetest.get_node(check_pos)
                            if node and node.name == "core:leaves" then
                                minetest.dig_node(check_pos)
                            end
                        end
                    end
                end
            end
        end

        if is_creative then
            if not privs.fly or not privs.fast then
                privs.fly = true
                privs.fast = true
                minetest.set_player_privs(name, privs)
            end
            if physics.fly == false then physics.fly = true end
            physics.speed_fast = 5.0
        else
            if privs.fly or privs.fast then
                privs.fly = nil
                privs.fast = nil
                minetest.set_player_privs(name, privs)
            end
            physics.fly = false
            physics.speed_fast = 1.0
        end

        if controls.up and not last_keys[name] then
            if sprint_window_timers[name] > 0 and sprint_window_timers[name] < DOUBLE_TAP_TIME then
                players_is_sprinting[name] = true
            end
            sprint_window_timers[name] = DOUBLE_TAP_TIME
        end

        if players_is_sprinting[name] then
            if not controls.up or controls.sneak then
                players_is_sprinting[name] = false
            end
        end

        local target_speed = players_is_sprinting[name] and SPRINT_SPEED or NORMAL_SPEED
        if physics.speed ~= target_speed then physics.speed = target_speed end
        if physics.jump ~= JUMP_HEIGHT_2_BLOCKS then physics.jump = JUMP_HEIGHT_2_BLOCKS end
        
        player:set_physics_override(physics)

        if sprint_window_timers[name] > 0 then
            sprint_window_timers[name] = sprint_window_timers[name] - dtime
        end
        last_keys[name] = controls.up

        -- Bruits de pas
        local pos = player:get_pos()
        if pos and pos.x and pos.y and pos.z then
            local pos_under = {x = pos.x, y = pos.y - 0.5, z = pos.z}
            local node_under = minetest.get_node(pos_under)
            local config_under = get_json_config(node_under and node_under.name)
            
            if config_under and config_under.footstep then
                local vel = player:get_velocity()
                local is_moving = vel and vel.x and vel.z and (vel.x ~= 0 or vel.z ~= 0) and (vel.y == 0)
                
                if is_moving then
                    timers.step = timers.step + dtime
                    local step_cooldown = players_is_sprinting[name] and 0.22 or 0.35
                    if timers.step >= step_cooldown then
                        minetest.sound_play(config_under.footstep, {
                            object = player,
                            gain = config_under.gain or 0.5,
                            pitch = 0.5 + (math.random() * 1.0),
                            max_hear_distance = 10,
                        })
                        timers.step = 0
                    end
                else
                    timers.step = 0
                end
            end
        end

        if controls.LMB then
            local p_eye = player:get_pos()
            if p_eye and p_eye.x and p_eye.y and p_eye.z then
                local props = player:get_properties()
                p_eye.y = p_eye.y + (props and props.eye_height or 1.5)
                local look_dir = player:get_look_dir()
                if look_dir and look_dir.x and look_dir.y and look_dir.z then
                    local p_target = {
                        x = p_eye.x + look_dir.x * 4,
                        y = p_eye.y + look_dir.y * 4,
                        z = p_eye.z + look_dir.z * 4
                    }
                    local ray = minetest.raycast(p_eye, p_target, false, false)
                    local pointed = ray:next()
                    
                    if pointed and pointed.type == "node" then
                        local node_pointed = minetest.get_node(pointed.under)
                        local config_pointed = get_json_config(node_pointed and node_pointed.name)
                        
                        if config_pointed and config_pointed.footstep then
                            timers.dig = timers.dig + dtime
                            if timers.dig >= 0.18 then
                                minetest.sound_play(config_pointed.footstep, {
                                    pos = pointed.under,
                                    gain = (config_pointed.gain or 0.5) + 0.1,
                                    pitch = 1.0 + (math.random() * 0.5),
                                    max_hear_distance = 12,
                                })
                                timers.dig = 0
                            end
                        end

                        if is_creative and node_pointed.name ~= "air" then
                            local p_state = creative_dig_timers[name]
                            if not p_state.pos or p_state.pos.x ~= pointed.under.x or p_state.pos.y ~= pointed.under.y or p_state.pos.z ~= pointed.under.z then
                                p_state.pos = pointed.under
                                p_state.time = 0
                            else
                                p_state.time = p_state.time + dtime
                                if p_state.time >= 0.3 then
                                    minetest.node_dig(pointed.under, node_pointed, player)
                                    p_state.pos = nil
                                    p_state.time = 0
                                end
                            end
                        end
                    else
                        creative_dig_timers[name].pos = nil
                    end
                end
            end
        else
            timers.dig = 0
            if creative_dig_timers[name] then creative_dig_timers[name].pos = nil end
        end
        ::continue::
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer)
    if not placer or not placer:is_player() then return end
    local config = get_json_config(newnode and newnode.name)
    if config and config.footstep then
        minetest.sound_play(config.footstep, {
            pos = pos,
            gain = config.gain or 0.5,
            pitch = 1.0 + (math.random() * 0.5),
        })
    end
end)

minetest.register_on_player_hpchange(function(player, hp_change)
    if hp_change < 0 then
        minetest.sound_play("core_damage", {
            object = player,
            gain = 0.8,
            max_hear_distance = 10,
            pitch = 0.5 + (math.random() * 1.0),
        })
    end
    return hp_change
end, true)

-- =======================================================================
-- 4. CONFIGURATION ET GÉNÉRATION DE TERRAIN (BIOMES, EAU, LAVE)
-- =======================================================================
minetest.set_mapgen_setting("mg_name", "singlenode", true)
local mapgen_type = minetest.settings:get("core_mapgen_type") or "standard"

local noise_params = {
    offset = 10,
    scale = 15,
    spread = {x = 150, y = 150, z = 150},
    seed = 538,
    octaves = 3,
    persist = 0.5
}

local biome_noise_params = {
    offset = 0,
    scale = 1,
    spread = {x = 300, y = 300, z = 300},
    seed = 4242,
    octaves = 2,
    persist = 0.5
}

local cave_noise_params = {
    offset = 0,
    scale = 1,
    spread = {x = 35, y = 25, z = 35},
    seed = 12345,
    octaves = 3,
    persist = 0.5
}

local cave_mask_params = {
    offset = 0,
    scale = 1,
    spread = {x = 70, y = 50, z = 70},
    seed = 9999,
    octaves = 2,
    persist = 0.5
}

local forest_noise_params = {
    offset = 0,
    scale = 1,
    spread = {x = 250, y = 250, z = 250},
    seed = 89123,
    octaves = 3,
    persist = 0.5
}

minetest.register_on_generated(function(minp, maxp)
    local c_grass_base = minetest.get_content_id("core:grass")
    local c_dirt       = minetest.get_content_id("core:dirt")
    local c_stone      = minetest.get_content_id("core:stone")
    local c_stone_slab = minetest.get_content_id("core:stone_slab")
    local c_sand       = minetest.get_content_id("core:sand")
    local c_snow_block = minetest.get_content_id("core:snow_block")
    local c_cactus     = minetest.get_content_id("core:cactus")
    local c_water      = minetest.get_content_id("core:water_source")
    local c_lava       = minetest.get_content_id("core:lava_source")
    local c_air        = minetest.CONTENT_AIR
    local c_wood       = minetest.get_content_id("core:wood")
    local c_leaves     = minetest.get_content_id("core:leaves")

    local variant_cids = {}
    local total_grass_weight = 0
    if #grass_variants > 0 then
        for _, v in ipairs(grass_variants) do
            local weight = 1000 / (2 ^ v.num)
            table.insert(variant_cids, { cid = minetest.get_content_id(v.id), weight = weight })
            total_grass_weight = total_grass_weight + weight
        end
    end

    local function get_c_grass()
        if total_grass_weight == 0 then return c_grass_base end
        local r = math.random() * total_grass_weight
        for _, v in ipairs(variant_cids) do
            r = r - v.weight
            if r <= 0 then return v.cid end
        end
        return c_grass_base
    end

    local function get_c_stone(y)
        if y <= -12 and math.random(1, 100) <= 8 then
            return c_lava
        end
        local r_ore = math.random(1, 1000)
        if r_ore <= 3 then return minetest.get_content_id("core:voltstone")
        elseif r_ore <= 15 then return minetest.get_content_id("core:gold")
        elseif r_ore <= 60 then return minetest.get_content_id("core:coat")
        else return c_stone end
    end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local param2_data = vm:get_param2_data()

    local perlin_cave = minetest.get_perlin(cave_noise_params)
    local perlin_cave_mask = minetest.get_perlin(cave_mask_params)
    local perlin_biome = minetest.get_perlin(biome_noise_params)

    if mapgen_type == "skyblock" then
        for i = 1, #data do data[i] = c_air end
        if minp.x <= 0 and maxp.x >= 0 and minp.z <= 0 and maxp.z >= 0 and minp.y <= 30 and maxp.y >= 30 then
            for z = -2, 2 do
                for x = -2, 2 do
                    local vi_grass = area:index(x, 30, z)
                    data[vi_grass] = get_c_grass()
                    param2_data[vi_grass] = math.random(0, 3)
                    for y = 28, 29 do
                        data[area:index(x, y, z)] = c_dirt
                    end
                    data[area:index(x, 27, z)] = c_stone
                end
            end
        end
    else
        local perlin = minetest.get_perlin(noise_params)
        local perlin_forest = minetest.get_perlin(forest_noise_params)
        local sea_level = 6

        for z = minp.z, maxp.z do
            for x = minp.x, maxp.x do
                local biome_val = perlin_biome:get_2d({x = x, y = z})
                local height_offset = 0
                local surface_node_type = "grass"
                
                if biome_val < -0.3 then
                    height_offset = -4
                    surface_node_type = "sand"
                elseif biome_val > 0.3 then
                    height_offset = -3
                    surface_node_type = "snow"
                end

                local exact_ground = perlin:get_2d({x = x, y = z}) + height_offset
                local ground_level = math.floor(exact_ground)
                local surface_y = ground_level

                for y = minp.y, maxp.y do
                    local vi = area:index(x, y, z)

                    if y < ground_level then
                        local cave_val = perlin_cave:get_3d({x = x, y = y, z = z})
                        local mask_val = perlin_cave_mask:get_3d({x = x, y = y, z = z})
                        local is_cave = (y <= ground_level - 3) and (math.abs(cave_val) < 0.08) and (mask_val > -0.15) and (mask_val < 0.35)

                        if is_cave then
                            data[vi] = c_air
                        elseif y > ground_level - 4 then
                            if surface_node_type == "sand" then
                                data[vi] = c_sand
                            elseif surface_node_type == "snow" then
                                data[vi] = c_snow_block
                            else
                                data[vi] = c_dirt
                            end
                        else
                            data[vi] = get_c_stone(y)
                        end
                    elseif y == ground_level then
                        local cave_val = perlin_cave:get_3d({x = x, y = y, z = z})
                        local mask_val = perlin_cave_mask:get_3d({x = x, y = y, z = z})
                        local is_cave = (y <= ground_level - 3) and (math.abs(cave_val) < 0.08) and (mask_val > -0.15) and (mask_val < 0.35)

                        if is_cave then
                            data[vi] = c_air
                        else
                            if surface_node_type == "sand" then
                                data[vi] = c_sand
                            elseif surface_node_type == "snow" then
                                data[vi] = c_snow_block
                            else
                                data[vi] = get_c_grass()
                                param2_data[vi] = math.random(0, 3)
                            end
                        end
                    else
                        if data[vi] == nil or data[vi] == c_air then
                            if y <= sea_level then
                                data[vi] = c_water
                            else
                                data[vi] = c_air
                            end
                        end
                    end
                end

                -- Génération d'éléments de surface (Cactus unique pour désert, Arbres pour standard)
                if surface_y >= minp.y and surface_y <= maxp.y then
                    local vi_surface = area:index(x, surface_y, z)
                    local surface_node = data[vi_surface]

                    if surface_node == c_sand then
                        -- Cactus unique (un seul bloc) et rare dans le désert
                        if math.random() < 0.003 then
                            if surface_y + 1 <= emax.y then
                                local vi_c = area:index(x, surface_y + 1, z)
                                if data[vi_c] == c_air then
                                    data[vi_c] = c_cactus
                                end
                            end
                        end
                    elseif surface_node ~= c_air and surface_node ~= c_stone and surface_node ~= c_stone_slab and surface_node ~= c_dirt and surface_node ~= c_snow_block then
                        local forest_val = perlin_forest:get_2d({x = x, y = z})
                        local tree_chance = forest_val > 0.25 and 0.035 or (forest_val > -0.15 and 0.008 or 0.0005)

                        if math.random() < tree_chance then
                            local tree_h = math.random(4, 6)
                            if surface_y + tree_h + 2 <= emax.y then
                                for ty = 1, tree_h do
                                    data[area:index(x, surface_y + ty, z)] = c_wood
                                end
                                for ly = surface_y + tree_h - 2, surface_y + tree_h + 1 do
                                    for lx = -2, 2 do
                                        for lz = -2, 2 do
                                            local px, py, pz = x + lx, ly, z + lz
                                            local vi_l = area:index(px, py, pz)
                                            if data[vi_l] == c_air then
                                                data[vi_l] = c_leaves
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    vm:set_data(data)
    vm:set_param2_data(param2_data)
    vm:calc_lighting()
    vm:write_to_map()
end)

minetest.register_on_newplayer(function(player)
    player:set_pos({x = 0, y = 30, z = 0})
    local privs = minetest.get_player_privs(player:get_player_name())
    privs.interact = true
    minetest.set_player_privs(player:get_player_name(), privs)
    set_player_inventory(player)
end)

minetest.register_on_joinplayer(function(player)
    set_player_inventory(player)
end)

minetest.log("action", "[Mod] Core Engine with Cactus, Biomes, Liquids and Crafting Loaded")
