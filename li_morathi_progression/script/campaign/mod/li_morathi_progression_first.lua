local trait_name = "li_trait_morathi_hot_body";
local li_ai_corruption_chance = 80;
local this_stage = 1;

local region_key = "wh3_main_combi_region_ancient_city_of_quintex";
local codex_anc_key = "li_blank_codex";
local codex_mission_key = "li_morathi_progression_first_battle";
local codex_mission_finished_key = "li_morathi_progression_first_battle_finished";
local set_piece_battle_key = "li_morathi_progression_first_battle";
local mission_fight_listener_name = "Li_Blank_Codex_Battle_Listener";

local alith_fight_mission_key = "li_morathi_progression_alith_battle";

local alliance_anc_key = "wh3_main_anc_follower_sla_epicurean";
local alliance_mission_key = "li_morathi_progression_slaanesh_alliance";
local alliance_mission_finished_key = "li_morathi_progression_slaanesh_alliance_finished";

local alith_anar_mission_key = "li_morathi_progression_alith_anar";
local alith_anar_mission_finished_key = "li_morathi_progression_alith_anar_finished";

local dilemma_name = "li_morathi_progression_consummate";
local progression_finished_key = "li_morathi_progression_consummate_finished";
local dilemma_sub_name = "li_morathi_progression_consummate_sub";
local dilemma_dom_name = "li_morathi_progression_consummate_dom";
local dilemma_reject_name = "li_morathi_progression_consummate_reject";

local function progression_callback(context, is_human)
    -- dilemma for choosing to accept or reject the gift
    if is_human then
        li_mor:log("Human progression, trigger dilemma " .. dilemma_name);
        cm:trigger_dilemma(li_mor:get_char():faction():name(), dilemma_name);
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
                    li_mor:modify_sub_score(CFSettings.mor_sub_gain);
                    li_mor:adjust_character_loyalty(-1);
                    cm:trigger_dilemma(li_mor:get_char():faction():name(), dilemma_sub_name);
                    li_mor:advance_stage(trait_name, this_stage);
                elseif choice == 1 then
                    li_mor:modify_sub_score(-CFSettings.mor_dom_gain);
                    li_mor:adjust_character_loyalty(1);
                    cm:trigger_dilemma(li_mor:get_char():faction():name(), dilemma_dom_name);
                    li_mor:advance_stage(trait_name, this_stage);
                elseif choice == 2 then
                    li_mor:adjust_character_loyalty(2);
                    cm:trigger_dilemma(li_mor:get_char():faction():name(), dilemma_reject_name);
                    li_mor:fire_event({type="reject", stage=this_stage});
                end
                core:remove_listener(delimma_choice_listener_name);
            end,
            true
        );
    else
        -- if it's not the human
        local rand = cm:random_number(100, 1);
        li_mor:log("AI rolled " .. tostring(rand) .. " against chance to corrupt " .. li_ai_corruption_chance)
        if rand <= li_ai_corruption_chance then
            -- roll for sub/dom choice
            local rand = cm:random_number(100, 1);
            if rand <= 50 then
                li_mor:modify_sub_score(CFSettings.mor_sub_gain);
            else
                li_mor:modify_sub_score(-CFSettings.mor_dom_gain);
            end
            li_mor:advance_stage(trait_name, this_stage);
        else
            li_mor:fire_event({type="reject", stage=this_stage});
        end
    end
end

local function codex_mission_trigger(context)
    -- only fire once 2nd stage of Quintex landmark gets built
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    -- get quintex region
    local region = cm:get_region(region_key);
    if not region then
        return;
    end

    -- listen for landmark existence
    local built_landmark = region:building_exists("wh2_main_special_quintex_2");
    if CFSettings.mor_min_landmark_for_quest < 3 and region:building_exists("wh2_main_special_quintex_1") then
        built_landmark = true;
    end
    if CFSettings.mor_min_landmark_for_quest < 2 and region:building_exists("wh2_main_special_quintex_0") then
        built_landmark = true;
    end

    if not built_landmark then
        return;
    end

    cm:set_saved_value(codex_mission_key, true);
    if mor:faction():is_human() then
        li_mor:log("triggering codex mission");
        cm:trigger_mission(mor:faction():name(), codex_mission_key, true);
    else
        -- give AI blank codex directly
        li_mor:log("skipping mission battle for AI")
        cm:set_saved_value(codex_mission_finished_key, true);
        cm:force_add_ancillary(mor, codex_anc_key, true, true);
    end
end

local function slaanesh_aliance_trigger(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    cm:set_saved_value(alliance_mission_key, true);
    if mor:faction():is_human() then
        li_mor:log("triggering Slaanesh alliance mission");
        cm:trigger_dilemma(mor:faction():name(), alliance_mission_key);
    else
        -- give AI mission reward
        li_mor:log("skipping Slaanesh alliance for AI")
        cm:force_add_ancillary(mor, alliance_anc_key, true, true);
    end
end

local function trigger_alith_anar_mission()
    -- cm:trigger_mission(mor:faction():name(), alith_anar_mission_key, true);
    local mor = li_mor:get_char();
    local alith_anar = li_mor:get_target_character(li_mor.alith_anar);
    if mor == nil or alith_anar == nil or not alith_anar:has_military_force() then
        return;
    end

    local mm = mission_manager:new(mor:faction():name(), alith_anar_mission_key);
    if not mm then
        li_mor:log("ERROR: not create alith anar mission manager");
        return;
    end
    mm:set_mission_issuer("CLAN_ELDERS");
    mm:add_new_objective("KILL_CHARACTER_BY_ANY_MEANS");
    mm:add_condition("family_member " .. alith_anar:family_member():command_queue_index());
    mm:add_payload("money 1000");
    mm:set_show_mission(true);
    mm:add_each_time_trigger_callback(function()
        cm:set_saved_value(alith_anar_mission_key, true);
        li_mor:log("triggered Alith Anar mission");
    end);
    mm:trigger();
end

local function alith_anar_capture_start(context, ignore_alliance)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    ignore_alliance = ignore_alliance or false;
    if ignore_alliance == false then
        -- check if we have an alliance with Slaanesh faction
        local has_slaanesh_alliance = false;
        local faction_list = mor:faction():factions_allied_with();
        for i = 0, faction_list:num_items() - 1 do
            if faction_list:item_at(i):culture() == "wh3_main_sla_slaanesh" then
                has_slaanesh_alliance = true;
                break;
            end
        end

        if not has_slaanesh_alliance then
            return;
        end
    end

    li_mor:log("has alliance with Slaanesh and finished codex quest");
    if not cm:get_saved_value(alliance_mission_finished_key) then
        cm:set_saved_value(alliance_mission_finished_key, true);
        if mor:faction():is_human() then
            cm:trigger_dilemma(mor:faction():name(), alliance_mission_finished_key);
        else
            -- add reward directly
            li_mor:log("skipping Alith Anar mission for AI");
            cm:force_add_ancillary(mor, alliance_anc_key, true, true);
            li_mor:trigger_progression(context, false);
        end
    end
    -- additionally trigger mission if we're not on it; note that we may fail and need to restart
    if mor:faction():is_human() and not cm:get_saved_value(alith_anar_mission_key) then
        -- on-campaign kill mission
        -- trigger_alith_anar_mission();
        -- set piece battle mission
        cm:trigger_mission(mor:faction():name(), alith_fight_mission_key, true);
        cm:set_saved_value(alith_anar_mission_key, true);
    end
end

---Restore target character and their faction needed for this mission
---@param context any
local function keep_target_alive_for_mission(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    local alith = li_mor:get_target_character(li_mor.alith_anar);
    if alith == nil then
        -- spawn alith with an army in his home province
        local spawn_region = "wh3_main_combi_region_karond_kar";
        local faction_name = li_mor.alith_anar.faction;
        local unit_list =
        "wh2_dlc15_hef_mon_arcane_phoenix_0,wh2_main_hef_art_eagle_claw_bolt_thrower,wh2_main_hef_art_eagle_claw_bolt_thrower,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0,wh2_dlc10_hef_inf_shadow_warriors_0,wh2_dlc10_hef_inf_shadow_warriors_0,wh2_dlc10_hef_inf_shadow_warriors_0,wh2_dlc10_hef_inf_shadow_warriors_0,wh2_dlc10_hef_inf_shadow_walkers_0,wh2_dlc10_hef_inf_shadow_walkers_0,wh2_dlc10_hef_inf_shadow_walkers_0,wh2_dlc10_hef_inf_shadow_walkers_0,wh2_dlc10_hef_inf_shadow_walkers_0,wh2_dlc10_hef_inf_shadow_walkers_0";
        li_mor:log("respawning Alith Anar faction");
        li_mor:respawn_faction(spawn_region, faction_name, unit_list);
        alith = li_mor:get_target_character(li_mor.alith_anar);
        if alith == nil then
            li_mor:error("Alith Anar not found even after respawn");
            return;
        end
    end

    cm:stop_character_convalescing(alith:cqi());
end

local function alith_anar_capture_failed(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= alith_anar_mission_key and mission_key ~= alith_fight_mission_key then
        return;
    end
    -- mission should retrigger when the target recovers
    li_mor:log("Alith Anar captured failed, allow retry");
    cm:set_saved_value(alith_anar_mission_key, false);
end

local function do_alith_anar_capture_end()
    local mor = li_mor:get_char();
    local alith_anar = li_mor:get_target_character(li_mor.alith_anar);
    if mor == nil or alith_anar == nil then
        return;
    end

    li_mor:log("successfully finished alith anar capture mission");
    -- remove Alith Anar from his faction
    cm:set_saved_value(alith_anar_mission_finished_key, true);
    --spawn this force as a guard against the player killing Alith Anar and occupying his last settlement at the same time. kill them with notice supressed after confederation
    -- local cqi_generated = nil;
    -- cm:create_force_with_general("wh2_main_hef_nagarythe", "", "wh3_main_combi_region_hag_graef", 74, 590, "general",
    --     "wh2_main_def_dreadlord_fem", "names_name_2147359620", "", "", "", true,
    --     function(cqi)
    --         cqi_generated = cqi;
    --     end
    -- );

    -- find faction to transfer to
    local faction_to_transfer = nil;
    for i = 3, #li_mor.alith_anar.confed_factions do
        if cm:get_faction(li_mor.alith_anar.confed_factions[i]) ~= false then
            faction_to_transfer = li_mor.alith_anar.confed_factions[i];
            li_mor:log("transferring alith anar to " .. faction_to_transfer);
            break;
        end
    end

    -- remove all but his home region
    local home_region = alith_anar:faction():home_region();
    -- has some regions
    if home_region ~= nil and not home_region:is_null_interface() then
        local region_list = alith_anar:faction():region_list();
        for i = 0, region_list:num_items() - 1 do
            local region = region_list:item_at(i);
            if region:cqi() ~= home_region:cqi() then
                li_mor:log("removing alith anar non-home region " .. region:name());
                -- transfer to rebel faction
                if faction_to_transfer == nil then
                    cm:set_region_abandoned(region:name());
                else
                    cm:transfer_region_to_faction(region:name(), faction_to_transfer);
                end
            end
        end
    end

    -- confederate
    li_mor:clear_faction_character_stance(alith_anar:faction());
    cm:force_confederation(mor:faction():name(), alith_anar:faction():name());
    -- li_mor:delayed_kill_cqi(cqi_generated, 15);
end

local function alith_anar_capture_end(context)
    local mission_key = context:mission():mission_record_key();
    -- allow both quest battle mission and on-campus kill mission to trigger this
    if mission_key ~= alith_anar_mission_key and mission_key ~= alith_fight_mission_key then
        return;
    end

    do_alith_anar_capture_end();
end

local function delayed_progression_check(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    li_mor:log("stage 0 to 1 delayed progression");

    -- need to change his name after to reflect his new culture
    local alith_anar = li_mor:get_target_character(li_mor.alith_anar);
    if alith_anar == nil then
        li_mor:log("ERROR: Alith Anar nil after confederation for some reason");
        return;
    end
    cm:change_character_localised_name(alith_anar, "names_name_" .. li_mor.alith_anar.name_id, "", "", "");

    -- set him to wounded max turns until our training of him is complete
    -- cm:wound_character("character_cqi:" .. alith_anar:cqi(), 999);
    -- NOTE use cm:stop_character_convalescing to instantly recover

    cm:set_saved_value(progression_finished_key, true);
    li_mor:trigger_progression(context, mor:faction():is_human());
end

local function alith_anar_main_progression_turn_start_manager(context)
    local mor = li_mor:get_char();
    if mor == nil or context:faction():name() ~= mor:faction():name() or li_mor:get_stage() ~= 0 then
        return;
    end

    if not cm:get_saved_value(codex_mission_key) then
        codex_mission_trigger(context);
    end

    -- listen for when we've finished the quest and can move onto forming an alliance with Slaanesh
    if cm:get_saved_value(codex_mission_finished_key) and not cm:get_saved_value(alliance_mission_key) then
        slaanesh_aliance_trigger(context);
    end

    -- keep alith anar alive for mission
    if mor:faction():is_human() and not cm:get_saved_value(alith_anar_mission_finished_key) then
        keep_target_alive_for_mission(context);
    end

    -- listen for when we've finished the previous two and need to capture Alith Anar
    if cm:get_saved_value(codex_mission_finished_key) and not cm:get_saved_value(alith_anar_mission_key) then
        alith_anar_capture_start(context);
    end

    -- delay checking for progression to another turn to avoid crashing via having too many things happening at once
    if mor:faction():is_human() and cm:get_saved_value(alith_anar_mission_finished_key) then
        delayed_progression_check(context);
    end
end

local function broadcast_self()
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    -- command script will define API to register stage
    local name = "first"; -- use as the key for everything
    li_mor:stage_register(name, this_stage, progression_callback);

    core:add_listener(
        "MorEnterNameChange",
        li_mor.main_event,
        function(context)
            return context:type() == "enter";
        end,
        function(context)
            -- TODO consider if we can use different names depending on sub/dom level
            li_mor:change_title(context:stage());
        end,
        true
    );

    if li_mor:get_stage() == 0 then
        core:add_listener(
            "FactionTurnStartMorathiAlithAnar",
            "FactionTurnStart",
            true,
            alith_anar_main_progression_turn_start_manager,
            true
        );
    end

    -- listen for completing the quest battle
    if mor:faction():is_human() and not cm:get_saved_value(codex_mission_finished_key) then
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

                li_mor:log("fought codex quest mission won? " .. tostring(won) ..
                    " set piece key " ..
                    pb:set_piece_battle_key() .. " has been fought " .. tostring(pb:has_been_fought()));

                if won then
                    cm:set_saved_value(codex_mission_finished_key, true);
                    core:remove_listener(mission_fight_listener_name);
                end
            end,
            true
        );
    end


    -- listen for when we've finished the alith anar mission
    if mor:faction():is_human() and not cm:get_saved_value(alith_anar_mission_finished_key) then
        core:add_listener(
            "MissionSucceededMorathiAlithAnar",
            "MissionSucceeded",
            true,
            alith_anar_capture_end,
            true
        );
        -- listen for mission failure for some reason (potentially also recover their faction if they get wiped out)
        core:add_listener(
            "MissionCancelledMorathiAlithAnar",
            "MissionCancelled",
            true,
            alith_anar_capture_failed,
            true
        );
    end
end

function Debug_start_alith_anar()
    alith_anar_capture_start(nil, true);
end

cm:add_first_tick_callback(function() broadcast_self() end);
