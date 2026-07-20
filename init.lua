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
-- (Prend en charge automatiquement l'héritage des variantes et des minerais vers la pierre)
local function get_json_config(node_name)
    if block_sounds[node_name] then
        return block_sounds[node_name]
    end
    -- Les minerais utilisent automatiquement le son de la pierre
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
-- 2. ENREGISTREMENT DES BLOCS ET DE LA MAIN (SANS AUCUN SON PAR DÉFAUT)
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

-- Registration des minerais
minetest.register_node("core:voltstone", {
    description = "Minerai de Voltstone",
    tiles = {"voltstone.png"},
    groups = {cracky = 2},
    sounds = {},
})

minetest.register_node("core:gold", {
    description = "Minerai d'Or",
    tiles = {"gold.png"},
    groups = {cracky = 2},
    sounds = {},
})

minetest.register_node("core:coat", {
    description = "Minerai de Coat",
    tiles = {"coat.png"},
    groups = {cracky = 3},
    sounds = {},
})

minetest.register_alias("mapgen_stone", "core:stone")

-- =======================================================================
-- 2.5 AUTO-DÉTECTION DES VARIANTES D'HERBE (GRASS_1.PNG, GRASS_2.PNG...)
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

-- Tri par numéro pour s'assurer que les calculs de rareté se font dans le bon ordre
table.sort(grass_variants, function(a, b) return a.num < b.num end)

for _, v in ipairs(grass_variants) do
    minetest.register_node(v.id, {
        description = "Bloc d'herbe (Variante " .. v.num .. ")",
        tiles = {v.tex, "dirt.png", "dirt.png^grass_side.png"},
        paramtype2 = "facedir",
        groups = {crumbly = 3, soil = 1, not_in_creative_inventory = 1},
        sounds = {},
        drop = "core:dirt", -- Les variantes lootent de la terre classique pour ne pas polluer l'inventaire
    })
end

-- =======================================================================
-- 2.8 GESTION DU DROP DES BLOCS (SURVIE VS CRÉATIF)
-- =======================================================================
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

    if is_creative then
        -- Mode Créatif : Aucun drop au sol et rien dans l'inventaire
        return
    else
        -- Mode Survie : Drop l'item au sol à la position du bloc détruit
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
        allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
            return 0
        end,
        allow_put = function(inv, listname, index, stack, player)
            return 0
        end,
        allow_take = function(inv, listname, index, stack, player)
            local name = player:get_player_name()
            local privs = minetest.get_player_privs(name)
            local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative
            if is_creative then
                return stack:get_stack_max()
            end
            return 0
        end,
        on_take = function(inv, listname, index, stack, player)
            -- Réapprovisionnement infini du slot créatif
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
            "label[0,4.9;Inventaire Joueur]" ..
            "list[current_player;main;0,5.4;8,4;]" ..
            "listring[current_player;main]"
        player:set_inventory_formspec(formspec)
    end
end

minetest.register_on_mods_loaded(function()
    build_creative_inventory()
end)

-- =======================================================================
-- 3. LE MOTEUR AUDIO, CONFIGURATION DU SPRINT ET CONTRÔLE DE VOL ULTIME
-- =======================================================================

-- Configuration du Sprint au sol
local SPRINT_SPEED = 1.6
local NORMAL_SPEED = 1.0
local DOUBLE_TAP_TIME = 0.3

-- Tables d'états pour le sprint et le minage temporisé
local player_timers = {}
local players_is_sprinting = {}
local last_keys = {}
local sprint_window_timers = {}
local creative_dig_timers = {}
local last_creative_state = {}

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local privs = minetest.get_player_privs(name)
        local controls = player:get_player_control()
        
        -- Initialisation des tables d'états
        if not player_timers[name] then
            player_timers[name] = { step = 0, dig = 0 }
        end
        if not players_is_sprinting[name] then players_is_sprinting[name] = false end
        if not sprint_window_timers[name] then sprint_window_timers[name] = 0 end
        if not last_keys[name] then last_keys[name] = false end
        if not creative_dig_timers[name] then creative_dig_timers[name] = { pos = nil, time = 0 } end
        
        local timers = player_timers[name]
        local physics = player:get_physics_override()
        
        local is_creative = minetest.settings:get_bool("creative_mode") or privs.creative

        -- Mise à jour dynamique de l'inventaire si le mode créatif change
        if last_creative_state[name] == nil or last_creative_state[name] ~= is_creative then
            last_creative_state[name] = is_creative
            set_player_inventory(player)
        end

        -- -------------------------------------------------------------------
        -- SÉCURITÉ DU VOL & CONFIGURATION DES PRIVILÈGES FAST
        -- -------------------------------------------------------------------
        if is_creative then
            if not privs.fly or not privs.fast then
                privs.fly = true
                privs.fast = true
                minetest.set_player_privs(name, privs)
            end
            if physics.fly == false then
                physics.fly = true
            end
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

        -- -------------------------------------------------------------------
        -- SYSTÈME DE SPRINT INTÉGRÉ AU SOL (DOUBLE TAP)
        -- -------------------------------------------------------------------
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

        local target_speed = NORMAL_SPEED
        if players_is_sprinting[name] then
            target_speed = SPRINT_SPEED
        end

        if physics.speed ~= target_speed then
            physics.speed = target_speed
        end
        
        player:set_physics_override(physics)

        if sprint_window_timers[name] > 0 then
            sprint_window_timers[name] = sprint_window_timers[name] - dtime
        end
        last_keys[name] = controls.up

        -- -------------------------------------------------------------------
        -- A. GESTION DES BRUITS DE PAS (MARCHER / SPRINT)
        -- -------------------------------------------------------------------
        local pos = player:get_pos()
        local pos_under = {x = pos.x, y = pos.y - 0.5, z = pos.z}
        local node_under = minetest.get_node(pos_under)
        local config_under = get_json_config(node_under.name)
        
        if config_under and config_under.footstep then
            local velocity = player:get_velocity()
            local is_moving = (velocity.x ~= 0 or velocity.z ~= 0) and (velocity.y == 0)
            
            if is_moving then
                timers.step = timers.step + dtime
                local step_cooldown = players_is_sprinting[name] and 0.22 or 0.35
                
                if timers.step >= step_cooldown then
                    local step_pitch = 0.5 + (math.random() * 1.0)
                    minetest.sound_play(config_under.footstep, {
                        object = player,
                        gain = config_under.gain or 0.5,
                        pitch = step_pitch,
                        max_hear_distance = 10,
                    })
                    timers.step = 0
                end
            else
                timers.step = 0
            end
        end
        
        -- -------------------------------------------------------------------
        -- B. GESTION DU CLIC GAUCHE ENFONCÉ (MINAGE AVEC SÉCURITÉ CRÉATIF 1S)
        -- -------------------------------------------------------------------
        if controls.LMB then
            local p_eye = player:get_pos()
            p_eye.y = p_eye.y + player:get_properties().eye_height
            local look_dir = player:get_look_dir()
            local p_target = {
                x = p_eye.x + look_dir.x * 4,
                y = p_eye.y + look_dir.y * 4,
                z = p_eye.z + look_dir.z * 4
            }
            local ray = minetest.raycast(p_eye, p_target, false, false)
            local pointed = ray:next()
            
            if pointed and pointed.type == "node" then
                local node_pointed = minetest.get_node(pointed.under)
                local config_pointed = get_json_config(node_pointed.name)
                
                -- Bruits de minage
                if config_pointed and config_pointed.footstep then
                    timers.dig = timers.dig + dtime
                    if timers.dig >= 0.18 then
                        local dig_pitch = 1.0 + (math.random() * 0.5)
                        minetest.sound_play(config_pointed.footstep, {
                            pos = pointed.under,
                            gain = (config_pointed.gain or 0.5) + 0.1,
                            pitch = dig_pitch,
                            max_hear_distance = 12,
                        })
                        timers.dig = 0
                    end
                end

                -- Système de destruction forcée en Créatif
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
        else
            timers.dig = 0
            if creative_dig_timers[name] then
                creative_dig_timers[name].pos = nil
            end
        end
    end
end)

-- =======================================================================
-- C. GESTION DU CLIC DROIT (PLACEMENT)
-- =======================================================================
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if not placer or not placer:is_player() then return end
    
    local config = get_json_config(newnode.name)
    if config and config.footstep then
        local place_pitch = 1.0 + (math.random() * 0.5)
        minetest.sound_play(config.footstep, {
            pos = pos,
            gain = config.gain or 0.5,
            pitch = place_pitch,
        })
    end
end)

-- =======================================================================
-- D. BRUITAGE DES DÉGÂTS
-- =======================================================================
minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change < 0 then
        local damage_pitch = 0.5 + (math.random() * 1.0)
        minetest.sound_play("core_damage", {
            object = player,
            gain = 0.8,
            max_hear_distance = 10,
            pitch = damage_pitch,
        })
    end
    return hp_change
end, true)

-- =======================================================================
-- 4. CONFIGURATION ET SYSTÈMES MULTI-MAPGENS (STANDARD, FLAT, SKYBLOCK)
-- =======================================================================

-- Force Luanti à utiliser le mode singlenode en arrière-plan pour éviter les conflits de générateurs natifs
minetest.set_mapgen_setting("mg_name", "singlenode", true)

-- Récupération de l'option de monde ("standard", "flat", ou "skyblock")
local mapgen_type = minetest.settings:get("core_mapgen_type") or "standard"

-- Bruit Perlin 2D pour les reliefs de surface
local noise_params = {
    offset = 10,
    scale = 15,
    spread = {x = 150, y = 150, z = 150},
    seed = 538,
    octaves = 3,
    persist = 0.5
}

-- Bruit Perlin 3D pour la génération de grottes et réseaux souterrains
local cave_noise_params = {
    offset = 0,
    scale = 1,
    spread = {x = 30, y = 20, z = 30},
    seed = 12345,
    octaves = 3,
    persist = 0.5
}

minetest.register_on_generated(function(minp, maxp, blockseed)
    local c_grass_base = minetest.get_content_id("core:grass")
    local c_dirt  = minetest.get_content_id("core:dirt")
    local c_stone = minetest.get_content_id("core:stone")
    local c_air   = minetest.CONTENT_AIR

    local c_voltstone = minetest.get_content_id("core:voltstone")
    local c_gold      = minetest.get_content_id("core:gold")
    local c_coat      = minetest.get_content_id("core:coat")

    -- Préparation des probabilités pour les variantes d'herbe dynamiques
    local variant_cids = {}
    local total_grass_weight = 0
    if #grass_variants > 0 then
        for _, v in ipairs(grass_variants) do
            -- La rareté augmente avec le chiffre de la variante (1 = 500, 2 = 250, 3 = 125, etc.)
            local weight = 1000 / (2 ^ v.num)
            table.insert(variant_cids, { cid = minetest.get_content_id(v.id), weight = weight })
            total_grass_weight = total_grass_weight + weight
        end
    end

    -- Fonction pour piocher la variante d'herbe appropriée lors de la génération
    local function get_c_grass()
        if total_grass_weight == 0 then return c_grass_base end
        local r = math.random() * total_grass_weight
        for _, v in ipairs(variant_cids) do
            r = r - v.weight
            if r <= 0 then return v.cid end
        end
        return c_grass_base
    end

    -- Fonction pour piocher un minerai ou de la pierre sous terre
    local function get_c_stone()
        local r_ore = math.random(1, 1000)
        if r_ore <= 3 then       -- Voltstone : Le plus rare (0.3%)
            return c_voltstone
        elseif r_ore <= 15 then  -- Gold : Rare mais moins que voltstone (1.2%)
            return c_gold
        elseif r_ore <= 60 then  -- Coat : Le plus fréquent (4.5%)
            return c_coat
        else
            return c_stone
        end
    end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local param2_data = vm:get_param2_data()

    local perlin_cave = minetest.get_perlin(cave_noise_params)

    -- A. LOGIQUE S'IL S'AGIT D'UN SKYBLOCK
    if mapgen_type == "skyblock" then
        for i = 1, #data do
            data[i] = c_air
        end

        if minp.x <= 0 and maxp.x >= 0 and minp.z <= 0 and maxp.z >= 0 and minp.y <= 30 and maxp.y >= 30 then
            for z = -2, 2 do
                for x = -2, 2 do
                    local vi_grass = area:index(x, 30, z)
                    data[vi_grass] = get_c_grass()
                    param2_data[vi_grass] = math.random(0, 3) -- Rotation aléatoire (0°, 90°, 180°, 270°/-90°)

                    for y = 28, 29 do
                        local vi_dirt = area:index(x, y, z)
                        data[vi_dirt] = c_dirt
                    end

                    local vi_stone = area:index(x, 27, z)
                    data[vi_stone] = get_c_stone()
                end
            end
        end

    -- B. LOGIQUE S'IL S'AGIT D'UN FLATWORLD
    elseif mapgen_type == "flat" then
        local flat_level = 10

        for z = minp.z, maxp.z do
            for x = minp.x, maxp.x do
                for y = minp.y, maxp.y do
                    local vi = area:index(x, y, z)

                    if y <= flat_level then
                        -- Détection et creusage des grottes sous le sol
                        local cave_val = perlin_cave:get_3d({x = x, y = y, z = z})
                        if math.abs(cave_val) < 0.12 then
                            data[vi] = c_air
                        elseif y == flat_level then
                            data[vi] = get_c_grass()
                            param2_data[vi] = math.random(0, 3)
                        elseif y > flat_level - 4 then
                            data[vi] = c_dirt
                        else
                            data[vi] = get_c_stone()
                        end
                    else
                        data[vi] = c_air
                    end
                end
            end
        end

    -- C. LOGIQUE STANDARD DE TERRAIN (RELIEFS PERLIN NOISE & GROTTES 3D)
    else
        local perlin = minetest.get_perlin(noise_params)

        for z = minp.z, maxp.z do
            for x = minp.x, maxp.x do
                local ground_level = math.floor(perlin:get_2d({x = x, y = z}))

                for y = minp.y, maxp.y do
                    local vi = area:index(x, y, z)

                    if y <= ground_level then
                        -- Détection et creusage des grottes sous le sol
                        local cave_val = perlin_cave:get_3d({x = x, y = y, z = z})
                        if math.abs(cave_val) < 0.12 then
                            data[vi] = c_air
                        elseif y == ground_level then
                            data[vi] = get_c_grass()
                            param2_data[vi] = math.random(0, 3)
                        elseif y > ground_level - 4 then
                            data[vi] = c_dirt
                        else
                            data[vi] = get_c_stone()
                        end
                    else
                        data[vi] = c_air
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
    if mapgen_type == "skyblock" then
        player:set_pos({x = 0, y = 32, z = 0})
    else
        player:set_pos({x = 0, y = 30, z = 0})
    end
    local privs = minetest.get_player_privs(player:get_player_name())
    privs.interact = true
    minetest.set_player_privs(player:get_player_name(), privs)
    set_player_inventory(player)
end)

minetest.register_on_joinplayer(function(player)
    set_player_inventory(player)
end)

minetest.log("action", "[Mod] Core Engine with Multi-Mapgen Options Loaded")
