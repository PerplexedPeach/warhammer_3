local subtype = "wh2_main_def_morathi";
-- stubs in case we don't have the progression framework
local function find_subtype_in_faction(faction, subtype)
    if faction == nil or faction:is_null_interface() then
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

local function get_morathi()
    return get_character_all(subtype,
        { "wh2_main_def_cult_of_pleasure", "wh2_main_def_naggarond", "wh2_main_def_hag_graef",
            "wh2_dlc11_def_the_blessed_dread", "wh2_twa03_def_rakarth", "wh2_main_def_har_ganeth" });
end


local function broadcast_self()
    -- apply reskin
    cm:add_character_model_override(get_morathi(), "wh2_main_art_set_def_morathi_fourth");
end


cm:add_first_tick_callback(function() broadcast_self() end);