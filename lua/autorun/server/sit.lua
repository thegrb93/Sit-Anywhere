-- "Oh my God, I can Sit Anywhere!" by Xerasin.
local NextUse = setmetatable({}, {
	__mode = 'k',
	__index = function()
		return 0
	end
})
local SitOnEntsMode = CreateConVar("sitting_ent_mode", "3", {FCVAR_NOTIFY})

--[[
	0 - Cannot sit on any Entities.
	1 - Cannot sit on any Player Entities.
	2 - Can only sit on your own Entities.
	3 - Can sit on Anything.
]]
local SittingOnPlayer = CreateConVar("sitting_can_sit_on_players", "1", {FCVAR_NOTIFY})
local SittingOnPlayer2 = CreateConVar("sitting_can_sit_on_player_ent", "1", {FCVAR_NOTIFY})
local PlayerDamageOnSeats = CreateConVar("sitting_can_damage_players_sitting", "0", {FCVAR_NOTIFY})
local AllowWeaponsInSeat = CreateConVar("sitting_allow_weapons_in_seat", "0", {FCVAR_NOTIFY})
local AdminOnly = CreateConVar("sitting_admin_only", "0", {FCVAR_NOTIFY})
local META = FindMetaTable("Player")

local function ShouldAlwaysSit(ply)
	if not ms then return end
	if not ms.GetTheaterPlayers then return end
	if not ms.GetTheaterPlayers() then return end
	
	return ms.GetTheaterPlayers()[ply]
end

local function Sit(ply, pos, ang, parent, parentbone, func, exit)
	ply:ExitVehicle()
	
	local vehicle = ents.Create("prop_vehicle_prisoner_pod")
	vehicle:SetAngles(ang)
	pos = pos + vehicle:GetUp() * 18
	vehicle:SetPos(pos)
	
	vehicle.playerdynseat = true
	vehicle.oldpos = vehicle:WorldToLocal(ply:GetPos())
	vehicle.oldang = vehicle:WorldToLocalAngles(ply:EyeAngles())
	
	vehicle:SetModel("models/nova/airboat_seat.mdl") -- DO NOT CHANGE OR CRASHES WILL HAPPEN!
	vehicle:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
	vehicle:SetKeyValue("limitview", "0")
	vehicle:Spawn()
	vehicle:Activate()
	
	-- Set the owner to World.
	if CPPI then
		vehicle:CPPISetOwner(Entity(0))
	end
	
	-- Let's try not to crash.
	vehicle:SetMoveType(MOVETYPE_PUSH)
	vehicle:SetCollisionGroup(COLLISION_GROUP_NONE)
	vehicle:SetNotSolid(true)
	
	local vehiclePhys = vehicle:GetPhysicsObject()
	vehiclePhys:Sleep()
	vehiclePhys:EnableGravity(false)
	vehiclePhys:EnableMotion(false)
	vehiclePhys:EnableCollisions(false)
	vehiclePhys:SetMass(1)
	
	-- Visibles.
	vehicle:SetNoDraw(true)
	
	vehicle.VehicleName = "Airboat Seat"
	vehicle.ClassOverride = "prop_vehicle_prisoner_pod"
	
	if parent and parent:IsValid() then
		local r = math.rad(ang.yaw + 90)
		vehicle.plyposhack = vehicle:WorldToLocal(pos + Vector(math.cos(r) * 2, math.sin(r) * 2, 2))
		
		vehicle:SetParent(parent)
		vehicle.parent = parent
	else
		vehicle.OnWorld = true
	end
	
	local prev = ply:GetAllowWeaponsInVehicle()
	if prev then 
		ply.sitting_allowswep = nil
	elseif AllowWeaponsInSeat:GetBool() then
		ply.sitting_allowswep = prev
		ply:SetAllowWeaponsInVehicle(true)
	end
	
	ply:EnterVehicle(vehicle)
	
	if PlayerDamageOnSeats:GetBool() then
		ply:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	end
	
	vehicle.removeonexit = true
	vehicle.exit = exit
	
	--local ang = vehicle:GetAngles() -- ???
	ply:SetEyeAngles(Angle(0, 90, 0))
	
	if func then 
		func(ply) 
	end 
	
	return vehicle
end

local d = function(a, b)
	return math.abs(a - b)
end

local SittingOnPlayerPoses = {
	{
		Pos = Vector(-33, 13, 7),
		Ang = Angle(0, 90, 90),
		FindAng = 90,
	},
	{
		Pos = Vector(33, 13, 7),
		Ang = Angle(0, 270, 90),
		Func = function(ply) 
			if not ply:LookupBone("ValveBiped.Bip01_R_Thigh") then return end
			
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_R_Thigh"), Angle(0, 90, 0)) 
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_L_Thigh"), Angle(0, 90, 0)) 
		end,
		OnExitFunc = function(ply)
			if not ply:LookupBone("ValveBiped.Bip01_R_Thigh") then return end
			
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_R_Thigh"), Angle(0, 0, 0)) 
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_L_Thigh"), Angle(0, 0, 0))
		end,
		FindAng = 270,
	},
	{
		Pos = Vector(0, 16, -15),
		Ang = Angle(0, 180, 0),
		Func = function(ply) 
			if not ply:LookupBone("ValveBiped.Bip01_R_Thigh") then return end
			
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_R_Thigh"), Angle(45, 0, 0)) 
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_L_Thigh"), Angle(-45, 0, 0)) 
		end,
		OnExitFunc = function(ply)
			if not ply:LookupBone("ValveBiped.Bip01_R_Thigh") then return end
			
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_R_Thigh"), Angle(0, 0, 0)) 
			ply:ManipulateBoneAngles(ply:LookupBone("ValveBiped.Bip01_L_Thigh"), Angle(0, 0, 0))
		end,
		FindAng = 0,		
	},
	{
		Pos = Vector(0, 8, -18),
		Ang = Angle(0, 0, 0),
		FindAng = 180,
	},
}

local lookup = {}
for k, v in pairs(SittingOnPlayerPoses) do
	table.insert(lookup,{v.FindAng,v})
	table.insert(lookup,{v.FindAng + 360, v})
	table.insert(lookup,{v.FindAng - 360, v})
end

local function FindPose(this, me)
	local avec = me:GetAimVector()
	avec.z = 0
	avec:Normalize()
	
	local evec = this:GetRight()
	evec.z = 0
	evec:Normalize()
	
	local derp = avec:Dot(evec)
	
	local avec = me:GetAimVector()
	avec.z = 0
	avec:Normalize()
	
	local evec = this:GetForward()
	evec.z = 0
	evec:Normalize()
	
	local herp = avec:Dot(evec)
	local v = Vector(derp, herp, 0)
	local a = v:Angle()
	
	local ang = a.y
	assert(ang >= 0)
	assert(ang <= 360)
	ang = ang + 90 + 180
	ang = ang % 360
	
	table.sort(lookup, function(aa,bb)
		return d(ang,aa[1]) < d(ang,bb[1])
	end)
	
	return lookup[1][2]
end

local blacklist = {
	["gmod_wire_keyboard"] = true
}
local model_blacklist = { -- I need help finding out why these crash.
	--[[["models/props_junk/sawblade001a.mdl"] = true, 
	["models/props_c17/furnitureshelf001b.mdl"] = true,
	["models/props_phx/construct/metal_plate1.mdl"] = true,
	["models/props_phx/construct/metal_plate1x2.mdl"] = true,
	["models/props_phx/construct/metal_plate1x2_tri.mdl"] = true,
	["models/props_phx/construct/metal_plate1_tri.mdl"] = true,
	["models/props_phx/construct/metal_plate2x2.mdl"] = true,
	["models/props_phx/construct/metal_plate2x2_tri.mdl"] = true,
	["models/props_phx/construct/metal_plate2x4.mdl"] = true,
	["models/props_phx/construct/metal_plate2x4_tri.mdl"] = true,
	["models/props_phx/construct/metal_plate4x4.mdl"] = true,
	["models/props_phx/construct/metal_plate4x4_tri.mdl"] = true,]]
}

function META.Sit(ply, EyeTrace, ang, parent, parentbone, func, exit)
	if not EyeTrace then
		EyeTrace = ply:GetEyeTrace()
	elseif type(EyeTrace) == "Vector" then
		return Sit(ply, EyeTrace, ang or Angle(0, 0, 0), parent, parentbone or 0, func, exit)
	end
	
	if not EyeTrace.Hit then return end
	if EyeTrace.HitPos:Distance(EyeTrace.StartPos) > 100 then return end
	
	local sitting_disallow_on_me = ply:GetInfoNum("sitting_disallow_on_me", 0) == 1
	if SittingOnPlayer:GetBool() then
		for k, v in ipairs(ents.FindInSphere(EyeTrace.HitPos, 5)) do 
			local safe = 256
			
			while IsValid(v.SittingOnMe) and safe > 0 do
				safe = safe - 1
				v = v.SittingOnMe
			end
			
			local driver = v:IsVehicle() and v:GetDriver()
			if v:GetClass() == "prop_vehicle_prisoner_pod" and v:GetModel() ~= "models/vehicles/prisoner_pod_inner.mdl" and IsValid(driver) and not v.PlayerSitOnPlayer then	
				if driver:GetInfoNum("sitting_disallow_on_me", 0) ~= 0 then
					ply:ChatPrint(driver:Name()..' has disabled sitting!')
					return
				end
				
				if sitting_disallow_on_me then
					ply:ChatPrint("You've disabled sitting on players!")
					return
				end
			
				local pose = FindPose(v, ply) --SittingOnPlayerPoses[math.random(1, #SittingOnPlayerPoses)]
				local pos = driver:GetPos()
				
				if v.plyposhack then
					pos = v:LocalToWorld(v.plyposhack)
				end
				
				local vec, ang = LocalToWorld(pose.Pos, pose.Ang, pos, v:GetAngles())
				if v:GetParent() == ply then return end
				
				local ent = Sit(ply, vec, ang, v, 0, pose.Func, pose.OnExitFunc)
				ent.PlayerOnPlayer = true
				v.SittingOnMe = ent
				
				return ent
			end
		end
	else
		for k, v in ipairs(ents.FindInSphere(EyeTrace.HitPos, 5)) do 
			if v.removeonexit then
				return
			end
		end
	end
	
	if not EyeTrace.HitWorld and SitOnEntsMode:GetInt() == 0 then return end
	if not EyeTrace.HitWorld and blacklist[string.lower(EyeTrace.Entity:GetClass())] then return end
	if not EyeTrace.HitWorld and EyeTrace.Entity:GetModel() and model_blacklist[string.lower(EyeTrace.Entity:GetModel())] then return end
	
	if CPPI then
		if SitOnEntsMode:GetInt() >= 1 then
			if SitOnEntsMode:GetInt() == 1 then
				if not EyeTrace.HitWorld then
					local owner = EyeTrace.Entity:CPPIGetOwner()
					
					if IsValid(owner) and owner:IsPlayer() then
						return
					end
				end
			end
			
			if SitOnEntsMode:GetInt() == 2 then
				if not EyeTrace.HitWorld then
					local owner = EyeTrace.Entity:CPPIGetOwner()
					
					if IsValid(owner) and owner:IsPlayer() and owner ~= ply then
						return
					end
				end
			end
		end
	end
	
	local EyeTrace2Tr = util.GetPlayerTrace(ply)
	EyeTrace2Tr.filter = ply
	EyeTrace2Tr.mins = Vector(-5, -5, -5)
	EyeTrace2Tr.maxs = Vector(5, 5, 5)
	
	local EyeTrace2 = util.TraceHull(EyeTrace2Tr)
	if EyeTrace2.Entity ~= EyeTrace.Entity then return end
	
	local ang = EyeTrace.HitNormal:Angle() + Angle(-270, 0, 0)
	if math.abs(ang.pitch) <= 15 then
		local ang = Angle()
		local filter = player.GetAll()
		local dists = {}
		local distsang = {}
		local ang_smallest_hori = nil
		local smallest_hori = 90000
		
		for i = 0, 360, 15 do 
			local rad = math.rad(i)
			local dir = Vector(math.cos(rad), math.sin(rad), 0)
			local trace = util.QuickTrace(EyeTrace.HitPos + dir * 20 + Vector(0, 0, 5), Vector(0, 0, -15000), filter)
			trace.HorizontalTrace = util.QuickTrace(EyeTrace.HitPos + Vector(0, 0, 5), (dir) * 1000, filter)
			trace.Distance = trace.StartPos:Distance(trace.HitPos)
			trace.Distance2 = trace.HorizontalTrace.StartPos:Distance(trace.HorizontalTrace.HitPos)
			trace.ang = i
			
			if (not trace.Hit or trace.Distance > 14) and (not trace.HorizontalTrace.Hit or trace.Distance2 > 20) then
				table.insert(dists, trace)
			end
			
			if trace.Distance2 < smallest_hori and (not trace.HorizontalTrace.Hit or trace.Distance2 > 3) then
				smallest_hori = trace.Distance2
				ang_smallest_hori = i
			end
			
			distsang[i] = trace
		end
		local infront = ((ang_smallest_hori or 0) + 180) % 360
		
		if ang_smallest_hori and distsang[infront].Hit and distsang[infront].Distance > 14 and smallest_hori <= 16 then
			local hori = distsang[ang_smallest_hori].HorizontalTrace
			ang.yaw = hori.HitNormal:Angle().yaw - 90
			
			local ent = nil
			if not EyeTrace.HitWorld then
				ent = EyeTrace.Entity
				local entPlayer = ent:IsPlayer()
				
				if entPlayer and not SittingOnPlayer2:GetBool() then return end
				
				if entPlayer and ent:GetInfoNum("sitting_disallow_on_me", 0) == 1 then
					ply:ChatPrint(ent:Name()..' has disabled sitting!')
					return
				end
				
				if sitting_disallow_on_me then
					ply:ChatPrint("You've disabled sitting on players!")
					return
				end
			end
			
			local vehicle = Sit(ply, EyeTrace.HitPos - Vector(0, 0, 20), ang, ent, EyeTrace.PhysicsBone or 0)
			return vehicle
		else
			table.sort(dists, function(a, b)
				return b.Distance < a.Distance
			end)
			
			local wants = {}
			local eyeang = ply:EyeAngles() + Angle(0, 180, 0)
			
			for i = 1, #dists do 
				local trace = dists[i]
				local behind = distsang[(trace.ang + 180) % 360]
				if behind.Distance2 > 3 then
					local cost = 0
					if trace.ang % 90 ~= 0 then
						cost = cost + 12
					end
					
					if math.abs(eyeang.yaw - trace.ang) > 12 then
						cost = cost + 30
					end
					
					local tbl = {
						cost = cost,
						ang = trace.ang,
					}
					
					table.insert(wants, tbl)
				end
			end
			
			table.sort(wants, function(a,b)
				return b.cost > a.cost
			end)
			
			if #wants == 0 then return end
			
			ang.yaw = wants[1].ang - 90
			local ent = nil
			
			if not EyeTrace.HitWorld then
				ent = EyeTrace.Entity
				local entPlayer = ent:IsPlayer()
				local entVehicle = entPlayer and ent:GetVehicle()
				
				if entPlayer and not SittingOnPlayer2:GetBool() then return end
				if entPlayer and IsValid(entVehicle) and entVehicle:GetParent() == ply then return end

				if entPlayer and ent:GetInfoNum("sitting_disallow_on_me", 0) == 1 then
					ply:ChatPrint(ent:Name()..' has disabled sitting!')
					return
				end
				
				if sitting_disallow_on_me then
					ply:ChatPrint("You've disabled sitting on players!")
					return
				end
			end
			
			local vehicle = Sit(ply, EyeTrace.HitPos - Vector(0, 0, 20), ang, ent, EyeTrace.PhysicsBone or 0)
			
			return vehicle
		end
	end
end

local function sitcmd(ply)
	if ply:InVehicle() then return end
	if AdminOnly:GetBool() and not ply:IsAdmin() then return end
	
	local now = CurTime()
	if NextUse[ply] > now then return end
	
	-- We want to prevent the player getting off right after getting in, but how?
	if ply:Sit() then
		NextUse[ply] = now + 1
	else
		NextUse[ply] = now + 0.1
	end
end

concommand.Add("sit", function(ply, cmd, args)
	sitcmd(ply)
end)

hook.Add("CanExitVehicle", "Remove_Seat", function(self, ply)
	if not self.playerdynseat then return end
	if CurTime() < NextUse[ply] then return false end
	NextUse[ply] = CurTime() + 1
		
	local function OnExit()
		local prev = ply.sitting_allowswep
		
		if prev then
			ply.sitting_allowswep = nil
			ply:SetAllowWeaponsInVehicle(prev)
		end
		
		if (self.exit) then
			self.exit(ply)
		end
		
		self:Remove()
	end
	
	if ShouldAlwaysSit(ply) then
		-- Cinema Gamemode.
		if ply.UnStuck then
			local pos, ang = LocalToWorld(Vector(0, 36, 20), Angle(), self:GetPos(), Angle(0, self:GetAngles().yaw, 0))
			ply:UnStuck(pos, pos, OnExit)
			
			return false
		else
			timer.Simple(0, function()
				if IsValid(ply) and IsValid(self) then
					ply:SetPos(self:GetPos() + Vector(0, 0, 36))
					OnExit()
				end
			end)
		end
	else
		local oldpos, oldang = self:LocalToWorld(self.oldpos), self:LocalToWorldAngles(self.oldang)
		if ply.UnStuck then
			ply:UnStuck(oldpos, OnExit)
			
			return false
		else
			timer.Simple(0, function()
				if IsValid(ply) then
					ply:SetPos(oldpos)
					ply:SetEyeAngles(oldang)
					OnExit()
				end
			end)
		end
	end
end)

hook.Add("AllowPlayerPickup", "Nopickupwithalt", function(ply) 
	if ply:KeyDown(IN_WALK) then 
		return false 
	end 
end)

hook.Add("PlayerDeath", "SitSeat", function(ply) 
	for k, v in next, player.GetAll() do
		local veh = v:GetVehicle()
		
		if veh:IsValid() and veh.playerdynseat and veh:GetParent() == ply then
			veh:Remove()
		end
	end 
end)

hook.Add("PlayerEnteredVehicle", "unsits", function(ply, veh)
	for k, v in next, player.GetAll() do
		local vehicle = v:GetVehicle()
		
		if v ~= ply and v:InVehicle() and vehicle:IsValid() and vehicle:GetParent() == ply then
			v:ExitVehicle()
		end
	end
	
	DropEntityIfHeld(veh)
	
	if veh:GetParent():IsValid() then
		DropEntityIfHeld(veh:GetParent())	
	end
end)

hook.Add("EntityRemoved", "Sitting_EntityRemoved", function(ent)
	for k, v in ipairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do 
		if v:GetParent() == ent then
			local driver = v:GetDriver()
			
			if IsValid(driver) then
				driver:ExitVehicle()
				v:Remove()
			end
		end
	end
end)

timer.Create("RemoveSeats", 15, 0, function() 
	for k, v in ipairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
		local driver = v:GetDriver()
		
		if v.removeonexit and (not driver or not driver:IsValid() or driver:GetVehicle() ~= v --[[ ??? ]]) then
			v:Remove()
		end
	end
end)

hook.Add("InitPostEntity", "SAW_CompatFix", function()
	if hook.GetTable()["CanExitVehicle"]["PAS_ExitVehicle"] and PM_SendPassengers then
		local function IsSCarSeat(seat)
			if IsValid(seat) and seat.IsScarSeat and seat.IsScarSeat then
				return true
			end
			
			return false
		end
		
		hook.Add("CanExitVehicle", "PAS_ExitVehicle", function(veh, ply)
			if not IsSCarSeat(veh) and not veh.playerdynseat and veh.vehicle then
				-- L + R.
				if ply:VisibleVec(veh:LocalToWorld(Vector(80, 0, 5))) then
					ply:ExitVehicle()
					ply:SetPos(veh:LocalToWorld(Vector(75, 0, 5)))
					
					if veh:GetClass() == "prop_vehicle_prisoner_pod" and ply ~= veh.vehicle:GetDriver() then
						PM_SendPassengers(veh.vehicle:GetDriver())
					end
					
					return false
				end
			   
				if ply:VisibleVec(veh:LocalToWorld(Vector(-80, 0, 5))) then
					ply:ExitVehicle()
					ply:SetPos(veh:LocalToWorld(Vector(-75, 0, 5)))
					
					if veh:GetClass() == "prop_vehicle_prisoner_pod" and ply ~= veh.vehicle:GetDriver() then
						PM_SendPassengers(veh.vehicle:GetDriver())
					end
					
					return false
				end
			end
		end)
	end
end)
