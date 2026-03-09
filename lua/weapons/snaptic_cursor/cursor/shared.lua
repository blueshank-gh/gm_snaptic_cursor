_ENT = {}
local ENT = _ENT

local exists = scripted_ents.GetStored("snaptic_cursor_handle")
if not exists or not exists.t or not exists.t.Cursors then
    ENT.Cursors = {} -- global cursors array
else
    ENT.Cursors = exists.t.Cursors
end

ENT.Type = "anim"
ENT.PrintName		= "Snaptic's Cursor"
ENT.Spawnable		= false
ENT.AdminSpawnable	= false
ENT.Category		= "Other"
ENT.AutomaticFrameAdvance = true
ENT.Author          = "BlueShank"

ENT.Types = { -- this is also used to check if it should use a selected mode, defaulting to "arrow"
    arrow = Material("materials/snaptic/aero_arrow.png"),
    helpsel = Material("materials/snaptic/aero_helpsel.png"),
    link = Material("materials/snaptic/aero_link.png"),
    pen = Material("materials/snaptic/aero_pen.png"),
    pen_center = Material("materials/snaptic/aero_pen_center.png"),
    unavail = Material("materials/snaptic/aero_unavail.png"),
    hand_open = Material("materials/snaptic/aero_hand_open.png"),

    move = Material("materials/snaptic/aero_move.png"),
    ew = Material("materials/snaptic/aero_ew.png"),
    nesw = Material("materials/snaptic/aero_nesw.png"),
    ns = Material("materials/snaptic/aero_ns.png"),
    nwse = Material("materials/snaptic/aero_nwse.png"),
}
ENT.Types_RND = {}
for k, v in pairs(ENT.Types) do
    ENT.Types_RND[#ENT.Types_RND+1] = k
end

do
    ENT.CVAR_Lives = CreateConVar(
        "snaptic_cursor_lives", "4",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Maximum number of i-frame lives for the cursors.",
        1, 10
    )

    ENT.CVAR_Durability = CreateConVar(
        "snaptic_cursor_durability", "2000",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCARF_NOTIFY },
        "Maximum durability of the cursors.",
        100, 100000
    )

    ENT.CVAR_DurabilityRegen = CreateConVar(
        "snaptic_cursor_durabilityregen", "250",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "How much durability is restored each regeneration tick.",
        1, 100000
    )

    ENT.CVAR_RegenCooldown = CreateConVar(
        "snaptic_cursor_regencooldown",
        "10",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "Delay (in seconds) before durability regeneration can begin.",
        0, 60
    )

    ENT.CVAR_RegenDelay = CreateConVar(
        "snaptic_cursor_regendelay",
        "5",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "How often (in seconds) a regeneration tick occurs.",
        0, 60
    )
end

function ENT:SetupPhysics()
    self:SetMoveType(MOVETYPE_NONE)
    if SERVER then self:SetUseType(SIMPLE_USE) end
    self:PhysicsInit(SOLID_VPHYSICS)
    -- self:SetMoveType(MOVETYPE_VPHYSICS) -- shouldn't really have physics for now
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
end

function ENT:SetupDataTables()
    if self.DTSetup then return end
    self.DTSetup = true

    self:NetworkVar("Entity", 0, "Operator")
    self:NetworkVar("String", 0, "Type") -- cursor type, ex: arrow 
    self:NetworkVar("Float", 0, "Size")
    self:NetworkVar("Bool", 0, "Debug")
    self:NetworkVar("Bool", 1, "Hidden")
    self:NetworkVar("Bool", 2, "Idle")
    self:NetworkVar("Bool", 3, "Interpolate")

    self:NetworkVar("Int", 0, "Lives")
    self:NetworkVar("Float", 1, "Durability")
    self:NetworkVar("Float", 2, "Immunity")

    self:NetworkVar("Float", 3, "Emote") -- on-use clap sound

    self:NetworkVar("Float", 4, "Redirected") -- damage block feature
    self:NetworkVar("Vector", 0, "Redirection")
    
    self:NetworkVar("Bool", 4, "Zipped")
    self:NetworkVar("Vector", 1, "ZippedMin")
    self:NetworkVar("Vector", 2, "ZippedMax")

    if SERVER then
        self:SetLives(self.CVAR_Lives:GetInt())
        self:SetDurability(self.CVAR_Durability:GetFloat())
        self:SetType("arrow")
        self:SetSize(20)
        self:SetDebug(false)
        self:SetInterpolate(true)
    end
end

function ENT:Initialize()
    if self.Initialized then return end
    self:SetModel("models/maxofs2d/cube_tool.mdl")
    self:SetModelScale(0.2)
    self:SetColor(Color(255, 255, 255))

    local cursors = ENT.Cursors
    if not cursors[self] then
        cursors[#cursors+1] = self
        cursors[self] = true
    end

    do
        local mins, maxs = Vector(-10, -10, -10), Vector(10, 10, 10)

        -- Define the min corner of the box
        local x0 = mins.x
        local y0 = mins.y
        local z0 = mins.z

        -- Define the max corner of the box
        local x1 = maxs.x
        local y1 = maxs.y
        local z1 = maxs.z

        self:PhysicsInitConvex( {
            Vector( x0, y0, z0 ),
            Vector( x0, y0, z1 ),
            Vector( x0, y1, z0 ),
            Vector( x0, y1, z1 ),
            Vector( x1, y0, z0 ),
            Vector( x1, y0, z1 ),
            Vector( x1, y1, z0 ),
            Vector( x1, y1, z1 )
        } )
    end

    self:EnableCustomCollisions(true)
    self:DrawShadow(false)
    self:SetupPhysics()
    self.Initialized = true
end

function ENT:OnRemove()
    local operator = self:GetOperator()
    if IsValid(operator) then
        local cursors = operator.Cursors
        for i=1, #cursors do
            if cursors[i] == self then
                table.remove(cursors, i)
                break
            end
        end
        cursors[self] = nil
    end
    
    local cursors = ENT.Cursors
    for i=1, #cursors do
        if cursors[i] == self then
            table.remove(cursors, i)
            cursors[self] = nil
            break
        end
    end

    if self.zip then
        self:UnZipify()
    end
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
        if SERVER then self:Remove() end
        return
    end

    local cursors = ENT.Cursors
    if not cursors[self] then
        cursors[#cursors+1] = self
        cursors[self] = true
    end

    if self:GetMoveType() ~= MOVETYPE_NONE then
        self:SetMoveType(MOVETYPE_NONE)
    end

    local owner = operator:GetOwner()
    local cursors = operator.Cursors

    if not cursors then
        if operator.Initialize then
            operator:Initialize()
        end
        return
    end

    if not cursors[self] then -- TODO: edgecase for operator change needed
        cursors[#cursors+1] = self
        cursors[self] = true
    end

    if SERVER then
        if not self.last_damage or self.last_damage + self.CVAR_RegenCooldown:GetFloat() < ct then
            if not self.last_regenerate or self.last_regenerate + self.CVAR_RegenDelay:GetFloat() < ct then
                self:Regenerate()
                self.last_regenerate = ct
            end
        end
    end

    if CLIENT and owner == LocalPlayer() and not operator:Predictable(self) then
        self:SetPredictedPos(self:GetPos())
    end
end

if SERVER then
    include("server.lua")
    AddCSLuaFile("client.lua")
else
    include("client.lua")
end

scripted_ents.Register(_ENT, "snaptic_cursor_handle"); _ENT = nil

print("[Snaptic] Cursors are ready.")