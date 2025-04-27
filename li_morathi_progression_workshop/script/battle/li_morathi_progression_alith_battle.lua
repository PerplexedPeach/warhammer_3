load_script_libraries();
local message = "morathi_alith_battle";
local gb = generated_battle:new(
                false,                                      -- screen starts black
                false,                                      -- prevent deployment for player
                false,                                                 -- prevent deployment for ai
                nil,
                true                                                  -- debug mode
);
bm:enable_cinematic_ui(false, true, false)

--------------------------------
-------ENEMY ARMY DEFINED-------

local ga_ai = gb:get_army(gb:get_non_player_alliance_num(), message);

gb:queue_help_on_message(message, message, 1500, 2000, 3000);
gb:message_on_time_offset(message, 2000);