local this_stage = 5;
CFSettings.miao[this_stage] = {
    dilemma_name = "li_corrupt_body_corset",
    trait_name = "li_trait_corrupt_body",
    this_stage = this_stage,
    ai_corruption_chance = 80
};


local function broadcast_self()
    local name = "corset"; -- use as the key for everything
    li_miao:stage_register(name, this_stage,
        function(context, is_human)
            li_miao:simple_progression_callback(context, is_human, CFSettings.miao[this_stage])
        end);
end

cm:add_first_tick_callback(function() broadcast_self() end);
