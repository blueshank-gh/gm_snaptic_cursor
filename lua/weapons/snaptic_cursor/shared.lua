Snaptic = SWEP -- globalize this since a lot of Snaptic's code should be shared

-- Some of you may notice the redundancy code for DTSetup and Initialize.
-- This is intentional if you plan on using Dev-IDEs like Mortis to hot-load this addon.

local exists = weapons.GetStored("snaptic_cursor_handle")
if not exists or not exists.Operators then
    SWEP.Operators = {}
else
    SWEP.Operators = exists.Operators
end

SWEP.PrintName = "Snaptic's Cursor"
SWEP.Instructions = "X + Δ + R2"
SWEP.Author = "BlueShank"
SWEP.Contact = "abuse@msn.com" -- don't actually contact this :rofl:
SWEP.Category = "Other"
SWEP.IconOverride = "snaptic/snaptic_cursor.png"

SWEP.Spawnable = true
SWEP.ViewModel = ""
SWEP.WorldModel = ""

SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Primary = {}
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary = {}
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:SetupDataTables()
    if self.DTSetup then return end
    self.DTSetup = true

    -- Features
	self:NetworkVar("Bool", 0, "Debug")
	self:NetworkVar("Bool", 1, "Always")
	self:NetworkVar("Bool", 2, "Drag")
	self:NetworkVar("Bool", 3, "Auto")

    -- Drag
    self:NetworkVar("Entity", 0, "DragCursor")
	self:NetworkVar("Entity", 1, "DragEntity")
	self:NetworkVar("Int", 0, "DragPhysBone")
	self:NetworkVar("Vector", 0, "DragLocalPos")
	self:NetworkVar("Angle", 0, "DragLocalAng")
	self:NetworkVar("Float", 0, "DragDistance")

    if SERVER then
        self:SetDebug(false)
        self:SetDrag(true)
        self:SetAuto(false)
        self:SetAlways(false)
    end
end

function SWEP:Initialize()
    if self.Initialized then return end

    local operators = Snaptic.Operators
    if not operators[self] then
        operators[#operators+1] = self
        operators[self] = true
    end

    self.Cursors = {} -- list of cursor entities we have

    self:SetMoveType(MOVETYPE_NONE)
    self:SetHoldType("magic")

    self.Initialized = true

    timer.Simple(0, function()
        if not IsValid(self) then return end
        if not IsValid(self:GetOwner()) then self:Remove() end
        if not self.DTSetup then -- live-loading
            self:InstallDataTable()
            self:SetupDataTables()
            print("[Snaptic] Installed Datatables (seems we where live-loaded?)")
        end
    end)
end

function SWEP:TraceLine(options, invoker, ...)
    local owner = invoker or self:GetOwner()
    if not IsValid(owner) then return end
    local cursors = self.Cursors
    cursors[#cursors+1] = owner
    cursors[#cursors+1] = self
    local t = {...}
    for i=1, #t do
        cursors[#cursors+1] = t[i]
    end
    options.filter = cursors
    local tr = util.TraceLine(options)
    table.remove(cursors, #cursors)
    table.remove(cursors, #cursors)
    for i=1, #t do
        table.remove(cursors, #cursors)
    end
    return tr
end

function SWEP:CanDrag(entity)
    if not IsValid(entity) then return false end
    local owner = self:GetOwner()
    local interaction = hook.Run("Snaptic.Interact", owner, self, entity)
    if interaction ~= nil then return interaction end
    if entity == owner then return true end
    if entity.CPPIGetOwner then
        if entity:CPPIGetOwner() ~= owner then
            return hook.Run("PhysgunPickup", owner, entity)
        end
    elseif entity:GetOwner() ~= owner then
        return hook.Run("PhysgunPickup", owner, entity)
    end
    return true
end

function SWEP:IsDragging()
    local ent = self:GetDragEntity()
    if self:CanDrag(ent) then
        return ent
    end
end

-- TODO: We should mimic CBasePlayer::FindUseEntity, wonder why we don't just have a hook to modify FindUseEntity scanning...
hook.Add("FindUseEntity", "Snaptic.Use", function(invoker, entity)
    local operator = invoker:GetWeapon("snaptic_cursor")
    if not IsValid(operator) then return end
    local active = invoker:GetActiveWeapon()
    if operator:GetAlways() or active == operator then
        local ep = invoker:GetShootPos()
        local tr = operator:TraceLine({
            start = ep,
            endpos = ep + invoker:GetAimVector() * 72,
        })

        local target = tr.Entity
        if IsValid(target) then
            if target:IsPlayer() then
                if SERVER then
                    target:EmitSound("snaptic/aol_yougotmail.mp3")
                end
            end
            return target
        end
    end
end)

-- CAMI Support
if CAMI then
    CAMI.RegisterPrivilege({
        Name = "snaptic_cursor",
        MinAccess = "superadmin"
    })
end

if SERVER then -- Helpers
    AddCSLuaFile("helpers.lua")
end
include("helpers.lua")

if SERVER then -- Context
    AddCSLuaFile("context/shared.lua")
end
include("context/shared.lua")

if SERVER then -- Cursor
    AddCSLuaFile("cursor/shared.lua")
end
include("cursor/shared.lua")

if SERVER then -- Ragdoll
    AddCSLuaFile("ragdoll/shared.lua")
end
include("ragdoll/shared.lua")

if SERVER then -- SWEP
    include("server.lua")
    AddCSLuaFile("client.lua")
else
    include("client.lua")
end

print("[Snaptic] Operators are ready.")