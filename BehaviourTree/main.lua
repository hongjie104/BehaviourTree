require("func")
local BT = require("behaviourtree")

local time = 0

BT.GetTime = function()
	return time
end

print("behaviourtree test")

local root = BT.SequenceNode:create({
	BT.ActionNode:create(function()
		print("BT.ActionNode_Start")
	end),
	BT.ActionNode:create(function()
		print("BT.ActionNode")
	end),
	BT.ActionNode:create(function()
		print("BT.ActionNode_2")
	end),
	BT.ActionNode:create(function()
		print("BT.ActionNode_End")
	end),
	BT.WaitNode:create(1),
	})

local test = {}
test.bt = BT.BehaviourTree:create(root)

local start = os.clock()

while time < 10 do
	time = os.clock() - start
	test.bt:Update()
end

print "Run Finish"