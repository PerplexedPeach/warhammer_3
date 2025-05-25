-- script for introducing a mission to fight Slaanesh at turn 10, as well as revealing diplomacy after the battle
local mission_key = "li_miao_corruption_introduction";
local mission_finished_key = mission_key .. "_finished";
local set_piece_battle_key = "li_miao_corruption_introduction";
local mission_fight_listener_name = "Li_Starting_Battle_Listener";

local function reveal_slaanesh_diplomacy()
    local miao = li_miao:get_char();
    if miao == nil then
        return;
    end
    li_miao:log("revealing diplomacy with Slaaneshi factions");
    local miao_faction = miao:faction():name();
    cm:make_diplomacy_available(miao_faction, "wh3_main_sla_seducers_of_slaanesh");
    cm:make_diplomacy_available(miao_faction, "wh3_dlc20_chs_sigvald");
    cm:make_diplomacy_available(miao_faction, "wh3_dlc20_chs_azazel");
end

local function introduction_mission_trigger(context)
    -- only fire once after turn 9
    local events_seen = cm:get_saved_value(mission_key);
    if events_seen or cm:turn_number() < CFSettings.miao_intro_quest_turn then
        return;
    end

    local miao = li_miao:get_char();
    if miao == nil or context:faction():name() ~= miao:faction():name() then
        return;
    end

    -- seems like AI miao can't handle missions
    cm:set_saved_value(mission_key, true);
    if miao:faction():is_human() then
        li_miao:log("triggering introduction mission");
        cm:trigger_mission(miao:faction():name(), mission_key, true);
    else
        li_miao:log("triggering AI progression instead of mission");
        li_miao:modify_progress_percent(100, "blade mission");
    end
end

local function ai_corruption_chance_pulse(context)
    local miao = li_miao:get_char();
    -- only for AI 
    if miao == nil or context:faction():name() ~= miao:faction():name() then
        return;
    end

    if miao:faction():is_human() then
        if li_miao:get_stage() > 0 then
            li_miao:modify_progress_percent(CFSettings.miao_human_corruption_per_turn, "human corruption pulse");
        end
    else
        li_miao:modify_progress_percent(CFSettings.miao_ai_corruption_per_turn, "AI corruption pulse");
    end
end

local function broadcast_self()
    -- command script will define API to register stage

    -- event up as we visit Kislev cities
    core:add_listener(
        "FactionTurnStartMiaoIntroduction",
        "FactionTurnStart",
        true,
        introduction_mission_trigger,
        true
    );

    -- corruption pulse for AI Maio
    core:add_listener(
        "FactionTurnStartMiaoCorruptionPulse",
        "FactionTurnStart",
        true,
        ai_corruption_chance_pulse,
        true
    );

    -- listen for victory or defeat, where we abort the mission
    local events_seen = cm:get_saved_value(mission_finished_key);
    if not events_seen then
        li_miao:log("adding listener for set piece " .. set_piece_battle_key);

        core:add_listener(
            mission_fight_listener_name,
            "BattleCompleted",
            function(context)
                local pb = context:model():pending_battle();
                return pb:has_been_fought() and pb:set_piece_battle_key() == set_piece_battle_key;
            end,
            function(context)
                local pb = context:model():pending_battle();
                local won = pb:attacker_won() and not pb:is_draw();

                li_miao:log("fought introduction quest mission won? " .. tostring(won) ..
                    " set piece key " ..
                    pb:set_piece_battle_key() .. " has been fought " .. tostring(pb:has_been_fought()));

                if not won then
                    local miao = li_miao:get_char();
                    cm:cancel_custom_mission(miao:faction():name(), mission_key);
                end
                reveal_slaanesh_diplomacy();
                core:remove_listener(mission_fight_listener_name);
                cm:set_saved_value(mission_finished_key, true);
                -- guarantee progress to stage
                li_miao:modify_progress_percent(100, "finished introduction mission");
            end,
            true
        );
    end

end

cm:add_first_tick_callback(function() broadcast_self() end);
