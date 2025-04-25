local mct = get_mct();
local cf = mct:get_mod_by_key("li_cf");
local this_section = cf:add_new_section("li_kat");

local option = cf:add_new_option("kat_heart_of_winter_corruption", "slider")
option:set_default_value(50);
option:slider_set_min_max(0, 100);
option:slider_set_step_size(5);

option = cf:add_new_option("kat_events_to_progress_second", "slider")
option:set_default_value(3);
option:slider_set_min_max(1, 3);
option:slider_set_step_size(1);

option = cf:add_new_option("kat_events_to_progress_third", "slider")
option:set_default_value(3);
option:slider_set_min_max(1, 3);
option:slider_set_step_size(1);

option = cf:add_new_option("kat_events_to_progress_fourth", "slider")
option:set_default_value(3);
option:slider_set_min_max(1, 3);
option:slider_set_step_size(1);

option = cf:add_new_option("kat_daemonize_decay_per_turn", "slider")
option:set_default_value(1);
option:slider_set_min_max(0, 5);
option:slider_set_step_size(1);

option = cf:add_new_option("kat_daemonize_second_tier_threshold", "slider")
option:set_default_value(4);
option:slider_set_min_max(1, 10);
option:slider_set_step_size(1);
