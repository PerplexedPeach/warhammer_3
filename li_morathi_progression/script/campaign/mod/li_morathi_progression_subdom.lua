local subdom_effect_bundle = "li_morathi_subdom";

local function morathi_subdom_effect_bundle(context) 
    local mor = li_mor:get_char();
    if mor == nil or context:faction():name() ~= mor:faction():name() then
        return;
    end

    local sub = li_mor:sub_score();

    cm:remove_effect_bundle_from_character(subdom_effect_bundle, mor);

    local bundle = cm:create_new_custom_effect_bundle(subdom_effect_bundle);
    bundle:add_effect("wh_main_effect_character_stat_leadership", "character_to_character_own", -sub);
    if sub > 0 then
        bundle:add_effect("wh_main_effect_force_all_campaign_movement_range", "character_to_force_own", sub);
    elseif sub < 0 then
        bundle:add_effect("wh3_main_effect_character_experience_per_turn", "character_to_character_own", -sub * 20);
    end
    bundle:set_duration(0);
    cm:apply_custom_effect_bundle_to_character(bundle, mor);
end

local function broadcast_self()

    -- effect bundle that scales with her submod level
    core:add_listener(
        "FactionTurnStartMorathiSubDomDisplay",
        "FactionTurnStart",
        true,
        morathi_subdom_effect_bundle,
        true
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);
