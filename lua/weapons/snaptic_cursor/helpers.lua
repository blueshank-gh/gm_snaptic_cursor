local SWEP = SWEP or Snaptic
SWEP.Helpers = {}
local Helpers = SWEP.Helpers

-- This... looks really... bad... :cry:

function Helpers.DebugVariables(entity)
    local dt = {}
    if not entity.GetNetworkVars then return dt end
    local name, datatable = debug.getupvalue(entity.GetNetworkVars, 1)
    if name ~= "datatable" then return entity:GetNetworkVars() or dt end
    for k, v in pairs(datatable) do
        if ( v.element ) then
            dt[ k ] = v.GetFunc( entity, v.index )[ v.element ]
        else
            dt[ k ] = v.GetFunc( entity, v.index )
        end
    end
    return dt
end

function Helpers.OBBRadius(entity)
    local maxs = entity:OBBMaxs()
    local mins = entity:OBBMins()
    return math.min(
        math.abs(maxs.x),
        math.abs(maxs.y),
        math.abs(mins.x),
        math.abs(mins.y)
    )
end

function Helpers.OBBCenter(entity)
    return entity:GetPos() + entity:OBBCenter()
end

local props = {
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/wood_crate001a_damaged.mdl"
}

Helpers.Boxify = function(invoker)
    if CLIENT then return end -- server-only
    invoker:EmitSound("snaptic/bowling_pins.mp3")

    local center = invoker:GetPos() + invoker:OBBCenter()
    local cache = {}
    
    for i=1, 15 do
        local death_prop = ents.Create("prop_physics")
        death_prop:SetModel(props[math.random(1, #props)])
        death_prop:SetPos(center + Vector(math.random(-10, 10), math.random(-10, 10), math.random(5, 10)))
        death_prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        death_prop:Activate()
        death_prop:Spawn()
        local dir = (death_prop:GetPos() - center):GetNormalized()
        local phys = death_prop:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(dir * math.random(1000, 2000) * phys:GetMass())
            phys:ApplyTorqueCenter(Vector(math.random(-1,1),math.random(-1,1),math.random(-1,1)) * math.random(500, 1000) * phys:GetMass())
        end
        cache[#cache+1] = death_prop
    end

    timer.Simple(3, function()
        for i=1, #cache do
            local entry = cache[i]
            if IsValid(entry) then
                entry:Fire("break",1,0)
            end
        end
    end)

    timer.Simple(4, function()
        for i=1, #cache do
            local entry = cache[i]
            if IsValid(entry) then
                entry:Remove()
            end
        end
    end)
end

local damage_types = {
    DMG_GENERIC, DMG_PHYSGUN, DMG_BLAST, DMG_SHOCK, DMG_MISSILEDEFENSE, DMG_AIRBOAT, DMG_BURN, DMG_BULLET
}
local cycle = 1
Helpers.Annihilate = function(invoker, entity, damage)
    if entity:IsPlayer() or entity:IsNPC() then
        local d = DamageInfo()
        d:SetDamage(damage or 100)
        d:SetDamagePosition(entity:GetPos() + entity:OBBCenter())
        d:SetDamageForce(((entity:GetPos() + entity:OBBCenter()) - invoker:EyePos()) * 100)
        d:SetAttacker(invoker)
        d:SetInflictor(invoker)
        d:SetDamageCustom(6969)
        if entity:IsPlayer() then
            entity:ExitVehicle()
            entity:SetMoveType(MOVETYPE_WALK)
            entity:Freeze(false)
            entity:GodDisable()
        end
        local dmgt = damage_types[cycle]
        d:SetDamageType(bit.bor(DMG_DISSOLVE, DMG_ALWAYSGIB, dmgt))
        entity:TakeDamageInfo(d)
        cycle = cycle + 1
        if cycle > #damage_types then cycle = 1 end
        Helpers.Click(entity:GetPos() + entity:OBBCenter())
    elseif entity.Health then
        local d = DamageInfo()
        d:SetDamage(damage or 100)
        d:SetDamagePosition(entity:GetPos() + entity:OBBCenter())
        d:SetDamageForce(((entity:GetPos() + entity:OBBCenter()) - invoker:EyePos()) * 100)
        d:SetAttacker(invoker)
        d:SetInflictor(invoker)
        d:SetDamageCustom(6969)
        local dmgt = damage_types[cycle]
        d:SetDamageType(bit.bor(DMG_DISSOLVE, DMG_ALWAYSGIB, dmgt))
        entity:TakeDamageInfo(d)
        cycle = cycle + 1
        if cycle > #damage_types then cycle = 1 end
        Helpers.Click(entity:GetPos() + entity:OBBCenter())
    end
end

Helpers.Obliterate = function(invoker, victim)
    if victim:IsPlayer() then
        Helpers.Boxify(victim)
        victim:KillSilent()
    end
end

local MIN_DIST = 40
local MAX_DIST = 56756
Helpers.MIN_DIST = MIN_DIST
Helpers.MAX_DIST = MAX_DIST
function Helpers.GetTargetEntity(ent)
    local parent = ent:GetParent()
    if parent:IsValid() then return Helpers.GetTargetEntity(parent) end
    return ent
end

-- movetypes that make a player tough to move
local movetypes = {
    [MOVETYPE_NONE] = true,
    [MOVETYPE_NOCLIP] = true,
    [MOVETYPE_STEP] = true,
    [MOVETYPE_FLY] = true,
    [MOVETYPE_PUSH] = true,
    [MOVETYPE_LADDER] = true
}

local PLY_MASS = 85
local MAX_MASS = 1000
Helpers.PLY_MASS = PLY_MASS
Helpers.MAX_MASS = MAX_MASS
function Helpers.GetMass(phys)
    if not phys:IsMoveable() or not phys:IsMotionEnabled() then return math.huge end -- frozen physobj
    local ent = phys:GetEntity()
    if movetypes[ent:GetMoveType()] then return math.huge end -- tough to move
    if ent:IsWorld() then return math.huge end
    if ent:IsFlagSet(FL_FROZEN) then return math.huge end -- frozen player
    if ent:IsPlayer() then return PLY_MASS end
    return phys:GetMass()
end

local SPEED_LIMIT = 4000
Helpers.SPEED_LIMIT = SPEED_LIMIT
function Helpers.CheckEntityVelocity(vel)
    if vel.x > -SPEED_LIMIT and vel.x < SPEED_LIMIT and
        vel.y > -SPEED_LIMIT and vel.y < SPEED_LIMIT and
        vel.z > -SPEED_LIMIT and vel.z < SPEED_LIMIT
    then return end
    vel:Mul(SPEED_LIMIT / vel:Length())
end

function Helpers.Click(position)
    EmitSound("snaptic/click.mp3", position, 0, CHAN_AUTO, 1, 75, 0, 100 + math.random(-25, 25))
end

function Helpers.Click_Meme(position)
    EmitSound("snaptic/click_meme.mp3", position, 0, CHAN_AUTO, 1, 75, 0, 100 + math.random(-25, 25))
end