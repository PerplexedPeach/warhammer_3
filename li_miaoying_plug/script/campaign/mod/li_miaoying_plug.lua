local miao_faction = "wh3_main_cth_the_northern_provinces";
local miao_subtype = "wh3_main_cth_miao_ying";
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

function get_miaoying_all()
    -- check Cathay factions that can naturally confederate her
    local factions_to_consider = { "wh3_main_cth_the_western_provinces" };
    for j = 1, #factions_to_consider do
        local miao = find_subtype_in_faction(cm:get_faction(factions_to_consider[j]), miao_subtype);
        if miao then
            return miao;
        end
    end

    faction_list = cm:get_human_factions();
    for i = 1, #faction_list do
        local miao = find_subtype_in_faction(cm:get_faction(faction_list[i]), miao_subtype);
        if miao then
            return miao;
        end
    end
    return nil;
end

local function get_miaoying()
    local faction = cm:get_faction(miao_faction);
    -- miao will always be faction leader, so only need to consider when the faction no longer exists
    if faction:is_null_interface() then
        return get_miaoying_all()
    end
    return faction:faction_leader();
end

local function broadcast_self()
    cm:add_character_model_override(get_miaoying(), "wh3_main_art_set_cth_miao_ying_plug");
end

cm:add_first_tick_callback(function() broadcast_self() end);