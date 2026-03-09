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
    if lives >= self.MaxLives and durability >= self.MaxDurability then return end
    durability = durability + self.DurabilityRegen
    if durability > self.MaxDurability and lives < 4 then
        lives = lives + 1
        durability = self.DurabilityRegen
    end
    durability = math.Clamp(durability, 0, 1000)
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
    durability = math.Clamp(durability - damage, 0, self.MaxDurability)
    self:EmitSound("eli_lab.al_buttonPunch")

    if durability == 0 then
        self:EmitSound("Buttons.snd11")
        lives = lives - 1
        durability = self.MaxDurability
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