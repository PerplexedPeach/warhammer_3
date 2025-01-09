local faction = "wh_main_chs_chaos";
-- stubs in case we don't have the progression framework
local subtype = "wh_main_chs_archaon";
-- stubs in case we don't have the progression framework
local function find_subtype_in_faction(faction, subtype)
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

local function get_character_all(subtype, factions_to_consider)
    local faction_list = cm:get_human_factions();
    for i = 1, #faction_list do
        local char = find_subtype_in_faction(cm:get_faction(faction_list[i]), subtype);
        if char then
            return char;
        end
    end

    if factions_to_consider ~= nil then
        for j = 1, #factions_to_consider do
            local char = find_subtype_in_faction(cm:get_faction(factions_to_consider[j]), subtype);
            if char then
                return char;
            end
        end
    end
    return nil;
end

local function get_character_faction_leader(subtype, faction_name, possible_confed_factions)
    -- try to shortcut getting the character
    local faction = cm:get_faction(faction_name);
    if faction and not faction:is_null_interface() then
        local leader = faction:faction_leader();
        if not leader:is_null_interface() and leader:character_subtype(subtype) then
            return faction:faction_leader();
        end
    end
    return get_character_all(subtype, possible_confed_factions);
end

local function get_archaon()
    return get_character_faction_leader(subtype, faction, {});
end


local function broadcast_self()
    -- apply reskin
    cm:add_character_model_override(get_archaon(), "wh_main_art_set_chs_archaon_first");
end


cm:add_first_tick_callback(function() broadcast_self() end);