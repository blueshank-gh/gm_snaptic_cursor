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
SWEP.Snaptic = true

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
	self:NetworkVar("Entity", 0, "Context")
    self:NetworkVar("Entity", 1, "DragCursor")
	self:NetworkVar("Entity", 2, "DragEntity")
	self:NetworkVar("Int", 0, "DragPhysBone")
	self:NetworkVar("Vector", 0, "DragLocalPos")
	self:NetworkVar("Angle", 0, "DragLocalAng")
	self:NetworkVar("Float", 0, "DragDistance")
    self:NetworkVar("Float", 1, "Balance") -- block certain feature

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

do
    SWEP.CVAR_SuperAdmin = CreateConVar(
        "snaptic_cursor_superadmin",
        "1",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Allows superadmins to use the cursors.",
        0, 1
    )

    SWEP.CVAR_SuperAdmin_Players = CreateConVar(
        "snaptic_cursor_superadmin_players",
        "1",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Allows superadmins to target all players regardless.",
        0, 1
    )

    SWEP.CVAR_Admin = CreateConVar(
        "snaptic_cursor_admin",
        "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Allows admins to use the cursors.",
        0, 1
    )

    SWEP.CVAR_Admin_Players = CreateConVar(
        "snaptic_cursor_admin_players",
        "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Allows admins to target all players regardless.",
        0, 1
    )

    SWEP.CVAR_Ragdoll_Duration = CreateConVar(
        "snaptic_cursor_ragdoll_duration",
        "5",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "How long (in seconds) a player can be stuck in ragdoll after being dunked on.",
        1, 60
    )

    SWEP.CVAR_Ragdoll_Self = CreateConVar(
        "snaptic_cursor_ragdoll_self",
        "1",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "If ragdoll slamming can also inflict the user themselves.",
        0, 1
    )

    SWEP.CVAR_Balance = CreateConVar(
        "snaptic_cursor_balance",
        "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Disables certain features in seconds when taking damage.",
        0, 60 * 60
    )

    SWEP.CVAR_Damage = CreateConVar(
        "snaptic_cursor_damage",
        "100",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "If the % of damage caused by whiplash and impacts.",
        0, 10000
    )

    SWEP.CVAR_Damage_Ragdoll = CreateConVar(
        "snaptic_cursor_damage_ragdoll",
        "1",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "If we should ragdoll players for slam damage.",
        0, 1
    )

    SWEP.CVAR_Damage_Ragdoll_Light = CreateConVar(
        "snaptic_cursor_damage_ragdoll_light",
        "50",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Amount of damage needed to ragdoll from light damage.",
        0, 10000
    )

    SWEP.CVAR_Damage_Ragdoll_Heavy = CreateConVar(
        "snaptic_cursor_damage_ragdoll_heavy",
        "100",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Amount of damage needed to ragdoll from heavy damage.",
        0, 10000
    )

    SWEP.CVAR_Damage_Constant = CreateConVar(
        "snaptic_cursor_damage_constant",
        "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Damage that is applied consistantly when picked up.",
        0, 10000
    )

    SWEP.CVAR_Damage_Rate = CreateConVar(
        "snaptic_cursor_damage_rate",
        "500",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Rate at which constant damage is applied in milliseconds.",
        0, 10000
    )

    SWEP.CVAR_Double_Click = CreateConVar(
        "snaptic_cursor_double_click",
        "500",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Rate at which a double click is registered in milliseconds.",
        0, 1000
    )

    if CLIENT then
        SWEP.CVAR_Always = CreateClientConVar("snaptic_cursor_always", "0", true, true)
        SWEP.CVAR_Drag = CreateClientConVar("snaptic_cursor_drag", "1", true, true)
        SWEP.CVAR_Auto = CreateClientConVar("snaptic_cursor_auto", "0", true, true)
    end
end

function SWEP:InBalance()
    return self:GetBalance() + self.CVAR_Balance:GetFloat() > CurTime()
end

local usable = {
    ["prop_door_rotating"] = true,
    ["func_button"] = true
}

function SWEP:CanDrag(entity)
    if not IsValid(entity) then return false end
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end -- This should never happen...
    local class = entity:GetClass()
    if usable[class] then return false end
    local interaction = hook.Run("Snaptic.Interact", owner, self, entity)
    if interaction ~= nil then return interaction end
    if entity == owner then return true end
    if entity:IsPlayer() then
        if owner:IsAdmin() and self.CVAR_Admin_Players:GetBool() then
            return true
        elseif owner:IsSuperAdmin() and self.CVAR_SuperAdmin_Players:GetBool() then
            return true
        end
    end
    if entity:GetClass() == "snaptic_archive" then return true end
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
        if operator:IsDragging() then
            return game.GetWorld() -- may not be a good idea...?
        end

        local ep = invoker:GetShootPos()
        local tr = operator:TraceLine({
            start = ep,
            endpos = ep + invoker:GetAimVector() * (72 + 32),
        })

        local target = tr.Entity
        if IsValid(target) then
            if target:IsPlayer() then
                if SERVER and (not target.Snaptic_Use or target.Snaptic_Use + engine.TickInterval() * 2 < CurTime()) then
                    target:EmitSound("snaptic/aol_yougotmail.mp3")
                end
                target.Snaptic_Use = CurTime() -- debounce so that... it doesn't spam...
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

if SERVER then -- File
    AddCSLuaFile("file/shared.lua")
end
include("file/shared.lua")

if SERVER then -- Archive
    AddCSLuaFile("archive/shared.lua")
end
include("archive/shared.lua")

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