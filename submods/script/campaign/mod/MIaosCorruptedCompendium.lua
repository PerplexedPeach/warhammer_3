function pp_log(text)
  -- TODO don't always flush to file
  if type(text) == "string" then
    local file = io.open("pp_log.txt", "a")
    file:write(tostring(cm:turn_number()) .. " " .. text .. "\n")
    file:close()
  end
end

-- we will be adding a bunch of dilemmas that we only want to fire at most once
-- to do that we'll need a bunch of saved values to store whether we've fired them or not
-- since we're lazy, let's just use the dilemma names itself as the stored value

-- let's also define some reused variables so we can change it all at once
local faction_name = "wh3_main_cth_the_northern_provinces";
-- we don't want multiple events firing on the same turn
local min_turn_between_events = 1;
local absurdly_high_turn_number = 500;

-- next we'll want to define how to make our listeners, since we won't be creating the listeners directly
-- we give up the task of creating our listeners to the main framework so it can do it at the right time
local function setup_banner_getting_via_dilemma(dilemma_name, chance_of_random_firing, min_turn_refire, additional_checks)
  -- for events that should only fire once, we'll use an absurd turn limit so that it should never fire more than once
  -- the 'or' keyword will only use the second value if the first value evaluates to false (if you don't pass it in)
  local min_turn_refire = min_turn_refire or absurdly_high_turn_number;
  core:add_listener(
    "Maio_Compendium_Corruption_Listener" .. dilemma_name,
    "FactionTurnStart",
    function(context)
      -- note that we no longer have to check for stage because we're guaranteed to be at the correct stage or later
      return context:faction():name() == faction_name;
    end,

    function(context)
      -- note also that we check that it's a human playing that faction; AI doesn't do anything with dilemmas
      -- you might want to do something like randomly accepting if it's the AI
      if context:faction():is_human() then
        -- get the last turn we've fired this event
        -- it will return nil if we haven't fired it yet, so give it a numerical value in that case
        -- using -high turn number ensures that our current turn, even if it's 0 is fine for it to fire
        local last_turn_fired = cm:get_saved_value(dilemma_name) or -absurdly_high_turn_number;
        local turn = cm:turn_number();
        -- not enough turns between last turn firing and current turn
        if last_turn_fired + min_turn_refire > turn then
          return
        end
        -- roll a random number to decide if the event should fire or not
        local rand = cm:random_number(100, 1);
        if rand > chance_of_random_firing then
          return
        end
        -- additional checks for this particular dilemma
        if additional_checks ~= nil and not additional_checks(context) then
          return
        end

        -- let's avoid firing multiple events on the same turn
        if Li_miaoying_turns_since_last_event() < min_turn_between_events then
          return
        end
        pp_log("firing " .. dilemma_name);
        cm:trigger_dilemma(Get_miaoying():faction():name(), dilemma_name);
        -- tell the framework that an event happened so that it'll update the timer
        Li_miaoying_fire_submod_event(dilemma_name);
        -- save the fact that we've fired this event
        cm:set_saved_value(dilemma_name, turn);
      end
    end,
    true
  );
end

cm:add_first_tick_callback(function()
  -- here we're going to tell the framework to call our setup whenever we're at or past a certain stage
  Li_miaoying_persistent_initialization_register(2, function()
    -- setup our banner dilemma at stage 2 or after with a 50% chance of randomly firing if we don't have it already
    setup_banner_getting_via_dilemma("Stained_Banner_Get", 50);
    -- if an additiona conditional do 'setup_banner_getting_via_dilemma("Stained_Banner_Get", 50, function context return true; end);'
  end);

  Li_miaoying_persistent_initialization_register(4, function()
    setup_banner_getting_via_dilemma("DragonMare_Banner_Get", 25);
  end);

  Li_miaoying_persistent_initialization_register(5, function()
    setup_banner_getting_via_dilemma("Pantie_Banner_Get", 15);
  end);

  -- kind of abusing the system here since the tutor event chain is different from the banners, but we can use it for now
  Li_miaoying_persistent_initialization_register(1, function()
    setup_banner_getting_via_dilemma("Personal_Tutor_Start", 40);
  end);
end);
