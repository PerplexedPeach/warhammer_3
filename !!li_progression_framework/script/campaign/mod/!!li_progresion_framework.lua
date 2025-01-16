function Mod_log(text)
    -- TODO don't always flush to file
    if type(text) == "string" then
        local file = io.open("li_log.txt", "a")
        file:write(tostring(cm:turn_number()) .. " " .. text .. "\n")
        file:close()
    end
end

function Is_character_attacker_or_defender(pending_battle, subtype_key)
    local is_attacker = false
    local is_defender = false
	local attacker = pending_battle:attacker()
	local defender = pending_battle:defender()
	local secondary_attackers = pending_battle:secondary_attackers()
	local secondary_defenders = pending_battle:secondary_defenders()

    if attacker:character_subtype_key() == subtype_key then
        is_attacker = true
    end

    if defender:character_subtype_key() == subtype_key then
        is_defender = true
    end

    for i = 0, secondary_attackers:num_items() - 1 do
        attacker = secondary_attackers:item_at(i);

        if attacker:character_subtype_key() == subtype_key then
            is_attacker = true
        end
    end

    for i = 0, secondary_defenders:num_items() - 1 do
        defender = secondary_defenders:item_at(i);

        if defender:character_subtype_key() == subtype_key then
            is_defender = true
        end
    end


    return is_attacker, is_defender
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
    self.PROGRESSION_CALLBACK = { [0] = nil }
    self.ENTER_CALLBACK = {};
    self.PERSISTENT_CALLBACK = {};
    self.PERSISTENT_CALLBACK_NAMES = {};

    self.shortname = main_shortname;
    self.main_faction = main_faction;
    self.main_subtype = main_subtype;
    self.main_art_set = main_art_set;
    self.main_event = main_event;
    self.confed_factions = confed_factions;
    self.names_name_id_prefix = names_name_id_prefix;
    -- for variant selector; assumes that main_art_set is for the base art set
    self.unlocked_art_sets = { self.main_art_set };

    self.stored_stage_name = "li_" .. main_shortname .. "_current_stage";
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
---@param type string one of {"progression", "accept", "reject"}
---@param stage integer numerical stage of the next one we're advancing to
function LiProgression:fire_corrupt_event(type, stage)
    core:trigger_custom_event(self.main_event, { type = type, stage = stage });
    self:log(self.main_event .. type .. tostring(stage));
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
    self:stage_enter_callback_register(stage, callback_on_entering);
end

function LiProgression:stage_enter_callback_register(stage, callback)
    self:log("Registering stage enter callback for stage " .. tostring(stage));
    if not is_number(stage) then
        self:log("Rejecting registration of invalid stage");
        return
    end
    if self.ENTER_CALLBACK[stage] then
        local callbacks = self.ENTER_CALLBACK[stage];
        callbacks[#callbacks + 1] = callback;
    else
        self.ENTER_CALLBACK[stage] = { callback };
    end
end

---Register persistent callbacks for when a certain stage or above is reached
---@param stage integer
---@param callback function
---@param name any|nil
function LiProgression:persistent_initialization_register(stage, callback, name)
    -- put registration of stage-specific persistent callbacks inside it
    -- at initialization, all stages up to and including the current one will be called
    -- needed for proper loading
    if name == nil then
        name = tostring(callback);
    end
    self:log("Registering persistent factories for stage " .. tostring(stage) .. " " .. tostring(name));
    if not is_number(stage) then
        self:log("Rejecting registration of invalid stage");
        return
    end
    if self.PERSISTENT_CALLBACK[stage] then
        local callbacks = self.PERSISTENT_CALLBACK[stage];
        callbacks[#callbacks + 1] = callback;
        local names = self.PERSISTENT_CALLBACK_NAMES[stage];
        names[#callbacks + 1] = name;
    else
        self.PERSISTENT_CALLBACK[stage] = { callback };
        self.PERSISTENT_CALLBACK_NAMES[stage] = { name };
    end
end

function LiProgression:find_subtype_in_faction(faction, subtype)
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

function LiProgression:get_character_all(subtype, factions_to_consider)
    faction_list = cm:get_human_factions();
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

function LiProgression:get_art_set_name(stage)
    local stage_name = self.REGISTERED_STAGES[stage];
    local art_set_name = self.main_art_set;
    if stage > 0 then
        art_set_name = self.main_art_set .. "_" .. stage_name;
    end
    return art_set_name;
end

function LiProgression:switch_art_set_stage(stage)
    -- change 3D model and 2D portraits
    local art_set_name = self:get_art_set_name(stage);
    self:log(art_set_name);
    cm:add_character_model_override(self:get_char(), art_set_name);
    self:unlock_art_set_stage(stage);
end

function LiProgression:unlock_art_set_stage(stage)
    local art_set_name = self:get_art_set_name(stage);
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

function LiProgression:call_persistent_callback_factory(stage)
    local persistent_callbacks = self.PERSISTENT_CALLBACK[stage];
    local names = self.PERSISTENT_CALLBACK_NAMES[stage];
    if persistent_callbacks then
        for i = 1, #persistent_callbacks do
            self:log("Calling persistent callback for stage " .. tostring(stage) .. " " .. tostring(names[i]));
            persistent_callbacks[i](stage);
        end
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

function LiProgression:set_stage(stage)
    -- directly set a corruption stage if it was registered and call the callback on it, returning the new stage
    if self.REGISTERED_STAGES[stage] then
        self:log("Set stage " .. tostring(stage));
        self:switch_art_set_stage(stage);
        local on_enter_callbacks = self.ENTER_CALLBACK[stage];
        if on_enter_callbacks then
            for i = 1, #on_enter_callbacks do
                on_enter_callbacks[i]();
            end
        end
        cm:set_saved_value(self.stored_stage_name, stage);
        self:call_persistent_callback_factory(stage);
        return stage;
    else
        self:log("cannot switch to unregistered stage " .. tostring(stage));
        return self:get_stage();
    end
end

function LiProgression:get_next_stage_callback()
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
    -- assumes load order is above others so we get loaded last and can see all the corruption stages
    local current_stage = self:get_stage();
    self:log("---- start " .. tostring(current_stage));
    cm:callback(function()
        for stage = 1, current_stage - 1 do
            -- unlock the previous stage art sets to allow variant selector to switch between them
            self:unlock_art_set_stage(stage);
            -- don't need to do <= since set stage will call the current stage's persistent callback factory
            self:call_persistent_callback_factory(stage);
        end
        self:set_stage(current_stage);
    end, 1.3, "Li_" .. self.shortname .. "_initialize");
end

function LiProgression:progression_cooldown_base()
    return self.refractory_period;
end

function LiProgression:progression_cooldown_left()
    -- Get number of turns before progression events can fire again; 0 means it's ready to fire
    local last_progression_turn = cm:get_saved_value(self.last_progression_turn_name) or -self.refractory_period;
    local turn_remaining = last_progression_turn - cm:turn_number() + self.refractory_period;
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

function LiProgression:trigger_progression(context, is_human)
    -- The corruptee needs some turns to settle into her new life before progressing down the corruption
    if self:progression_cooldown_left() > 0 then
        self:log("Too close to last corruption progression event on turn " ..
            cm:get_saved_value(self.last_progression_turn_name))
        return false;
    end
    self:log("Triggering progression, looking for next stage");
    local callback, next_stage = self:get_next_stage_callback();
    if callback ~= nil then
        self:log("Progression callback for stage " .. tostring(next_stage));
        callback(context, is_human);
        self:fire_corrupt_event("progression", next_stage);
        cm:set_saved_value(self.last_progression_turn_name, cm:turn_number());
        return true;
    else
        self:log("No progression callback for stage " .. tostring(next_stage));
        return false;
    end
end

function LiProgression:advance_stage(trait_name, next_stage)
    cm:force_add_trait("character_cqi:" .. self:get_char():cqi(), trait_name, 1);
    self:set_stage(next_stage);
    self:fire_corrupt_event("accept", next_stage);
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
    cm:create_force_with_general(--create_force_with_general is used because create_force sometimes stops working
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
