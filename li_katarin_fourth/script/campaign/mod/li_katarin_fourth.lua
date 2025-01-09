local kat_subtype = "wh3_main_ksl_katarin";
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

local function get_kat()
    return get_character_all(kat_subtype, { "wh3_main_ksl_the_ice_court", "wh3_main_ksl_the_great_orthodoxy", "wh3_main_ksl_kislev"});
end

local function broadcast_self()
    -- apply reskin
    cm:add_character_model_override(get_kat(), "wh3_main_art_set_ksl_katarin_fourth");
end


cm:add_first_tick_callback(function() broadcast_self() end);