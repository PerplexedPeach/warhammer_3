local this_stage = 1;
CFSettings.miao[this_stage] = {
    dilemma_name = "li_offer_corrupt_boots", 
    trait_name = "li_trait_corrupt_boots",
    this_stage = this_stage, 
    ai_corruption_chance = 30
};


local function broadcast_self()
    local name = "scale"; -- use as the key for everything
    li_miao:stage_register(name, this_stage,
    function(context, is_human)
        li_miao:simple_progression_callback(context, is_human, CFSettings.miao[this_stage])
    end);

    li_miao:add_listener(
        "MiaoEnterNameChange",
        function(context)
            return context:type() == "enter";
        end,
        function(context)
            li_miao:change_title(context:stage());
            li_miao:log("Adding diplomatic bonuses to Slaanesh forces to reflect their change in strategy in dealing with you");
            local miao = li_miao:get_char();
            if miao ~= nil then
                cm:apply_dilemma_diplomatic_bonus(miao:faction():name(), "wh3_dlc20_chs_sigvald", 5);
                cm:apply_dilemma_diplomatic_bonus(miao:faction():name(), "wh3_dlc20_chs_azazel", 5);
            end
        end,
        true
    );
end

cm:add_first_tick_callback(function() broadcast_self() end);
