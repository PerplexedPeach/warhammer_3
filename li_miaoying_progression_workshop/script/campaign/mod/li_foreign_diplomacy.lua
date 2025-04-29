local progression_response_listener_name = "ScriptEventNkariResponseListener";
local response_dilemma_base = "li_miaoying_resp_";
local suppress_next_msg = "diplomacy_suppress_next_response";


CFSettings["diplomacy"] = {
    nkari = {
        faction = "wh3_main_sla_seducers_of_slaanesh",
        subtype = "wh3_main_sla_nkari",
        consecutive_loss_name = "li_miaoying_consec_loss_nkari",
        -- these should also be dilemma keys
        miao_effect_bundles = {
            "li_miaoying_loss_miao_nkari_1",
            "li_miaoying_loss_miao_nkari_2",
        },
        self_effect_bundles = {
            "li_miaoying_loss_nkari_miao_1",
            "li_miaoying_loss_nkari_miao_2",
        },
        vassalize_dilemma = "li_miaoying_loss_nkari_miao_2_vas",
        consecutive_loss_thresholds = {
            2,
            4,
        },
    }
}
CFSettings["corruption_factions"] = { "wh3_dlc20_chs_sigvald", "wh3_dlc20_chs_azazel" };
CFSettings["enable_diplomacy_for_cultures"] = { ["wh3_main_sla_slaanesh"] = true, ["wh_main_chs_chaos"] = true };

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

local function get_char(char_table)
    return li_miao:get_character_faction_leader(char_table.subtype, char_table.faction);
end

local function progression_response_callback(context, target_name)
    local target_table = CFSettings.diplomacy[target_name];
    -- listener only created for human players of that faction, so no need to check here
    -- trigger dilemmas for target to respond to Miao's choice
    local miao_response = context:type();
    li_miao:log("Miao response type " .. miao_response);
    -- only care about accept or reject
    if miao_response ~= "reject" or miao_response ~= "accept" then
        return
    end

    local suppressed = cm:get_saved_value(suppress_next_msg);
    if suppressed then
        cm:set_saved_value(suppress_next_msg, false);
        return
    end

    local stage = context:stage();
    -- trigger dilemma with choices
    -- if it's accept then just display this for the target
    local response_dilemma = response_dilemma_base .. miao_response .. "_" .. tostring(stage);
    li_miao:log(target_name .. " responds to Miao's choice " .. miao_response .. " with dilemma " .. response_dilemma);
    local target = get_char(target_table);
    if target == nil then
        return
    end
    cm:trigger_dilemma(target:faction():name(), response_dilemma);
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


---When Miao is a subject of target, her traditional means of progression will become less available
---Instead, make it so that target just has to be in the same region on turn start
local function add_progression_trigger_as_subject(target_name)
    li_miao:log("Adding new ways of Miao progression as subject of " .. target_name);
    core:add_listener(
        "FactionTurnStartMiaoProgression" .. target_name,
        "FactionTurnStart",
        true,
        function(context)
            local miao = li_miao:get_char();
            if miao == nil or context:faction():name() ~= miao:faction():name() then
                return
            end
            local target = get_char(CFSettings.diplomacy[target_name]);
            if target == nil or target:region():cqi() ~= miao:region():cqi() then
                return
            end
            -- always trigger progression; rely on cooldown to make it manageable
            li_miao:trigger_progression(context, miao:faction():is_human());
        end,
        true);
end

local function handle_miao_loss(target_name)
    local target_table = CFSettings.diplomacy[target_name];
    local consecutive_losses = (cm:get_saved_value(target_table.consecutive_loss_name) or 0) + 1;
    li_miao:log("Miao lost to " .. target_name .. " consecutively " .. tostring(consecutive_losses));
    local miao = li_miao:get_char();
    local target = get_char(target_table);
    if miao == nil or target == nil then
        return;
    end

    if consecutive_losses == target_table.consecutive_loss_thresholds[1] then
        -- apply effect bundle
        cm:apply_effect_bundle_to_character(target_table.miao_effect_bundles[1], miao, -1);
        cm:apply_effect_bundle_to_character(target_table.self_effect_bundles[1], target, -1);
        -- give flavor dilemma if human for target and Miao faction
        if miao:faction():is_human() then
            local response_dilemma = target_table.miao_effect_bundles[1];
            cm:trigger_dilemma(miao:faction():name(), response_dilemma);
            li_miao:log("Notify player miao miao lost twice");
        end
        if target:faction():is_human() then
            local response_dilemma = target_table.self_effect_bundles[1];
            cm:trigger_dilemma(target:faction():name(), response_dilemma);
            li_miao:log("Notify player " .. target_name .. " miao lost twice");
        end
    elseif consecutive_losses == target_table.consecutive_loss_thresholds[2] then
        -- don't have to remove this event listener because she won't be fighting target unless she rebels
        -- in which case everything should still apply
        -- TODO events for rebellion after she's been vassalized?
        -- apply effect bundle
        cm:remove_effect_bundle_from_character(target_table.miao_effect_bundles[1], miao);
        cm:remove_effect_bundle_from_character(target_table.self_effect_bundles[1], target);
        cm:apply_effect_bundle_to_character(target_table.miao_effect_bundles[2], miao, -1);
        cm:apply_effect_bundle_to_character(target_table.self_effect_bundles[2], target, -1);

        -- add new ways to trigger her progression
        add_progression_trigger_as_subject();

        -- if Miao is player, she gets vassalized, even if target is also a player
        if miao:faction():is_human() then
            -- don't remove effect bundle, still make her weak vs Slaanesh forces
            -- give vassalization dilemma; single choice but do the vassalization after hitting the button
            local response_dilemma = target_table.miao_effect_bundles[2];
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
                    cm:force_make_vassal(target:faction():name(), miao:faction():name());
                    core:remove_listener(delimma_choice_listener_name);
                    -- notify target
                    if target:faction():is_human() then
                        cm:trigger_dilemma(target:faction():name(), target_table.vassalize_dilemma);
                        li_miao:log("Notify player " .. target_name .. " miao vassalized");
                    end
                end,
                true
            );
            li_miao:log("Notify player miao miao vassalized");
        elseif target:faction():is_human() then
            local response_dilemma = target_table.self_effect_bundles[2];
            cm:trigger_dilemma(target:faction():name(), response_dilemma);
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
                        cm:force_make_vassal(target:faction():name(), miao:faction():name());
                    else
                        cm:force_confederation(target:faction():name(), miao:faction():name());
                    end
                    core:remove_listener(delimma_choice_listener_name);
                end,
                true
            );
            li_miao:log("Notify player " ..
                target_name .. " miao lost " .. target_table.consecutive_loss_thresholds[2] .. " times, choose her fate");
        else
            -- AI Miao will become a vassal to AI target
            cm:force_make_vassal(target:faction():name(), miao:faction():name());
        end
    end
    cm:set_saved_value(target_table.consecutive_loss_name, consecutive_losses);
end

local function handle_miao_win(target_name)
    local target_table = CFSettings.diplomacy[target_name];
    -- clear consecutive loss counter and effect bundle
    local miao = li_miao:get_char();
    local target = get_char(target_table);
    -- clear effect bundles
    if miao ~= nil then
        for i = 1, #target_table.miao_effect_bundles do
            cm:remove_effect_bundle_from_character(target_table.miao_effect_bundles[i], miao);
        end
    end
    if target ~= nil then
        for i = 1, #target_table.self_effect_bundles do
            cm:remove_effect_bundle_from_character(target_table.self_effect_bundles[i], target);
        end
    end
    cm:set_saved_value(target_table.consecutive_loss_name, 0);
    li_miao:log("Miao cleared accumulated losses to " .. target_name);
end

local function miao_loss_callback(context, target_name)
    -- only care if target was the one inflicting the loss
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

    local target_table = CFSettings.diplomacy[target_name];
    local target = get_char(target_table);
    if target == nil then
        return
    end
    local target_fmcqi = target:family_member():command_queue_index();

    -- for some reason the above function doesn't work
    local target_invovled = false;
    if miao_attacker then
        target_invovled = cm:pending_battle_cache_get_defender_fm_cqi(1) == target_fmcqi;
    elseif miao_defender then
        target_invovled = cm:pending_battle_cache_get_attacker_fm_cqi(1) == target_fmcqi;
    end
    li_miao:log(target_name .. " involved? " .. tostring(target_invovled));

    if not target_invovled then
        return
    end

    -- don't have to gate behind progression events since this only occurs after battle, so you won't get a spam of events hopefully
    if miao_lost then
        handle_miao_loss(target_name);
    else
        handle_miao_win(target_name);
    end
end

function Test_miao_loss(target_name)
    handle_miao_loss(target_name)
end

function Test_miao_win(target_name)
    handle_miao_win(target_name)
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
                    CFSettings.enable_diplomacy_for_cultures, "NAP with ") then
                to_add = to_add + CFSettings.miao_progress_nap;
            end
            if check_if_faction_list_contains_cultures(miao:faction():factions_trading_with(),
                    CFSettings.enable_diplomacy_for_cultures, "trading with ") then
                to_add = to_add + CFSettings.miao_progress_trade;
            end
            if check_if_faction_list_contains_cultures(miao:faction():factions_allied_with(),
                    CFSettings.enable_diplomacy_for_cultures, "allied with ") then
                to_add = to_add + CFSettings.miao_progress_ally;
            end

            local l = miao:faction():factions_met();
            for i = 0, l:num_items() - 1 do
                local faction = l:item_at(i);
                if CFSettings.enable_diplomacy_for_cultures[faction:culture()] and
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
    li_miao:log("Enabling all diplomacy between Miao and Slaanesh factions");
    local miao = li_miao:get_char();
    if miao ~= nil then
        for culture, _ in pairs(CFSettings.enable_diplomacy_for_cultures) do
            cm:force_diplomacy("faction:" .. miao:faction():name(), "culture:" .. culture, "all", true, true);
            li_miao:log("Enabling all diplomacy between Miao and culture " .. culture);
        end

        add_progression_trigger_with_diplomacy();
    end
end

local function persistent_diplomacy_bonus()
    li_miao:log("Adding diplomatic bonuses to Slaanesh forces to reflect their change in strategy in dealing with you");
    core:add_listener(
        "FactionTurnStartMiaoCorruptingForceChangeAttitude",
        "FactionTurnStart",
        true,
        function(context)
            local miao = li_miao:get_char();
            if miao == nil or context:faction():name() ~= miao:faction():name() then
                return
            end
            for i = 1, #CFSettings.corruption_factions do
                local faction_name = CFSettings.corruption_factions[i];
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
    for target_name, _ in pairs(CFSettings.diplomacy) do
        local target_table = CFSettings.diplomacy[target_name];
        local target = get_char(target_table);
        if target ~= nil and target:faction():is_human() then
            li_miao:log("As player " .. target_name .. ", listening to respond to Miao progression events");
            -- listen for main progression events
            li_miao:add_listener(
                progression_response_listener_name,
                true,
                function(context)
                    progression_response_callback(context, target_name);
                end,
                true
            );
        end

        local miao = li_miao:get_char();
        if miao ~= nil then
            -- loss callback always fires; only get dilemma for flavour text if human though (checked separately for each faction)
            -- can only leave a lasting mark on her when she's sufficiently corrupted
            li_miao:add_listener(
                "MiaoBattleCompletedLossFactory" .. target_name,
                function(context)
                    return (context:type() == "enter" or context:type() == "init") and context:stage() >= 2;
                end,
                function(context)
                    li_miao:log("Miao Ying sufficiently corrupted to start consecutive loss sequence to " .. target_name);
                    core:add_listener(
                        "BattleCompletedMiaoYingLoss" .. target_name,
                        "BattleCompleted",
                        true,
                        function(context)
                            miao_loss_callback(context, target_name);
                        end,
                        true);
                end,
                false -- not persistent! This is important to avoid adding duplicate listeners inside
            );
        end

        -- check if she's already a vassal or confederated to add new progression triggers
        if miao ~= nil and target ~= nil then
            if miao:faction():is_vassal_of(target:faction()) or (miao:faction():name() == target:faction():name()) then
                add_progression_trigger_as_subject(target_name);
            end
        end
    end

    local miao = li_miao:get_char();
    if miao ~= nil then
        li_miao:add_listener(
            "MiaoDiplomacyExpansion",
            function(context)
                return (context:type() == "enter" or context:type() == "init") and context:stage() >= 1;
            end,
            function(context)
                enable_diplomacy();
                persistent_diplomacy_bonus();
            end,
            false -- not persistent! This is important to avoid adding duplicate listeners inside
        );
    end
end

cm:add_first_tick_callback(function() broadcast_self() end);
