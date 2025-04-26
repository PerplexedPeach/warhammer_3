local mct = get_mct();
local cf = mct:get_mod_by_key("li_cf");
local this_section = cf:add_new_section("mor");
-- TODO consider character specific cooldowns
-- local cd_option = cf:add_new_option("progression_cooldown_miaoying", "slider")
-- cd_option:set_default_value(3);
-- cd_option:slider_set_min_max(0, 5);
-- cd_option:slider_set_step_size(1);

-- how much progression is gained from battle
local option = cf:add_new_option("mor_min_landmark_for_quest", "slider")
option:set_default_value(2);
option:slider_set_min_max(1, 3);
option:slider_set_step_size(1);

option = cf:add_new_option("mor_sub_gain", "slider")
option:set_default_value(1);
option:slider_set_min_max(0, 3);
option:slider_set_step_size(1);

option = cf:add_new_option("mor_dom_gain", "slider")
option:set_default_value(1);
option:slider_set_min_max(0, 3);
option:slider_set_step_size(1);

option = cf:add_new_option("mor_sok_donation", "slider")
option:set_default_value(10000);
option:slider_set_min_max(0, 50000);
option:slider_set_step_size(1000);

option = cf:add_new_option("mor_teclis_donation", "slider")
option:set_default_value(50000);
option:slider_set_min_max(0, 100000);
option:slider_set_step_size(5000);