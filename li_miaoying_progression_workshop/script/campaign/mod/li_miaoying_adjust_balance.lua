-- add effects to hidden effect bundle to adjust balance
local effect_bundle_name = "li_miao_balance_adjustment";
local speed_effect = "wh_main_effect_character_stat_speed"; -- percent
local charge_bonus_effect = "wh_main_effect_character_stat_charge_bonus_pct"; -- percent
local ward_save_effect = "wh_main_effect_character_stat_ward_save"; -- flat

local function apply_effect_bundle()
    local miao = li_miao:get_char();
    if miao == nil then
        return
    end
    cm:remove_effect_bundle_from_character(effect_bundle_name, miao);

    li_miao:log("Adjusting speed by " ..
        tostring(CFSettings.miao_speed_adjustment) .. " charge bonus by " ..
        tostring(CFSettings.miao_charge_bonus_adjustment) .. " ward save by " ..
        tostring(CFSettings.miao_ward_save_adjustment));

    local bundle = cm:create_new_custom_effect_bundle(effect_bundle_name);
    -- adjust speed, charge bonus, and ward save
    bundle:add_effect(speed_effect, "character_to_character_own", CFSettings.miao_speed_adjustment);
    bundle:add_effect(charge_bonus_effect, "character_to_character_own", CFSettings.miao_charge_bonus_adjustment);
    bundle:add_effect(ward_save_effect, "character_to_character_own", CFSettings.miao_ward_save_adjustment);
    bundle:set_duration(0);
    cm:apply_custom_effect_bundle_to_character(bundle, miao);
end

-- apply this on new turn and when settings change
core:add_listener(
    "MiaoAdjustmentApplication",
    "MctOptionSettingFinalized",
    true,
    function(context)
        cm:callback(apply_effect_bundle, 1.0, "li_miao_adjustment_application");
    end,
    true
);

core:add_listener(
    "MiaoAdjustmentApplicationTurnStart",
    "FactionTurnStart",
    true,
    function(context)
        local miao = li_miao:get_char();
        if miao == nil or context:faction():name() ~= miao:faction():name() then
            return
        end
        apply_effect_bundle();
    end,
    true
);
