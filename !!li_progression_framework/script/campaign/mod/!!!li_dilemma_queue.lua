
function Mod_log(text)
    -- TODO don't always flush to file
    if type(text) == "string" then
        local file = io.open("li_log.txt", "a")
        file:write(tostring(cm:turn_number()) .. " " .. text .. "\n")
        file:close()
    end
end

---@class LiQueue
LiQueue = {};
---Priority queue for storing dilemmas
---@param name string name of the queue for saving and loading; should be unique
---@return LiQueue
function LiQueue:new(name)
    local self = {} ---@class LiQueue
    setmetatable(self, {
        __index = LiQueue
    })
    self.name = name;
    self.queue = {};
    return self;
end

---Push a dilemma to the queue with a specified delay
---@param dilemma string dilemma key in database to trigger
---@param delay number delay in turns before the dilemma is triggered, 0 means to fire asap, will be incremented until it does not collide with another pushed dilemma. Can also use negative numbers to push it to the front of the queue such as -1 will be before 0.
---@param faction_name string faction triggering the dilemma
function LiQueue:push(dilemma, delay, faction_name)
    local entry = { dilemma = dilemma, faction_name = faction_name, delay = delay };
    -- look for where to insert the entry in the queue
    local insert_index = #self.queue + 1;
    for i = 1, #self.queue do
        if self.queue[i].delay > delay then
            insert_index = i;
            break;
        end
    end
    -- insert the entry into the queue
    table.insert(self.queue, insert_index, entry);
    self:save();
end

function LiQueue:log(message)
    Mod_log(self.name .. " " .. message);
end

function LiQueue:pop()
    -- remove the first entry in the queue and return it
    if #self.queue > 0 then
        local entry = self.queue[1];
        table.remove(self.queue, 1);
        self:save();
        return entry;
    end
    return nil;
end

---Check if the dilemma is in the queue and return the number of turns until it fires, or -1 if it is not in the queue
---@param dilemma string
---@return integer
function LiQueue:turns_until(dilemma)
    -- its listed delay is its priority, but there could be multiple dilemmas with the same delay so it depends on insertion order
    for i = 1, #self.queue do
        if self.queue[i].dilemma == dilemma then
            -- the maximum of the delay and the turn
            return math.max(self.queue[i].delay, i);
        end
    end
    return -1;
end

function LiQueue:process_turn()
    -- decrement the delay of all entries in the queue
    for i = 1, #self.queue do
        self.queue[i].delay = self.queue[i].delay - 1;
    end
    -- fire the first entry in the queue if it is ready
    if #self.queue > 0 and self.queue[1].delay <= 0 then
        local entry = self:pop();
        assert(entry ~= nil, "Entry should not be nil");
        -- fire the dilemma
        cm:trigger_dilemma(entry.faction_name, entry.dilemma);
        -- return true to indicate that a dilemma was fired
        return entry;
    end
    return nil;
end

function LiQueue:save()
    cm:set_saved_value(self.name, self.queue);
    -- self:log("Saving with " .. #self.queue .. " entries");
end

function LiQueue:load()
    local queue = cm:get_saved_value(self.name);
    if queue ~= nil then
        self.queue = queue;
    else
        self.queue = {};
    end
    -- self:log("Loading for " .. tostring(#self.queue) .. " entries");
end