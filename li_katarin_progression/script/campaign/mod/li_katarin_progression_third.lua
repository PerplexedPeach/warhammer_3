local trait_name = "li_trait_corrupt_collar";
local dilemma_name = "li_place_posture_collar";
local notification_dilemma_name = "li_notify_ready_for_collar";
local li_ai_corruption_chance = 60;
local this_stage = 3;

local mission_key = "li_katarin_battle";


local function stage_enter_callback()
    li_kat:change_title(this_stage);
end

-- city to dilemma title mapping
local city_to_dilemma = {
    ["wh3_main_chaos_region_praag"] = "li_katarin_stage_2_praag",
    ["wh3_main_combi_region_praag"] = "li_katarin_stage_2_praag",
    ["cr_oldworld_region_praag"] = "li_katarin_stage_2_praag",
    ["wh3_main_chaos_region_kislev"] = "li_katarin_stage_2_kislev",
    ["wh3_main_combi_region_kislev"] = "li_katarin_stage_2_kislev",
    ["cr_oldworld_region_kislev"] = "li_katarin_stage_2_kislev",
    ["wh3_main_combi_region_erengrad"] = "li_katarin_stage_2_erengrad",
    ["wh3_main_chaos_region_erengrad"] = "li_katarin_stage_2_erengrad",
    ["cr_oldworld_region_erengrad"] = "li_katarin_stage_2_erengrad",
};
local events_to_progress = 3;
local events_seen_name = "li_katarin_third_events_seen";

-- from stage 1 to stage 2, progression is offered after triggering events from starting a turn in a unique Kislev city
local function visit_major_kislev_city(context)
    if li_kat:get_stage() ~= 2 then
        return
    end

    local kat = li_kat:get_char();
    if kat == nil or context:faction():name() ~= kat:faction():name() then
        return;
    end

    local events_seen = cm:get_saved_value(events_seen_name) or 0;
    -- for stage 2, we stage up upon losing to a Slaanesh force once we have all events
    -- fire dilemma informing the player that they are ready for the next step
    if events_seen == events_to_progress then
        if kat:faction():is_human() then
            cm:trigger_dilemma(kat:faction():name(), notification_dilemma_name);

            li_miao:log("triggering battle mission");
            cm:trigger_mission(kat:faction():name(), mission_key, true);
        end
        -- increment by 1 so we don't have this notification fire again
        cm:set_saved_value(events_seen_name, events_seen + 1);
        return;
    end

    -- check what region we're in and if we can trigger the event
    local region = kat:region();
    if not region or region:is_null_interface() then
        li_kat:log("Katarin not in a valid region");
        return;
    end
    local region_name = region:name();
    local event_name = city_to_dilemma[region_name];
    -- is there an event registered
    li_kat:log("Starting a turn in settlement of region " .. region_name .. " associated with event " .. tostring(event_name));
    if event_name == nil or cm:get_saved_value(event_name) then
        return;
    end

    -- fire event and save progression
    li_kat:log("First time visiting major Kislev city to trigger event " .. event_name .. " " .. events_seen + 1 ..
        " events needed out of " .. events_to_progress);
    if kat:faction():is_human() then
        cm:trigger_dilemma(kat:faction():name(), event_name);
    end
    cm:set_saved_value(event_name, true);
    cm:set_saved_value(events_seen_name, events_seen + 1);
end

local function kat_loss_callback(context)
    if li_kat:get_stage() ~= 2 then
        return
    end

    -- only care if we've seen sufficient events
    local events_seen = cm:get_saved_value(events_seen_name) or 0;
    if events_seen < events_to_progress then
        return;
    end
    
    local pb = cm:model():pending_battle();
    local is_attacker, is_defender = li_kat:attacker_or_defender()
    local player_lost = false;
    local opponent_slaanesh = false;
    if is_attacker then
        player_lost = pb:defender_won();
        opponent_slaanesh = li_kat:opponent_slaanesh(pb:defender():faction());
    elseif is_defender then
        player_lost = pb:attacker_won();
        opponent_slaanesh = li_kat:opponent_slaanesh(pb:attacker():faction());
    else
        -- only care if our character is in it is in it
        return
    end
    li_kat:log("Katarin involved lost in battle? " .. tostring(player_lost) .. " against slaanesh " .. tostring(opponent_slaanesh));

    if player_lost and opponent_slaanesh then
        li_kat:trigger_progression(context, li_kat:get_char():faction():is_human());
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
    local name = "third";  -- use as the key for everything
    li_kat:stage_register(name, this_stage, progression_callback, stage_enter_callback);

    -- event up as we visit Kislev cities
    core:add_listener(
        "FactionTurnStartKatarinStage2Events",
        "FactionTurnStart",
        true,
        visit_major_kislev_city,
        true
    );

    
    if li_kat:get_stage() < 3 then
        -- finishing event after visiting cities
        core:add_listener("BattleCompletedKatStage2Transition", "BattleCompleted", true, kat_loss_callback, true);
    end
end

cm:add_first_tick_callback(function() broadcast_self() end);
