local daemonize_spawn = {
    ["li_daemonization_tze_1"] = "wh3_main_tze_inf_forsaken_0",
    ["li_daemonization_tze_2"] = "wh3_main_tze_mon_spawn_of_tzeentch_0",
    ["li_daemonization_sla_1"] = "wh3_main_sla_inf_chaos_furies_0",
    ["li_daemonization_sla_2"] = "wh3_main_sla_inf_daemonette_0"
};

local daemonize_score = "li_katarin_daemonize_score";
local second_tier_daemonize_dilemma = "li_katarin_daemonize_tier_second";
local d_faction_bundle_name = "li_effect_bundle_daemonize";
local d_character_bundle_name = "li_effect_bundle_daemonize_character";

-- city to dilemma title mapping
local city_to_dilemma = {
    ["wh3_main_chaos_region_praag"] = "li_katarin_stage_4_praag",
    ["wh3_main_combi_region_praag"] = "li_katarin_stage_4_praag",
    ["cr_oldworld_region_praag"] = "li_katarin_stage_4_praag",
    ["wh3_main_chaos_region_kislev"] = "li_katarin_stage_4_kislev",
    ["wh3_main_combi_region_kislev"] = "li_katarin_stage_4_kislev",
    ["cr_oldworld_region_kislev"] = "li_katarin_stage_4_kislev",
    ["wh3_main_combi_region_erengrad"] = "li_katarin_stage_4_erengrad",
    ["wh3_main_chaos_region_erengrad"] = "li_katarin_stage_4_erengrad",
    ["cr_oldworld_region_erengrad"] = "li_katarin_stage_4_erengrad",

};
local events_seen_name = "li_katarin_daemonize_events_seen";

local function create_daemonize_effect_bundle()

    local kat = li_kat:get_char();
    if kat == nil then
        return;
    end
    local faction = kat:faction();

    if (kat:has_effect_bundle(d_character_bundle_name)) then
        cm:remove_effect_bundle_from_character(d_character_bundle_name, kat);
    end
    if (faction:has_effect_bundle(d_faction_bundle_name)) then
        cm:remove_effect_bundle(d_faction_bundle_name, faction:name());
    end

    local score = cm:get_saved_value(daemonize_score) or 0;

    if score > 0 then
        local bundle = cm:create_new_custom_effect_bundle(d_faction_bundle_name);
        local bundlec = cm:create_new_custom_effect_bundle(d_character_bundle_name);
        bundle:add_effect("wh_main_effect_public_order_events", "faction_to_province_own", -1 * score);
        bundle:add_effect("wh3_main_effect_corruption_tzeentch_events_bad", "faction_to_province_own", score);
        bundle:add_effect("wh3_main_effect_corruption_slaanesh_events_bad", "faction_to_province_own", score);
        bundle:add_effect("wh_main_effect_province_growth_events", "faction_to_province_own", -score * 4);
        bundlec:add_effect("wh_main_effect_province_growth_events", "character_to_province_own", -score * 25);
        bundle:add_effect("wh_main_effect_force_all_campaign_recruitment_cost_all", "faction_to_force_own", score * 10);
        bundle:add_effect("wh3_main_effect_upkeep_sla_all", "faction_to_force_own", -score * 5);
        bundle:add_effect("wh3_main_effect_upkeep_tze_all", "faction_to_force_own", -score * 5);
        bundle:add_effect("wh2_dlc15_faction_diplomacy_bonus_all_order_factions", "faction_to_faction_own", -score * 10);
        bundle:add_effect("wh3_main_faction_political_diplomacy_mod_slaanesh", "faction_to_faction_own", score * 3);
        bundle:add_effect("wh3_main_faction_political_diplomacy_mod_tzeentch", "faction_to_faction_own", score * 3);
        bundle:set_duration(0);
        bundlec:set_duration(0);

        if score > CFSettings.kat_daemonize_second_tier_threshold then
            if not cm:get_saved_value(second_tier_daemonize_dilemma) then
                if faction:is_human() then
                    cm:trigger_dilemma(faction:name(), second_tier_daemonize_dilemma);
                end
                cm:set_saved_value(second_tier_daemonize_dilemma, true);
            end
            -- add ability to effect bundle
            bundlec:add_effect("li_effect_enable_daemonization_tze_2", "character_to_character_own", 1);
            bundlec:add_effect("li_effect_enable_daemonization_sla_2", "character_to_character_own", 1);
        end

        li_kat:log("Create Kat Daemonization effect with score " .. tostring(score));
        cm:apply_custom_effect_bundle_to_character(bundlec, kat);
        cm:apply_custom_effect_bundle_to_faction(bundle, faction);
    end
end

local function visit_major_kislev_city(context)
    if li_kat:get_stage() ~= 4 then
        return
    end

    local kat = li_kat:get_char();
    if kat == nil or context:faction():name() ~= kat:faction():name() then
        return;
    end

    -- daemonization score ticks down by 1 every turn
    local score = cm:get_saved_value(daemonize_score) or 0;
    if score > 0 then
        score = score - CFSettings.kat_daemonize_decay_per_turn;
        cm:set_saved_value(daemonize_score, score);
        create_daemonize_effect_bundle();
    end

    local events_seen = cm:get_saved_value(events_seen_name) or 0;

    -- check what region we're in and if we can trigger the event
    local region_name = kat:region():name();
    local event_name = city_to_dilemma[region_name];
    -- is there an event registered
    li_kat:log("Starting a turn in settlement of region " ..
        region_name .. " associated with event " .. tostring(event_name));
    if event_name == nil or cm:get_saved_value(event_name) then
        return;
    end

    -- fire event and save progression
    li_kat:log("First time visiting major Kislev city to trigger event " ..
        event_name .. " " .. events_seen + 1 .. " events");
    if kat:faction():is_human() then
        cm:trigger_dilemma(kat:faction():name(), event_name);
    end
    cm:set_saved_value(event_name, true);
    cm:set_saved_value(events_seen_name, events_seen + 1);
end

local function track_daemonization_after_battle(context)
    local kat = li_kat:get_char();
    if kat == nil then
        return;
    end

    local is_attacker, is_defender = li_kat:attacker_or_defender();
    if not is_attacker and not is_defender then
        return
    end
    local pb = cm:model():pending_battle();
    li_kat:log("Kat in battle " .. tostring(is_attacker) .. " defender " .. tostring(is_defender));

    -- don't think ability used in battle works for AI; instead use a percentage based system for them
    local faction = kat:faction();
    local faction_cqi = faction:command_queue_index();

    -- tick down by 1 every turn while increased by number of times used in battle
    local score = cm:get_saved_value(daemonize_score) or 0;
    local times_daemonized = 0;
    -- no effect on AI, too hard to make them use this ability
    if faction:is_human() then
        local char_str = cm:char_lookup_str(kat);
        for ability, spawned_unit in pairs(daemonize_spawn) do
            local times_used = pb:get_how_many_times_ability_has_been_used_in_battle(faction_cqi, ability);
            times_daemonized = times_daemonized + times_used;
            -- generate the unit
            for i = 1, times_used do
                cm:grant_unit_to_character(char_str, spawned_unit);
            end
        end
    end
    li_kat:log("Units daemonized " ..  tostring(times_daemonized));

    score = score + times_daemonized;
    cm:set_saved_value(daemonize_score, score);
    create_daemonize_effect_bundle();
end


local function broadcast_self()
    -- command script will define API to register stage

    -- event up as we visit Kislev cities
    core:add_listener(
        "FactionTurnStartKatarinStage4Events",
        "FactionTurnStart",
        true,
        visit_major_kislev_city,
        true
    );


    -- track how many times she daemonized her own units in battle
    core:add_listener(
        "BattleCompletedDaemonizationUsage",
        "BattleCompleted",
        true,
        track_daemonization_after_battle,
        true
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);