local trait_name = "li_trait_corrupt_body";
local dilemma_name = "li_corrupt_body_piercing";
local li_ai_corruption_chance = 70;
local this_stage = 4;

local function stage_enter_callback()
    li_miao:change_title(this_stage);
end

local function progression_callback(context, is_human)
    -- dilemma for choosing to accept or reject the gift
    if is_human then
        li_miao:log("Human progression, trigger dilemma " .. dilemma_name);
        cm:trigger_dilemma(li_miao:get_char():faction():name(), dilemma_name);
        local delimma_choice_listener_name = dilemma_name .. "_DilemmaChoiceMadeEvent";
        -- using persist = true even for a delimma event in case they click on another delimma first
        core:add_listener(
            delimma_choice_listener_name,
            "DilemmaChoiceMadeEvent",
            function(context)
                return context:dilemma() == dilemma_name;
            end,
            function(context)
                local choice = context:choice();
                li_miao:log(dilemma_name .. " choice " .. tostring(choice));
                if choice == 0 then
                    li_miao:advance_stage(trait_name, this_stage);
                else
                    li_miao:fire_corrupt_event("reject", this_stage);
                end
                core:remove_listener(delimma_choice_listener_name);
            end,
            true
        );
    else
        -- if it's not the human
        local rand = cm:random_number(100, 1);
        li_miao:log("AI rolled " .. tostring(rand) .. " against chance to corrupt " .. li_ai_corruption_chance)
        if rand <= li_ai_corruption_chance then
            li_miao:advance_stage(trait_name, this_stage);
        else
            li_miao:fire_corrupt_event("reject", this_stage);
        end
    end
end

-- TODO add more interesting hooks (condition before able to progress to the next stage or this stage?)
local function broadcast_self()
    -- command script will define API to register stage
    local name = "bare"; -- use as the key for everything
    li_miao:stage_register(name, this_stage, progression_callback, stage_enter_callback);
end

cm:add_first_tick_callback(function() broadcast_self() end);