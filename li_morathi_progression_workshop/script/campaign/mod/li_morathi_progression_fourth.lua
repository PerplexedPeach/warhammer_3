local teclis_trait_name = "li_trait_teclis_morathi";
-- for AI this stage gets rolled every turn
local this_stage = 4;

local missions = { "li_morathi_teclis_convene", "li_morathi_progression_fourth_battle" };
local missions_finished = { "li_morathi_teclis_convene_finished", "li_morathi_convene_distraction_finished" };
local dilemmas = { "li_morathi_teclis_convinced", "li_morathi_teclis_orgy", "li_morathi_teclis_confed",
    "li_morathi_teclis_final" };
local events = {
    { ["sub"] = "li_morathi_teclis_orgy_sub", ["dom"] = "li_morathi_teclis_orgy_dom" },
};
local set_piece_battle_key = "li_morathi_progression_fourth_battle";

local shrine_of_asuryan_region = "wh3_main_combi_region_shrine_of_asuryan";
-- the progression dilemma is the last dilemma

local enter_mission_next_turn = "li_morathi_teclis_enter_mission_next_turn";
local confed_next_turn = "li_morathi_teclis_confed_next_turn";
local progress_next_turn = "li_morathi_teclis_progress_next_turn";

local target_table = li_mor.teclis;

CFSettings.mor[this_stage] = {
    dilemma_name = dilemmas[#dilemmas],
    trait_name = "li_trait_morathi_marked_body",
    this_stage = this_stage,
    ai_corruption_chance = 15,
    target = target_table,
};


local function teclis_transaction()
    local mor = li_mor:get_char();
    local teclis = li_mor:get_target_character(li_mor.teclis);
    if mor == nil or teclis == nil then
        return;
    end
    -- teclis receives 50k gold
    cm:treasury_mod(mor:faction():name(), -CFSettings.mor_teclis_donation);
    cm:treasury_mod(teclis:faction():name(), CFSettings.mor_teclis_donation);
    cm:force_make_peace(teclis:faction():name(), mor:faction():name());
    for i = 1, 5 do
        cm:apply_dilemma_diplomatic_bonus(mor:faction():name(), teclis:faction():name(), 5);
    end
end

local function start_fourth_stage(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    -- AI passes mission for free, but gets the penalties too
    if not mor:faction():is_human() then
        teclis_transaction();
        cm:set_saved_value(missions[1], true);
        cm:set_saved_value(missions_finished[1], true);
        return;
    end

    -- only trigger after 1 turn in this stage
    if not cm:get_saved_value(enter_mission_next_turn) then
        cm:set_saved_value(enter_mission_next_turn, true);
        return;
    end

    local mm = mission_manager:new(mor:faction():name(), missions[1]);
    if not mm then
        li_mor:log("ERROR: not create convene at shrine of asuryan mission manager");
        return;
    end
    mm:set_mission_issuer("CLAN_ELDERS");
    mm:add_new_objective("MOVE_TO_REGION");
    mm:add_condition("region " .. shrine_of_asuryan_region);
    mm:add_payload("text_display li_morathi_give_away_convene");
    -- mm:add_new_objective("INCOME_AT_LEAST_X");
    -- mm:add_condition("income " .. 5000);
    -- mm:add_payload("text_display li_morathi_give_away_money");
    mm:set_show_mission(true);
    mm:add_each_time_trigger_callback(function()
        cm:set_saved_value(missions[1], true);
    end);
    mm:trigger();
end

local function convene_end(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= missions[1] then
        return;
    end
    teclis_transaction();
    cm:trigger_dilemma(li_mor:get_char():faction():name(), dilemmas[1]);
    cm:set_saved_value(missions_finished[1], true);
end

local function respawn_teclis()
    local spawn_region = "wh3_main_combi_region_soteks_trail";
    local faction_name = li_mor.teclis.faction;
    local unit_list =
    "wh2_dlc15_hef_mon_arcane_phoenix_0,wh2_dlc15_hef_mon_arcane_phoenix_0,wh2_main_hef_art_eagle_claw_bolt_thrower,wh2_main_hef_art_eagle_claw_bolt_thrower,wh2_main_hef_inf_phoenix_guard,wh2_main_hef_inf_phoenix_guard,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_swordmasters_of_hoeth_0,wh2_main_hef_inf_swordmasters_of_hoeth_0,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0";
    li_mor:log("respawning Teclis faction");
    li_mor:respawn_faction(spawn_region, faction_name, unit_list);
end


local function teclis_distraction_battle_end(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= missions[2] then
        return;
    end

    local mor = li_mor:get_char();
    local target = li_mor:get_target_character(target_table);
    if mor == nil or target == nil then
        return;
    end

    li_mor:log("successfully finished Teclis council distraction mission");
    -- confederate his entire faction; since they are dark evles they accept your rule nominally, but will likely rebel
    cm:set_saved_value(missions_finished[2], true);

    local dilemma_name = dilemmas[2];
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
            -- adds 2 sub/dom points
            if choice == 0 then
                li_mor:sub_choice(target_table, false);
                cm:trigger_dilemma(li_mor:get_char():faction():name(), events[1]["sub"]);
            elseif choice == 1 then
                li_mor:dom_choice(target_table, false);
                cm:trigger_dilemma(li_mor:get_char():faction():name(), events[1]["dom"]);
            end
            -- progression on the next turn
            core:remove_listener(delimma_choice_listener_name);
            cm:set_saved_value(confed_next_turn, true);
        end,
        true
    );
    cm:trigger_dilemma(mor:faction():name(), dilemma_name);
end

local function teclis_confederation()
    local mor = li_mor:get_char();
    local target = li_mor:get_target_character(li_mor.teclis);
    if mor == nil or target == nil then
        li_mor:log("Couldn't confederate Teclis, missing characters");
        return;
    end

    li_mor:log("confederating Teclis");
    local dilemma_name = dilemmas[3];
    local delimma_choice_listener_name = dilemma_name .. "_DilemmaChoiceMadeEvent";
    -- using persist = true even for a delimma event in case they click on another delimma first
    core:add_listener(
        delimma_choice_listener_name,
        "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == dilemma_name;
        end,
        function(context)
            -- confederation after next dilemma (inevitable)
            -- TODO trigger last dilemma somewhere
            local target = li_mor:get_target_character(li_mor.teclis);
            if target == nil then
                li_mor:log("Couldn't confederate Teclis, missing characters");
                return;
            end
            li_mor:clear_faction_character_stance(target:faction());
            cm:force_confederation(mor:faction():name(), target:faction():name());
            -- cm:wound_character("character_cqi:" .. target:cqi(), 999);

            -- seems to not trigger reliably?
            -- cm:change_character_localised_name(target, "names_name_" .. li_mor.teclis.name_id, "", "", "");

            core:remove_listener(delimma_choice_listener_name);
            cm:set_saved_value(progress_next_turn, true);
        end,
        true
    );
    cm:trigger_dilemma(mor:faction():name(), dilemma_name);
end

---Restore target character and their faction needed for this mission
---@param context any
local function keep_target_alive_for_mission(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end
    local teclis = li_mor:get_target_character(li_mor.teclis);
    if teclis == nil then
        respawn_teclis()
        teclis = li_mor:get_target_character(li_mor.teclis);
        if teclis == nil then
            li_mor:error("Teclis not found even after respawn");
            return;
        end
    end
    cm:stop_character_convalescing(teclis:cqi());
end

local function recover_target()
    local mor = li_mor:get_char();
    local target = li_mor:get_target_character(li_mor.teclis);
    if mor == nil or target == nil then
        return;
    end
    cm:change_character_localised_name(target, "names_name_" .. li_mor.teclis.name_id, "", "", "");
    cm:stop_character_convalescing(target:cqi());
    cm:force_add_trait(cm:char_lookup_str(target), teclis_trait_name, true);
end

local function start_distraction_mission(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end
    cm:set_saved_value(missions[2], true);
    if mor:faction():is_human() then
        li_mor:log("triggering distraction mission");
        cm:trigger_mission(mor:faction():name(), missions[2], true);
    else
        -- give AI a pass
        li_mor:log("skipping mission battle for AI")
        cm:set_saved_value(missions_finished[2], true);
        cm:set_saved_value(progress_next_turn, true);
    end
end

local function teclis_main_progression_turn_start_manager(context)
    local mor = li_mor:get_char();
    if mor == nil or context:faction():name() ~= mor:faction():name() or li_mor:get_stage() ~= (this_stage - 1) then
        return;
    end

    if not cm:get_saved_value(missions[1]) then
        start_fourth_stage(context);
    end

    -- need to keep Teclis alive for the entire stage
    if mor:faction():is_human() then
        keep_target_alive_for_mission(context);
    end

    -- start distraction mission for Malus (quest battle)
    if cm:get_saved_value(missions_finished[1]) and not cm:get_saved_value(missions[2]) then
        start_distraction_mission(context);
    end

    if mor:faction():is_human() then
        if cm:get_saved_value(confed_next_turn) and not cm:get_saved_value(progress_next_turn) then
            teclis_confederation();
        elseif cm:get_saved_value(progress_next_turn) then
            recover_target();
            li_mor:trigger_progression(context, true);
        end
    end
end

local function progress_to_this_stage_triggers()
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    if li_mor:get_stage() == this_stage - 1 then
        core:add_listener(
            "FactionTurnStartMorathiTeclis",
            "FactionTurnStart",
            true,
            teclis_main_progression_turn_start_manager,
            true
        );

        -- listen for completing the quest battle
        -- if mor:faction():is_human() and not cm:get_saved_value(missions_finished[2]) then
        --     local mission_fight_listener_name = missions[2] .. "_BattleCompletedListener";
        --     core:add_listener(
        --         mission_fight_listener_name,
        --         "BattleCompleted",
        --         function(context)
        --             local pb = context:model():pending_battle();
        --             return pb:has_been_fought() and pb:set_piece_battle_key() == set_piece_battle_key;
        --         end,
        --         function(context)
        --             local pb = context:model():pending_battle();
        --             local won = pb:attacker_won() and not pb:is_draw();

        --             li_mor:log("fought distraction quest mission won? " .. tostring(won) ..
        --                 " set piece key " ..
        --                 pb:set_piece_battle_key() .. " has been fought " .. tostring(pb:has_been_fought()));

        --             if won then
        --                 cm:set_saved_value(missions_finished[2], true);
        --                 core:remove_listener(mission_fight_listener_name);
        --             end
        --         end,
        --         true
        --     );
        -- end

        -- listen for missions for humans
        if mor:faction():is_human() then
            if not cm:get_saved_value(missions_finished[1]) then
                core:add_listener(
                    "MissionSucceededMorathiConvene",
                    "MissionSucceeded",
                    true,
                    convene_end,
                    true
                );
            end
            if not cm:get_saved_value(missions_finished[2]) then
                core:add_listener(
                    "MissionSucceededMorathiDistraction",
                    "MissionSucceeded",
                    true,
                    teclis_distraction_battle_end,
                    true
                );
            end
        end
    end
end

local function broadcast_self()
    local name = "fourth"; -- use as the key for everything
    li_mor:stage_register(name, this_stage, function(context, is_human)
        li_mor:subdom_progression_callback(context, is_human, CFSettings.mor[this_stage]);
    end); 

    li_mor:add_listener(
        "MorProgressionTrigger".. this_stage,
        function(context)
            return (context:type() == "enter" or context:type() == "init") and context:stage() == this_stage - 1;
        end,
        function(context)
            progress_to_this_stage_triggers();
        end,
        false -- not persistent! This is important to avoid adding duplicate listeners inside
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);
