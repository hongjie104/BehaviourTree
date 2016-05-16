local SUCCESS = "SUCCESS"
local FAILED = "FAILED"
local READY = "READY"
local RUNNING = "RUNNING"

local BT = {}

BT.SUCCESS = SUCCESS
BT.FAILED = FAILED
BT.READY = READY
BT.RUNNING = RUNNING

BT.GetTime = function()
    return os.clock()
end

BT.iskindof = function(cls, name)
    if cls.__cname == name then
        return true
    end

    if not cls.__supers then
        return false
    end

    for _,v in ipairs(cls.__supers) do
        local bvalue = BT.iskindof(v, name)
        if bvalue == true then
            return true
        end
    end

    return false
end

---------------------------------------------------------------------------------------

local BehaviourTree = class("BehaviourTree", function(root)
    local instance = {}
    instance.root = root
    return instance
end)

function BehaviourTree:SetOwner(owner)
    self.owner = owner

    if self.root and self.root.SetOwner and type(self.root.SetOwner) then
        self.root:SetOwner(owner)
    end
end

function BehaviourTree:GetOwner()
    return self.owner
end

function BehaviourTree:ForceUpdate()
    self.forceupdate = true
end

function BehaviourTree:Update()
    local sleeptime = self.root:GetTreeSleepTime()

    if sleeptime and sleeptime > 0 then
        print("BehaviourTree:Update", sleeptime)
    end

    if not sleeptime or sleeptime == 0 then
        self.root:Visit()
        self.root:SaveStatus()
        self.root:Step()
    end

    self.forceupdate = false
end

function BehaviourTree:Reset()
    self.root:Reset()
end

function BehaviourTree:Stop()
    self.root:Stop()
end

function BehaviourTree:Suspend()
    self.root:Suspend()
end

function BehaviourTree:Restart()
    self.root:Restart()
end

function BehaviourTree:GetSleepTime()
    if self.forceupdate then
        return 0
    end
    
    return self.root:GetTreeSleepTime()
end

function BehaviourTree:__tostring()
    return self.root:GetTreeString()
end

BT.BehaviourTree = BehaviourTree

---------------------------------------------------------------------------------------

local BehaviourNode = class("BehaviourNode", function(children)
    local instance = {}

    instance.name = name or ""
    instance.children = children
    instance.status = READY
    instance.lastresult = READY
    instance.owner = nil
    if children then
        for i,k in pairs(children) do
            k.parent = instance
        end
    end

    return instance
end)

function BehaviourNode:SetOwner(owner)
    self.owner = owner

    if self.children then
        for k,v in pairs(self.children) do
            if v and v.SetOwner and type(v.SetOwner) == "function" then
                v:SetOwner(owner)
            end
        end
    end
end

function BehaviourNode:GetOwner()
    return self.owner
end

function BehaviourNode:DoToParents(fn)
    if self.parent then
        fn(self.parent)
        return self.parent:DoToParents(fn)
    end
end

function BehaviourNode:GetTreeString(indent)
    indent = indent or ""
    local str = string.format("%s%s>%2.2f\n", indent, self:GetString(), self:GetTreeSleepTime() or 0)
    if self.children then
        for k, v in ipairs(self.children) do
            str = str .. v:GetTreeString(indent .. "   >")
        end
    end
    return str
end

function BehaviourNode:DBString()
    return ""
end

function BehaviourNode:Sleep(t)
    self.nextupdatetime = BT.GetTime() + t 
end

function BehaviourNode:GetSleepTime()
    
    -- if self.status == RUNNING and not self.children and not self:is_a(ConditionNode) then
    if self.status == RUNNING and not self.children and not BT.iskindof(self, "ConditionNode") then
        if self.nextupdatetime then
            local time_to = self.nextupdatetime - BT.GetTime()
            if time_to < 0 then
                time_to = 0
            end
            return time_to
        end
        return 0
    end
    
    return nil
end

function BehaviourNode:GetTreeSleepTime()
    
    local sleeptime = nil
    if self.children then
        for k,v in ipairs(self.children) do
            if v.status == RUNNING then
                local t = v:GetTreeSleepTime()
                if t and (not sleeptime or sleeptime > t) then
                    sleeptime = t
                end
            end
        end
    end
    
    local my_t = self:GetSleepTime()
    
    if my_t and (not sleeptime or sleeptime > my_t) then
        sleeptime = my_t
    end
    
    return sleeptime
end

function BehaviourNode:GetString()
    local str = ""
    if self.status == RUNNING then
        str = self:DBString()
    end
    return string.format([[%s - %s <%s> (%s)]], self.name, self.status or "UNKNOWN", self.lastresult or "?", str)
end

function BehaviourNode:Visit()
    self.status = FAILED
end

function BehaviourNode:SaveStatus()
    self.lastresult = self.status
    if self.children then
        for k,v in pairs(self.children) do
            v:SaveStatus()
        end
    end
end

function BehaviourNode:Step()
    if self.status ~= RUNNING then
        self:Reset()
    elseif self.children then
        for k, v in ipairs(self.children) do
            v:Step()
        end
    end
end

function BehaviourNode:Reset()
    if self.status ~= READY then
        self.status = READY
        if self.children then
            for idx, child in ipairs(self.children) do
                child:Reset()
            end
        end
    end
end

function BehaviourNode:Stop()
    if self.OnStop then
        self:OnStop()
    end
    if self.children then
        for idx, child in ipairs(self.children) do
            child:Stop()
        end
    end
end

function BehaviourNode:Suspend()
    if self.children then
        for k,v in pairs(self.children) do
            v:Suspend()
        end
    end
end

function BehaviourNode:Restart()
    if self.children then
        for k,v in pairs(self.children) do
            v:Restart()
        end
    end
end

BT.BehaviourNode = BehaviourNode

---------------------------------------------------------------------------------------

local DecoratorNode = class("DecoratorNode", BehaviourNode, function(child)
   return BehaviourNode.__create({child})
end)

BT.DecoratorNode = DecoratorNode

---------------------------------------------------------------------------------------

local ConditionNode = class("ConditionNode", BehaviourNode, function(func)
    local instance = BehaviourNode.__create()
    instance.fn = func
    return instance
end)

function ConditionNode:Visit()
    if self.fn() then
        self.status = SUCCESS
    else
        self.status = FAILED
    end
end

BT.ConditionNode = ConditionNode

---------------------------------------------------------------------------------------

local ConditionWaitNode = class("ConditionWaitNode", BehaviourNode, function(func)
    local instance = BehaviourNode.__create()
    instance.fn = func
    return instance
end)

function ConditionWaitNode:Visit()
    if self.fn() then
        self.status = SUCCESS
    else
        self.status = RUNNING
    end
end

BT.ConditionWaitNode = ConditionWaitNode

---------------------------------------------------------------------------------------

local ActionNode = class("ActionNode", BehaviourNode, function(action)
    local instance = BehaviourNode.__create()
    instance.action = action
    return instance
end)

function ActionNode:Visit()
    self.action()
    self.status = SUCCESS
end

BT.ActionNode = ActionNode

---------------------------------------------------------------------------------------

local WaitNode = class("WaitNode", BehaviourNode, function(time)
    local instance = BehaviourNode.__create()
    instance.wait_time = time
    return instance
end)

function WaitNode:DBString()
    local w = self.wake_time - BT.GetTime()
    return string.format("%2.2f", w)
end

function WaitNode:Visit()
    local current_time = BT.GetTime() 
    
    if self.status ~= RUNNING then
        self.wake_time = current_time + self.wait_time
        self.status = RUNNING
    end
    
    if self.status == RUNNING then
        if current_time >= self.wake_time then
            self.status = SUCCESS
        else
            -- self:Sleep(current_time - self.wake_time)
            self:Sleep(self.wake_time - current_time)
        end
    end
    
end

BT.WaitNode = WaitNode

---------------------------------------------------------------------------------------

local SequenceNode = class("SequenceNode", BehaviourNode, function(children)
    local instance = BehaviourNode.__create(children)
    instance.idx = 1
    return instance
end)

function SequenceNode:DBString()
    return tostring(self.idx)
end


function SequenceNode:Reset()
    -- self._base.Reset(self)
    -- self.super.Reset(self)

    if self.status ~= READY then
        self.status = READY
        if self.children then
            for idx, child in ipairs(self.children) do
                child:Reset()
            end
        end
    end
    self.idx = 1
end

function SequenceNode:Visit()
    
    if self.status ~= RUNNING then
        self.idx = 1
    end
    
    local done = false
    while self.idx <= #self.children do
    
        local child = self.children[self.idx]
        child:Visit()
        if child.status == RUNNING or child.status == FAILED then
            self.status = child.status
            return
        end
        
        self.idx = self.idx + 1
    end 
    
    self.status = SUCCESS
end

BT.SequenceNode = SequenceNode

---------------------------------------------------------------------------------------

local SelectorNode = class("SelectorNode", BehaviourNode, function(children)
    local instance = BehaviourNode.__create(children)
    instance.idx = 1
    return instance
end)

function SelectorNode:DBString()
    return tostring(self.idx)
end


function SelectorNode:Reset()
    -- self._base.Reset(self)
    -- self.super.Reset(self)
    
    if self.status ~= READY then
        self.status = READY
        if self.children then
            for idx, child in ipairs(self.children) do
                child:Reset()
            end
        end
    end
    self.idx = 1
end

function SelectorNode:Visit()
    
    if self.status ~= RUNNING then
        self.idx = 1
    end
    
    local done = false
    while self.idx <= #self.children do
    
        local child = self.children[self.idx]
        child:Visit()
        if child.status == RUNNING or child.status == SUCCESS then
            self.status = child.status
            return
        end
        
        self.idx = self.idx + 1
    end 
    
    self.status = FAILED
end

BT.SelectorNode = SelectorNode

---------------------------------------------------------------------------------------

local NotDecorator = class("NotDecorator", DecoratorNode, function(child)
    return DecoratorNode.__create(child)
end)

function NotDecorator:Visit()
    local child = self.children[1]
    child:Visit()
    if child.status == SUCCESS then
        self.status = FAILED
    elseif child.status == FAILED then
        self.status = SUCCESS
    else
        self.status = child.status
    end
end

BT.NotDecorator = NotDecorator

---------------------------------------------------------------------------------------

local FailIfRunningDecorator = class("FailIfRunningDecorator", DecoratorNode, function(child)
    return DecoratorNode.__create(child)
end)

function FailIfRunningDecorator:Visit()
    local child = self.children[1]
    child:Visit()
    if child.status == RUNNING then
        self.status = FAILED
    else
        self.status = child.status
    end
end

BT.FailIfRunningDecorator = FailIfRunningDecorator

---------------------------------------------------------------------------------------

local RunningIfFailDecorator = class("RunningIfFailDecorator", DecoratorNode, function(child)
    return DecoratorNode.__create(child)
end)

function RunningIfFailDecorator:Visit()
    local child = self.children[1]
    child:Visit()
    if child.status == FAILED then
        self.status = RUNNING
    else
        self.status = child.status
    end
end

BT.RunningIfFailDecorator = RunningIfFailDecorator

---------------------------------------------------------------------------------------

local LoopNode = class("LoopNode", BehaviourNode, function(children, maxreps)
    local instance = BehaviourNode.__create(children)
    instance.idx = 1
    instance.maxreps = maxreps
    instance.rep = 0
    return instance
end)

function LoopNode:DBString()
    return tostring(self.idx)
end


function LoopNode:Reset()
    -- self._base.Reset(self)
    self.super.Reset(self)
    self.idx = 1
    self.rep = 0
end

function LoopNode:Visit()
    
    if self.status ~= RUNNING then
        self.idx = 1
        self.rep = 0
        self.status = RUNNING
    end
    
    local done = false
    while self.idx <= #self.children do
    
        local child = self.children[self.idx]
        child:Visit()
        if child.status == RUNNING or child.status == FAILED then
            -- if child.status == FAILED then
            --     --print("EXIT LOOP ON FAIL")
            -- end
            self.status = child.status
            return
        end
        
        self.idx = self.idx + 1
    end 
    
    self.idx = 1
    
    self.rep = self.rep + 1
    if self.maxreps and self.rep >= self.maxreps then
        --print("DONE LOOP")
        self.status = SUCCESS
    else
        for k,v in ipairs(self.children) do
            v:Reset()
        end
    
    end
end

BT.LoopNode = LoopNode

---------------------------------------------------------------------------------------

local RandomNode = class("RandomNode", BehaviourNode, function(children, weights)
    local instance = BehaviourNode.__create(children)
    if weights then
        -- self._weights = weights
        instance._weights = {}
        instance._weight_sum = 0

        for i = 1, #children do
            table.insert(instance._weights, weights[i] or 1)
            instance._weight_sum = instance._weight_sum + (weights[i] or 1)
        end

        -- for i, v in ipairs(weights) do

        --     self._weight_sum = self._weight_sum + v
        -- end
    end
    return instance
end)

function RandomNode:Reset()
    -- self._base.Reset(self)
    self.super.Reset(self)
    self.idx = nil
end


function RandomNode:Visit()

-- TODO bianchx:随机节点并不应该保证随机到的节点应该是Success
    
    if not self.idx and self.children then
        if not self._weights then
            self.idx = math.random(#self.children)
        else
            local index = math.random(self._weight_sum)
            for i,v in ipairs(self._weights) do
                if v >= index then
                    self.idx = i
                    break
                end
                index = index - v
            end
        end
    end

    if self.idx then
        local child = self.children[self.idx]
        child:Visit()
        self.status = child.status

        if self.status ~= RUNNING then
            self.idx = nil
        end        
    end


    -- local done = false
    
    -- if self.status == READY then
    --     --pick a new child
    --     self.idx = math.random(#self.children)
    --     local start = self.idx
    --     while true do
        
    --         local child = self.children[self.idx]
    --         child:Visit()
            
    --         if child.status ~= FAILED then
    --             self.status = child.status
    --             return
    --         end
            
    --         self.idx = self.idx + 1
    --         if self.idx == #self.children then
    --             self.idx = 1
    --         end
            
    --         if self.idx == start then
    --             self.status = FAILED
    --             return
    --         end
    --     end
        
    -- else
    --     local child = self.children[self.idx]
    --     child:Visit()
    --     self.status = child.status
    -- end
    
end

BT.RandomNode = RandomNode

---------------------------------------------------------------------------------------    

-- TODO bianchx:因为EventNode被注释掉了所以优先级节点暂时也不能用

-- local PriorityNode = class("PriorityNode", BehaviourNode, function(children, period)
--     local instance = BehaviourNode.__create(children)
--     instance.period = period or 1
--     return instance
-- end)

-- function PriorityNode:GetSleepTime()
--     if self.status == RUNNING then
        
--         if not self.period then
--             return 0
--         end
        
        
--         local time_to = 0
--         if self.lasttime then
--             time_to = self.lasttime + self.period - BT.GetTime()
--             if time_to < 0 then
--                 time_to = 0
--             end
--         end
    
--         return time_to
--     elseif self.status == READY then
--         return 0
--     end
    
--     return nil
    
-- end


-- function PriorityNode:DBString()
--     local time_till = 0
--     if self.period then
--        time_till = (self.lasttime or 0) + self.period - BT.GetTime()
--     end
    
--     return string.format("execute %d, eval in %2.2f", self.idx or -1, time_till)
-- end


-- function PriorityNode:Reset()
--     self.super.Reset(self)
--     self.idx = nil
-- end

-- function PriorityNode:Visit()
    
--     local time = BT.GetTime()
--     local do_eval = not self.lasttime or not self.period or self.lasttime + self.period < time 
--     local oldidx = self.idx
    
    
--     if do_eval then
        
--         local old_event = nil
--         -- if self.idx and self.children[self.idx]:is_a(EventNode) then
--         if self.idx and BT.iskindof(self.children[self.idx], "EventNode") then
--             old_event = self.children[self.idx]
--         end

--         self.lasttime = time
--         local found = false
--         for idx, child in ipairs(self.children) do
        
--             -- local should_test_anyway = old_event and child:is_a(EventNode) and old_event.priority <= child.priority
--             local should_test_anyway = old_event and BT.iskindof(child, "EventNode") and old_event.priority <= child.priority
--             if not found or should_test_anyway then
            
--                 if child.status == FAILED or child.status == SUCCESS then
--                     child:Reset()
--                 end
--                 child:Visit()
--                 local cs = child.status
--                 if cs == SUCCESS or cs == RUNNING then
--                     if should_test_anyway and self.idx ~= idx then
--                         self.children[self.idx]:Reset()
--                     end
--                     self.status = cs
--                     found = true
--                     self.idx = idx
--                 end
--             else
                
--                 child:Reset()
--             end
--         end
--         if not found then
--             self.status = FAILED
--         end
        
--     else
--         if self.idx then
--             local child = self.children[self.idx]
--             if child.status == RUNNING then
--                 child:Visit()
--                 self.status = child.status
--                 if self.status ~= RUNNING then
--                     self.lasttime = nil
--                 end
--             end
--         end
--     end
    
-- end

-- BT.PriorityNode = PriorityNode

---------------------------------------------------------------------------------------

local ParallelNode = class("ParallelNode", BehaviourNode, function(children)
    return BehaviourNode.__create(children)
end)

function ParallelNode:Step()
    if self.status ~= RUNNING then
        self:Reset()
    elseif self.children then
        for k, v in ipairs(self.children) do
            -- if v.status == SUCCESS and v:is_a(ConditionNode) then
            if v.status == SUCCESS and BT.iskindof(v, "ConditionNode") then
                v:Reset()
            end         
        end
    end
end

function ParallelNode:Visit()
    local done = true
    local any_done = false
    for idx, child in ipairs(self.children) do
        
        -- if child:is_a(ConditionNode) then
        if BT.iskindof(child, "ConditionNode") or BT.iskindof(child, "NotDecorator") then
            child:Reset()
        end
        
        if child.status ~= SUCCESS then
            child:Visit()
            if child.status == FAILED then
                self.status = FAILED
                return
            end
        end
        
        if child.status == RUNNING then
            done = false
        else
            any_done = true
        end
        
        
    end

    if done or (self.stoponanycomplete and any_done) then
        self.status = SUCCESS
    else
        self.status = RUNNING
    end    
end

function ParallelNode:GetSleepTime()
    return 0
end

function ParallelNode:GetTreeSleepTime()
    return 0
end

BT.ParallelNode = ParallelNode


---------------------------------------------------------------------------------------
 
 local ParallelNodeAny = class("ParallelNodeAny", ParallelNode, function(children)
     local instance = ParallelNode.__create(children)
     instance.stoponanycomplete = true
     return instance
 end)

 BT.ParallelNodeAny = ParallelNodeAny

---------------------------------------------------------------------------------------

-- TODO bianchx:事件的相关内容跟业务耦合的非常紧密，需要根据业务重写

-- EventNode = Class(BehaviourNode, function(self, inst, event, child, priority)
--     BehaviourNode._ctor(self, "Event("..event..")", {child})
--     self.inst = inst
--     self.event = event
--     self.priority = priority or 0

--     self.eventfn = function(inst, data) self:OnEvent(data) end
--     self.inst:ListenForEvent(self.event, self.eventfn)
--     --print(self.inst, "EventNode()", self.event)
-- end)


-- local EventNode = class("EventNode", BehaviourNode, function(inst, event, child, priority)
--     local instance = BehaviourNode.__create()
--     instance.inst = inst
--     instance.event = event
--     instance.priority = priority or 0

--     instance.eventfn = function(inst, data) instance:OnEvent(data) end
--     instance.inst:ListenForEvent(instance.event, instance.eventfn)
--     --print(instance.inst, "EventNode()", instance.event)
--     return instance
-- end)

-- function EventNode:OnStop()
--     --print(self.inst, "EventNode:OnStop()", self.event)
--     if self.eventfn then
--         self.inst:RemoveEventCallback(self.event, self.eventfn)
--         self.eventfn = nil
--     end
-- end

-- function EventNode:OnEvent(data)
--     --print(self.inst, "EventNode:OnEvent()", self.event)
    
--     if self.status == RUNNING then
--         self.children[1]:Reset()
--     end
--     self.triggered = true
--     self.data = data
    
--     if self.inst.brain then
--         self.inst.brain:ForceUpdate()
--     end
    
--     -- self:DoToParents(function(node) if node:is_a(PriorityNode) then node.lasttime = nil end end)
--     self:DoToParents(function(node) if BT.iskindof(node, "PriorityNode") then node.lasttime = nil end end)
    
--     --wake the parent!
-- end

-- function EventNode:Step()
--     self._base.Step(self)
--     self.triggered = false
-- end

-- function EventNode:Reset()
--     self.triggered = false
--    -- self._base.Reset(self)
--     self.super.Reset(self)
-- end

-- function EventNode:Visit()
    
--     if self.status == READY and self.triggered then
--         self.status = RUNNING
--     end

--     if self.status == RUNNING then
--         if self.children and #self.children == 1 then
--             local child = self.children[1]
--             child:Visit()
--             self.status = child.status
--         else
--             self.status = FAILED
--         end
--     end
    
-- end

-- BT.EventNode = EventNode

---------------------------------------------------------------

local WhileNode = class("WhileNode", ParallelNode, function(cond, node)
    return ParallelNode.__create({ConditionNode:create(cond), node})
end)

BT.WhileNode = WhileNode

---------------------------------------------------------------

local IfNode = class("IfNode", SequenceNode, function(cond, node)
    return SequenceNode.__create({ConditionNode:create(cond), node})
end)

BT.IfNode = IfNode

---------------------------------------------------------------

return BT