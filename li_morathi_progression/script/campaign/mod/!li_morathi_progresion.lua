local faction = "wh2_main_def_cult_of_pleasure";
local subtype = "wh2_main_def_morathi";
local LI_MAIN_EVENT = "ScriptEventMorathiAscensionEvent"
local confed_factions = { "wh2_main_def_cult_of_pleasure", "wh2_main_def_naggarond", "wh2_main_def_hag_graef",
    "wh2_dlc11_def_the_blessed_dread", "wh2_twa03_def_rakarth", "wh2_main_def_har_ganeth" };
local art_set = "wh2_main_art_set_def_morathi";
local names_name_id = "1248512";
li_mor = LiProgression:new("morathi", faction, subtype, art_set, LI_MAIN_EVENT, confed_factions, names_name_id);

local subbiness_key = "li_morathi_subdom";
function li_mor:sub_score()
    -- integer of how submissive the character has become with positive values indicating more sub
    return cm:get_saved_value(subbiness_key) or 0;
end

function li_mor:modify_sub_score(modifier)
    cm:set_saved_value(subbiness_key, li_mor:sub_score() + modifier);
end

-- common functions for each target

---Retrieve target character of some stage
---@param target any
---@return CHARACTER_SCRIPT_INTERFACE|nil
function li_mor:get_target_character(target)
    return self:get_character_all(target.subtype, target.confed_factions);
end

---Get the sub/dom score of a target
---@param target any
---@return integer
function li_mor:get_target_sub(target)
    local mor = li_mor:get_char();
    if mor == nil then
        return 0;
    end
    local dom = mor:trait_level(target.morathi_dom);
    local sub = mor:trait_level(target.morathi_sub);
    if dom > 0 then
        return dom;
    end
    if sub > 0 then
        return -sub;
    end
    return 0;
end

---Adjust the sub/dom score of a target, affecting the corresponding traits in both Morathi and target
---@param target any
---@param modifier integer
function li_mor:adjust_target_sub(target, modifier)
    local mor = li_mor:get_char();
    local target_char = li_mor:get_target_character(target);
    if mor == nil or target_char == nil then
        return;
    end

    if modifier > 0 then
        cm:force_add_trait(cm:char_lookup_str(mor), target.morathi_dom, true, modifier);
        cm:force_add_trait(cm:char_lookup_str(target_char), target.sub, true, modifier);
    elseif modifier < 0 then
        cm:force_add_trait(cm:char_lookup_str(mor), target.morathi_sub, true, -modifier);
        cm:force_add_trait(cm:char_lookup_str(target_char), target.dom, true, -modifier);
    end
end

-- Alith Anar ---------------
-----------------------------
li_mor.alith_anar = {
    ["subtype"] = "wh2_dlc10_hef_alith_anar",
    ["faction"] = "wh2_main_hef_nagarythe",
    ["confed_factions"] = { faction, "wh2_main_hef_nagarythe", "wh2_main_hef_eataine",
        "wh2_main_hef_order_of_loremasters", "wh2_main_hef_avelorn", "wh2_dlc15_hef_imrik",
        "wh2_twa03_def_rakarth" };
    -- TODO
    ["morathi_sub"] = nil,
    ["morathi_dom"] = nil,
    ["sub"] = nil,
    ["dom"] = nil,
    ["name_id"] = "3521245",
};

li_mor.malus = {
    ["subtype"] = "wh2_dlc14_def_malus_darkblade",
    ["faction"] = "wh2_main_def_hag_graef",
    ["confed_factions"] = { faction, "wh2_main_def_hag_graef", "wh2_main_def_cult_of_pleasure",
        "wh2_main_def_dark_elves", "wh2_main_def_hag_graef", "wh2_main_def_naggarond",
        "wh2_twa03_def_rakarth", "wh2_main_def_blood_hall_coven" };
    ["morathi_sub"] = "li_morathi_malus_sub",
    ["morathi_dom"] = "li_morathi_malus_dom",
    ["sub"] = "li_malus_morathi_sub",
    ["dom"] = "li_malus_morathi_dom",
    ["name_id"] = "3521246",
};

li_mor.nkari = {
    ["subtype"] = "wh3_main_sla_nkari",
    ["faction"] = "wh3_main_sla_seducers_of_slaanesh",
    ["confed_factions"] = { faction, "wh3_main_sla_seducers_of_slaanesh" },
    ["morathi_sub"] = "li_trait_morathi_nkari_sub",
    ["morathi_dom"] = "li_trait_morathi_nkari_dom",
    ["sub"] = "li_trait_nkari_morathi_sub",
    ["dom"] = "li_trait_nkari_morathi_dom",
    ["name_id"] = "3521247",
};

li_mor.teclis = {
    ["subtype"] = "wh2_main_hef_teclis",
    ["faction"] = "wh2_main_hef_order_of_loremasters",
    ["confed_factions"] = { faction, "wh2_main_hef_order_of_loremasters", "wh2_main_hef_nagarythe", "wh2_main_hef_eataine",
     "wh2_main_hef_avelorn", "wh2_dlc15_hef_imrik", "wh2_twa03_def_rakarth" },
    ["morathi_sub"] = "li_trait_morathi_teclis_sub",
    ["morathi_dom"] = "li_trait_morathi_teclis_dom",
    ["sub"] = "li_trait_teclis_morathi_sub",
    ["dom"] = "li_trait_teclis_morathi_dom",
    ["name_id"] = "3521248",
};

function li_mor:adjust_character_loyalty(modifier, character)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end

    -- if character is not given, then apply to all in faction
    if character == nil then
        local characters = mor:faction():character_list();
        for i = 0, characters:num_items() - 1 do
            local char = characters:item_at(i);
            -- does nothing if they're a legendary lord or a hero
            cm:modify_character_personal_loyalty_factor(cm:char_lookup_str(char), modifier);
        end
    else
        cm:modify_character_personal_loyalty_factor(cm:char_lookup_str(character), modifier);
    end
end

---Clear the force stance from all armies of this faction before a confederation to avoid being left with
---armies that you can't use afterwards
---@param faction any
function li_mor:clear_faction_character_stance(faction)
    local characters = faction:character_list();
    for i = 0, characters:num_items() - 1 do
        local char = characters:item_at(i);
        -- does nothing if they're a legendary lord or a hero
        cm:force_character_force_into_stance(cm:char_lookup_str(char), "MILITARY_FORCE_ACTIVE_STANCE_TYPE_DEFAULT");
    end
end

---Delay the killing of a generated force by its CQI
---@param cqi_generated string|nil generated CQI of the force returned by the success callback of create_force_with_general
---@param delay_s number delay in seconds
function li_mor:delayed_kill_cqi(cqi_generated, delay_s)
    cm:callback(function() 
        if cqi_generated ~= nil then
            li_mor:log("killing temp spawned force");
            cm:disable_event_feed_events(true, "wh_event_category_character", "", "")
            cm:kill_character(cqi_generated, true);
            cm:disable_event_feed_events(false, "wh_event_category_character", "", "")
        end
    end, delay_s);
end

cm:add_first_tick_callback(function() li_mor:initialize() end);
