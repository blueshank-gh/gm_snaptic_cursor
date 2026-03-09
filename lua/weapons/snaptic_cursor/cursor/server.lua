local ENT = _ENT
if not ENT then
    print("[Snaptic] to reload this file, please reload the shared.lua")
    return
end

function ENT:Regenerate()
    local ct = CurTime()
    if self:GetImmunity() > ct then return end
    local durability = self:GetDurability()
    local lives = self:GetLives()
    if lives >= self.CVAR_Lives:GetInt() and durability >= self.CVAR_Durability:GetFloat() then return end
    durability = durability + self.CVAR_DurabilityRegen:GetFloat()
    if durability > self.CVAR_Durability:GetFloat() and lives < 4 then
        lives = lives + 1
        durability = self.CVAR_DurabilityRegen:GetFloat()
    end
    durability = math.Clamp(durability, 0, self.CVAR_Durability:GetFloat())
    self:SetLives(lives)
    self:SetDurability(durability)
end

function ENT:TakeDamage(damage, attacker, inflictor)
    local dmg = DamageInfo()
    dmg:SetDamage(damage)
    dmg:SetAttacker(attacker or game.GetWorld())
    dmg:SetInflictor(inflictor or game.GetWorld())
    self:OnTakeDamage(dmg)
end

function ENT:OnTakeDamage(cdmg)
    local ct = CurTime()
    if self:GetImmunity() > ct then return end
    self.last_damage = ct
    local damage = cdmg:GetDamage()
    local durability = self:GetDurability()
    local lives = self:GetLives()
    durability = math.Clamp(durability - damage, 0, self.CVAR_Durability:GetFloat())
    self:EmitSound("eli_lab.al_buttonPunch")

    if durability == 0 then
        self:EmitSound("Buttons.snd11")
        lives = lives - 1
        durability = self.CVAR_Durability:GetFloat()
        self:SetImmunity(ct + 1)
    end

    if lives == 0 then
        self:EmitSound("Glass.Break")
        self:Remove() -- for now
        return
    end

    self:SetLives(lives)
    self:SetDurability(durability)
end

function ENT:Hide()
    if self:GetHidden() then return end
    self:SetHidden(true)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    timer.Simple(0, function()
        if not IsValid(self) then return end
        self:SetPos(Vector(0, 0, 0))
    end)
end

function ENT:Show()
    if not self:GetHidden() then return end
    self:SetHidden(false)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:SetupPhysics()
    local operator = self:GetOperator()
    if not IsValid(operator) then return end
    self:SetPos(operator:GetPos())
end

function ENT:Use(activator, caller, useType, value)
    local operator = self:GetOperator()
    if not operator then return end
    local st = SysTime()
    local ct = CurTime()
    local diff = (activator:GetPos() + activator:OBBCenter()) - self:GetPos()
    if diff:Length() > 200 then return end
    if self:GetEmote() + 1.5 > ct then return end
    if activator:IsPlayer() and activator ~= operator:GetOwner() then
        self:SetEmote(ct)
        self:EmitSound("snaptic/single_clap.mp3", 75, 150 + math.random(-50, 50))
        activator:SetGroundEntity()
        activator:SetMoveType(MOVETYPE_WALK)
        activator:SetVelocity(diff:GetNormalized() * 500)
    end
end

function ENT:Zipify(target)
    if target:IsPlayer() then
        self.zip = target
        Snaptic.Ragdoll.Spectate(target, self)
        self:SetZippedMin(target:OBBMins())
        self:SetZippedMax(target:OBBMaxs())
    else
        local operator = self:GetOperator()
        if not IsValid(operator) then return end
        local owner = operator:GetOwner()
        duplicator.SetLocalAng(Angle(0,self:GetAngles().y,0))
        local vec = self:GetPos()
        vec.z = owner:GetPos().z
        duplicator.SetLocalPos(vec)
        local zip = duplicator.Copy(target)
        duplicator.SetLocalPos(vector_origin)
	    duplicator.SetLocalAng(angle_zero)
        local min, max = duplicator.WorkoutSize(zip.Entities)
        self:SetZippedMin(min)
        self:SetZippedMax(max)
        for k, v in pairs(zip.Entities) do
            local ent = Entity(k)
            if IsValid(ent) then ent:Remove() end
        end
        self.zip = zip
    end
    self:SetZipped(true)
    self:EmitSound("snaptic/apple_pay.mp3")
end

function ENT:UnZipify(position, angle)
    if not self.zip then return end
    self:SetZipped(false)
    local zip = self.zip
    self.zip = nil

    if isentity(zip) then
        if zip:IsPlayer() then
            Snaptic.Ragdoll.UnSpectate(zip)
            if position then
                zip:SetPos(position)
            end
        end
    else
        local operator = self:GetOperator()
        if not IsValid(operator) then return end
        local owner = operator:GetOwner()
        duplicator.SetLocalAng(angle or Angle(0,self:GetAngles().y,0))
        duplicator.SetLocalPos(position or self:GetPos())
        local Ents = duplicator.Paste(owner, zip.Entities, zip.Constraints)
        duplicator.SetLocalPos(vector_origin)
	    duplicator.SetLocalAng(angle_zero)
        undo.Create("Zipify")
            for k, ent in pairs(Ents) do
                undo.AddEntity(ent)
            end
            for k, ent in pairs(Ents)	do
                owner:AddCleanup("duplicates", ent)
            end
            undo.SetPlayer(owner)
            undo.SetCustomUndoText("Undone #undo.duplication")
        undo.Finish("#undo.duplication (" .. tostring( table.Count( Ents ) ) ..  ")")
    end
    self:EmitSound("snaptic/apple_pay.mp3")
end