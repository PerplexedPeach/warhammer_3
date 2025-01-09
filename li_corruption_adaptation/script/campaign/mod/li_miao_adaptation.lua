local province_bundle_name = "li_miao_slaanesh_adaptation";
local ambient_bundle_name = "li_miao_slaanesh_ambient";
local upkeep_bundle_name = "li_miao_slaanesh_upkeep";
local ignore_adaptation = "do_ignore_corruption_adaptation";

-- [adaption_level][corruption_level]
local growth_effects = {
    [1] = { 0, 1, 3, 5, 7, 10, 30, 40, 60, 75, 100 },
    [2] = { 0, 4, 10, 12, 10, 15, 50, 70, 100, 130, 200 },
    [3] = { -10, 0, 7, 14, 28, 50, 95, 120, 150, 170, 250 },
    [4] = { -20, -8, 5, 12, 25, 50, 100, 140, 185, 230, 320 },
    [5] = { -40, -20, 0, 10, 25, 50, 100, 140, 200, 260, 370 },
    [6] = { -80, -40, -20, 0, 20, 60, 120, 180, 250, 340, 470 }
};
local public_order_effects = {
    [1] = { 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
    [2] = { 0, 1, 2, 3, 6, 7, 8, 9, 10, 11, 12 },
    [3] = { -1, 0, 2, 4, 9, 11, 14, 15, 16, 16, 17 },
    [4] = { -2, 0, 2, 4, 9, 11, 13, 16, 18, 20, 21 },
    [5] = { -4, -2, 0, 4, 8, 11, 13, 16, 19, 21, 24 },
    [6] = { -8, -4, -2, 0, 8, 11, 14, 17, 20, 23, 26 }
};
local gdp_effects = {
    [1] = { 0, 0, 0, 2, 4, 6, 8, 10, 12, 15, 18 },
    [2] = { 0, 0, 1, 6, 8, 11, 15, 18, 20, 25, 30 },
    [3] = { -3, 0, -1, 5, 11, 17, 23, 26, 30, 35, 40 },
    [4] = { -5, -4, -2, 6, 11, 17, 22, 28, 34, 43, 52 },
    [5] = { -10, -5, 0, 5, 12, 18, 24, 30, 37, 48, 60 },
    [6] = { -20, -10, -5, 0, 10, 18, 25, 32, 40, 55, 70 }
};

-- [adaption_level]
local ambient_corruption_effects = { 0, 0, 1, 1, 2, 2, 3 };

-- don't add any adaptation levels, need this to prevent breaking saves
function li_miao:do_ignore_adaptation()
    cm:set_saved_value("do_ignore_corruption_adaptation", true);
    return cm:get_saved_value("do_ignore_corruption_adaptation");
end

local function adapt_province(province, adaption_level)
    -- adaption level 0 == stage 0 means no benefits from corruption
    local region = province:capital_region();
    local sla_corr = cm:get_corruption_value_in_region(region, "wh3_main_corruption_slaanesh");

    -- subtract a small amount to handle when it's equal to 100
    local corruption_level = math.floor((sla_corr - 0.01) / 10) + 2;
    -- special level 0 if 0 corruption (1-10 is level 1)
    if sla_corr == 0 then
        corruption_level = 1;
    end

    -- remove to recalculate and reapply effects
    if (region:has_effect_bundle(province_bundle_name)) then
        cm:remove_effect_bundle_from_region(province_bundle_name, region:name());
    end

    if adaption_level < 1 then
        return sla_corr;
    end

    if cm:get_saved_value(ignore_adaptation) then
        return sla_corr;
    end

    local bundle = cm:create_new_custom_effect_bundle(province_bundle_name);
    bundle:add_effect("wh3_main_effect_province_growth_slaanesh_corruption", "region_to_province_own",
        growth_effects[adaption_level][corruption_level]);
    bundle:add_effect("wh3_main_effect_public_order_corruption_slaanesh", "region_to_province_own",
        public_order_effects[adaption_level][corruption_level]);
    bundle:add_effect("wh_main_effect_economy_gdp_mod_all", "province_to_region_own_unseen",
        gdp_effects[adaption_level][corruption_level]);
    bundle:set_duration(0);
    cm:apply_custom_effect_bundle_to_region(bundle, region);
    return sla_corr;
end

local function adapt_all_provinces(adaption_level)
    -- adjust every owned province
    local faction = li_miao:get_char():faction();
    local province_list = faction:provinces();
    local should_ignore = cm:get_saved_value(ignore_adaptation);
    if should_ignore then
        li_miao:log("Ignoring corruption adaptation");
    else
        li_miao:log("Corruption adapation at level " ..
            tostring(adaption_level) .. " for " .. tostring(province_list:num_items()) .. " provinces");
    end
    local total_cor = 0;
    for i = 0, province_list:num_items() - 1 do
        total_cor = total_cor + adapt_province(province_list:item_at(i):province(), adaption_level);
    end
    local avg_cor = total_cor / province_list:num_items();

    -- adjust based on average provincial corruption
    if (faction:has_effect_bundle(upkeep_bundle_name)) then
        cm:remove_effect_bundle(upkeep_bundle_name, faction:name());
    end


    if not should_ignore and avg_cor > 0 then
        local bundle = cm:create_new_custom_effect_bundle(upkeep_bundle_name);
        bundle:add_effect("wh3_main_effect_upkeep_sla_all", "faction_to_force_own", -math.floor(avg_cor / 2));
        bundle:add_effect("wh3_main_effect_upkeep_cth_peasant", "faction_to_force_own", math.floor(avg_cor));
        bundle:set_duration(0);
        cm:apply_custom_effect_bundle_to_faction(bundle, faction);
    end

    -- adjust global ambient corruption
    if (faction:has_effect_bundle(ambient_bundle_name)) then
        cm:remove_effect_bundle(ambient_bundle_name, faction:name());
    end

    local to_add = ambient_corruption_effects[adaption_level + 1];
    if not should_ignore and to_add > 0 then
        local bundle = cm:create_new_custom_effect_bundle(ambient_bundle_name);
        bundle:add_effect("wh3_main_effect_corruption_slaanesh_events", "faction_to_faction_own", to_add);
        bundle:set_duration(0);
        cm:apply_custom_effect_bundle_to_faction(bundle, faction);
    end
end

local function broadcast_self()

    -- only register main progression response dilemmas when player is slaanesh
    local miao = li_miao:get_char();
    if miao ~= nil then
        core:add_listener(
            "FactionTurnStartMiaoAdaptation",
            "FactionTurnStart",
            true,
            function(context)
                local miao = li_miao:get_char();
                if miao == nil or context:faction():name() ~= miao:faction():name() then
                    return
                end
                adapt_all_provinces(math.min(6, li_miao:get_stage()));
            end,
            true);
    end
end

cm:add_first_tick_callback(function() broadcast_self() end);
