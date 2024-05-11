local valk_subtype = "wh3_dlc20_kho_valkia";
-- stubs in case we don't have the progression framework
local function find_subtype_in_faction(faction, subtype)
    if faction:is_null_interface() then
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

local function get_valkia()
    return get_character_all(valk_subtype,
        { "wh3_dlc20_chs_valkia", "wh_main_chs_chaos", "wh3_dlc20_chs_sigvald", "wh3_dlc20_chs_kholek",
            "wh3_dlc20_chs_azazel", "wh3_dlc20_chs_festus" });
end

local function broadcast_self()
    -- apply reskin
    local char = get_valkia();
    if char ~= nil then
        cm:add_character_model_override(char, "wh3_dlc20_art_set_kho_valkia_first");
    end
end

cm:add_first_tick_callback(function() broadcast_self() end);
