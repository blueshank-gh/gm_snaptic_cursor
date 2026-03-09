_ENT = {}
local ENT = _ENT

ENT.Type = "anim"
ENT.PrintName		= "Snaptic File"
ENT.Spawnable		= false
ENT.AdminSpawnable	= false
ENT.Category		= "Other"
ENT.AutomaticFrameAdvance = true
ENT.Author          = "BlueShank"
ENT.Snaptic_File    = true
ENT.Snaptic         = true

function ENT:SetupDataTables()
    if self.DTSetup then return end
    self.DTSetup = true
    self:NetworkVar("Entity", "Operator")
    self:NetworkVar("Entity", "Relation")
    self:NetworkVar("Bool", "Relative")
    self:NetworkVar("Bool", "Debug")
    self:NetworkVar("Bool", "Hidden")
    self:NetworkVar("String", "Icon")
    self:NetworkVar("String", "Title")
    self:NetworkVar("Int", "Size")
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
end

if SERVER then
    include("server.lua")
    AddCSLuaFile("client.lua")
else
    include("client.lua")
end

scripted_ents.Register(_ENT, "snaptic_file"); _ENT = nil

print("[Snaptic] Files are ready.")