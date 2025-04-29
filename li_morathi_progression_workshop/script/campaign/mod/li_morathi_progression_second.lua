local malus_trait_name = "li_trait_malus_morathi";
-- for AI this stage gets rolled every turn
local this_stage = 2;

local malus_capture_mission_key = "li_morathi_progression_malus";
local malus_capture_mission_finished_key = "li_morathi_progression_malus_finished";
local malus_capture_delay_process = "li_morathi_progression_malus_captured";

local malus_fight_mission_key = "li_morathi_progression_malus_battle";

local malus_torture_start = "li_morathi_progression_malus_zeroth";
local malus_first = "li_morathi_progression_malus_first";
local malus_second = "li_morathi_progression_malus_second";
local events = {
    { ["sub"] = "li_morathi_progression_malus_first_sub",  ["dom"] = "li_morathi_progression_malus_first_dom" },
    { ["sub"] = "li_morathi_progression_malus_second_sub", ["dom"] = "li_morathi_progression_malus_second_dom" },
};
local target = li_mor.malus;

-- progression notification dilemma (choice of proceeding is to do previous quests or not)
local progress_next_turn = "li_morathi_malus_progress_next_turn";

CFSettings.mor[this_stage] = {
    dilemma_name = "li_morathi_progression_malus_third",
    trait_name = "li_trait_morathi_hot_clothing",
    this_stage = this_stage,
    ai_corruption_chance = 15,
    target = target,
};

local function trigger_malus_mission()
    -- cm:trigger_mission(mor:faction():name(), alith_anar_mission_key, true);
    local mor = li_mor:get_char();
    local malus = li_mor:get_target_character(li_mor.malus);
    if mor == nil or malus == nil or not malus:has_military_force() then
        return;
    end

    local mm = mission_manager:new(mor:faction():name(), malus_capture_mission_key);
    if not mm then
        li_mor:log("ERROR: not create malus mission manager");
        return;
    end
    mm:set_mission_issuer("CLAN_ELDERS");
    mm:add_new_objective("KILL_CHARACTER_BY_ANY_MEANS");
    mm:add_condition("family_member " .. malus:family_member():command_queue_index());
    mm:add_payload("money 1000");
    mm:set_show_mission(true);
    mm:add_each_time_trigger_callback(function()
        cm:set_saved_value(malus_capture_mission_key, true);
    end);
    mm:trigger();
end


local function malus_capture_start(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    if mor:faction():is_human() then
        li_mor:log("starting Malus capture quest");
        -- trigger_malus_mission();
        cm:trigger_mission(mor:faction():name(), malus_fight_mission_key, true);
        cm:set_saved_value(malus_capture_mission_key, true);
    else
        -- add reward directly
        li_mor:log("skipping Malus mission for AI, trigger random progression");
        li_mor:trigger_progression(context, false);
    end
end

local function malus_capture_end(context)
    local mission_key = context:mission():mission_record_key();
    li_mor:log("checking mission success against mission " .. mission_key);
    if mission_key ~= malus_capture_mission_key and mission_key ~= malus_fight_mission_key then
        return;
    end

    local mor = li_mor:get_char();
    local malus = li_mor:get_target_character(li_mor.malus);
    if mor == nil or malus == nil then
        li_mor:error("Malus capture mission complete, but Morathi or Malus is nil");
        return;
    end

    li_mor:log("successfully finished malus capture mission");
    -- confederate his entire faction; since they are dark evles they accept your rule nominally, but will likely rebel
    cm:set_saved_value(malus_capture_mission_finished_key, true);
    --spawn this force as a guard against the player killing Malus and occupying his last settlement at the same time. kill them with notice supressed after confederation
    local cqi_generated = nil;
    cm:create_force_with_general("wh2_main_def_hag_graef", "", "wh3_main_combi_region_ancient_city_of_quintex", 74, 590,
        "general", "wh2_main_def_dreadlord_fem", "names_name_2147359621", "", "", "", false,
        function(cqi)
            cqi_generated = cqi;
        end, true);


    -- confederate
    li_mor:clear_faction_character_stance(malus:faction());
    cm:force_confederation(mor:faction():name(), malus:faction():name());

    li_mor:delayed_kill_cqi(cqi_generated, 15);
    cm:change_character_localised_name(malus, "names_name_" .. li_mor.malus.name_id, "", "", "");
end

---Restore target character and their faction needed for this mission
---@param context any
local function keep_target_alive_for_mission(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    local malus = li_mor:get_target_character(li_mor.malus);
    if malus == nil then
        -- spawn alith with an army in his home province
        local spawn_region = "wh3_main_combi_region_hag_graef";
        local faction_name = li_mor.malus.faction;
        local unit_list =
        "wh2_main_def_inf_shades_0,wh2_main_def_inf_shades_0,wh2_main_def_inf_shades_0,wh2_main_def_inf_shades_0,wh2_main_def_inf_har_ganeth_executioners_0,wh2_main_def_inf_har_ganeth_executioners_0,wh2_main_def_mon_black_dragon,wh2_main_def_inf_dreadspears_0,wh2_main_def_inf_dreadspears_0,wh2_main_def_cav_cold_one_knights_0,wh2_main_def_cav_cold_one_knights_0,wh2_main_def_cav_cold_one_knights_0,wh2_main_def_cav_cold_one_knights_0,wh2_main_def_art_reaper_bolt_thrower,wh2_main_def_art_reaper_bolt_thrower,wh2_main_def_cav_dark_riders_1,wh2_main_def_cav_dark_riders_1";
        li_mor:log("respawning Malus faction");
        li_mor:respawn_faction(spawn_region, faction_name, unit_list);
        malus = li_mor:get_target_character(li_mor.malus);
        if malus == nil then
            li_mor:error("Malus not found even after respawn");
            return;
        end
    end

    cm:stop_character_convalescing(malus:cqi());
end

local function malus_capture_failed(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= malus_capture_mission_key and mission_key ~= malus_fight_mission_key then
        return;
    end
    -- mission should retrigger when the target recovers
    li_mor:log("Malus captured failed, allow retry");
    cm:set_saved_value(malus_capture_mission_key, false);
end

local function delayed_capture(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    cm:set_saved_value(malus_capture_delay_process, true);
    li_mor:log("initiating delayed capture");

    -- need to change his name after to reflect his new culture
    local malus = li_mor:get_target_character(li_mor.malus);
    if malus == nil then
        li_mor:log("ERROR: Malus nil after confederation for some reason");
        return;
    end
    -- cm:change_character_localised_name(malus, "names_name_" .. malus_name_id, "", "", "");

    -- -- set him to wounded max turns until our training of him is complete
    cm:wound_character("character_cqi:" .. malus:cqi(), 999);
    -- -- NOTE use cm:stop_character_convalescing to instantly recover
    local delimma_choice_listener_name = malus_torture_start .. "_DilemmaChoiceMadeEvent";
    -- using persist = true even for a delimma event in case they click on another delimma first
    core:add_listener(
        delimma_choice_listener_name,
        "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == malus_torture_start;
        end,
        function(context)
            cm:trigger_mission(mor:faction():name(), malus_first, true);
            core:remove_listener(delimma_choice_listener_name);
        end,
        true
    );
    cm:trigger_dilemma(mor:faction():name(), malus_torture_start);
end

local function recover_malus()
    -- convelesce Malus so you can recruit him
    local mor = li_mor:get_char();
    local malus = li_mor:get_target_character(li_mor.malus);
    if mor == nil or malus == nil then
        return;
    end
    cm:stop_character_convalescing(malus:cqi());
    -- add trait to disable his Daemon transformation, and as a debuff to him
    cm:force_add_trait(cm:char_lookup_str(malus), malus_trait_name, true);
end

local function malus_main_progression_turn_start_manager(context)
    local mor = li_mor:get_char();
    if mor == nil or context:faction():name() ~= mor:faction():name() or li_mor:get_stage() ~= 1 then
        return;
    end

    if not cm:get_saved_value(malus_capture_mission_key) then
        malus_capture_start(context);
    end

    if mor:faction():is_human() and not cm:get_saved_value(malus_capture_mission_finished_key) then
        keep_target_alive_for_mission(context);
    end

    if mor:faction():is_human() and cm:get_saved_value(malus_capture_mission_finished_key) and
        not cm:get_saved_value(malus_capture_delay_process) then
        delayed_capture(context);
    end

    if mor:faction():is_human() and cm:get_saved_value(progress_next_turn) then
        recover_malus();
        li_mor:trigger_progression(context, true);
    end
end

local function progress_to_this_stage_triggers()
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    if li_mor:get_stage() == 1 then
        core:add_listener(
            "FactionTurnStartMorathiMalus",
            "FactionTurnStart",
            true,
            malus_main_progression_turn_start_manager,
            true
        );
    end

    -- listen for when we've finished the first mission
    if mor:faction():is_human() and not cm:get_saved_value(malus_capture_mission_finished_key) then
        li_mor:log("adding malus mission listeners");
        core:add_listener(
            "MissionSucceededMorathiMalus",
            "MissionSucceeded",
            true,
            malus_capture_end,
            true
        );
        -- listen for mission failure for some reason (potentially also recover their faction if they get wiped out)
        core:add_listener(
            "MissionCancelledMorathiMalus",
            "MissionCancelled",
            true,
            malus_capture_failed,
            true
        );
    end

    -- listen for sub/dom dilemma choice selection
    if mor:faction():is_human() and li_mor:get_stage() == 1 then
        local dilemma_name = malus_first;
        local delimma_choice_listener_name = dilemma_name .. "_DilemmaChoiceMadeEvent";
        -- using persist = true even for a delimma event in case they click on another delimma first
        core:add_listener(
            delimma_choice_listener_name,
            "DilemmaChoiceMadeEvent",
            function(context)
                return context:dilemma() == dilemma_name;
            end,
            function(context)
                local choice = context:choice();
                li_mor:log(dilemma_name .. " choice " .. tostring(choice));
                -- add sub/dom tracking here
                if choice == 0 then
                    li_mor:sub_choice(target, true);
                    cm:trigger_dilemma(li_mor:get_char():faction():name(), events[1]["sub"]);
                elseif choice == 1 then
                    li_mor:dom_choice(target, true);
                    cm:trigger_dilemma(li_mor:get_char():faction():name(), events[1]["dom"]);
                end
                -- trigger next mission
                cm:trigger_mission(mor:faction():name(), malus_second, true);
                core:remove_listener(delimma_choice_listener_name);
            end,
            true
        );
    end

    if mor:faction():is_human() and li_mor:get_stage() == 1 then
        local dilemma_name = malus_second;
        local delimma_choice_listener_name = dilemma_name .. "_DilemmaChoiceMadeEvent";
        -- using persist = true even for a delimma event in case they click on another delimma first
        core:add_listener(
            delimma_choice_listener_name,
            "DilemmaChoiceMadeEvent",
            function(context)
                return context:dilemma() == dilemma_name;
            end,
            function(context)
                local choice = context:choice();
                li_mor:log(dilemma_name .. " choice " .. tostring(choice));
                -- add sub/dom tracking here
                if choice == 0 then
                    li_mor:sub_choice(target, true);
                    cm:trigger_dilemma(li_mor:get_char():faction():name(), events[2]["sub"]);
                elseif choice == 1 then
                    li_mor:dom_choice(target, true);
                    cm:trigger_dilemma(li_mor:get_char():faction():name(), events[2]["dom"]);
                end
                -- progression on the next turn
                core:remove_listener(delimma_choice_listener_name);
                cm:set_saved_value(progress_next_turn, true);
            end,
            true
        );
    end
end

local function broadcast_self()
    local name = "second"; -- use as the key for everything
    li_mor:stage_register(name, this_stage, function(context, is_human)
        li_mor:subdom_progression_callback(context, is_human, CFSettings.mor[this_stage]);
    end);

    li_mor:add_listener(
        "MorProgressionTrigger" .. this_stage,
        function(context)
            return (context:type() == "enter" or context:type() == "init") and context:stage() == this_stage - 1;
        end,
        function(context)
            progress_to_this_stage_triggers();
        end,
        false -- not persistent! This is important to avoid adding duplicate listeners inside
    );
end

function Debug_malus_capture_start()
    malus_capture_start(nil);
end

cm:add_first_tick_callback(function() broadcast_self() end);
