require("func")
local BT = require("behaviourtree")

SUCCESS = BT.SUCCESS
FAILED = BT.FAILED
READY = BT.READY
RUNNING = BT.RUNNING

local data = {}

local _time = 0
local _should_time = 0

print("behaviourtree test")

local NothingNode = class("NothingNode", BT.BehaviourNode)
function NothingNode:Visit() end

local RunningNode = class("RunningNode", BT.BehaviourNode)
function RunningNode:Visit()
	print("RunningNode RUNNING")
	_time = _time + 1
	self.status = RUNNING
end

local node_action_add1 = BT.ActionNode:create(function()
	print("BT.ActionNode runing")
	_time = _time + 1
end)

local node_cond_true = BT.ConditionNode:create(function()
	return true
end)

local node_cond_false = BT.ConditionNode:create(function()
	return false
end)

local node_status_failed = NothingNode:create()
node_status_failed.status = FAILED

local node_status_success = NothingNode:create()
node_status_success.status = SUCCESS

local node_status_running = NothingNode:create()
node_status_running.status = RUNNING

local function_true = function() return true end
local function_false = function() return false end

local function_true_false_time = 0
local function_true_false = function()
	local value = function_true_false_time % 2 == 0
	function_true_false_time = function_true_false_time + 1
	return value
end

local test = {}
test.bt = BT.BehaviourTree:create(node_action_add1)

local start = os.clock()

local testtype = ""


print("")

----------------------------------------------------------------------------

testtype = "BT.iskindof"

print("Test Start\t" .. testtype)
assert(BT.iskindof(BT.NotDecorator, "BehaviourNode"), "BT.NotDecorator >> BehaviourNode Should be true")
assert(not BT.iskindof(BT.NotDecorator, "BehaviourTree"), "BT.NotDecorator >> BehaviourTree Should be false")
assert(BT.iskindof(BT.NotDecorator, "DecoratorNode"), "BT.NotDecorator >> DecoratorNode Should be true")
print("Test Ended \t" .. testtype .. "\n")

----------------------------------------------------------------------------

testtype = "BT.BehaviourTree & BT.ActionNode"
print("Test Start\t" .. testtype)
test.bt:Update()
print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 1
assert(_time == _should_time, "BT.ActionNode Not Run")

----------------------------------------------------------------------------

local node_seq = BT.SequenceNode:create({node_action_add1, node_action_add1, node_action_add1})

testtype = "BT.SequenceNode"
start = os.clock()
print("Test Start\t" .. testtype)

test.bt = BT.BehaviourTree:create(node_seq)
test.bt:Update()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 3
assert(_time == _should_time, "BT.SequenceNode Not Run")

----------------------------------------------------------------------------

node_seq = BT.SequenceNode:create({node_cond_true, node_action_add1})

testtype = "BT.ConditionNode Branch:Success"
start = os.clock()
print("Test Start\t" .. testtype)

test.bt = BT.BehaviourTree:create(node_seq)
test.bt:Update()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 1
assert(_time == _should_time, "BT.ConditionNode No Work")

----------------------------------------------------------------------------

local node = BT.SequenceNode:create({node_cond_false, node_action_add1})

testtype = "BT.ConditionNode Branch:Error"
start = os.clock()
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

-- _should_time = _should_time + 1
assert(_time == _should_time, "BT.ConditionNode No Work")

----------------------------------------------------------------------------

local node_wait = BT.ConditionWaitNode:create(function_true)

testtype = "BT.ConditionWaitNode ConditionWaitNode:SUCCESS"
start = os.clock()
print("Test Start\t" .. testtype)

node_wait:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node_wait.status == SUCCESS, "BT.ConditionWaitNode Should Be SUCCESS")

----------------------------------------------------------------------------

local node_wait = BT.ConditionWaitNode:create(function_false)

testtype = "BT.ConditionWaitNode ConditionWaitNode:RUNNING"
start = os.clock()
print("Test Start\t" .. testtype)

node_wait:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node_wait.status == RUNNING, "BT.ConditionWaitNode Should Be RUNNING")

----------------------------------------------------------------------------

-- testtype = "BT.ActionNode"
-- start = os.clock()
-- print("Test Start\t" .. testtype)

-- node_action_add1:Visit()

-- print("Test Ended \t" .. testtype .. "\n")

-- _should_time = _should_time + 1
-- assert(_should_time == _time, "BT.ActionNode Not Run")
-- assert(node_action_add1.status == SUCCESS, "BT.ActionNode Should Be SUCCESS")

----------------------------------------------------------------------------

start = os.clock()
local node = BT.WaitNode:create(1)

testtype = "BT.WaitNode"
print("Test Start\t" .. testtype)

while node.status == RUNNING or node.status == READY do
node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

assert(os.clock() - start >= 1, "BT.WaitNode WaitTime Must Big Than 1")

----------------------------------------------------------------------------

local node = BT.SelectorNode:create({node_cond_true, node_action_add1})

testtype = "BT.SelectorNode Branch:True"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

-- _should_time = _should_time + 1
assert(_time == _should_time, "BT.SelectorNode No Work")

----------------------------------------------------------------------------

local node = BT.SelectorNode:create({node_cond_false, node_action_add1})

testtype = "BT.SelectorNode Branch:False"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 1
assert(_time == _should_time, "BT.SelectorNode No Work")

----------------------------------------------------------------------------

local node = BT.NotDecorator:create(node_status_success)

testtype = "BT.NotDecorator Branch:SUCCESS"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node.status == FAILED, "BT.NotDecorator No Work")

----------------------------------------------------------------------------

local node = BT.NotDecorator:create(node_status_failed)

testtype = "BT.NotDecorator Branch:FAILED"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node.status == SUCCESS, "BT.NotDecorator No Work")

----------------------------------------------------------------------------

local node = BT.NotDecorator:create(node_status_running)

testtype = "BT.NotDecorator Branch:RUNNING"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node.status == RUNNING, "BT.NotDecorator No Work")

----------------------------------------------------------------------------

local node = BT.FailIfRunningDecorator:create(node_status_success)

testtype = "BT.FailIfRunningDecorator Branch:SUCCESS"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node.status == SUCCESS, "BT.FailIfRunningDecorator No Work")

----------------------------------------------------------------------------

local node = BT.FailIfRunningDecorator:create(node_status_failed)

testtype = "BT.FailIfRunningDecorator Branch:FAILED"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node.status == FAILED, "BT.FailIfRunningDecorator No Work")

----------------------------------------------------------------------------

local node = BT.FailIfRunningDecorator:create(node_status_running)

testtype = "BT.FailIfRunningDecorator Branch:RUNNING"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

assert(node.status == FAILED, "BT.FailIfRunningDecorator No Work")

----------------------------------------------------------------------------

local loopcount = 2
local node = BT.LoopNode:create({node_action_add1, node_action_add1}, loopcount)

testtype = "BT.LoopNode Branch:SUCCESS"
print("Test Start\t" .. testtype)

while node.status == READY or node.status == RUNNING do
	node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 2 * loopcount;
assert(_time == _should_time, "BT.LoopNode No Work")

----------------------------------------------------------------------------

local node = BT.LoopNode:create({node_action_add1, node_action_add1})

testtype = "BT.LoopNode Branch:Always"
print("Test Start\t" .. testtype)

for i=1,10 do
	node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 2 * 10;
assert(_time == _should_time, "BT.LoopNode No Work")

----------------------------------------------------------------------------

local _time2 = 0
local _time3 = 0
local node_action_add2 = BT.ActionNode:create(function()
	print("BT.ActionNode RUNNING 2")
 	_time2 = _time2 + 1 
 end)
local node_action_add3 = BT.ActionNode:create(function()	
	print("BT.ActionNode RUNNING 3")
 	_time3 = _time3 + 1 
 end)

local node = BT.RandomNode:create({node_action_add2, node_action_add3})

testtype = "BT.RandomNode"
print("Test Start\t" .. testtype)

while _time2 <= 0 or _time3 <= 0 do
	node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

assert(_time2 > 0, "BT.RandomNode No Work")
assert(_time3 > 0, "BT.RandomNode No Work")

----------------------------------------------------------------------------

local node = BT.ParallelNode:create({clone(node_action_add1), clone(node_action_add1)})

testtype = "BT.ParallelNode"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 2;
assert(node.status == SUCCESS, "BT.ParallelNode Status != SUCCESS")
assert(_time == _should_time, "BT.ParallelNode No Work")

----------------------------------------------------------------------------

local node = BT.ParallelNode:create({clone(node_action_add1), clone(node_action_add1), node_status_running})

testtype = "BT.ParallelNode Branch:RUNNING"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 2;
assert(node.status == RUNNING, "BT.ParallelNode Status != RUNNING")
assert(_time == _should_time, "BT.ParallelNode No Work")

----------------------------------------------------------------------------

local node = BT.ParallelNode:create({clone(node_action_add1), node_status_failed, clone(node_action_add1)})

testtype = "BT.ParallelNode Branch:Error"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 1;
assert(node.status == FAILED, "BT.ParallelNode Status != FAILED")
assert(_time == _should_time, "BT.ParallelNode No Work")

----------------------------------------------------------------------------

local node = BT.ParallelNodeAny:create({clone(node_action_add1), node_status_running})

testtype = "BT.ParallelNodeAny"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 1;
assert(node.status == SUCCESS, "BT.ParallelNodeAny Status != SUCCESS")
assert(_time == _should_time, "BT.ParallelNodeAny No Work")

----------------------------------------------------------------------------

local node = BT.ParallelNodeAny:create({clone(node_action_add1), clone(node_action_add1)})

testtype = "BT.ParallelNodeAny Branch:SUCCESS"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 2
assert(node.status == SUCCESS, "BT.ParallelNodeAny Status != SUCCESS")
assert(_time == _should_time, "BT.ParallelNodeAny No Work")

----------------------------------------------------------------------------

local node = BT.ParallelNodeAny:create({clone(node_action_add1), node_status_failed, clone(node_action_add1)})

testtype = "BT.ParallelNodeAny Branch:Error"
print("Test Start\t" .. testtype)

node:Visit()

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 1;
assert(node.status == FAILED, "BT.ParallelNodeAny Status != FAILED")
assert(_time == _should_time, "BT.ParallelNodeAny No Work")

----------------------------------------------------------------------------

local node = BT.WhileNode:create(function_true_false, node_action_add1)

testtype = "BT.WhileNode"
print("Test Start\t" .. testtype)

for i=1,10 do
	node:Step()
	node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 5
assert(node.status == FAILED, "BT.WhileNode Status != FAILED")
assert(_time == _should_time, "BT.WhileNode No Work")

----------------------------------------------------------------------------

local node = BT.WhileNode:create(function_true_false, RunningNode:create())

testtype = "BT.WhileNode"
print("Test Start\t" .. testtype)

for i=1,10 do
	node:Step()
	node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 5
assert(node.status == FAILED, "BT.WhileNode Status != FAILED")
assert(_time == _should_time, "BT.WhileNode No Work")

----------------------------------------------------------------------------

local node = BT.IfNode:create(function_true_false, node_action_add1)

testtype = "BT.IfNode"
print("Test Start\t" .. testtype)

for i=1,10 do
	node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 5
-- assert(node.status == SUCCESS, "BT.IfNode Status != SUCCESS")
assert(_time == _should_time, "BT.IfNode No Work")

----------------------------------------------------------------------------

local node = BT.IfNode:create(function_true_false, RunningNode:create())

testtype = "BT.IfNode"
print("Test Start\t" .. testtype)

for i=1,10 do
	node:Visit()
end

print("Test Ended \t" .. testtype .. "\n")

_should_time = _should_time + 10
assert(node.status == RUNNING, "BT.IfNode Status != RUNNING")
assert(_time == _should_time, "BT.IfNode No Work")

----------------------------------------------------------------------------

local node = BT.SequenceNode:create({
	BT.ActionNode:create(function() print("this is a ActionNode") end),
	BT.SelectorNode:create({
		BT.IfNode:create(function_true, node_action_add1)
	}),
})

testtype = "BT.BehaviourNode:SetOwner"
print("Test Start\t" .. testtype)

node:SetOwner(function_true_false_time)

print("Test Ended \t" .. testtype .. "\n")

function testSetOwner(btnode)
	if not btnode then
		return
	end

	assert(btnode.owner == function_true_false_time, "BT.BehaviourNode:SetOwner Not Work")

	if btnode.children then
		for k,v in pairs(btnode.children) do
			testSetOwner(v)
		end
	end
end

testSetOwner(node)

-- assert(_time == _should_time, "BT.BehaviourNode:SetOwner")

----------------------------------------------------------------------------

print "Test Finish"