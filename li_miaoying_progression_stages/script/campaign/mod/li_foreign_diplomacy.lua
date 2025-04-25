local progression_response_listener_name = "ScriptEventNkariResponseListener";
local nkari_faction = "wh3_main_sla_seducers_of_slaanesh";
local response_dilemma_base = "li_miaoying_resp_";
local suppress_next_msg = "diplomacy_suppress_next_response";
local consecutive_loss_to_nkari_name = "li_miaoying_consec_loss_nkari";
local nkari_subtype = "wh3_main_sla_nkari";

local enable_diplomacy_for_cultures = { ["wh3_main_sla_slaanesh"] = true, ["wh_main_chs_chaos"] = true };

local function trait_name_for_stage(stage)
    if stage < 4 then
        return "li_trait_corrupt_boots";
    elseif stage < 7 then
        return "li_trait_corrupt_body";
    else
        -- this means that after she gets max corrupted, losing to Nkari will get you impregnated? (doesn't quite make sense)
        -- return "li_trait_broodmother";
        return "li_trait_corrupt_body";
    end
end

local function progression_response_callback(context)
    -- listener only created for human players of that faction, so no need to check here
    -- trigger dilemmas for Nkari to respond to Miao's choice
    local miao_response = context:type();
    li_miao:log("Miao response type " .. miao_response);
    if miao_response == "progression" then
        return
    end

    local suppressed = cm:get_saved_value(suppress_next_msg);
    if suppressed then
        cm:set_saved_value(suppress_next_msg, false);
        return
    end

    local stage = context:stage();
    -- trigger dilemma with choices
    local response_dilemma = response_dilemma_base .. miao_response .. "_" .. tostring(stage);
    li_miao:log("Nkari responds to Miao's choice " .. miao_response .. " with dilemma " .. response_dilemma);
    cm:trigger_dilemma(nkari_faction, response_dilemma);
    -- only have to care about response if she rejects, otherwise it's just flavor text
    if miao_response == "reject" then
        -- listen to triggered dilemma's choices
        local delimma_choice_listener_name = response_dilemma .. "_DilemmaChoiceMadeEvent";
        -- using persist = true even for a delimma event in case they click on another delimma first
        core:add_listener(
            delimma_choice_listener_name,
            "DilemmaChoiceMadeEvent",
            function(context)
                return context:dilemma() == response_dilemma;
            end,
            function(context)
                local choice = context:choice();
                li_miao:log(response_dilemma .. " choice " .. tostring(choice));
                -- on rejection player opted to pay influence
                if choice == 1 then
                    -- temporarily suppress next message (since the accept message will fire)
                    cm:set_saved_value(suppress_next_msg, true);
                    li_miao:advance_stage(trait_name_for_stage(stage), stage);
                end
                core:remove_listener(delimma_choice_listener_name);
            end,
            true
        );
    end
end

local function get_nkari()
    return li_miao:get_character_faction_leader(nkari_subtype, nkari_faction);
end

---When Miao is a subject of Nkari, her traditional means of progression will become less available
---Instead, make it so that Nkari just has to be in the same region on turn start
local function add_progression_trigger_as_subject()
    li_miao:log("Adding new ways of Miao progression as N'Kari's subject");
    core:add_listener(
        "FactionTurnStartMiaoNkariProgression",
        "FactionTurnStart",
        true,
        function(context)
            local miao = li_miao:get_char();
            if miao == nil or context:faction():name() ~= miao:faction():name() then
                return
            end
            local nkari = get_nkari();
            if nkari == nil or nkari:region():cqi() ~= miao:region():cqi() then
                return
            end
            -- always trigger progression; rely on cooldown to make it manageable
            li_miao:trigger_progression(context, miao:faction():is_human());
        end,
        true);
end

local function handle_miao_loss()
    local consecutive_losses = (cm:get_saved_value(consecutive_loss_to_nkari_name) or 0) + 1;
    li_miao:log("Miao lost to Nkari consecutively " .. tostring(consecutive_losses));
    local miao = li_miao:get_char();
    local nkari = get_nkari();
    if miao == nil or nkari == nil then
        return;
    end

    if consecutive_losses == 2 then
        -- apply effect bundle
        cm:apply_effect_bundle_to_character("li_miaoying_loss_miao_nkari_1", miao, -1);
        cm:apply_effect_bundle_to_character("li_miaoying_loss_nkari_miao_1", nkari, -1);
        -- give flavor dilemma if human for Nkari and Miao faction
        if miao:faction():is_human() then
            local response_dilemma = "li_miaoying_loss_miao_nkari_1";
            cm:trigger_dilemma(miao:faction():name(), response_dilemma);
            li_miao:log("Notify player miao miao lost twice");
        end
        if nkari:faction():is_human() then
            local response_dilemma = "li_miaoying_loss_nkari_miao_1";
            cm:trigger_dilemma(nkari:faction():name(), response_dilemma);
            li_miao:log("Notify player nkari miao lost twice");
        end
    elseif consecutive_losses == 4 then
        -- don't have to remove this event listener because she won't be fighting Nkari unless she rebels
        -- in which case everything should still apply
        -- TODO events for rebellion after she's been vassalized?
        -- apply effect bundle
        cm:remove_effect_bundle_from_character("li_miaoying_loss_miao_nkari_1", miao);
        cm:remove_effect_bundle_from_character("li_miaoying_loss_nkari_miao_1", nkari);
        cm:apply_effect_bundle_to_character("li_miaoying_loss_miao_nkari_2", miao, -1);
        cm:apply_effect_bundle_to_character("li_miaoying_loss_nkari_miao_2", nkari, -1);

        -- add new ways to trigger her progression
        add_progression_trigger_as_subject();

        -- if Miao is player, she gets vassalized, even if Nkari is also a player
        if miao:faction():is_human() then
            -- don't remove effect bundle, still make her weak vs Slaanesh forces
            -- give vassalization dilemma; single choice but do the vassalization after hitting the button
            local response_dilemma = "li_miaoying_loss_miao_nkari_2";
            cm:trigger_dilemma(miao:faction():name(), response_dilemma);
            local delimma_choice_listener_name = response_dilemma .. "_DilemmaChoiceMadeEvent";
            core:add_listener(
                delimma_choice_listener_name,
                "DilemmaChoiceMadeEvent",
                function(context)
                    return context:dilemma() == response_dilemma;
                end,
                function(context)
                    -- get vassalized
                    cm:force_make_vassal(nkari:faction():name(), miao:faction():name());
                    core:remove_listener(delimma_choice_listener_name);
                    -- notify nkari
                    if nkari:faction():is_human() then
                        cm:trigger_dilemma(nkari:faction():name(), "li_miaoying_loss_nkari_miao_2_vas");
                        li_miao:log("Notify player nkari miao vassalized");
                    end
                end,
                true
            );
            li_miao:log("Notify player miao miao vassalized");
        elseif nkari:faction():is_human() then
            local response_dilemma = "li_miaoying_loss_nkari_miao_2";
            cm:trigger_dilemma(nkari:faction():name(), response_dilemma);
            local delimma_choice_listener_name = response_dilemma .. "_DilemmaChoiceMadeEvent";
            core:add_listener(
                delimma_choice_listener_name,
                "DilemmaChoiceMadeEvent",
                function(context)
                    return context:dilemma() == response_dilemma;
                end,
                function(context)
                    -- choose to either vassalize or confederate Miao
                    local choice = context:choice();
                    local miao = li_miao:get_char();
                    if miao == nil then
                        return;
                    end
                    li_miao:log(response_dilemma .. " choice " .. tostring(choice));
                    if choice == 0 then
                        cm:force_make_vassal(nkari:faction():name(), miao:faction():name());
                    else
                        cm:force_confederation(nkari:faction():name(), miao:faction():name());
                    end
                    core:remove_listener(delimma_choice_listener_name);
                end,
                true
            );
            li_miao:log("Notify player nkari miao lost 4 times, choose her fate");
        else
            -- AI Miao will become a vassal to AI Nkari
            cm:force_make_vassal(nkari:faction():name(), miao:faction():name());
        end
    end
    cm:set_saved_value(consecutive_loss_to_nkari_name, consecutive_losses);
end

local function handle_miao_win()
    -- clear consecutive loss counter and effect bundle
    local miao = li_miao:get_char();
    local nkari = get_nkari();
    -- clear effect bundles
    if miao ~= nil then
        cm:remove_effect_bundle_from_character("li_miaoying_loss_miao_nkari_1", miao);
        cm:remove_effect_bundle_from_character("li_miaoying_loss_miao_nkari_2", miao);
    end
    if nkari ~= nil then
        cm:remove_effect_bundle_from_character("li_miaoying_loss_nkari_miao_1", nkari);
        cm:remove_effect_bundle_from_character("li_miaoying_loss_nkari_miao_2", nkari);
    end
    cm:set_saved_value(consecutive_loss_to_nkari_name, 0);
    li_miao:log("Miao cleared accumulated losses to Nkari");
end

local function miao_loss_callback(context)
    -- only care if Nkari was the one inflicting the loss
    local pb = cm:model():pending_battle();
    local miao_attacker, miao_defender = li_miao:attacker_or_defender()
    local miao_lost = false;
    if miao_attacker then
        miao_lost = pb:defender_won();
    elseif miao_defender then
        miao_lost = pb:attacker_won();
    else
        -- only care if Miao is in it
        return
    end
    li_miao:log("Miao involved lost in battle? " .. tostring(miao_lost));

    local nkari = get_nkari();
    if nkari == nil then
        return
    end
    local nkari_fmcqi = nkari:family_member():command_queue_index();

    -- local nkari_involved = cm:pending_battle_cache_char_is_involved(nkari);
    -- for some reason the above function doesn't work
    local nkari_involved = false;
    if miao_attacker then
        nkari_involved = cm:pending_battle_cache_get_defender_fm_cqi(1) == nkari_fmcqi;
    elseif miao_defender then
        nkari_involved = cm:pending_battle_cache_get_attacker_fm_cqi(1) == nkari_fmcqi;
    end
    li_miao:log("Nkari involved? " .. tostring(nkari_involved));

    if not nkari_involved then
        return
    end

    -- don't have to gate behind progression events since this only occurs after battle, so you won't get a spam of events hopefully
    if miao_lost then
        handle_miao_loss();
    else
        handle_miao_win();
    end
end

function Test_miao_loss()
    handle_miao_loss()
end

function Test_miao_win()
    handle_miao_win()
end

local function check_if_faction_list_contains_cultures(faction_list, culture_table, debug_prefix)
    for i = 0, faction_list:num_items() - 1 do
        if culture_table[faction_list:item_at(i):culture()] then
            if debug_prefix ~= nil then
                li_miao:log(debug_prefix .. faction_list:item_at(i):name());
            end
            return true;
        end
    end
    return false;
end

local function add_progression_trigger_with_diplomacy()
    li_miao:log("Adding new ways of Miao progression through diplomacy with Slaanesh");
    core:add_listener(
        "FactionTurnStartMiaoDiplomacyProgression",
        "FactionTurnStart",
        true,
        function(context)
            local miao = li_miao:get_char();
            if miao == nil or context:faction():name() ~= miao:faction():name() then
                return
            end
            -- check if we have any diplomatic relations with the diplomatic daemon factions
            -- loop over all relevant factions; max of 1 applied for each option
            local to_add = 0;
            if check_if_faction_list_contains_cultures(miao:faction():factions_non_aggression_pact_with(),
                enable_diplomacy_for_cultures, "NAP with ") then
                to_add = to_add + CFSettings.miao_progress_nap;
            end
            if check_if_faction_list_contains_cultures(miao:faction():factions_trading_with(),
                enable_diplomacy_for_cultures, "trading with ") then
                to_add = to_add + CFSettings.miao_progress_trade;
            end
            if check_if_faction_list_contains_cultures(miao:faction():factions_allied_with(),
                enable_diplomacy_for_cultures, "allied with ") then
                to_add = to_add + CFSettings.miao_progress_ally;
            end

            local l = miao:faction():factions_met();
            for i = 0, l:num_items() - 1 do
                local faction = l:item_at(i);
                if enable_diplomacy_for_cultures[faction:culture()] and
                    (faction:is_vassal_of(miao:faction()) or miao:faction():is_vassal_of(faction)) then
                    to_add = to_add + CFSettings.miao_progress_vassal;
                    li_miao:log("vassal relationship with " .. faction:name());
                    break
                end
            end

            -- each diplomacy point is worth 5% progression 
            li_miao:modify_progress_percent(to_add, "diplomacy");
        end,
        true);
end

local function enable_diplomacy()
    local miao = li_miao:get_char();
    if miao ~= nil then
        for culture, _ in pairs(enable_diplomacy_for_cultures) do
            cm:force_diplomacy("faction:" .. miao:faction():name(), "culture:" .. culture, "all", true, true);
            li_miao:log("Enabling all diplomacy between Miao and culture " .. culture);
        end

        add_progression_trigger_with_diplomacy();
    end
end

local function persistent_diplomacy_bonus()
    li_miao:log("Adding diplomatic bonuses to Slaanesh forces to reflect their change in strategy in dealing with you");
    local corruption_factions = { "wh3_dlc20_chs_sigvald", "wh3_dlc20_chs_azazel" };
    core:add_listener(
        "FactionTurnStartMiaoCorruptingForceChangeAttitude",
        "FactionTurnStart",
        true,
        function(context)
            local miao = li_miao:get_char();
            if miao == nil or context:faction():name() ~= miao:faction():name() then
                return
            end
            for i = 1, #corruption_factions do
                local faction_name = corruption_factions[i];
                local diplo_standing = miao:faction():diplomatic_standing_with(faction_name);
                if diplo_standing < 0 then
                    cm:apply_dilemma_diplomatic_bonus(miao:faction():name(), faction_name, 5);
                    li_miao:log(faction_name .. " standing " .. tostring(diplo_standing) .. " adding bonus");
                end
            end
        end,
        true);
end

local function broadcast_self()

    -- only register main progression response dilemmas when player is slaanesh
    local nkari = get_nkari();
    -- AI nkari just ignores her responses
    if nkari ~= nil and nkari:faction():is_human() then
        li_miao:log("As player Nkari, listening to respond to Miao progression events");
        -- listen for main progression events
        core:add_listener(progression_response_listener_name, li_miao.main_event, true, progression_response_callback,
            true);
    end
    -- loss callback always fires; only get dilemma for flavour text if human though (checked separately for each faction)
    -- can only leave a lasting mark on her when she's sufficiently corrupted
    li_miao:persistent_initialization_register(2, function()
        li_miao:log("Miao Ying sufficiently corrupted to start consecutive loss sequence to Nkari");
        core:add_listener("BattleCompletedMiaoYingNkariLoss", "BattleCompleted", true, miao_loss_callback, true);
    end, "start count consecutive losses");
    -- check if she's already a vassal or confederated to add new progression triggers
    local miao = li_miao:get_char();
    if miao ~= nil and nkari ~= nil then
        if miao:faction():is_vassal_of(nkari:faction()) or (miao:faction():name() == nkari:faction():name()) then
            add_progression_trigger_as_subject();
        end
    end
    if miao ~= nil then
        -- enable dipomacy with Slaanesh when Miao's sufficiently corrupted
        li_miao:persistent_initialization_register(1, enable_diplomacy, "enable diplomacy with all major corrupting forces");
        li_miao:persistent_initialization_register(1, persistent_diplomacy_bonus, "diplomatic bonus until positive");
    end
end

cm:add_first_tick_callback(function() broadcast_self() end);
