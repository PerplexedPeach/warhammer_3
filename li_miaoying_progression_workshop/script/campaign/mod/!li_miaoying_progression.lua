
local miao_faction = "wh3_main_cth_the_northern_provinces";
local miao_subtype = "wh3_main_cth_miao_ying";
local LI_MIAOYING_MAIN_EVENT = "ScriptEventMiaoYingCorruptEvent"

local confed_factions = { "wh3_main_cth_the_western_provinces" };
local miao_art_set = "wh3_main_art_set_cth_miao_ying";
local names_name_id = "190911577";

---@type LiProgression
li_miao = LiProgression:new("miaoying", miao_faction, miao_subtype, miao_art_set, LI_MIAOYING_MAIN_EVENT, confed_factions, names_name_id);

cm:add_first_tick_callback(function() li_miao:initialize() end);


-- hooks where each stage gets callback
-- hook into losing combat against Slaanesh force (later events can check against )
core:add_listener(
    "li_miaoying_slaanesh_combat_loss_listener",
    "CharacterCompletedBattle",
    function(context)
        local pb = cm:model():pending_battle();
        -- ignore any without 2 parties
        if pb:defender():is_null_interface() or pb:attacker():is_null_interface() then
            return false;
        end
        local miao_attacker, miao_defender = li_miao:attacker_or_defender();
        -- can also voluntarily take gift even if you win
        if miao_attacker then
            li_miao:log("Miao attacked slaanesh force");
            local opponent_won = pb:defender_won();
            local opp_fac = pb:defender():faction();
            local opponent_slaanesh = li_miao:opponent_slaanesh(opp_fac);
            li_miao:log("Opponent won " .. tostring(opponent_won));
            li_miao:log("Opponent is Slaanesh " ..
                tostring(opponent_slaanesh) .. " culture " .. opp_fac:culture() .. " name " .. opp_fac:name());
            return opponent_slaanesh;
        elseif miao_defender then
            li_miao:log("Miao defended against slaanesh force");
            local opponent_won = pb:attacker_won();
            local opp_fac = pb:attacker():faction();
            local opponent_slaanesh = li_miao:opponent_slaanesh(opp_fac);
            li_miao:log("Opponent won " .. tostring(opponent_won));
            li_miao:log("Opponent is Slaanesh " ..
                tostring(opponent_slaanesh) .. " culture " .. opp_fac:culture() .. " name " .. opp_fac:name());
            return opponent_slaanesh;
        else
            return false;
        end
    end,
    function(context)
        li_miao:modify_progress_percent(CFSettings.miao_progress_battle, "battle");
    end,
    true
);
-- hook into completing the Slaanesh realm
core:add_listener(
    "li_miaoying_complete_slaanesh_realm_listener",
    "MissionSucceeded",
    function(context)
        local mission_faction = context:faction();
        local faction_name = mission_faction:name();
        local mission = context:mission():mission_record_key();
        return faction_name == miao_faction and mission:starts_with("wh3_main_survival_") and mission:find("slaanesh");
    end,
    function(context)
        li_miao:modify_progress_percent(100, "survival mission success");
    end,
    true
);

-- hook for taking a Slaanesh gift, happening the turn after
local last_gift_taken_turn_name = "li_miaoying_take_slaanesh_gift_turn";
core:add_listener(
    "li_miaoying_take_slaanesh_gift_listener",
    "FactionTurnStart",
    true,
    function(context)
        -- only should work if she's the one entering the rift, which she can only do if she's the faction leader of her original faction
        if context:faction():name() ~= miao_faction then
            return
        end
        local miao = li_miao:get_char();
        if miao == nil then
            return
        end
        local taken_gift = cm:get_saved_value("slaanesh_realm_offer_taken_" .. miao:faction():name());
        if not taken_gift then
            return
        end
        -- prevent triggering more than once after taking a gift
        local last_turn_gift_taken = cm:get_saved_value(last_gift_taken_turn_name);
        if last_turn_gift_taken == nil or (last_turn_gift_taken + rifts_duration + 1) > cm:turn_number() then
            li_miao:modify_progress_percent(100, "taken slaanesh gift");
            cm:set_saved_value(last_gift_taken_turn_name, cm:turn_number());
        end
    end,
    true
);
