-- figure out buildings per stage
local buildings_unlocked_per_stage = {
    [3] = {
        "pleasure_gardens",
    },
    [4] = {
        "temple_of_dominating_moon",
        "temple_of_the_purple_blood",
    },
    [5] = {
        "the_excessive_observatory",
        "great_embrace",
        "the_six_gates",
        "celestial_hood",
    },
    [6] = {
        "court_of_bliss_0",
        "court_of_bliss_1",
        "court_of_bliss_2",
    }
};

local function get_full_building_list()
    local combined = {};
    for stage, buildings in pairs(buildings_unlocked_per_stage) do
        for i = 1, #buildings do
            combined[#combined + 1] = buildings[i];
        end
    end
    return combined;
end

local function decide_what_builds_are_unlocked(context)
    local miao = li_miao:get_char();
    if not miao or (context and context:faction():name() ~= miao:faction():name()) then
        return;
    end

    local building_stage_name = "corrupted_landmark";
    if not cm:get_saved_value(building_stage_name) then
        li_miao:log("Locking all landmarks at stage 0");
        cm:set_saved_value(building_stage_name, true);
        local all_locked_buildings = get_full_building_list();
        cm:restrict_buildings_for_faction(miao:faction():name(), all_locked_buildings, true);
    end

    local cur_stage = li_miao:get_stage();
    for i = 1, cur_stage do
        local this_building_stage_name = building_stage_name .. tostring(i);
        local buildings = buildings_unlocked_per_stage[i];
        if buildings then
            if not cm:get_saved_value(this_building_stage_name) then
                li_miao:log("Unlocking all landmarks at stage " .. i);
                cm:set_saved_value(this_building_stage_name, true);
                cm:restrict_buildings_for_faction(miao:faction():name(), buildings, false);
            end
        end
    end
end

local function broadcast_self()
    core:add_listener(
        "FactionTurnStartCorruptedLandmarks",
        "FactionTurnStart",
        true,
        decide_what_builds_are_unlocked,
        true);
    decide_what_builds_are_unlocked();
end

cm:add_first_tick_callback(function() broadcast_self() end);
