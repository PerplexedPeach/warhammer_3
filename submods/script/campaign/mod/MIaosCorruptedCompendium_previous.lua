function seu_log(text)
  -- TODO don't always flush to file
  if type(text) == "string" then
      local file = io.open("seu_log.txt", "a")
      file:write(tostring(cm:turn_number()) .. " " .. text .. "\n")
      file:close()
  end
end
cm:add_first_tick_callback(function()
                         
local dilemma_name = "DragonMare_Banner_Get";
   
local dilemma_faction = "wh3_main_cth_the_northern_provinces";

core:add_listener(
  "Maio_Compendium_Corruption_Listener+Pantie_Banner",
  "FactionTurnStart",
  function(context) 
    return  Li_miaoying_get_stage() == 2 and context:faction():name() == "wh3_main_cth_the_northern_provinces"
  end,

  function(context)
          --  code to execute
    seu_log("please work...");
     cm:trigger_dilemma(Get_miaoying():faction():name(), "Stained_Banner_Get");             
  end,
  false  -- false = only fires the once , true fires infinitely, use remove_listener on a count for in between 
);
                          
                          core:add_listener(
  "Maio_Compendium_Corruption_Listener+Banner2",
  "FactionTurnStart",
  function(context) 
    return  Li_miaoying_get_stage() == 4 and context:faction():name() == "wh3_main_cth_the_northern_provinces"
  end,

  function(context)
          --  code to execute
    seu_log("please work...");
     cm:trigger_dilemma(Get_miaoying():faction():name(), "DragonMare_Banner_Get");             
  end,
  false  -- false = only fires the once , true fires infinitely, use remove_listener on a count for in between 
);
  
                            
                          core:add_listener(
  "Maio_Compendium_Corruption_Listener+Banner3",
  "FactionTurnStart",
  function(context) 
    return  Li_miaoying_get_stage() == 5 and context:faction():name() == "wh3_main_cth_the_northern_provinces"
  end,

  function(context)
          --  code to execute
    seu_log("please work...");
     cm:trigger_dilemma(Get_miaoying():faction():name(), "Pantie_Banner_Get");             
  end,
  false  -- false = only fires the once , true fires infinitely, use remove_listener on a count for in between 
);
    
                          core:add_listener(
  "Maio_Compendium_Corruption_Tutor_Start",
  "FactionTurnStart",
  function(context) 
    return  Li_miaoying_get_stage() == 3 and context:faction():name() == "wh3_main_cth_the_northern_provinces" 
  end,

  function(context)
          --  code to execute
    seu_log("please work...");
     cm:trigger_dilemma(Get_miaoying():faction():name(), "Personal_Tutor_Start");             
  end,
  false  -- false = only fires the once , true fires infinitely, use remove_listener on a count for in between 
);
                          
                          
end);

-- gap
-- gap 
-- gap
--
--wh3_main_mis_gen_raze_sack_settlement_cth
--cm:trigger_mission(Get_miaoying():faction():name(),"miao_ying_personal_tutor",True);
--cm:trigger_dilemma(Get_miaoying():faction():name(),"Personal_Tutor_Lvl1_Massage_Random",True);
--cm:trigger_mission(Get_miaoying():faction():name(),"wh3_main_mis_gen_raze_sack_settlement_cth",True);
--  cm:trigger_dilemma(Get_miaoying():faction():name(), "DragonMare_Banner_Get");
--local function advance_stage()
--Li_miaoying_set_stage(3);
--    cm:force_add_trait("character_cqi:"..Get_miaoying():cqi(), trait_name, 1);
--Li_test_trigger_progression(context, is_human)
--    Li_miaoying_set_progression_cooldown_base(3);
--    Li_miaoying_set_progression_cooldown_left(2);
--    Li_miaoying_set_stage(3);
--console_print(Li_miaoying_set_stage())
--end

--local function progression_callback(context, is_human)
  -- for third stage, progression can get more interesting

  -- dilemma for choosing to accept or reject the gift
--  if is_human then
  --    Mod_log("Human progression, trigger dilemma " .. dilemma_name);
    --  cm:trigger_dilemma(Get_miaoying():faction():name(), dilemma_name);
     -- local delimma_choice_listener_name = dilemma_name .. "_DilemmaChoiceMadeEvent";
      -- using persist = true even for a delimma event in case they click on another delimma first
     -- core:add_listener(
       --   delimma_choice_listener_name,
         -- "DilemmaChoiceMadeEvent",
         -- function(context)
          --    return context:dilemma() == dilemma_name;
         -- end,
         -- function(context)
           --   local choice = context:choice();
             -- Mod_log(dilemma_name .. " choice " .. tostring(choice));
              -- if choice == 0 then
             --     advance_stage()
             -- end
             -- core:remove_listener(delimma_choice_listener_name);
         -- end,
        --  true
   --   );
--  else
      -- if it's not the human
  --    local rand = cm:random_number(100, 1);
    --  Mod_log("AI rolled " .. tostring(rand) .. " against chance to corrupt " .. li_ai_corruption_chance)
   --   if rand <= li_ai_corruption_chance then
     --     advance_stage()
    --  end
--  end
-- end

-- stubs in case we don't have the progression framework
-- local function get_miaoying_all()
--   local factions_to_consider = {"wh3_main_cth_the_western_provinces"};
--  for j = 1, #factions_to_consider do
--       local characters = cm:get_faction(factions_to_consider[j]):character_list();
--      for i = 0, characters:num_items() - 1 do
--          local character = characters:item_at(i);
--           local is_miao = character:character_subtype(miao_subtype);
--          if is_miao then
--               return character;
--            end
  --    end
--    end
--    return nil;
--end

--local function get_miaoying()
--  local faction = cm:get_faction(miao_faction);
  -- miao will always be faction leader, so only need to consider when the faction no longer exists
--   if faction:is_null_interface() then
--       return get_miaoying_all()
--   end
--   return faction:faction_leader();
--end

-- TODO add more interesting hooks (condition before able to progress to the next stage or this stage?)
--local function broadcast_self()
 -- command script will define API to register stage
--   if is_nil(Li_miaoying_stage_register) then
      -- if it's not defined, then we don't have a command script so we will just reskin everything
      -- apply reskin
--      cm:add_character_model_override(get_miaoying(), "wh3_main_art_set_cth_miao_ying_ballet");
--  else
--       local name = "li_miaoying_ballet"; -- use as the key for everything
--       local stage = 3;
--       Li_miaoying_stage_register(name, stage, progression_callback)
--   end
--end

--cm:add_first_tick_callback(function() broadcast_self() end);