local mct = get_mct();
local cf = mct:register_mod("li_cf");
-- cooldown between each progression stage
local cd_option = cf:add_new_option("progression_cooldown", "slider")
cd_option:set_default_value(3);
cd_option:slider_set_min_max(0, 5);
cd_option:slider_set_step_size(1);
