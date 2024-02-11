local trait_name = "li_trait_corrupt_amulet";
local dilemma_name = "li_offer_corrupt_amulet";
local li_ai_corruption_chance = 30;
local this_stage = 1;

local function stage_enter_callback()
    li_kat:change_title(this_stage);
end

-- from stage 0 to stage 1, progression is offered after using heart of winter twice in a battle
-- hooks where each stage gets callback
-- hook into losing combat against Slaanesh force (later events can check against )
local heart_of_winter_ability_name = "wh3_main_spell_ice_heart_of_winter";
local overexertion_used_times = 2;
-- TODO consider making trigger chance scale with Katarin's level (character:rank()?)
local ai_trigger_chance = 30;
local function initial_amulet_offer_after_battle_listener(context)
    -- only listen for stage 0
    if li_kat:get_stage() > 0 then
        return
    end

    local pb = cm:model():pending_battle();
    local is_attacker, is_defender = li_kat:attacker_or_defender();
    if not is_attacker and not is_defender then
        return
    end
    li_kat:log("Kat in battle " .. tostring(is_attacker) .. " defender " .. tostring(is_defender));

    -- don't think ability used in battle works for AI; instead use a percentage based system for them
    local character = li_kat:get_char();
    local faction = character:faction();
    local faction_cqi = faction:command_queue_index();
    if faction:is_human() then
        local times_base = pb:get_how_many_times_ability_has_been_used_in_battle(faction_cqi, heart_of_winter_ability_name);
        local times_overcast = pb:get_how_many_times_ability_has_been_used_in_battle(faction_cqi, heart_of_winter_ability_name .. "_upgraded");
        local times_how = times_base + times_overcast;
        li_kat:log("Times used heart of winter " .. tostring(times_how) .. " vs overexertion at " .. overexertion_used_times);

        if times_how >= overexertion_used_times then
            li_kat:trigger_progression(context, true);
        end
    else
        local rand = cm:random_number(100, 1);
        li_kat:log("AI rolled " .. tostring(rand) .. " against chance of being offered amulet " .. ai_trigger_chance)
        if rand <= ai_trigger_chance then
            li_kat:trigger_progression(context, false);
        end
    end
end

local function progression_callback(context, is_human)
    -- dilemma for choosing to accept or reject the gift
    if is_human then
        li_kat:log("Human progression, trigger dilemma " .. dilemma_name);
        cm:trigger_dilemma(li_kat:get_char():faction():name(), dilemma_name);
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
                li_kat:log(dilemma_name .. " choice " .. tostring(choice));
                if choice == 0 then
                    li_kat:advance_stage(trait_name, this_stage);
                else
                    li_kat:fire_corrupt_event("reject", this_stage);
                end
                core:remove_listener(delimma_choice_listener_name);
            end,
            true
        );
    else
        -- if it's not the human
        local rand = cm:random_number(100, 1);
        li_kat:log("AI rolled " .. tostring(rand) .. " against chance to corrupt " .. li_ai_corruption_chance)
        if rand <= li_ai_corruption_chance then
            li_kat:advance_stage(trait_name, this_stage);
        else
            li_kat:fire_corrupt_event("reject", this_stage);
        end
    end
end

local function broadcast_self()
    -- command script will define API to register stage
    local name = "first";  -- use as the key for everything
    li_kat:stage_register(name, this_stage, progression_callback, stage_enter_callback);

    core:add_listener(
        "BattleCompleted_offer_amulet",
        "BattleCompleted",
        true,
        initial_amulet_offer_after_battle_listener,
        true
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);
