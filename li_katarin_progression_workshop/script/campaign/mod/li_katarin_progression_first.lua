local this_stage = 1;
-- simple dilemma based progression
CFSettings.kat[this_stage] = {
    dilemma_name = "li_offer_corrupt_amulet", 
    trait_name = "li_trait_corrupt_amulet",
    this_stage = this_stage, 
    ai_corruption_chance = 30
};


-- from stage 0 to stage 1, progression is offered after using heart of winter twice in a battle
-- hooks where each stage gets callback
-- hook into losing combat against Slaanesh force (later events can check against )
local heart_of_winter_ability_name = "wh3_main_spell_ice_heart_of_winter";
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
    li_kat:log("Checking if we should offer amulet");

    -- don't think ability used in battle works for AI; instead use a percentage based system for them
    local character = li_kat:get_char();
    if character == nil then
        return;
    end

    local faction = character:faction();
    local faction_cqi = faction:command_queue_index();
    if faction:is_human() then
        local times_base = pb:get_how_many_times_ability_has_been_used_in_battle(faction_cqi,
            heart_of_winter_ability_name);
        local times_overcast = pb:get_how_many_times_ability_has_been_used_in_battle(faction_cqi,
            heart_of_winter_ability_name .. "_upgraded");
        local times_how = times_base + times_overcast;
        li_kat:log("Times used heart of winter " .. tostring(times_how));
        li_kat:modify_progress_percent(CFSettings.kat_heart_of_winter_corruption * times_how, "heart of winter in battle");
    else
        local rand = cm:random_number(100, 1);
        li_kat:log("AI rolled " .. tostring(rand) .. " against chance of being offered amulet " .. ai_trigger_chance)
        if rand <= ai_trigger_chance then
            li_kat:trigger_progression(context, false);
        end
    end
end



local function broadcast_self()
    -- command script will define API to register stage
    local name = "first"; -- use as the key for everything
    li_kat:stage_register(name, this_stage,
        function(context, is_human)
            li_kat:simple_progression_callback(context, is_human, CFSettings.kat[this_stage])
        end);

    li_kat:add_listener(
        "KatEnterNameChange",
        function(context)
            return context:type() == "enter";
        end,
        function(context)
            li_kat:change_title(context:stage());
        end,
        true
    );

    core:add_listener(
        "BattleCompleted_offer_amulet",
        "BattleCompleted",
        true,
        initial_amulet_offer_after_battle_listener,
        true
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);
