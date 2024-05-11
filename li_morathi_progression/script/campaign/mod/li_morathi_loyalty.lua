-- loyalty below which they can trigger a loyalty event
local loyalty_threshold = 8;
local loyalty_to_random_chance = {
    [7] = 20,
    [6] = 30,
    [5] = 40,
    [4] = 50,
    [3] = 60,
    [2] = 75,
    [1] = 100,
    [0] = 100,
};
local lord_subtype_to_key = {
    ["wh2_main_def_dreadlord"] = "md",
    ["wh2_main_def_dreadlord_fem"] = "fd",
    ["wh2_dlc14_def_high_beastmaster"] = "mb",
    ["wh2_dlc10_def_supreme_sorceress_beasts"] = "fs",
    ["wh2_dlc10_def_supreme_sorceress_dark"] = "fs",
    ["wh2_dlc10_def_supreme_sorceress_death"] = "fs",
    ["wh2_dlc10_def_supreme_sorceress_fire"] = "fs",
    ["wh2_dlc10_def_supreme_sorceress_shadow"] = "fs",
};
local hub_dilemma_key = "li_morathi_loyalty_hub";

---Create the hub dilemma, generating the correct payloads and event dilemmas for this character
---@param char CHARACTER_SCRIPT_INTERFACE
local function generate_low_loyalty_dilemma(char)
    local mor = li_mor:get_char();
    if mor == nil then
        return;
    end
    local char_key = lord_subtype_to_key[char:character_subtype_key()];
    -- decide what events to populate
    local dbldr = cm:create_dilemma_builder(hub_dilemma_key);
    dbldr:add_target("default", char:family_member());

    -- TODO do we need the following?
    local choice_keys = { "FIRST", "SECOND", "THIRD", "FOURTH" };
    local dilemma_choices = dbldr:possible_choices();
    for i = 1, #dilemma_choices do
        dbldr:remove_choice_payload(choice_keys[i]);
    end

    -- TODO find 2 appropriate events
    local event_keys = {};
    event_keys[1] = "dom_orgy";
    event_keys[2] = "dom_foot";

    local event_full_key = {};
    for i = 1, #event_keys do
        event_full_key[i] = "li_" .. char_key .. "_" .. event_keys[i];
    end

    for i = 1, #dilemma_choices do
        local payload_builder = cm:create_payload();
        -- payload_builder:clear();
        -- -- TODO select appropriate loyalty reward
        -- if i == 1 then
        --     payload_builder:character_loyalty_adjustment(char, 2);
        -- elseif i == 2 then
        --     payload_builder:character_loyalty_adjustment(char, 1);
        -- end
        -- dbldr:add_choice_payload(choice_keys[i], payload_builder);

        -- payload_builder = cm:create_payload();
        payload_builder:clear();
        local added_text = payload_builder:text_display(event_full_key[i]);
        -- local added_text = payload_builder:text_display("should fail");
        -- payload_builder:text_display("loyalty_change");
        local added_payload = dbldr:add_choice_payload(choice_keys[i], payload_builder);
        li_mor:log("payload option " .. event_full_key[i] .. " payload added " .. tostring(added_payload) .. " text added " .. tostring(added_text));
    end

    cm:launch_custom_dilemma_from_builder(dbldr, mor:faction());
end

local function handle_low_loyalty_lords(context)
    local mor = li_mor:get_char();
    if mor == nil or context:faction():name() ~= mor:faction():name() then
        return;
    end

    -- loop through characters of the faction and lookup characters who have low loyalty
    local characters = mor:faction():character_list();
    for i = 0, characters:num_items() - 1 do
        local char = characters:item_at(i);
        -- only care about active generals
        if char:has_military_force() and char:rank() > 0 then
            local char_key = lord_subtype_to_key[char:character_subtype_key()];
            local loyalty = char:loyalty();
            local random_event_chance = loyalty_to_random_chance[loyalty];
            li_mor:log("rank " .. char:rank() .. " " ..
                common.get_localised_string(char:get_forename()) ..
                " subtype " .. char:character_subtype_key() .. " loyalty " .. loyalty);
            if char_key ~= nil and loyalty < loyalty_threshold then
                local rand = cm:random_number(100, 1);
                li_mor:log("rolled " .. tostring(rand) .. " against loyalty event chance " .. random_event_chance);
                if rand < random_event_chance then
                    -- handle at most 1 character's low loyalty per turn
                    generate_low_loyalty_dilemma(char);
                    return;
                end
            end
        end
    end
end


-- local function listen_to_low_loyalty_lords()
--     core:add_listener(
--         "FactionTurnStartMorathiLoyalty",
--         "FactionTurnStart",
--         true,
--         handle_low_loyalty_lords,
--         true
--     );
-- end

-- local function broadcast_self()
--     local mor = li_mor:get_char();
--     if mor == nil then
--         return;
--     end

--     li_mor:persistent_initialization_register(1, listen_to_low_loyalty_lords);
-- end

-- cm:add_first_tick_callback(function() broadcast_self() end);
