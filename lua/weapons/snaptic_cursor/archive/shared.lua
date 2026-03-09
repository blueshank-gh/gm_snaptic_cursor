_ENT = {}
local ENT = _ENT

local exists = scripted_ents.GetStored("snaptic_context_handle")
if not exists or not exists.t or not exists.t.Archives then
    ENT.Archives = {}
else
    ENT.Archives = exists.t.Archives
end

ENT.Type = "anim"
ENT.PrintName		= "WinRAR"
ENT.Spawnable		= false
ENT.AdminSpawnable	= false
ENT.Category		= "Other"
ENT.AutomaticFrameAdvance = true
ENT.Author          = "BlueShank"
ENT.Snaptic_Archive = true
ENT.Snaptic         = true

do
    ENT.CVAR_Struggle = CreateConVar(
        "snaptic_cursor_archive_struggle",
        "1",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
        "How long (in seconds, tick-based) a player can keyboard mash before breaking free from archive.",
        0, 60
    )
end
    
function ENT:SetupDataTables()
    if self.DTSetup then return end
    self.DTSetup = true
    self:NetworkVar("Entity", "Operator")
    self:NetworkVar("Entity", "Player")
    self:NetworkVar("Bool", "Debug")
    self:NetworkVar("Bool", "Hidden")
    self:NetworkVar("Bool", "Active")
    self:NetworkVar("Vector", "Min")
    self:NetworkVar("Vector", "Max")
    self:NetworkVar("Int", "Size")
    self:NetworkVar("Int", "Files")
    self:NetworkVar("Int", "Folders")
    if SERVER then
        self:SetDebug(false)
    end
end

-- TODO: Behavior to use self:SetUseType(SIMPLE_USE) to release players?
function ENT:SetupPhysics()
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
end

function ENT:Initialize()
    if self.Initialized then return end
    self:SetModel("models/maxofs2d/cube_tool.mdl")
    self:SetModelScale(1)
    self:SetColor(Color(255, 255, 255))

    local archives = ENT.Archives
    if not archives[self] then
        archives[#archives+1] = self
        archives[self] = true
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

    self:DrawShadow(false)
    self:SetupPhysics()
    self.Initialized = true
end

function ENT:OnRemove()
    local archives = ENT.Archives
    for i=#archives, 1, -1 do
        if archives[i] == self then
            table.remove(archives, i)
            archives[self] = nil
            break
        end
    end

    if SERVER then self:Decompress(self:GetPos()) end
end

if SERVER then
    include("server.lua")
    AddCSLuaFile("client.lua")
else
    include("client.lua")
end

scripted_ents.Register(_ENT, "snaptic_archive"); _ENT = nil

print("[Snaptic] Archives are ready.")