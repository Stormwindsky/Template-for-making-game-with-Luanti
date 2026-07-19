-- Simple Run
-- Created by: Stormwindsky
-- License: CC0 1.0 Universal

local SPRINT_SPEED = 1.6
local NORMAL_SPEED = 1.0
local DOUBLE_TAP_TIME = 0.3

-- Table to store player states
local players_tap_time = {}
local players_is_sprinting = {}

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local controls = player:get_player_control()
        
        -- Initialize player data if not exists
        if not players_tap_time[name] then
            players_tap_time[name] = 0
            players_is_sprinting[name] = false
        end

        -- Logic for double tap detection
        if controls.up then
            if not players_is_sprinting[name] then
                -- Check if the key was pressed recently (double tap)
                if players_tap_time[name] > 0 and players_tap_time[name] < DOUBLE_TAP_TIME then
                    players_is_sprinting[name] = true
                    player:set_physics_override({ speed = SPRINT_SPEED })
                end
            end
        else
            -- If "up" is released, reset timer or stop sprinting
            if players_is_sprinting[name] then
                players_is_sprinting[name] = false
                player:set_physics_override({ speed = NORMAL_SPEED })
            end
            
            -- This counts how long since the key was last released
            -- We reset it if it's the first frame of release
            players_tap_time[name] = 0
        end

        -- Update the timer when NOT pressing up (to detect the gap between taps)
        if not controls.up then
            -- We use a small trick: if tap_time is stored, we increment it
            -- But we need to know when the key WAS pressed. 
            -- Let's refine the logic for Luanti's globalstep:
        end
    end
end)

-- Improved detection logic using a different approach for precision
local last_keys = {}
local timers = {}

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local controls = player:get_player_control()
        
        if not timers[name] then timers[name] = 0 end
        if not last_keys[name] then last_keys[name] = false end

        -- Detect the moment the key is pressed (edge trigger)
        if controls.up and not last_keys[name] then
            if timers[name] > 0 and timers[name] < DOUBLE_TAP_TIME then
                players_is_sprinting[name] = true
            end
            timers[name] = DOUBLE_TAP_TIME -- Start/Reset window
        end

        -- Apply physics
        if players_is_sprinting[name] then
            if not controls.up or controls.sneak then
                players_is_sprinting[name] = false
                player:set_physics_override({ speed = NORMAL_SPEED })
            else
                player:set_physics_override({ speed = SPRINT_SPEED })
            end
        end

        -- Update timers and state
        if timers[name] > 0 then
            timers[name] = timers[name] - dtime
        end
        last_keys[name] = controls.up
    end
end)

minetest.log("action", "[Mod] Simple Run (Double-Tap) by Stormwindsky loaded")
