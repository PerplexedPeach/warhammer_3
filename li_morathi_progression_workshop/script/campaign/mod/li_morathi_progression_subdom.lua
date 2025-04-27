local subdom_effect_bundle = "li_morathi_subdom";

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

	-- elixir_cost = {
	-- 	current = 1,
	-- 	base = 1,
	-- 	easy = 200,
	-- 	normal = 400,
	-- 	hard = 500,
	-- 	very_hard = 600,
	-- 	mod = 0.04
	-- },

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
}

local function should_create_ui()
    local mor = li_mor:get_char();
    if not mor then
        return false
    end
    local faction = mor:faction();
    if not faction or faction:is_null_interface() or not faction:is_human() then
        return false
    end
    -- only create the bar if the local faction is Morathi's faction
    return cm:get_local_faction_name(true) == mor:faction():name()
end

function Get_or_create_morathi_bar()
    if not should_create_ui() then
        return
    end

    local parent_ui = find_uicomponent(core:get_ui_root(), "hud_campaign", "resources_bar_holder", "resources_bar");
    -- li_mor:log("Creating Morathi bar UI component");
    -- actually generate the TWUI file
    local result = core:get_or_create_component("morathi_bar", "ui/campaign ui/morathi_bar.twui.xml", parent_ui)
    if not result then
        script_error("Morathi: ".. "ERROR: could not create morathi bar ui component? How can this be?");
        return false;
    end;
    return result;
end

function Populate_morathi_bar(bar)
    if not is_uicomponent(bar) then
        li_mor:error("Not a valid UIC passed to populate bar; probably called at wrong time");
        return
    end
    -- get Morathi's submissiveness which is the state to display via the UI
    -- local sub = li_mor:sub_score();
    local possession_ui = find_uicomponent(bar, "posession_orb");
    local dom_button_ui = find_uicomponent(possession_ui,  morathi_sub.dom_button_inner);
    local sub_button_ui = find_uicomponent(possession_ui,  morathi_sub.sub_button_inner);

    if not possession_ui then
        li_mor:error("Could not find the possession orb in the Morathi bar");
        return
    end
    if not dom_button_ui or not sub_button_ui then
        li_mor:error("Could not find the buttons in the Morathi bar");
        return
    end

    dom_button_ui:SetTooltipText(common.get_localised_string("campaign_localised_strings_string_dom_button"), true);
    sub_button_ui:SetTooltipText(common.get_localised_string("campaign_localised_strings_string_sub_button"), true);


    possession_ui:InterfaceFunction("UpdateDisplay");
    -- bar:SetVisible(true);
end


function morathi_sub:add_listeners()
	li_mor:log("Adding sub UI Listeners");

	if cm:is_new_game() == true then

        if should_create_ui() then
            self:update_ui();
        end

	end

	core:add_listener(
		"turn_start_actions",
		"ScriptEventHumanFactionTurnStart",
		function(context)
			local faction = context:faction()
            local mor = li_mor:get_char();
            if mor == nil or faction:name() ~= mor:faction():name() then
                return;
            end
			return faction:is_human();
		end,
		function(context)
            local mor = li_mor:get_char();

		-- 	local faction = cm:get_faction(self.faction_key)
		-- 	local malus_character = faction:faction_leader();

		-- 	if malus_character:in_settlement() == true then
		-- 		self:modify_sub(self.factors.in_settlement, self.garrison_decline);
		-- 	end

		-- 	self:modify_sub(self.factors.deterioration, self.sanity_per_turn);

			self:update_effects();
		end,
		true
	);


    -- UI trigger to be multiplayer safe
    core:add_listener(
		"dom_ComponentLClickUp",
		"ComponentLClickUp",
		function(context)
			if context.string == self.dom_button_inner then
				local component = UIComponent(context.component);
				local parent = UIComponent(component:Parent());

				if parent:Id() == self.dom_button then
					return true;
				end
			end
			return false;
		end,
		function(context)
			local local_faction = cm:get_local_faction_name(true);
			local faction = cm:get_faction(local_faction);
			local faction_cqi = faction:command_queue_index();
			CampaignUI.TriggerCampaignScriptEvent(faction_cqi, "morathi_dom");
			core:trigger_event("ScriptEventDomButtonClicked");
		end,
		true
	);

	core:add_listener(
		"sanity_UITrigger",
		"UITrigger",
		function(context)
			return context:trigger() == "morathi_dom";
		end,
		function(context)
			local faction = cm:model():faction_for_command_queue_index(context:faction_cqi());
            li_mor:log("Dom button clicked");
            self:modify_sub(self.factors.sync, -1);
			self:update_effects();

			-- self:modify_sanity(self.factors.medication, self.medicine_decline);
			-- self:update_effects(faction);
			-- self:update_ui();
		end,
		true
	);

    -- UI trigger to be multiplayer safe
    core:add_listener(
        "sub_ComponentLClickUp",
        "ComponentLClickUp",
        function(context)
            if context.string == self.sub_button_inner then
                local component = UIComponent(context.component);
                local parent = UIComponent(component:Parent());

                if parent:Id() == self.sub_button then
                    return true;
                end
            end
            return false;
        end,
        function(context)
            local local_faction = cm:get_local_faction_name(true);
            local faction = cm:get_faction(local_faction);
            local faction_cqi = faction:command_queue_index();
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, "morathi_sub");
            core:trigger_event("ScriptEventSubButtonClicked");
        end,
        true
    );

    core:add_listener(
        "sanity_UITrigger",
        "UITrigger",
        function(context)
            return context:trigger() == "morathi_sub";
        end,
        function(context)
            local faction = cm:model():faction_for_command_queue_index(context:faction_cqi());
            li_mor:log("Sub button clicked");
            self:modify_sub(self.factors.sync, 1);
            self:update_effects();
        end,
        true
    );


	local current_faction = li_mor:get_char():faction();
	if current_faction and current_faction:is_null_interface() == false and current_faction:is_human() then
		local faction = current_faction;

        -- sync the pooled resource with the stored sub score
        local sub = li_mor:sub_score();
        local pooled_sub = faction:pooled_resource_manager():resource(self.resource_key):value();
        local difference = sub - pooled_sub;

        li_mor:log("Stored sub score: "..tostring(sub) .. " Pooled sub score: "..tostring(pooled_sub) .. " Difference: "..tostring(difference));
        if difference ~= 0 then
            cm:faction_add_pooled_resource(faction:name(), self.resource_key, self.factors.sync, difference);
        end

		self:update_effects();
	end

end

function morathi_sub:update_effects()
    local mor = li_mor:get_char();
    if mor == nil then
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

	self:update_ui();
end

function morathi_sub:modify_sub(factor, amount)
    local faction = li_mor:get_char():faction();
	cm:faction_add_pooled_resource(faction:name(), self.resource_key, factor, amount);
    li_mor:modify_sub_score(amount);
end

function morathi_sub:update_ui()

    local sub_ui = Get_or_create_morathi_bar();
    if not sub_ui then
        return
    end
    Populate_morathi_bar(sub_ui);

end


--------------------------------------------------------------
----------------------- SAVING / LOADING ---------------------
--------------------------------------------------------------

-- cm:add_saving_game_callback(
-- 	function(context)
-- 		cm:save_named_value("malus_sanity", malus_sanity.elixir_cost.base, context);
-- 	end
-- );
-- cm:add_loading_game_callback(
-- 	function(context)
-- 		if cm:is_new_game() == false then
-- 			malus_sanity.elixir_cost.base = cm:load_named_value("malus_sanity", malus_sanity.elixir_cost.base, context);
-- 		end
-- 	end
-- );

---- my old code


cm:add_first_tick_callback(function() 
    morathi_sub:add_listeners();
end);
