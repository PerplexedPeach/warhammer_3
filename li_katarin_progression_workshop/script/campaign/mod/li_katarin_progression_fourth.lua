local this_stage = 4;
CFSettings.kat[this_stage] = {
    dilemma_name = "li_mark_tzesla_seal", 
    trait_name = "li_trait_corrupt_collar",
    this_stage = this_stage, 
    ai_corruption_chance = 80
};

-- city to dilemma title mapping
local city_to_dilemma = {
    ["wh3_main_chaos_region_praag"] = "li_katarin_stage_3_praag",
    ["wh3_main_combi_region_praag"] = "li_katarin_stage_3_praag",
    ["cr_oldworld_region_praag"] = "li_katarin_stage_3_praag",
    ["wh3_main_chaos_region_kislev"] = "li_katarin_stage_3_kislev",
    ["wh3_main_combi_region_kislev"] = "li_katarin_stage_3_kislev",
    ["cr_oldworld_region_kislev"] = "li_katarin_stage_3_kislev",
    ["wh3_main_combi_region_erengrad"] = "li_katarin_stage_3_erengrad",
    ["wh3_main_chaos_region_erengrad"] = "li_katarin_stage_3_erengrad",
    ["cr_oldworld_region_erengrad"] = "li_katarin_stage_3_erengrad",
};
local events_seen_name = "li_katarin_fourth_events_seen";

local function visit_major_kislev_city(context)
    if li_kat:get_stage() ~= 3 then
        return
    end

    local kat = li_kat:get_char();
    if kat == nil or context:faction():name() ~= kat:faction():name() then
        return;
    end

    local events_seen = cm:get_saved_value(events_seen_name) or 0;
    -- for stage 2, we stage up upon losing to a Slaanesh force once we have all events
    -- fire dilemma informing the player that they are ready for the next step
    if events_seen == CFSettings.kat_events_to_progress_fourth then
        li_kat:modify_progress_percent(100, "Finished events in Kislev cities");
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
    li_kat:log("Starting a turn in settlement of region " ..
    region_name .. " associated with event " .. tostring(event_name));
    if event_name == nil or cm:get_saved_value(event_name) then
        return;
    end

    -- fire event and save progression
    li_kat:log("First time visiting major Kislev city to trigger event " .. event_name .. " " .. events_seen + 1 ..
        " events needed out of " .. CFSettings.kat_events_to_progress_fourth);
    li_kat:modify_progress_percent(100 / CFSettings.kat_events_to_progress_fourth,
        "Finished single event in Kislev city");
    if kat:faction():is_human() then
        cm:trigger_dilemma(kat:faction():name(), event_name);
    end
    cm:set_saved_value(event_name, true);
    cm:set_saved_value(events_seen_name, events_seen + 1);
end

local function broadcast_self()
    -- command script will define API to register stage
    local name = "fourth"; -- use as the key for everything
    li_kat:stage_register(name, this_stage,
        function(context, is_human)
            li_kat:simple_progression_callback(context, is_human, CFSettings.kat[this_stage])
        end);
    -- event up as we visit Kislev cities
    core:add_listener(
        "FactionTurnStartKatarinStage3Events",
        "FactionTurnStart",
        true,
        visit_major_kislev_city,
        true
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);
