local ENT = _ENT
if not ENT then
    print("[Snaptic] to reload this file, please reload the shared.lua")
    return
end

function ENT:Think()
    if not self.GetOperator then
        if not self.DTSetup then
            self:InstallDataTable()
            self:SetupDataTables()
        end

        return
    end

    if not self.Initialized then
        self:Initialize()
        return
    end

    local operator = self:GetOperator()
    local ct = CurTime()
    local st = SysTime()

    self:NextThink(ct)
    
    if not IsValid(operator) or not operator:IsWeapon() then
        print(1)
        self:Remove()
        return
    end

    local owner = operator:GetOwner()
    if not IsValid(owner) then
        print(2)
        self:Remove()
        return
    end

    if not self:Validate() then
        print(3)
        self:Remove()
        return
    end

    if self:GetMoveType() ~= MOVETYPE_VPHYSICS then
        self:SetMoveType(MOVETYPE_VPHYSICS)
    end
end

function ENT:Validate()
    if IsValid(self:GetPlayer()) or self.duplication then
        return true
    end
    return false
end

function ENT:Compress(target, trace)
    if target:IsPlayer() then
        Snaptic.Ragdoll.Spectate(target, self)
        self:SetPlayer(target)
        self:SetMin(target:OBBMins())
        self:SetMax(target:OBBMaxs())
    else
        local operator = self:GetOperator()
        if not IsValid(operator) then return false end
        local owner = operator:GetOwner()
        local state = hook.Run("CanTool", owner, trace, "duplicator", target, IN_ATTACK2)
        if state == false then return false end
        duplicator.SetLocalAng(Angle(0,self:GetAngles().y,0))
        local vec = self:GetPos()
        duplicator.SetLocalPos(vec)
        local duplication = duplicator.Copy(target)
        duplicator.SetLocalPos(vector_origin)
	    duplicator.SetLocalAng(angle_zero)
        local min, max = duplicator.WorkoutSize(duplication.Entities)
        self:SetMin(min)
        self:SetMax(max)
        for k, v in pairs(duplication.Entities) do
            local ent = Entity(k)
            if IsValid(ent) then
                if ent.CPPIGetOwner then
                    v.__ownership = ent:CPPIGetOwner()
                end
                ent:Remove()
            end
        end
        self.duplication = duplication
    end
    self:SetActive(true) -- TODO: don't think this is really necessary?
    self:EmitSound("snaptic/apple_pay.mp3")
    return true
end

function ENT:Decompress(position, angle)
    self:SetActive(false)
    if IsValid(self:GetPlayer()) then
        local target = self:GetPlayer()
        self:SetPlayer(NULL)
        Snaptic.Ragdoll.UnSpectate(target)
        if position then target:SetPos(position) end
    elseif self.duplication then
        local duplication = self.duplication
        self.duplication = nil

        local operator = self:GetOperator()
        if not IsValid(operator) then return end
        local owner = operator:GetOwner()
        duplicator.SetLocalAng(angle or Angle(0,self:GetAngles().y,0))
        duplicator.SetLocalPos(position or self:GetPos())
        local entities = duplicator.Paste(owner, duplication.Entities, duplication.Constraints)
        duplicator.SetLocalPos(vector_origin)
	    duplicator.SetLocalAng(angle_zero)
        undo.Create("Archive")
            for k, ent in pairs(entities) do
                local entry = duplication.Entities[k]
                if entry and IsValid(entry.__ownership) then
                    undo.AddEntity(ent)
                    owner:AddCleanup("duplicates", ent)
                    if ent.CPPISetOwner then
                        ent:CPPISetOwner(entry.__ownership)
                    end
                else
                    ent:Remove()
                end
            end
            undo.SetPlayer(owner)
            undo.SetCustomUndoText("Undone #undo.duplication")
        undo.Finish("#undo.duplication (" .. tostring(table.Count(entities)) ..  ")")
    end

    self:EmitSound("snaptic/apple_pay.mp3")
end

function ENT:TakeDamage(damage, attacker, inflictor)
    local dmg = DamageInfo()
    dmg:SetDamage(damage)
    dmg:SetAttacker(attacker or game.GetWorld())
    dmg:SetInflictor(inflictor or game.GetWorld())
    self:OnTakeDamage(dmg)
end

function ENT:OnTakeDamage(cdmg)
    local target = self:GetPlayer()
    if IsValid(target) then target:TakeDamageInfo(cdmg) end
end

hook.Add("PlayerDeath", "Snaptic_Archive", function(victim, inflictor, attacker)
    local archive = victim:GetObserverTarget()
    if not IsValid(archive) or archive:GetClass() ~= "snaptic_archive" then return end
    Snaptic.Helpers.Boxify(archive)
    archive:Remove()
end)

hook.Add("PlayerSilentDeath", "Snaptic_Archive", function(victim)
    local archive = victim:GetObserverTarget()
    if not IsValid(archive) or archive:GetClass() ~= "snaptic_archive" then return end
    archive:Remove()
end)

hook.Add("CanPlayerSuicide", "Snaptic_Archive", function(invoker)
    local archive = invoker:GetObserverTarget()
    if not IsValid(archive) or archive:GetClass() ~= "snaptic_archive" then return end
    return false
end)

hook.Add("PlayerDisconnected", "Snaptic_Archive", function(invoker)
    local archive = invoker:GetObserverTarget()
    if not IsValid(archive) or archive:GetClass() ~= "snaptic_archive" then return end
	archive:Remove()
end)

local snd = {
    "physics/metal/metal_barrel_impact_soft1.wav",
    "physics/metal/metal_barrel_impact_soft2.wav",
    "physics/metal/metal_barrel_impact_soft3.wav"
}

hook.Add("StartCommand", "Snaptic_Archive", function(invoker, cmd)
    local archive = invoker:GetObserverTarget()
    if not IsValid(archive) or archive:GetClass() ~= "snaptic_archive" then return end
    local buttons = cmd:GetButtons()
    if not archive.last_buttons then
        archive.last_buttons = 0
        archive.pressed_count = 0
    end
    if buttons ~= archive.last_buttons then
        archive.last_pressed = SysTime()
        archive.pressed_count = archive.pressed_count + 1
        archive.last_buttons = buttons

        local phys = archive:GetPhysicsObject()
        if IsValid(phys) then
            phys:AddAngleVelocity(VectorRand(-750, 750))
        end

        EmitSound(snd[math.random(1, #snd)], archive:GetPos())

        if archive.pressed_count > (1/engine.TickInterval()) * ENT.CVAR_Struggle:GetFloat() then
            invoker:EmitSound("physics/metal/metal_box_break1.wav")
            archive:Remove()
        end
    end
end)