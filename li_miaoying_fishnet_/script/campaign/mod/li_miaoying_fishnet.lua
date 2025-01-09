-- stubs in case we don't have the progression framework
local subtype = "wh3_main_cth_miao_ying";
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

local function get_miaoying()
    return get_character_all(subtype, {"wh3_main_cth_the_northern_provinces", "wh3_main_cth_the_western_provinces"});
end

local function broadcast_self()
    local miao = get_miaoying();
    if miao ~= nil then
        cm:add_character_model_override(miao, "wh3_main_art_set_cth_miao_ying_fishnet");
    end
end

cm:add_first_tick_callback(function() broadcast_self() end);
