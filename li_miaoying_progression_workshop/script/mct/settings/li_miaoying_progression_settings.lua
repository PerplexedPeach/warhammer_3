local mct = get_mct();
local cf = mct:get_mod_by_key("li_cf");
local this_section = cf:add_new_section("miao");
-- TODO consider character specific cooldowns
-- local cd_option = cf:add_new_option("progression_cooldown_miaoying", "slider")
-- cd_option:set_default_value(3);
-- cd_option:slider_set_min_max(0, 5);
-- cd_option:slider_set_step_size(1);

-- how much progression is gained from battle
local progress_from_battle = cf:add_new_option("miao_progress_battle", "slider")
progress_from_battle:set_default_value(100);
progress_from_battle:slider_set_min_max(0, 100);
progress_from_battle:slider_set_step_size(5);

-- how long pregnancy lasts
local progress_from_battle = cf:add_new_option("miao_pregnancy_period", "slider")
progress_from_battle:set_default_value(3);
progress_from_battle:slider_set_min_max(1, 5);
progress_from_battle:slider_set_step_size(1);

-- gaining from diplomacy
local progress_from_nap = cf:add_new_option("miao_progress_nap", "slider")
progress_from_nap:set_default_value(5);
progress_from_nap:slider_set_min_max(0, 20);
progress_from_nap:slider_set_step_size(5);

local progress_from_trade = cf:add_new_option("miao_progress_trade", "slider")
progress_from_trade:set_default_value(5);
progress_from_trade:slider_set_min_max(0, 20);
progress_from_trade:slider_set_step_size(5);

local progress_from_ally = cf:add_new_option("miao_progress_ally", "slider")
progress_from_ally:set_default_value(10);
progress_from_ally:slider_set_min_max(0, 20);
progress_from_ally:slider_set_step_size(5);

local progress_from_ally = cf:add_new_option("miao_progress_vassal", "slider")
progress_from_ally:set_default_value(15);
progress_from_ally:slider_set_min_max(0, 30);
progress_from_ally:slider_set_step_size(5);

local option = cf:add_new_option("miao_intro_quest_turn", "slider")
option:set_default_value(10);
option:slider_set_min_max(1, 30);
option:slider_set_step_size(1);

option = cf:add_new_option("miao_ai_corruption_per_turn", "slider")
option:set_default_value(10);
option:slider_set_min_max(0, 30);
option:slider_set_step_size(5);

option = cf:add_new_option("miao_human_corruption_per_turn", "slider")
option:set_default_value(5);
option:slider_set_min_max(0, 30);
option:slider_set_step_size(1);