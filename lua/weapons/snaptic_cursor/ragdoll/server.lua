local Ragdoll = Snaptic.Ragdoll

Ragdoll.registry = Ragdoll.registry or {}

function Ragdoll.Spectate(invoker, entity)
	invoker:Spectate(OBS_MODE_NONE)
    invoker:SetObserverMode(OBS_MODE_CHASE) -- HACK: fixes needing to respawn the player after unspectating
	invoker:SpectateEntity(entity)
	invoker:SetSolid(SOLID_NONE)
	invoker:SetNoDraw(true)
	invoker.Snaptic_Ragdoll_Weapon = invoker:GetActiveWeapon()
    invoker.Snaptic_Spectating = entity
	invoker:SetActiveWeapon()
    invoker:SetPos(entity:GetPos())
end

function Ragdoll.UnSpectate(invoker)
	invoker:UnSpectate()
	invoker:DrawViewModel(true)
	invoker:SetSolid(SOLID_BBOX)
	invoker:SetMoveType(MOVETYPE_WALK)
	invoker:SetNoDraw(false)
	invoker:SetActiveWeapon(invoker.Snaptic_Ragdoll_Weapon)
	invoker.Snaptic_Ragdoll_Weapon = nil
    invoker.Snaptic_Spectating = nil
end

util.AddNetworkString("snaptic_ragdoll_color")

function Ragdoll.Start(invoker, caller, velocity, duration)
    duration = duration or 0
	if Ragdoll.GetRagdoll(invoker) then return end

	local ragdoll = ents.Create("prop_ragdoll")
	if not IsValid(ragdoll) then return end

	if ragdoll.CPPISetOwner then ragdoll:CPPISetOwner(caller or invoker) end
    ragdoll.caller = caller
	ragdoll:SetModel(invoker:GetModel())
	ragdoll:Spawn()
	ragdoll:Activate()

    if not IsValid(ragdoll:GetPhysicsObject()) then
        ragdoll:Remove()
        return
    end

	net.Start("snaptic_ragdoll_color")
	net.WriteUInt(ragdoll:EntIndex(), 13) -- MAX_EDICT_BITS
	net.WriteVector(invoker:GetPlayerColor())
	net.Broadcast()

    -- TODO: Make this kill them instead?
	ragdoll:CallOnRemove("Snaptic_Ragdoll", function()
		if not invoker:IsValid() then return end
        Ragdoll.UnSpectate(invoker)
        invoker:SetNW2Entity("snaptic.ragdoll", nil)
        ragdoll:SetNW2Entity("snaptic.ragdoll", nil)
        invoker:SetPos(ragdoll:GetPos() + ragdoll:OBBCenter())
        invoker:SetVelocity(ragdoll:GetVelocity())

        local r = Ragdoll.registry
        for i=1, #r do
            if r[i] == ragdoll then
                table.remove(r, i)
                break
            end
        end
	end)

    function ragdoll:OnTakeDamage(damage) -- DMG passthrough, TODO: doesn't seem to work?
        local controller = Ragdoll.GetController(self)
        if not IsValid(controller) then return end
        controller:TakeDamageInfo(damage)
    end

    function ragdoll:GetHealth()
        local controller = Ragdoll.GetController(self)
        if not IsValid(controller) then return 0 end
        return controller:GetHealth()
    end

	local vel = velocity or invoker:GetVelocity()

	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		local boneid = ragdoll:TranslatePhysBoneToBone(i)
		if boneid < 0 then continue end

		local matrix = invoker:GetBoneMatrix(boneid)
		if not matrix then continue end

		phys:SetPos(matrix:GetTranslation())
		phys:SetAngles(matrix:GetAngles())
		phys:AddVelocity(vel)
	end

	if invoker:InVehicle() then invoker:ExitVehicle() end

    ragdoll.time = SysTime()
    ragdoll.duration = duration
    invoker:SetNW2Entity("snaptic.ragdoll", ragdoll)
    ragdoll:SetNW2Entity("snaptic.ragdoll", invoker)
    local r = Ragdoll.registry
    r[#r+1] = ragdoll
	Ragdoll.Spectate(invoker, ragdoll)
end

function Ragdoll.Stop(invoker)
    local ragdoll = Ragdoll.GetRagdoll(invoker)
	if not ragdoll then return end

	Ragdoll.UnSpectate(invoker)
    invoker:SetNW2Entity("snaptic.ragdoll", nil)
    ragdoll:SetNW2Entity("snaptic.ragdoll", nil)

    local r = Ragdoll.registry
    for i=1, #r do
        if r[i] == ragdoll then
            table.remove(r, i)
            break
        end
    end

	invoker:SetVelocity(ragdoll:GetVelocity())
    invoker:SetPos(ragdoll:GetPos() + ragdoll:OBBCenter())
	ragdoll:RemoveCallOnRemove("Snaptic_Ragdoll")
	ragdoll:Remove()
end

-- if ragdolled player somehow respawns, make them spectate their ragdoll again
hook.Add("PlayerSpawn", "Snaptic_Ragdoll", function(invoker)
	if not Ragdoll.GetRagdoll(invoker) then return end
	timer.Simple(0, function()
		if not invoker:IsValid() then return end
        local ragdoll = Ragdoll.GetRagdoll(invoker)
		if not ragdoll then return end
		Ragdoll.Spectate(invoker, ragdoll)
	end)
end)

hook.Add("PlayerDeath", "Snaptic_Ragdoll", function(victim, inflictor, attacker)
    local ragdoll = Ragdoll.GetRagdoll(victim)
    if not IsValid(ragdoll) then return end
    Ragdoll.UnSpectate(victim)
    victim:SetPos(ragdoll:GetPos())
    victim:Dissolve()
    victim:SetNW2Entity("snaptic.ragdoll", nil)
    ragdoll:SetNW2Entity("snaptic.ragdoll", nil)

    local r = Ragdoll.registry
    for i=1, #r do
        if r[i] == ragdoll then
            table.remove(r, i)
            break
        end
    end

    ragdoll:RemoveCallOnRemove("Snaptic_Ragdoll")
    Snaptic.Helpers.Boxify(ragdoll)
    ragdoll:Dissolve()
    timer.Simple(5, function()
        if not IsValid(ragdoll) then return end
        ragdoll:Remove()
    end)
end)

hook.Add("PlayerSilentDeath", "Snaptic_Ragdoll", function(victim)
    local ragdoll = Ragdoll.GetRagdoll(victim)
    if not IsValid(ragdoll) then return end

    Ragdoll.UnSpectate(victim)
    victim:SetPos(ragdoll:GetPos())
    victim:SetNW2Entity("snaptic.ragdoll", nil)
    ragdoll:SetNW2Entity("snaptic.ragdoll", nil)

    local r = Ragdoll.registry
    for i=1, #r do
        if r[i] == ragdoll then
            table.remove(r, i)
            break
        end
    end

    ragdoll:RemoveCallOnRemove("Snaptic_Ragdoll")
    Snaptic.Helpers.Boxify(ragdoll)
    ragdoll:Dissolve()
    timer.Simple(5, function()
        if not IsValid(ragdoll) then return end
        ragdoll:Remove()
    end)
end)

-- if ragdolled player disconnected, delete their ragdoll
hook.Add("PlayerDisconnected", "Snaptic_Ragdoll", function(invoker)
    local r = Ragdoll.registry
    local c = 0
    for i=1, #r do
        local ragdoll = r[i-c]
        if not IsValid(ragdoll) then
            table.remove(r, i-c) c = c + 1
            continue
        end
        if ragdoll.caller == invoker then
            ragdoll:Remove()
        end
    end

    local ragdoll = Ragdoll.GetRagdoll(invoker)
	if not ragdoll then return end
	ragdoll:RemoveCallOnRemove("Snaptic_Ragdoll")
	ragdoll:Remove()
end)

hook.Add("CanPlayerSuicide", "Snaptic_Ragdoll", function(invoker)
    local ragdoll = Ragdoll.GetRagdoll(invoker)
	if not ragdoll then return end
    return false
end)

hook.Add("EntityTakeDamage", "Snaptic_Ragdoll", function(target, dmginfo)
    local controller = Ragdoll.GetController(target)
    if controller then
        controller:TakeDamageInfo(dmginfo)
        return true
    end
end)

hook.Add("Think", "Snaptic_Ragdoll", function()
    local st = SysTime()
    local r = Ragdoll.registry
    local c = 0
    for i=1, #r do
        local ragdoll = r[i-c]
        if not IsValid(ragdoll) then
            table.remove(r, i-c) c = c + 1
            continue
        end
        local controller = Ragdoll.GetController(ragdoll)
        if IsValid(controller) then
            if controller:GetObserverTarget() ~= ragdoll then
                Ragdoll.Spectate(controller, ragdoll)
            end
        end
        if ragdoll.duration ~= 0 and ragdoll.time + ragdoll.duration < st then
            ragdoll:Remove()
        end
    end

    for k, v in player.Iterator() do
        if v.Snaptic_Spectating and IsValid(v.Snaptic_Spectating) then
            local observer_target = v:GetObserverTarget()
            if observer_target ~= v.Snaptic_Spectating then
                Ragdoll.Spectate(v, v.Snaptic_Spectating)
            end
            v:SetPos(v.Snaptic_Spectating:GetPos())
        end
    end
end)

hook.Add("StartCommand", "Snaptic_Ragdoll", function(invoker, cmd)
    local ragdoll = Ragdoll.GetRagdoll(invoker)
	if not ragdoll then return end
    local buttons = cmd:GetButtons()
    if not ragdoll.last_buttons then
        ragdoll.last_buttons = 0
        ragdoll.pressed_count = 0
    end
    if buttons ~= ragdoll.last_buttons then
        ragdoll.last_pressed = SysTime()
        ragdoll.pressed_count = ragdoll.pressed_count + 1
        ragdoll.last_buttons = buttons

        for i = 1, ragdoll:GetPhysicsObjectCount() - 1 do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            if not IsValid(phys) then continue end

            local boneid = ragdoll:TranslatePhysBoneToBone(i)
            if boneid < 0 then continue end

            local matrix = invoker:GetBoneMatrix(boneid)
            if not matrix then continue end

            phys:AddVelocity(VectorRand(-250, 250))
        end

        EmitSound("Flesh.ImpactSoft", ragdoll:GetPos())

        if ragdoll.pressed_count > (1/engine.TickInterval()) * Ragdoll.CVAR_Ragdoll_Struggle:GetFloat() then
            Ragdoll.Stop(invoker)
        end
    end
end)