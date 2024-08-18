--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Telash Greywing", 2515, 2483)
if not mod then return end
mod:RegisterEnableMob(186737) -- Telash Greywing
mod:SetEncounterID(2583)
mod:SetRespawnTime(30)

--------------------------------------------------------------------------------
-- Locals
--

local absoluteZeroCount = 1
local frostBombCount = 1
local frostBombRemaining = 3
local icyDevastatorRemaining = 2

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		{388008, "CASTBAR"}, -- Absolute Zero
		{386781, "SAY_COUNTDOWN"}, -- Frost Bomb
		{387151, "SAY"}, -- Icy Devastator
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_CAST_START", "AbsoluteZero", 388008)
	self:Log("SPELL_CAST_SUCCESS", "AbsoluteZeroSuccess", 388008)
	self:Log("SPELL_AURA_APPLIED", "AbsoluteZeroApplied", 396722)
	self:Log("SPELL_CAST_START", "FrostBomb", 386781)
	self:Log("SPELL_AURA_APPLIED", "FrostBombApplied", 386881)
	self:Log("SPELL_AURA_REMOVED", "FrostBombRemoved", 386881)
	self:Log("SPELL_CAST_START", "IcyDevastator", 387151)
end

function mod:OnEngage()
	absoluteZeroCount = 1
	frostBombCount = 1
	frostBombRemaining = 1
	icyDevastatorRemaining = 1
	self:Bar(386781, 3.5, CL.count:format(self:SpellName(386781), frostBombCount)) -- Frost Bomb
	self:Bar(387151, 14.5) -- Icy Devastator
	-- cast at 100 energy, 20s energy gain + 1.5s delay
	self:Bar(388008, 21.5, CL.count:format(self:SpellName(388008), absoluteZeroCount)) -- Absolute Zero
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local playerList = {}

	function mod:AbsoluteZero(args)
		playerList = {}
		self:StopBar(CL.count:format(self:SpellName(386781), frostBombCount)) -- Frost Bomb
		self:StopBar(387151) -- Icy Devastator
		self:StopBar(CL.count:format(args.spellName, absoluteZeroCount)) -- Absolute Zero
		self:Message(args.spellId, "red", CL.count:format(args.spellName, absoluteZeroCount)) -- Absolute Zero
		self:PlaySound(args.spellId, "long")
		self:CastBar(args.spellId, 8)
	end

	function mod:AbsoluteZeroSuccess(args)
		frostBombRemaining = 3
		icyDevastatorRemaining = 2
		self:Bar(386781, 4.3, CL.count:format(self:SpellName(386781), frostBombCount)) -- Frost Bomb
		self:Bar(387151, 15.2) -- Icy Devastator
		-- 8s cast at 100 energy: 50s energy gain + 2.8s or 6.4s delay
		absoluteZeroCount = absoluteZeroCount + 1
		self:CDBar(args.spellId, 52.8, CL.count:format(args.spellName, absoluteZeroCount)) -- or 56.4
	end

	function mod:AbsoluteZeroApplied(args)
		if self:Dispeller("magic") or self:Dispeller("movement") or self:Me(args.destGUID) then
			playerList[#playerList + 1] = args.destName
			self:TargetsMessage(388008, "orange", playerList, 5)
			self:PlaySound(388008, "alert", nil, playerList)
		end
	end
end

function mod:FrostBomb(args)
	self:StopBar(CL.count:format(args.spellName, frostBombCount))
	self:Message(args.spellId, "orange", CL.count:format(args.spellName, frostBombCount))
	self:PlaySound(args.spellId, "alert")
	-- two possibilities:
	-- 1. AZ cycle is 64.4s and FB is [(AZ 8) 4.3, (ID) 18.2, 15.8 (ID)]
	-- 2. AZ cycle is 60.8s and FB is [(AZ 8) 4.3, (ID) 18.2, (ID) 23.1]
	frostBombCount = frostBombCount + 1
	frostBombRemaining = frostBombRemaining - 1
	if frostBombRemaining == 2 then
		self:Bar(args.spellId, 18.2, CL.count:format(args.spellName, frostBombCount))
	elseif frostBombRemaining == 1 then
		self:CDBar(args.spellId, 15.8, CL.count:format(args.spellName, frostBombCount)) -- or 23.1
	elseif frostBombRemaining == 0 then
		if icyDevastatorRemaining == 1 and absoluteZeroCount > 1 then
			-- fix final timers for the FB -> ID -> FB -> FB -> ID -> AZ variation
			self:Bar(387151, 10.8) -- Icy Devastator
			self:Bar(388008, {18.1, 52.8}, CL.count:format(self:SpellName(388008), absoluteZeroCount)) -- Absolute Zero
		end
	end
end

function mod:FrostBombApplied(args)
	if self:Me(args.destGUID) then
		self:PersonalMessage(386781)
		self:SayCountdown(386781, 5)
	end
end

function mod:FrostBombRemoved(args)
	if self:Me(args.destGUID) then
		self:CancelSayCountdown(386781)
	end
end

do
	local function printTarget(self, player, guid)
		if self:Me(guid) then
			self:Say(387151, nil, nil, "Icy Devastator")
			self:PlaySound(387151, "alarm")
		else
			self:PlaySound(387151, "alert", nil, player)
		end
		self:TargetMessage(387151, "orange", player)
	end

	function mod:IcyDevastator(args)
		self:GetUnitTarget(printTarget, 0.2, args.sourceGUID)
		-- two possibilities:
		-- 1. AZ cycle is 64.4s and ID is [(AZ 8)(FB) 15.2, (FB) (FB) 33.9]
		-- 2. AZ cycle is 60.8s and ID is [(AZ 8)(FB) 15.2, (FB) 23.1 (FB)]
		icyDevastatorRemaining = icyDevastatorRemaining - 1
		if icyDevastatorRemaining == 1 then
			self:CDBar(args.spellId, 23.1) -- or 33.9
		elseif icyDevastatorRemaining == 0 then
			self:StopBar(args.spellId)
			if frostBombRemaining == 1 then
				-- fix final timers for the FB -> ID -> FB -> ID -> FB -> AZ variation
				self:Bar(386781, 7.3, CL.count:format(self:SpellName(386781), frostBombCount)) -- Frost Bomb
			end
		end
	end
end
