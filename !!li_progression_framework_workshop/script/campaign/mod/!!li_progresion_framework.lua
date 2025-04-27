local version = "2.2.0";
local printed_version = false;

local progress_effect_bundle = "li_progress";
local progress_effect = "li_effect_progress";

-- load settings and keep setting updated
local mod_name = "li_cf";
CFSettings = {};
core:add_listener(
    "ProgressionFrameworkSettingsInit",
    "MctInitialized",
    true,
    function(context)
        -- get the mct object
        local mct = context:mct();
        local my_mod = mct:get_mod_by_key(mod_name);

        -- for some reason get_options doesn't work
        local keys = {};
        local option_types = { "checkbox", "slider", "dropdown" };
        for i = 1, #option_types do
            local option_type = option_types[i];
            local this_keys = my_mod:get_option_keys_by_type(option_type);
            for i = 1, #this_keys do
                keys[#keys + 1] = this_keys[i];
            end
        end

        for i = 1, #keys do
            local option = my_mod:get_option_by_key(keys[i]);
            CFSettings[keys[i]] = option:get_finalized_setting();
        end
        CFSettings.mct = my_mod;
    end,
    true
);

core:add_listener(
    "ProgressionFrameworkSettingsFinalized",
    "MctOptionSettingFinalized",
    true,
    function(context)
        local mct_mod = context:mod();
        if mct_mod:get_key() ~= mod_name then
            return false;
        end
        local mct_option = context:option();
        CFSettings[mct_option:get_key()] = context:setting();
        CFSettings.mct = mct_mod;

        Mod_log("Settings finalized " .. mct_option:get_key() .. " " .. tostring(context:setting()));
    end,
    true
);
function Print_settings()
    for k, v in pairs(CFSettings) do
        console_print(k .. " = " .. tostring(v));
    end
end

function Is_character_attacker_or_defender(pending_battle, subtype_key)
    -- local pb = cm:model():pending_battle();
    local pb = pending_battle;
    if not pb:has_been_fought() then
        return false, false;
    end
    local main = Get_character_full(subtype_key);
    local involved = cm:pending_battle_cache_char_is_involved(main);
    if not involved then
        return false, false;
    end
    if cm:pending_battle_cache_char_is_defender(main) then
        return false, true;
    else
        return true, false;
    end
end

---@class LiProgression
LiProgression = {};
---Main progression interface for a character
---@param main_shortname string Short name for logging
---@param main_faction string faction key for main character to be corrupted
---@param main_subtype string subtype key for main character
---@param main_art_set string art set prefix for main character
---@param main_event string custom event name for the main corruption event (e.g. ScriptEvent<shortname>CorruptEvent)
---@param confed_factions table[string] array of faction keys that could possibly confederate the main character
---@param names_name_id_prefix string prefix of names name ID (stage will be appended to become new ID for each stage's name)
---@return LiProgression
function LiProgression:new(main_shortname, main_faction, main_subtype, main_art_set, main_event, confed_factions,
                           names_name_id_prefix)
    local self = {} ---@class LiProgression
    setmetatable(self, {
        __index = LiProgression
    })
    self.REGISTERED_STAGES = { [0] = "" };
    self.PROGRESSION_CALLBACK = { [0] = nil };


    self.shortname = main_shortname;
    self.main_faction = main_faction;
    self.main_subtype = main_subtype;
    self.main_art_set = main_art_set;
    self.main_event = main_event;
    self.confed_factions = confed_factions;
    self.names_name_id_prefix = names_name_id_prefix;
    -- for variant selector; assumes that main_art_set is for the base art set
    self.unlocked_art_sets = { self.main_art_set };
    -- for dilemmas
    self.dilemma_queue = LiQueue:new("li_" .. main_shortname .. "_dilemma_queue");

    self.stored_stage_name = "li_" .. main_shortname .. "_current_stage";
    -- progress percent between 0 and 100
    self.progress_percent_name = "li_" .. main_shortname .. "_progress_percent";
    self.last_progression_turn_name = "li_" .. main_shortname .. "_last_progression";
    self.refractory_period = 3;
    self.last_submod_event_turn_name = "li_" .. main_shortname .. "_last_submod_event";

    return self;
end

function LiProgression:log(message)
    Mod_log(self.shortname .. " " .. message);
end

function LiProgression:error(message)
    self:log(" [ERROR] " .. message);
    script_error(self.shortname .. " " .. message);
end

--- Fire a main corruption event that others can listen to
---@param context_table table table of context to pass to the event (e.g. { type = "enter", stage = 1 })
function LiProgression:fire_event(context_table)
    self:log(self.main_event .. " " .. context_table.type .. " " .. tostring(context_table.stage));
    core:trigger_custom_event(self.main_event, context_table);
end

--- Add a listener to corruption events, wrapper around core:add_listener
---@param listener_name string name of the listener (does not have to be unique, but allows for easier debugging and removal if unique)
---@param conditional_test boolean|function function to test if the listener should fire (or true for always)
---@param target_callback function function taking in context as a parameter to call when the listener fires
---@param listener_persists_after_target_callback_called boolean if false, the listener will only be called once per game session
function LiProgression:add_listener(listener_name, conditional_test, target_callback,
                                    listener_persists_after_target_callback_called)
    core:add_listener(
        listener_name,
        self.main_event,
        conditional_test,
        target_callback,
        listener_persists_after_target_callback_called
    );
end

-- each stage mod decides the condition to advance to it (and not advance to the next stage)
-- callback should call the global set stage function to advance to its stage
-- callback will be called at common progression events (of course the stage mod could listen to additional events)
function LiProgression:stage_register(name, stage, callback_for_progression, callback_on_entering)
    self:log("registering stage " .. tostring(stage));
    if not is_number(stage) then
        self:log("Rejecting registration of invalid stage");
        return
    end
    self.REGISTERED_STAGES[stage] = name;
    self.PROGRESSION_CALLBACK[stage] = callback_for_progression;
    if callback_on_entering ~= nil then
        self:log("Registering entering callbacks is deprecated! Use a listener for " ..
            self.main_event .. " with type 'enter' instead");
    end
end

---Register persistent callbacks for when a certain stage or above is reached
---@param stage integer
---@param callback function
---@param name any|nil
function LiProgression:persistent_initialization_register(stage, callback, name)
    self:log("Registering persistent initializations is deprecated! Use a listener for " ..
        self.main_event .. " with type 'enter' or 'init' instead (remember to make it non-persistent)");
end

function Find_subtype_in_faction(faction, subtype)
    if faction == nil or faction == false or faction:is_null_interface() then
        return nil;
    end
    local characters = faction:character_list();
    for i = 0, characters:num_items() - 1 do
        local character = characters:item_at(i);
        if character:character_subtype(subtype) then
            return character;
        end
    end
    return nil;
end

function LiProgression:find_subtype_in_faction(faction, subtype)
    return Find_subtype_in_faction(faction, subtype);
end

function LiProgression:get_character_all(subtype, factions_to_consider)
    local faction_list = cm:get_human_factions();
    for i = 1, #faction_list do
        local char = self:find_subtype_in_faction(cm:get_faction(faction_list[i]), subtype);
        if char then
            return char;
        end
    end

    if factions_to_consider ~= nil then
        for j = 1, #factions_to_consider do
            local char = self:find_subtype_in_faction(cm:get_faction(factions_to_consider[j]), subtype);
            if char then
                return char;
            end
        end
    end

    self:error("Could not find character " .. subtype);
    return nil;
end

---Get a character that is likely a faction leader (used to shortcut search most of the time)
---@param subtype string Agent subtype from agent_subtypes_tables
---@param faction_name string Name of faction the character is likely leader of
---@param possible_confed_factions table[string] Array of factions the character may confederate with
---@return CHARACTER_SCRIPT_INTERFACE|nil
function LiProgression:get_character_faction_leader(subtype, faction_name, possible_confed_factions)
    -- try to shortcut getting the character
    local faction = cm:get_faction(faction_name);
    if faction and not faction:is_null_interface() then
        local leader = faction:faction_leader();
        if not leader:is_null_interface() and leader:character_subtype(subtype) then
            return faction:faction_leader();
        end
    end
    return self:get_character_all(subtype, possible_confed_factions);
end

function LiProgression:get_char_all()
    return self:get_character_all(self.main_subtype, self.confed_factions);
end

function LiProgression:get_char()
    return self:get_character_faction_leader(self.main_subtype, self.main_faction, self.confed_factions);
end

function Is_character_in_faction_factory(subtype)
    return function(faction)
        -- return cm:num_characters_of_type_in_faction(faction, subtype) > 0;
        return cm:faction_contains_characters_of_type(faction, subtype);
    end
end

local function stub_faction_callback(faction)
    return true;
end
function Get_all_factions()
    return cm:get_factions_by_filter(stub_faction_callback);
end

function Get_character_full(subtype)
    -- first look at all human factions
    local faction_list = cm:get_human_factions();

    for i = 1, #faction_list do
        local char = Find_subtype_in_faction(cm:get_faction(faction_list[i]), subtype);
        if char then
            return char;
        end
    end
    -- actually look at all characters
    faction_list = Get_all_factions();
    for i = 1, #faction_list do
        local char = Find_subtype_in_faction(faction_list[i], subtype);
        if char ~= nil and char:character_subtype(subtype) then
            return char;
        end
    end
    return nil;
end

function LiProgression:_get_art_set_name(stage)
    local stage_name = self.REGISTERED_STAGES[stage];
    local art_set_name = self.main_art_set;
    if stage > 0 then
        art_set_name = self.main_art_set .. "_" .. stage_name;
    end
    return art_set_name;
end

function LiProgression:switch_art_set_stage(stage)
    -- change 3D model and 2D portraits
    local art_set_name = self:_get_art_set_name(stage);
    self:log(art_set_name);
    cm:add_character_model_override(self:get_char(), art_set_name);
    self:_unlock_art_set_stage(stage);
end

function LiProgression:_unlock_art_set_stage(stage)
    local art_set_name = self:_get_art_set_name(stage);
    -- unlock this stage for the variant selector
    self.unlocked_art_sets[stage + 1] = art_set_name;
    local this_char = self:get_char();
    if this_char == nil then
        self:error("Could not find character to unlock art set stage (not an error if they are wiped out)");
        return;
    end

    -- different conventions for variant selector
    if Set_character_variants ~= nil then
        Set_character_variants(self.main_subtype, self.unlocked_art_sets);
        Has_set_character_variant(this_char:cqi(), stage + 1);
        self:log("Unlocked stage " .. tostring(stage) .. " variant for variant selector");
    elseif marthvs ~= nil then
        marthvs:set_subtype_variants(self.main_subtype, self.unlocked_art_sets);
        marthvs:set_character_variant_index(this_char:cqi(), stage + 1);
        self:log("Unlocked stage " .. tostring(stage) .. " variant for variant selector");
    end
end

function LiProgression:change_title(stage, override_id)
    if not is_number(stage) then
        self:log("Rejecting attempt to change to string stage " .. stage);
        return
    end
    -- TODO for some reason 1909115770 maps to 1909115776 math is broken?
    local id = override_id or (self.names_name_id_prefix .. tostring(stage));
    self:log("Change name to ID " ..
        tostring(id) .. " override id " .. tostring(override_id) .. " stage " .. tostring(stage));
    cm:change_character_localised_name(self:get_char(), "names_name_" .. tostring(id), "", "", "");
end

function LiProgression:get_stage()
    -- get the current corruption stage
    local current_stage = cm:get_saved_value(self.stored_stage_name);
    if current_stage == nil then
        current_stage = 0;
    end
    return current_stage;
end

function LiProgression:_set_stage(stage)
    -- directly set a corruption stage if it was registered and call the callback on it, returning the new stage
    if self.REGISTERED_STAGES[stage] then
        self:log("Set stage " .. tostring(stage));
        self:switch_art_set_stage(stage);
        cm:set_saved_value(self.stored_stage_name, stage);
        return stage;
    else
        self:log("cannot switch to unregistered stage " .. tostring(stage));
        return self:get_stage();
    end
end

function LiProgression:_get_next_stage_callback()
    -- get the callback function for the next stage (who will decide when to advance and do the advancement itself), or nil if it doesn't exist
    local current_stage = self:get_stage();
    -- get the smallest stage greater than the current stage
    local next_stage = 100;
    for stage, callback in pairs(self.PROGRESSION_CALLBACK) do
        if stage > current_stage and stage < next_stage then
            next_stage = stage;
        end
    end
    return self.PROGRESSION_CALLBACK[next_stage], next_stage;
end

function LiProgression:initialize()
    if not printed_version then
        Mod_log("Corruption framework version " .. version);
        printed_version = true;
    end

    -- assumes load order is above others so we get loaded last and can see all the corruption stages
    local current_stage = self:get_stage();
    self:log("---- start " .. tostring(current_stage));
    cm:callback(function()
        for stage = 1, current_stage - 1 do
            -- unlock the previous stage art sets to allow variant selector to switch between them
            self:_unlock_art_set_stage(stage);
        end
        self:_set_stage(current_stage);
        -- also set progress to update
        self:_set_progress_percent(self:get_progress_percent());
        self:fire_event({ type = "init", stage = current_stage });
    end, 1.3, "Li_" .. self.shortname .. "_initialize");
    -- reload dilemma queue
    self.dilemma_queue:load();

    -- add callback at start of turn to check if progress is 100%; sometimes we reach 100% but are blocked
    core:add_listener(
        "FactionTurnStartProgressCheck" .. self.shortname,
        "FactionTurnStart",
        true,
        function(context)
            local faction = context:faction();
            local char = self:get_char();
            if char == nil or faction == nil or faction:is_null_interface() or faction:name() ~= char:faction():name() then
                return false;
            end

            -- process dilemma queue
            local entry = self.dilemma_queue:process_turn();
            if entry ~= nil then
                self:log("Fired queued dilemma " .. entry.dilemma .. " for faction " .. entry.faction_name);
            end

            -- check if we need to stage up
            local progress_percent = self:get_progress_percent();
            self:log("Start of turn check progress percent " .. tostring(progress_percent));
            if progress_percent >= 100 then
                self:_call_progression_callback(context, faction:is_human());
            end
        end,
        true
    );
end

---Push a dilemma to the queue with a specified delay
---@param dilemma string Dilemma key in database to trigger
---@param delay number|nil Delay in turns before the dilemma is triggered; if nil, will use 0
---@param faction_name string|nil Faction name to trigger the dilemma for; if nil, will use the main character's faction
function LiProgression:queue_dilemma(dilemma, delay, faction_name)
    delay = delay or 0;
    faction_name = faction_name or self:get_char():faction():name();
    -- check if the dilemma is already in the queue
    local turns_until = self.dilemma_queue:turns_until(dilemma);
    if turns_until > 0 then
        self:log("Dilemma " .. dilemma .. " already in queue with delay " .. tostring(turns_until));
        return;
    else
        self:log("Pushing dilemma " .. dilemma .. " to queue with delay " .. tostring(delay));
        self.dilemma_queue:push(dilemma, delay, faction_name);
    end
end

function LiProgression:progression_cooldown_base()
    return CFSettings.progression_cooldown;
end

function LiProgression:progression_cooldown_left()
    -- Get number of turns before progression events can fire again; 0 means it's ready to fire
    local last_progression_turn = cm:get_saved_value(self.last_progression_turn_name) or -CFSettings
        .progression_cooldown;
    local turn_remaining = last_progression_turn - cm:turn_number() + CFSettings.progression_cooldown;
    if turn_remaining < 0 then
        turn_remaining = 0;
    end
    return turn_remaining;
end

-- cooldown for sub mods to avoid multi-triggers per turn
function LiProgression:turns_since_last_event()
    -- Get number of turns since last of any event firing, 0 being something fired this turn
    -- submods will decide how to proceed
    local last_submod_event = cm:get_saved_value(self.last_submod_event_turn_name) or 0;
    local last_progression_event = cm:get_saved_value(self.last_progression_turn_name) or -self.refractory_period;
    local turns_since = cm:turn_number() - math.max(last_submod_event, last_progression_event);
    if turns_since < 0 then
        turns_since = 0;
    end
    return turns_since;
end

function LiProgression:fire_submod_event(event_name)
    self:log("Firing submod" .. event_name);
    cm:set_saved_value(self.last_submod_event_turn_name, cm:turn_number());
end

function LiProgression:get_progress_percent()
    -- get the current corruption stage
    local progress_percent = cm:get_saved_value(self.progress_percent_name);
    if progress_percent == nil then
        progress_percent = 0;
    end
    return progress_percent;
end

function LiProgression:_set_progress_percent(percent)
    -- set the current corruption stage
    if percent < 0 or percent > 100 then
        self:error("Attempt to set progress percent to " .. tostring(percent) .. " out of bounds");
        return;
    end
    self:log("Set progress percent " .. tostring(percent));
    cm:set_saved_value(self.progress_percent_name, percent);
    self:_update_progress_effects();
    -- check for progression
    if percent == 100 then
        local is_human = self:get_char():faction():is_human();
        self:_call_progression_callback(nil, is_human);
    end
end

function LiProgression:modify_progress_percent(percent, cause)
    -- optional cause for debugging
    local current_percent = self:get_progress_percent();
    local new_percent = current_percent + percent;
    -- clamp to 0-100
    if new_percent < 0 then
        new_percent = 0;
    elseif new_percent > 100 then
        new_percent = 100;
    end
    self:log("Change progress percent " ..
        tostring(current_percent) .. " to " .. tostring(new_percent) .. " cause " .. tostring(cause));
    self:_set_progress_percent(new_percent);
end

function LiProgression:_update_progress_effects()
    local char = self:get_char();
    if char == nil then
        return;
    end
    local progress = self:get_progress_percent();

    cm:remove_effect_bundle_from_character(progress_effect_bundle, char);

    local bundle = cm:create_new_custom_effect_bundle(progress_effect_bundle);
    bundle:add_effect(progress_effect, "character_to_character_own", progress);
    bundle:set_duration(0);
    cm:apply_custom_effect_bundle_to_character(bundle, char);
end

function LiProgression:trigger_progression(context, is_human)
    return self:_set_progress_percent(100);
end

function LiProgression:_call_progression_callback(context, is_human)
    -- The corruptee needs some turns to settle into her new life before progressing down the corruption
    if self:progression_cooldown_left() > 0 then
        self:log("Too close to last corruption progression event on turn " ..
            cm:get_saved_value(self.last_progression_turn_name))
        return false;
    end
    self:log("Progress reached 100, looking for next stage");
    local callback, next_stage = self:_get_next_stage_callback();
    if callback ~= nil then
        self:log("Progression callback for stage " .. tostring(next_stage));
        callback(context, is_human);
        cm:set_saved_value(self.last_progression_turn_name, cm:turn_number());
        return true;
    else
        self:log("No progression callback for stage " .. tostring(next_stage));
        return false;
    end
end

function LiProgression:advance_stage(trait_name, next_stage)
    cm:force_add_trait("character_cqi:" .. self:get_char():cqi(), trait_name, 1);
    local prev_stage = self:get_stage();
    -- clear progress upon entering stage
    -- need to add some delay or it won't fire for some reason
    local new_stage = self:_set_stage(next_stage);
    self:log("Stage changed from " .. tostring(prev_stage) .. " to " .. tostring(new_stage));
    if new_stage ~= prev_stage then
        cm:callback(function()
            self:_set_progress_percent(0);
            self:fire_event({ type = "enter", stage = next_stage });
        end, 1);
    end
end

function LiProgression:attacker_or_defender()
    local pb = cm:model():pending_battle();
    if not pb:has_been_fought() then
        return false, false;
    end
    return Is_character_attacker_or_defender(pb, self.main_subtype);
end

local nkari_subtype = "wh3_main_sla_nkari";
local nkari_faction = "wh3_main_sla_seducers_of_slaanesh";

local sigvald_subtype = "wh_dlc01_chs_prince_sigvald";
local sigvald_faction = "wh3_dlc20_chs_sigvald";

local azazel_subtype = "wh3_dlc20_sla_azazel";
local azazel_faction = "wh3_dlc20_chs_azazel";

function LiProgression:opponent_slaanesh(faction)
    if faction:culture() == "wh3_main_sla_slaanesh" then
        return true;
    end
    if faction:name() == "wh3_main_rogue_the_pleasure_tide" then
        return true;
    end
    local nkari = self:get_character_faction_leader(nkari_subtype, nkari_faction);
    local sigvald = self:get_character_faction_leader(sigvald_subtype, sigvald_faction);
    local azazel = self:get_character_faction_leader(azazel_subtype, azazel_faction);
    if nkari ~= nil and not nkari:faction():is_null_interface() and faction:name() == nkari:faction():name() then
        return true;
    end
    if sigvald ~= nil and not sigvald:faction():is_null_interface() and faction:name() == sigvald:faction():name() then
        return true;
    end
    if azazel ~= nil and not azazel:faction():is_null_interface() and faction:name() == azazel:faction():name() then
        return true;
    end
    return false;
end

---Respawns a destoryed faction at a region (their start region) with an army led by their faction leader with unit_list units
---@param start_region string Region key of the region to spawn in
---@param faction_name string Faction key of the faction to respawn
---@param unit_list string Comma separated list of units in main_units (no spacing between commas)
function LiProgression:respawn_faction(start_region, faction_name, unit_list)
    local faction = cm:get_faction(faction_name);
    local x, y = cm:find_valid_spawn_location_for_character_from_settlement(faction_name, start_region, false, true, 9);
    cm:create_force_with_general( --create_force_with_general is used because create_force sometimes stops working
        faction_name,
        unit_list,
        start_region,
        x,
        y,
        "general",
        "wh3_prologue_general_test",
        "rdll_dummy",
        "",
        "",
        "",
        false,
        function(military_force_cqi)
            self:log("revived target");
            local faction_leader = faction:faction_leader();
            cm:stop_character_convalescing(faction_leader:cqi());

            local temp_general = faction:military_force_list():item_at(0):general_character();

            -- spawn the faction leader's army
            x, y = cm:find_valid_spawn_location_for_character_from_settlement(faction_name, start_region, false, true, 9);
            cm:create_force_with_existing_general(cm:char_lookup_str(faction_leader), faction_name, unit_list,
                start_region, x, y);

            cm:kill_character(cm:char_lookup_str(temp_general), true);
            -- give some money so they can sustain their force
            cm:treasury_mod(faction_name, 50000);
        end,
        false
    );
end
