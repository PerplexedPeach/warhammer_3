local trait_name = "li_trait_corrupt_body";
local dilemma_name = "li_corrupt_body_plug";
local this_stage = 6;

local get_bred_ability_name = "li_miaoying_get_bred";
local provide_service_ability_name = "li_offer_any_service";
local pregnancy_name = "li_miaoying_pregnant";
local pregnancy_turn = "li_miaoying_pregnant_start_turn";
local dilemma_name_prefix = "li_miaoying_bred_";
local birthing_script_event_name = "ScriptEventMiaoYingBirthing";
local broodmother_trait_name = "li_trait_broodmother";
-- unit record and mercenary recruitment pool group
local birth_unit_for_each_tier = {
    [1] = { "wh3_main_sla_inf_daemonette_0", "wh3_main_sla_inf_daemonette_0_warriors_faction_pool" },
    [2] = { "wh3_main_sla_inf_daemonette_1", "wh3_main_sla_inf_daemonette_1_belakor_faction_pool" },
    [3] = { "wh3_main_sla_mon_fiends_of_slaanesh_0", "wh3_main_sla_mon_fiends_of_slaanesh_0_warriors_faction_pool" }
};
-- local broodmother_title_for_each_tier = { [1] = "the Mother of Daemons", [2] = "the Daemon Seedbed", [3] = "the Defiled Broodmother" };

local miao_chain_name = "li_armour_slaanesh_leash";

local function birth_tier_for_num_times(bred_times)
    if bred_times < 3 then
        return 1;
    elseif bred_times < 5 then
        return 2;
    else
        return 3;
    end
end

local function progression_callback(context, is_human)
    -- there's no choice here, so always get the chain
    Attach_miao_chains();
    -- dilemma for choosing to accept or reject the gift
    if is_human then
        li_miao:log("Human progression, trigger dilemma " .. dilemma_name);
        cm:trigger_dilemma(li_miao:get_char():faction():name(), dilemma_name);
        local delimma_choice_listener_name = dilemma_name .. "_DilemmaChoiceMadeEvent";
        -- using persist = true even for a delimma event in case they click on another delimma first
        core:add_listener(
            delimma_choice_listener_name,
            "DilemmaChoiceMadeEvent",
            function(context)
                return context:dilemma() == dilemma_name;
            end,
            function(context)
                -- your choice doesn't matter at this stage
                local choice = context:choice();
                li_miao:log(dilemma_name .. " choice " .. tostring(choice));
                li_miao:advance_stage(trait_name, this_stage);
                core:remove_listener(delimma_choice_listener_name);
            end,
            true
        );
    else
        li_miao:advance_stage(trait_name, this_stage);
    end
end

local function get_bred(opponent_faction_name)
    local character = li_miao:get_char();
    if character == nil then
        return
    end
    local bred_times = character:trait_points(broodmother_trait_name) + 1;
    local bred_tier = birth_tier_for_num_times(bred_times);
    cm:set_saved_value(pregnancy_name, true);
    cm:set_saved_value(pregnancy_turn, cm:turn_number());
    -- trigger impregnantion dilemma
    if character:faction():is_human() then
        cm:trigger_dilemma(character:faction():name(), dilemma_name_prefix .. tostring(bred_tier) .. "_start");
    end
    -- switch to her pregnant model
    li_miao:log("Impregnated by " .. opponent_faction_name);
    if CFSettings.miao_visible_pregnancy then
        li_miao:switch_art_set_stage(this_stage + 1);
    end
end

local function give_birth(bred_tier, choice)
    local birthed_unit = birth_unit_for_each_tier[choice + 1];
    local birthed_num = bred_tier - choice;
    cm:set_saved_value(pregnancy_name, false);
    li_miao:log("Gave birth to " .. birthed_unit[1]);

    local character = li_miao:get_char();
    if character == nil then
        return;
    end
    -- add trait levels
    cm:force_add_trait("character_cqi:" .. character:cqi(), broodmother_trait_name, 0);
    li_miao:change_title(this_stage + bred_tier);
    -- once dilemma triggers, add demon units to faction mercenary pool and advance her trait (if not at end)
    -- consider making them replenish
    cm:add_unit_to_faction_mercenary_pool(character:faction(), birthed_unit[1], "renown", birthed_num, 20, birthed_num, 1,
        "", "", "", true, birthed_unit[2]);
    -- switch back to normal model
    if CFSettings.miao_visible_pregnancy then
        li_miao:switch_art_set_stage(this_stage);
    end
end

local function do_give_birth(character)
    local bred_times = character:trait_points(broodmother_trait_name) + 1;
    local bred_tier = birth_tier_for_num_times(bred_times);

    -- trigger delayed birthing dilemma
    local dilemma_birth_name = dilemma_name_prefix .. tostring(bred_tier) .. "_birth";
    local dilemma_listener_name = dilemma_birth_name .. "_listener";
    local dilemma_choice_listener_name = dilemma_listener_name .. "_choice";

    li_miao:log("Giving birth");
    if character:faction():is_human() then
        cm:trigger_dilemma(character:faction():name(), dilemma_birth_name);
        core:add_listener(
            dilemma_choice_listener_name,
            "DilemmaChoiceMadeEvent",
            function(context)
                return context:dilemma() == dilemma_birth_name;
            end,
            function(context)
                -- choices are in order; higher trait level gives
                local choice = context:choice();
                li_miao:log(dilemma_birth_name .. " choice " .. tostring(choice));

                give_birth(bred_tier, choice);
            end,
            false
        );
    else
        li_miao:log("AI choosing highest tier birth");
        give_birth(bred_tier, bred_tier - 1);
    end
end

local function check_birth(context)
    local character = li_miao:get_char();
    if character == nil or context:faction():name() ~= character:faction():name() then
        return
    end

    if not cm:get_saved_value(pregnancy_name) then
        return
    end

    local impregnated_turn = cm:get_saved_value(pregnancy_turn) or 0;
    if cm:turn_number() < impregnated_turn + CFSettings.miao_pregnancy_period then
        return
    end

    do_give_birth(character);
end


local function get_bred_callback(context)
    local pb = cm:model():pending_battle();
    local miao_attacker, miao_defender = li_miao:attacker_or_defender();
    if not miao_attacker and not miao_defender then
        return
    end
    local opponent_faction_name = cm:pending_battle_cache_get_defender_faction_name(1);
    if miao_defender then
        opponent_faction_name = cm:pending_battle_cache_get_attacker_faction_name(1);
    end
    li_miao:log("Miao attacker " ..
    tostring(miao_attacker) .. " defender " .. tostring(miao_defender) .. " fought " .. opponent_faction_name);
    -- TODO save the opposing faction so we can birth correct units?
    local character = li_miao:get_char();
    local faction = character:faction();
    local faction_cqi = faction:command_queue_index();
    -- check if Miao successfully got bred
    local got_bred = pb:get_how_many_times_ability_has_been_used_in_battle(faction_cqi, get_bred_ability_name);
    local times_serviced = pb:get_how_many_times_ability_has_been_used_in_battle(faction_cqi,
        provide_service_ability_name);
    li_miao:log("Times bred in battle " .. tostring(got_bred) .. " times serviced " .. tostring(times_serviced));

    -- check if already pregnant (when pregnant, can still get bred, but won't become more pregnant)
    if got_bred > 0 and not cm:get_saved_value(pregnancy_name) then
        get_bred(opponent_faction_name);
    end
end

function Test_get_bred(dad_name)
    get_bred(dad_name)
end

function li_miao:give_birth()
    local character = self:get_char();
    if character == nil then
        return
    end
    do_give_birth(character);
end

function Attach_miao_chains()
    local miao = li_miao:get_char();
    if miao == nil then
        return
    end
    cm:force_add_ancillary(miao, miao_chain_name, true, false);
end

local function broadcast_self()
    -- command script will define API to register stage
    li_miao:stage_register("plug", this_stage, progression_callback);
    li_miao:stage_register("plug_preg", this_stage + 1, nil); -- nil callback so you can't naturally advance to it

    li_miao:add_listener(
        "MiaoEnterAdvancedPreg",
        function(context)
            return context:type() == "enter" and context:stage() >= this_stage;
        end,
        function(context)
            li_miao:change_title(this_stage);
            local bred_times = li_miao:get_char():trait_points(broodmother_trait_name);
            local bred_tier = birth_tier_for_num_times(bred_times);
            if bred_times > 0 then
                li_miao:change_title(this_stage + bred_tier);
            end
            if CFSettings.miao_visible_pregnancy then
                if cm:get_saved_value(pregnancy_name) then
                    li_miao:switch_art_set_stage(this_stage + 1);
                else
                    li_miao:switch_art_set_stage(this_stage);
                end
            end
        end,
        true
    );


    li_miao:add_listener(
        "MiaoBattleCompletedBirthFactory",
        function(context)
            return (context:type() == "enter" or context:type() == "init") and context:stage() >= this_stage;
        end,
        function(context)
            li_miao:log("Creating breeding hooks");
            core:add_listener(
                "BattleCompleted_get_bred",
                "BattleCompleted",
                true,
                get_bred_callback,
                true
            );
            core:add_listener(
                "FactionTurnStartCheckBirth",
                "FactionTurnStart",
                true,
                check_birth,
                true
            );
        end,
        false -- not persistent! This is important to avoid adding duplicate listeners inside
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);
