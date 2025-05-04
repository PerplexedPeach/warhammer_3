local nkari_trait_name = "li_trait_nkari_morathi";
-- for AI this stage gets rolled every turn
local this_stage = 3;

local missions = { "li_morathi_teclis_offer", "li_morathi_teclis_nkari", "li_morathi_teclis_nkari_bind" };
local missions_finished = { "li_morathi_teclis_offer_finished", "li_morathi_teclis_nkari_finished",
    "li_morathi_teclis_nkari_bind_finished" };
local intro_dilemma = "li_morathi_teclis_intro";
local offer_made_dilemma = "li_morathi_teclis_offer_made";
local capture_nkari_dilemma = "li_morathi_nkari_capture";
local bind_nkari_dilemma = "li_morathi_nkari_bind";
local events = {
    { ["sub"] = "li_morathi_nkari_capture_sub", ["dom"] = "li_morathi_nkari_capture_dom" },
    { ["sub"] = "li_morathi_nkari_bind_sub",    ["dom"] = "li_morathi_nkari_bind_dom" },
};

local shrine_of_khaine_region = "wh3_main_combi_region_shrine_of_khaine";
-- local shrine_of_khaine_province = "wh3_main_combi_region_shrine_of_khaine";

-- progression notification dilemma (choice of proceeding is to do previous quests or not)
local nkari_capture_delay_process = "nkari_capture_delayed";
local progress_next_turn = "li_morathi_nkari_progress_next_turn";
local target_table = li_mor.nkari;

CFSettings.mor[this_stage] = {
    dilemma_name = "li_morathi_nkari_progression",
    trait_name = "li_trait_morathi_hot_body",
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
    -- teclis receives shrine of khaine and 10k gold
    -- you receive a NAP with teclis
    if not cm:is_region_owned_by_faction(shrine_of_khaine_region, mor:faction():name()) then
        cm:trigger_dilemma(mor:faction():name(), "li_morathi_shrine_trade");
    end
    cm:transfer_region_to_faction(shrine_of_khaine_region, teclis:faction():name());
    cm:treasury_mod(mor:faction():name(), -CFSettings.mor_sok_donation);
    cm:treasury_mod(teclis:faction():name(), CFSettings.mor_sok_donation);
    cm:force_make_peace(teclis:faction():name(), mor:faction():name());
    cm:force_remove_ancillary_from_faction(mor:faction(), "wh2_dlc10_anc_weapon_the_widowmaker_1");
    cm:force_remove_ancillary_from_faction(mor:faction(), "wh2_dlc10_anc_weapon_the_widowmaker_2");
    cm:force_remove_ancillary_from_faction(mor:faction(), "wh2_dlc10_anc_weapon_the_widowmaker_3");
    for i = 1, 10 do
        cm:apply_dilemma_diplomatic_bonus(mor:faction():name(), teclis:faction():name(), 5);
    end
end

local function start_third_stage(context)
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

    cm:trigger_dilemma(mor:faction():name(), intro_dilemma);

    local mm = mission_manager:new(mor:faction():name(), missions[1]);
    if not mm then
        li_mor:log("ERROR: not create shrine of khaine capture mission manager");
        return;
    end
    mm:set_mission_issuer("CLAN_ELDERS");
    mm:add_new_objective("CONTROL_N_REGIONS_FROM");
    mm:add_condition("region " .. shrine_of_khaine_region);
    mm:add_condition("total 1");
    mm:add_payload("text_display li_morathi_give_away_sok");
    -- mm:add_new_objective("INCOME_AT_LEAST_X");
    -- mm:add_condition("income " .. 5000);
    -- mm:add_payload("text_display li_morathi_give_away_money");
    mm:set_show_mission(true);
    mm:add_each_time_trigger_callback(function()
        cm:set_saved_value(missions[1], true);
    end);
    mm:trigger();
end

local function sok_capture_end(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= missions[1] then
        return;
    end

    teclis_transaction();
    cm:set_saved_value(missions_finished[1], true);
end

local function respawn_nkari(full_army)
    local spawn_region = "wh3_main_combi_region_shrine_of_kurnous";
    local faction_name = li_mor.nkari.faction;
    local unit_list = "wh3_main_sla_mon_soul_grinder_0,wh3_main_sla_mon_soul_grinder_0";
    if full_army then
        unit_list = unit_list .. ",wh3_main_sla_mon_spawn_of_slaanesh_0,wh3_main_sla_mon_spawn_of_slaanesh_0,wh3_main_sla_mon_fiends_of_slaanesh_0,wh3_main_sla_mon_fiends_of_slaanesh_0,wh3_main_sla_mon_keeper_of_secrets_0,wh3_main_sla_veh_exalted_seeker_chariot_0,wh3_main_sla_veh_exalted_seeker_chariot_0,wh3_main_sla_veh_seeker_chariot_0,wh3_main_sla_veh_seeker_chariot_0,wh3_main_sla_inf_daemonette_1,wh3_main_sla_inf_daemonette_1,wh3_main_sla_inf_daemonette_1,wh3_main_sla_inf_daemonette_1,wh3_main_sla_inf_marauders_2,wh3_main_sla_inf_marauders_2,wh3_main_sla_inf_marauders_2,wh3_main_sla_cav_heartseekers_of_slaanesh_0";
    end
    li_mor:log("respawning Nkari faction");
    li_mor:respawn_faction(spawn_region, faction_name, unit_list);
end

local function respawn_teclis()
    local spawn_region = "wh3_main_combi_region_soteks_trail";
    local faction_name = li_mor.teclis.faction;
    local unit_list =
    "wh2_dlc15_hef_mon_arcane_phoenix_0,wh2_dlc15_hef_mon_arcane_phoenix_0,wh2_main_hef_art_eagle_claw_bolt_thrower,wh2_main_hef_art_eagle_claw_bolt_thrower,wh2_main_hef_inf_phoenix_guard,wh2_main_hef_inf_phoenix_guard,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_lothern_sea_guard_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_archers_1,wh2_main_hef_inf_swordmasters_of_hoeth_0,wh2_main_hef_inf_swordmasters_of_hoeth_0,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0,wh2_main_hef_inf_spearmen_0";
    li_mor:log("respawning Teclis faction");
    li_mor:respawn_faction(spawn_region, faction_name, unit_list);
end

local function trigger_capture_mission()
    local mor = li_mor:get_char();
    local target = li_mor:get_target_character(target_table);
    if mor == nil or target == nil then
        return;
    end

    -- if the faction exists but Nkari is not on the field, heal them and spawn them with an army
    if not target:has_military_force() then
        cm:stop_character_convalescing(target:cqi());
        respawn_nkari();
        return
    end

    local teclis = li_mor:get_target_character(li_mor.teclis);
    if teclis == nil then
        li_mor:error("teclis is missing for nkari capture mission");
        return;
    end

    local this_dilemma = offer_made_dilemma;
    core:add_listener(
        "DielemmaChoiceMadeEvent" .. this_dilemma,
        "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == this_dilemma;
        end,
        function(context)
            -- local choice = context:choice();
            local mm = mission_manager:new(mor:faction():name(), missions[2]);
            if not mm then
                li_mor:error("could not create nkari capture mission manager");
                return;
            end
            mm:set_mission_issuer("CLAN_ELDERS");
            mm:add_new_objective("KILL_CHARACTER_BY_ANY_MEANS");
            mm:add_condition("family_member " .. target:family_member():command_queue_index());
            mm:add_payload("text_display li_morathi_capture_nkari");
            mm:set_show_mission(true);
            mm:add_each_time_trigger_callback(function()
                cm:set_saved_value(missions[2], true);
            end);
            mm:trigger();
        end,
        false
    );
    cm:trigger_dilemma(li_mor:get_char():faction():name(), offer_made_dilemma);
    cm:force_make_peace(teclis:faction():name(), mor:faction():name());
    cm:force_grant_military_access(teclis:faction():name(), mor:faction():name(), false);
    cm:force_declare_war(teclis:faction():name(), target:faction():name(), false, false);
    for i = 1, 10 do
        cm:apply_dilemma_diplomatic_bonus(mor:faction():name(), teclis:faction():name(), 5);
    end
end

local function nkari_capture_start(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    if mor:faction():is_human() then
        li_mor:log("starting Nkari capture quest");
        trigger_capture_mission();
    else
        -- add reward directly
        li_mor:log("skipping Nkari mission for AI, trigger random progression");
        li_mor:trigger_progression(context, false);
    end
end

local function nkari_capture_end(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= missions[2] then
        return;
    end

    local mor = li_mor:get_char();
    local target = li_mor:get_target_character(target_table);
    if mor == nil or target == nil then
        return;
    end

    li_mor:log("successfully finished nkari capture mission");
    -- confederate his entire faction; since they are dark evles they accept your rule nominally, but will likely rebel
    cm:set_saved_value(missions_finished[2], true);

    local teclis = li_mor:get_target_character(li_mor.teclis);
    if teclis == nil then
        li_mor:error("teclis is missing for nkari capture mission");
        return;
    end

    cm:force_make_peace(teclis:faction():name(), mor:faction():name());
    cm:force_alliance(teclis:faction():name(), mor:faction():name(), false);
    for i = 1, 5 do
        cm:apply_dilemma_diplomatic_bonus(mor:faction():name(), teclis:faction():name(), 5);
    end

    -- confederate

    li_mor:clear_faction_character_stance(target:faction());
    cm:force_confederation(mor:faction():name(), target:faction():name());

    -- seems to not trigger reliably?
    cm:change_character_localised_name(target, "names_name_" .. li_mor.nkari.name_id, "", "", "");
end

local function nkari_bind_end(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= missions[3] then
        return;
    end

    local mor = li_mor:get_char();
    local target = li_mor:get_target_character(target_table);
    li_mor:log("Nkari bind mission end, target is " .. tostring(target));
    if mor == nil or target == nil then
        return;
    end

    li_mor:log("successfully finished nkari binding mission");
    cm:set_saved_value(missions_finished[3], true);


    local teclis = li_mor:get_target_character(li_mor.teclis);
    if teclis == nil then
        li_mor:error("teclis is missing for nkari capture mission");
        return;
    end
    cm:force_make_peace(teclis:faction():name(), mor:faction():name());
    cm:force_alliance(teclis:faction():name(), mor:faction():name(), true);
    for i = 1, 5 do
        cm:apply_dilemma_diplomatic_bonus(mor:faction():name(), teclis:faction():name(), 5);
    end

    local dilemma_name = bind_nkari_dilemma;
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
                li_mor:sub_choice(target_table, true);
                cm:trigger_dilemma(li_mor:get_char():faction():name(), events[2]["sub"]);
            elseif choice == 1 then
                li_mor:dom_choice(target_table, true);
                cm:trigger_dilemma(li_mor:get_char():faction():name(), events[2]["dom"]);
            end
            -- progression on the next turn
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

    local nkari = li_mor:get_target_character(li_mor.nkari);
    if nkari == nil then
        respawn_nkari(true);
        nkari = li_mor:get_target_character(li_mor.nkari);
        if nkari == nil then
            li_mor:error("Nkari not found even after respawn");
            return;
        end
    end
    -- only recover him if nkari's not in our faction (after we've retrieved them)
    if nkari:faction():name() ~= mor:faction():name() then
        cm:stop_character_convalescing(nkari:cqi());
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

local function nkari_capture_failed(context)
    local mission_key = context:mission():mission_record_key();
    if mission_key ~= missions[2] then
        return;
    end
    -- mission should retrigger when the target recovers
    li_mor:log("Nkari captured failed, allow retry");
    cm:set_saved_value(missions[2], false);
end

local function delayed_capture(context)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    cm:set_saved_value(nkari_capture_delay_process, true);
    li_mor:log("initiating delayed capture");

    -- need to change his name after to reflect his new culture
    local nkari = li_mor:get_target_character(li_mor.nkari);
    if nkari == nil then
        li_mor:log("ERROR: Nkari nil after confederation for some reason");
        return;
    end

    cm:change_character_localised_name(nkari, "names_name_" .. li_mor.nkari.name_id, "", "", "");

    -- -- set him to wounded max turns until our training of him is complete
    cm:wound_character("character_cqi:" .. nkari:cqi(), 999);
    -- -- NOTE use cm:stop_character_convalescing to instantly recover
    local delimma_choice_listener_name = capture_nkari_dilemma .. "_DilemmaChoiceMadeEvent";
    -- using persist = true even for a delimma event in case they click on another delimma first
    core:add_listener(
        delimma_choice_listener_name,
        "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == capture_nkari_dilemma;
        end,
        function(context)
            local choice = context:choice();
            li_mor:log(capture_nkari_dilemma .. " choice " .. tostring(choice));
            -- add sub/dom tracking here
            if choice == 0 then
                li_mor:sub_choice(target_table, true);
                cm:trigger_dilemma(li_mor:get_char():faction():name(), events[1]["sub"]);
            elseif choice == 1 then
                li_mor:dom_choice(target_table, true);
                cm:trigger_dilemma(li_mor:get_char():faction():name(), events[1]["dom"]);
            end
            -- trigger next mission
            cm:trigger_mission(mor:faction():name(), missions[3], true);
            core:remove_listener(delimma_choice_listener_name);
        end,
        true
    );
    cm:trigger_dilemma(mor:faction():name(), capture_nkari_dilemma);
end

local function recover_nkari()
    local mor = li_mor:get_char();
    local target = li_mor:get_target_character(li_mor.nkari);
    if mor == nil or target == nil then
        return;
    end
    cm:stop_character_convalescing(target:cqi());
    cm:force_add_trait(cm:char_lookup_str(target), nkari_trait_name, true);
end

local function buff_nkari_faction()
    local target = li_mor:get_target_character(li_mor.nkari);
    if target == nil then
        return;
    end
    cm:treasury_mod(target:faction():name(), 5000);
end

local function nkari_main_progression_turn_start_manager(context)
    local mor = li_mor:get_char();
    if mor == nil or context:faction():name() ~= mor:faction():name() or li_mor:get_stage() ~= (this_stage - 1) then
        return;
    end

    if not cm:get_saved_value(missions[1]) then
        start_third_stage(context);
    end

    -- need to keep Teclis and Nkari alive for the entire stage
    if mor:faction():is_human() then
        keep_target_alive_for_mission(context);
    end

    if cm:get_saved_value(missions_finished[1]) and not cm:get_saved_value(missions[2]) then
        nkari_capture_start(context);
    end

    -- buff the faction while the mission is ongoing to keep them alive
    if not cm:get_saved_value(missions_finished[2]) then
        buff_nkari_faction();
    end

    if mor:faction():is_human() and cm:get_saved_value(missions_finished[2]) and
        not cm:get_saved_value(nkari_capture_delay_process) then
        delayed_capture(context);
    end

    if mor:faction():is_human() and cm:get_saved_value(progress_next_turn) then
        recover_nkari();
        li_mor:trigger_progression(context, true);
    end
end

local function progress_to_this_stage_triggers()
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    if li_mor:get_stage() == this_stage - 1 then
        core:add_listener(
            "FactionTurnStartMorathiNkari",
            "FactionTurnStart",
            true,
            nkari_main_progression_turn_start_manager,
            true
        );

        -- listen for missions for humans
        if mor:faction():is_human() then
            if not cm:get_saved_value(missions_finished[1]) then
                core:add_listener(
                    "MissionSucceededMorathiSOKCapture",
                    "MissionSucceeded",
                    true,
                    sok_capture_end,
                    true
                );
            end
            if not cm:get_saved_value(missions_finished[2]) then
                core:add_listener(
                    "MissionSucceededMorathiNkari",
                    "MissionSucceeded",
                    true,
                    nkari_capture_end,
                    true
                );
                core:add_listener(
                    "MissionCancelledMorathiNkari",
                    "MissionCancelled",
                    true,
                    nkari_capture_failed,
                    true
                );
            end
            if not cm:get_saved_value(missions_finished[3]) then
                core:add_listener(
                    "MissionSucceededMorathiNKariBind",
                    "MissionSucceeded",
                    true,
                    nkari_bind_end,
                    true
                );
            end
        end
    end
end

local function broadcast_self()
    local name = "third"; -- use as the key for everything
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
