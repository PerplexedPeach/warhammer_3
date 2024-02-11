local kat_faction = "wh3_main_ksl_the_ice_court";
local kat_subtype = "wh3_main_ksl_katarin";
local LI_KAT_MAIN_EVENT = "ScriptEventKatarinCorruptEvent"
local confed_factions = { "wh3_main_ksl_the_great_orthodoxy", "wh3_main_ksl_kislev" };
local kat_art_set = "wh3_main_art_set_ksl_katarin";
local names_name_id = "150649774";
li_kat = LiProgression:new("katarin", kat_faction, kat_subtype, kat_art_set, LI_KAT_MAIN_EVENT, confed_factions, names_name_id);

cm:add_first_tick_callback(function() li_kat:initialize() end);
