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
        self:Remove()
        return
    end

    local owner = operator:GetOwner()
    if not IsValid(owner) then
        self:Remove()
        return
    end

    if self:GetRelative() then
        local relative = self:GetRelation()
        if not IsValid(relative) then
            self:Remove()
            return
        end

        if relative:IsPlayer() and not relative:Alive() then
            self:Remove()
            return
        end
    end

    if self:GetMoveType() ~= MOVETYPE_VPHYSICS then
        self:SetMoveType(MOVETYPE_VPHYSICS)
    end
end

function ENT:TakeDamage(damage, attacker, inflictor)
    local dmg = DamageInfo()
    dmg:SetDamage(damage)
    dmg:SetAttacker(attacker or game.GetWorld())
    dmg:SetInflictor(inflictor or game.GetWorld())
    self:OnTakeDamage(dmg)
end

function ENT:OnTakeDamage(cdmg)
end