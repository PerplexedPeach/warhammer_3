local faction = "wh2_main_def_cult_of_pleasure";
local subtype = "wh2_main_def_morathi";
local LI_MAIN_EVENT = "ScriptEventMorathiAscensionEvent"
local confed_factions = { "wh2_main_def_cult_of_pleasure", "wh2_main_def_naggarond", "wh2_main_def_hag_graef",
    "wh2_dlc11_def_the_blessed_dread", "wh2_twa03_def_rakarth", "wh2_main_def_har_ganeth" };
local art_set = "wh2_main_art_set_def_morathi";
local names_name_id = "1248512";
---@class LiProgression
li_mor = LiProgression:new("morathi", faction, subtype, art_set, LI_MAIN_EVENT, confed_factions, names_name_id);

CFSettings["mor"] = {};

morathi_sub = {
	ui_key = "posession_orb",
    dom_button_inner = "mushroom_button",
	dom_button = "malus_potion",
    sub_button_inner = "tzarkan_button",
    sub_button = "tzarkan_potion",
	resource_key = "li_morathi_sub",
	-- sanity_per_turn = 1,
	-- garrison_decline = -1,
	-- medicine_decline = -10,

	factors = {
		-- deterioration = "wh2_dlc14_resource_factor_sanity_deterioration",
		-- in_settlement = "wh2_dlc14_resource_factor_sanity_in_settlement",
		-- medication = "wh2_dlc14_resource_factor_sanity_medication",
		-- ability = "wh2_dlc14_resource_factor_sanity_battle_ability"
        dilemma = "li_morathi_sub_dilemma",
        sync = "li_morathi_sub_sync",
	},

    -- TODO abilities in battle that affects sub/dom
	abilities = {
		"wh2_dlc14_lord_abilities_tzarkan_spite",
		"wh2_dlc14_lord_abilities_tzarkan"
	},

	effects = {
		-- ai = "wh2_dlc14_pooled_resource_malus_sanity_ai",
		-- sanity_7 = "wh2_dlc14_pooled_resource_malus_sanity_7",
		-- sanity_5 = "wh2_dlc14_pooled_resource_malus_sanity_5",
		-- sanity_6 = "wh2_dlc14_pooled_resource_malus_sanity_6",
		-- sanity_1 = "wh2_dlc14_pooled_resource_malus_sanity_1",
		-- sanity_4_character = "wh2_dlc14_pooled_resource_malus_sanity_4_character",
		-- sanity_5_character = "wh2_dlc14_pooled_resource_malus_sanity_5_character",
		-- sanity_6_character = "wh2_dlc14_pooled_resource_malus_sanity_6_character",
		-- sanity_7_character = "wh2_dlc14_pooled_resource_malus_sanity_7_character"
	},

	-- ability_cost = 2
};

local subbiness_key = "li_morathi_subdom";
function li_mor:sub_score()
    -- integer of how submissive the character has become with positive values indicating more sub
    return cm:get_saved_value(subbiness_key) or 0;
end

function li_mor:modify_sub_score(modifier, factor)
    factor = factor or morathi_sub.factors.dilemma;
    local faction = li_mor:get_char():faction();
	cm:faction_add_pooled_resource(faction:name(), morathi_sub.resource_key, factor, modifier);
    cm:set_saved_value(subbiness_key, li_mor:sub_score() + modifier);
    morathi_sub:update_effects();
end

-- common functions for each target

---Retrieve target character of some stage
---@param target table
---@return CHARACTER_SCRIPT_INTERFACE|nil
function li_mor:get_target_character(target)
    return self:get_character_all(target.subtype, target.confed_factions);
end

---Get the sub/dom score of a target
---@param target table
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
---@param target table
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

---Make a choice in the sub/dom dilemma
---@param target table target character
---@param loyalty_change boolean whether to change the loyalty of the target character
function li_mor:sub_choice(target, loyalty_change)
    self:log("Made sub choice for " .. target.subtype);
    self:modify_sub_score(CFSettings.mor_sub_gain);
    if loyalty_change then
        self:adjust_character_loyalty(-1);
    end
    self:adjust_target_sub(target, -1);
end

function li_mor:dom_choice(target, loyalty_change)
    self:log("Made dom choice for " .. target.subtype);
    self:modify_sub_score(-CFSettings.mor_dom_gain);
    if loyalty_change then
        self:adjust_character_loyalty(1);
    end
    self:adjust_target_sub(target, 1);
end

function li_mor:subdom_progression_callback(context, is_human, data)
    if is_human then
        self:log("Human progression, trigger dilemma " .. data.dilemma_name);
        local delimma_choice_listener_name = data.dilemma_name .. "_DilemmaChoiceMadeEvent";
        -- using persist = true even for a delimma event in case they click on another delimma first
        core:add_listener(
            delimma_choice_listener_name,
            "DilemmaChoiceMadeEvent",
            function(context)
                return context:dilemma() == data.dilemma_name;
            end,
            function(context)
                local choice = context:choice();
                self:log(data.dilemma_name .. " choice " .. tostring(choice));
                -- add sub/dom tracking here
                if choice == 0 then
                    self:sub_choice(data.target, false);
                elseif choice == 1 then
                    self:dom_choice(data.target, false);
                end
                self:fire_event({ type = "accept", stage = data.this_stage });
                self:advance_stage(data.trait_name, data.this_stage);
                core:remove_listener(delimma_choice_listener_name);
            end,
            true
        );
        cm:trigger_dilemma(self:get_char():faction():name(), data.dilemma_name);
    else
        -- if it's not the human
        local rand = cm:random_number(100, 1);
        self:log("AI rolled " .. tostring(rand) .. " against chance to corrupt " .. data.ai_corruption_chance)
        if rand <= data.ai_corruption_chance then
            self:fire_event({ type = "accept", stage = data.this_stage });
            self:advance_stage(data.trait_name, data.this_stage);
        else
            self:fire_event({ type = "reject", stage = data.this_stage });
            self:modify_progress_percent(-CFSettings.progression_rejection_progress_decrease, "dilemma rejection");
        end
    end
end

-- Alith Anar ---------------
-----------------------------
li_mor.alith_anar = {
    ["subtype"] = "wh2_dlc10_hef_alith_anar",
    ["faction"] = "wh2_main_hef_nagarythe",
    ["confed_factions"] = { faction, "wh2_main_hef_nagarythe", "wh2_main_hef_eataine",
        "wh2_main_hef_order_of_loremasters", "wh2_main_hef_avelorn", "wh2_dlc15_hef_imrik",
        "wh2_twa03_def_rakarth" },
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
        "wh2_twa03_def_rakarth", "wh2_main_def_blood_hall_coven" },
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
    ["confed_factions"] = { faction, "wh2_main_hef_order_of_loremasters", "wh2_main_hef_nagarythe",
        "wh2_main_hef_eataine",
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
