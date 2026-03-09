_ENT = {}
local ENT = _ENT

local exists = scripted_ents.GetStored("snaptic_context_handle")
if not exists or not exists.t or not exists.t.Contexts then
    ENT.Contexts = {}
else
    ENT.Contexts = exists.t.Contexts
end

ENT.Type = "anim"
ENT.PrintName		= "Snaptic's Context Menu"
ENT.Spawnable		= false
ENT.AdminSpawnable	= false
ENT.Category		= "Other"
ENT.AutomaticFrameAdvance = true
ENT.Author          = "BlueShank"
ENT.Snaptic         = true
    
function ENT:SetupDataTables()
    if self.DTSetup then return end
    self.DTSetup = true

    self:NetworkVar("Entity", 0, "Operator")
    self:NetworkVar("Entity", 1, "Cursor")
    self:NetworkVar("Entity", 2, "Target")
    self:NetworkVar("Bool", 0, "Debug")
    self:NetworkVar("Bool", 1, "Hidden")
    self:NetworkVar("Int", 0, "Option")

    if SERVER then
        self:SetDebug(false)
    end
end

function ENT:SetupPhysics()
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
end

ENT.RenderTextWidth = 11.5
ENT.RenderTextHeight = 24
ENT.RenderScale = 0.175
ENT.RenderSpacing = 1
function ENT:Bounds()
    local mins, maxs = Vector(0, 0, 0), Vector(0.1, 0.1, 0.1)
    local scale = self.RenderScale
    local spacing = self.RenderSpacing
    local ttw, tth = self.RenderTextWidth, self.RenderTextHeight
    local w, h = 0, 0
    local y = 0
    local options = self.options
    for i=1, #options do
        local option = options[i]
        local type = option.type
        if option.type == "option" then
            local tw, th = ttw * #option.name, tth
            if option.icon then
                tw = tw + 16 + 4
            end
            w = math.max(w, tw + 8)
            y = y + th + spacing
        elseif option.type == "spacer" then
            y = y + 1 + spacing
        end
    end
    h = math.max(1, y - spacing)
    w = math.max(1, w)
    return Vector(-1, -w * scale, -h * scale), maxs
end

function ENT:Inside(input_position)
    local pos = self:GetPos()
    local ang = self:GetAngles()
    local scale = self.RenderScale
    local mins, maxs = self:Bounds()
    local local_pos = WorldToLocal(input_position, Angle(0,0,0), pos, ang)
    local x, y = -local_pos.y / scale, -local_pos.z / scale
    local menu_w = math.abs(mins.y) / scale
    local menu_h = math.abs(mins.z) / scale
    if y < 0 or y > menu_h then return false, 0, 0 end
    if x < 0 or x > menu_w then return false, 0, 0 end
    return true, x, y
end

function ENT:SelectOption(input_position)
    local spacing = self.RenderSpacing
    local options = self.options
    local active, x, y = self:Inside(input_position)
    if not active then return false end

    local ttw, tth = self.RenderTextWidth, self.RenderTextHeight
    local cursor_y = 0
    for i, option in ipairs(options) do
        if option.type == "option" then
            if y >= cursor_y and y <= cursor_y + tth then
                return option, i
            end
            cursor_y = cursor_y + tth + spacing
        elseif option.type == "spacer" then
            cursor_y = cursor_y + 1 + spacing
        end
    end
    
    return false
end

function ENT:AddOption(name, callback, icon)
    local options = self.options
    options[#options+1] = {
        type = "option",
        name = name,
        callback = callback,
        icon = icon
    }
end

function ENT:AddSpacer()
    local options = self.options
    options[#options+1] = {type = "spacer"}
end

function ENT:Populate()
    local operator = self:GetOperator()
    if not IsValid(operator) or not operator.Initialized then return end
    local invoker = operator:GetOwner()
    local entity = self:GetTarget()

    local override = hook.Run("Snaptic.Context.Populate", invoker, operator, self, entity)
    if override ~= nil then
        return override
    end

    if entity == operator then
        self:AddOption("Always Active", function(invoker, operator, context, cursor, target)
            operator:SetAlways(not operator:GetAlways())
            context:Close()
        end, operator:GetAlways() and "accept" or "stop")
        self:AddSpacer()
        self:AddOption("Telekinesis", function(invoker, operator, context, cursor, target)
            operator:SetDrag(not operator:GetDrag())
            context:Close()
        end, operator:GetDrag() and "accept" or "stop")
        self:AddOption("Auto Smite", function(invoker, operator, context, cursor, target)
            operator:SetAuto(not operator:GetAuto())
            context:Close()
        end, operator:GetAuto() and "accept" or "stop")
        if not operator:InBalance() then
            self:AddSpacer()
            self:AddOption("Heal Cursors", function(invoker, operator, context, cursor, target)
                local cursors = operator.Cursors
                for i=1, #cursors do
                    local cursor = cursors[i]
                    if IsValid(cursor) then
                        cursor:SetDurability(cursor.CVAR_Durability:GetFloat())
                        cursor:SetLives(cursor.CVAR_Lives:GetInt())
                    end
                end
            end, "heart_add")
            self:AddOption("Add Cursor", function(invoker, operator, context, cursor, target)
                if #operator.Cursors < 10 then
                    operator:CreateCursor()
                end
            end, "add")
            self:AddOption("Remove Cursor", function(invoker, operator, context, cursor, target)
                if #operator.Cursors > 1 then
                    operator.Cursors[#operator.Cursors]:Remove()
                end
            end, "cancel")
        end
        self:AddSpacer()
        self:AddOption("Debug Mode", function(invoker, operator, context, cursor, target)
            operator:SetDebug(not operator:GetDebug())
            context:Close()
        end, "bug")
        return true
    elseif operator:CanDrag(entity) or entity:GetClass() == "snaptic_archive" then
        local ragdoll_controller = operator.Ragdoll.GetController(entity)
        if ragdoll_controller then
            self:AddOption("UnRagdoll", function(invoker, operator, context, cursor, target)
                if not IsValid(ragdoll_controller) then self:Close() return end
                ragdoll_controller:UnLock()
                ragdoll_controller:SetMoveType(MOVETYPE_WALK)
                ragdoll_controller:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                operator.Ragdoll.Stop(ragdoll_controller)
                context:Close()
            end, "user_delete")
        end

        if entity:IsPlayer() then
            if not operator:InBalance() or entity ~= invoker then
                self:AddOption("Heal", function(invoker, operator, context, cursor, target)
                    target:SetHealth(math.max(target:Health(), target:GetMaxHealth()))
                    context:Close()
                end, "heart_add")
            end

            self:AddOption("Ragdoll", function(invoker, operator, context, cursor, target)
                target:UnLock()
                target:SetMoveType(MOVETYPE_WALK)
                target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                operator.Ragdoll.Start(target, invoker)
                context:Close()
            end, "user_go")

            self:AddOption("Cripple", function(invoker, operator, context, cursor, target)
                target:SetRunSpeed(10)
                target:SetWalkSpeed(10)
                target:SetJumpPower(1)
                target:SetHealth(1)
                context:Close()
            end, "link_break")

            self:AddOption("Strip", function(invoker, operator, context, cursor, target)
                target:StripWeapons()
                context:Close()
            end, "gun")
        end

        if properties.CanBeTargeted(entity, invoker) or entity:IsPlayer() then
            if entity:IsOnFire() then
                self:AddOption("Extinguish", function(invoker, operator, context, cursor, target)
                    target:Extinguish()
                    context:Close()
                end, "water")
            else
                self:AddOption("Ignite", function(invoker, operator, context, cursor, target)
                    target:Ignite(360)
                    context:Close()
                end, "fire")
            end

            if not entity:IsPlayer() then
                if entity:GetCollisionGroup() ~= COLLISION_GROUP_NONE then
                    self:AddOption("Enable Collisions", function(invoker, operator, context, cursor, target)
                        if not properties.CanBeTargeted(target, invoker) then return end
                        target:SetCollisionGroup(COLLISION_GROUP_NONE)
                        context:Close()
                    end, "collision_on")
                else
                    self:AddOption("Disable Collisions", function(invoker, operator, context, cursor, target)
                        if not properties.CanBeTargeted(target, invoker) then return end
                        target:SetCollisionGroup(COLLISION_GROUP_WORLD)
                        context:Close()
                    end, "collision_off")
                end
                if gamemode.Call("CanProperty", invoker, "remover", entity) or entity:GetClass() == "snaptic_archive" then
                    self:AddOption("Remove", function(invoker, operator, context, cursor, target)
                        if not properties.CanBeTargeted(target, invoker) or not gamemode.Call("CanProperty", invoker, "remover", entity) then return end
                        context:Close()
                        target:Remove()
                    end, "delete")
                end
            end

            self:AddSpacer()

            if not entity.Snaptic then
                -- disabled for now, we need a better way to perform file storage.
                --[[self:AddOption("Extract", function(invoker, operator, context, cursor, target)
                    do
                        local materials = target:GetMaterials()
                        for i=1, #materials do
                            local material = materials[i]
                            local sub_material = target:GetSubMaterial(i-1)
                            if sub_material ~= "" and sub_material then
                                material = sub_material
                            else
                                sub_material = nil
                            end
                            
                            local path = "materials/" .. material .. ".vtf"
                            
                            if file.Exists(path, "GAME") then
                                local _f = ents.Create("snaptic_file")
                                local obb = target:OBBCenter()
                                obb:Rotate(target:GetAngles())
                                _f:SetPos(target:GetPos() + obb)
                                _f:SetAngles(target:GetAngles())
                                _f:SetRelative(true)
                                _f:SetOperator(operator)
                                _f:SetRelation(target)
                                _f:SetTitle(path:match("([^/\\]+)$"))
                                _f:SetIcon("icon16/image.png")
                                _f:SetSize(file.Size(path, "GAME"))
                                _f:Activate()
                                _f:Spawn()
                                function _f:PhysicsCollide( data, phys )
                                    if data.HitEntity == target then
                                        self:Remove()
                                    end
                                end
                                function _f:OnRemove()
                                    if not IsValid(target) then return end
                                    target:SetSubMaterial(i-1, sub_material)
                                end
                                local phys = _f:GetPhysicsObject()
                                if IsValid(phys) then
                                    phys:EnableMotion(true)
                                    phys:Wake()
                                    phys:ApplyForceCenter(VectorRand(-2000, 2000))
                                    phys:AddAngleVelocity(VectorRand(-300, 300))
                                end

                                target:SetSubMaterial(i-1, "models/debug/debugwhite")
                            end
                        end
                    end

                    do
                        local mdl = target:GetModel()
                        local _f = ents.Create("snaptic_file")
                        local obb = target:OBBCenter()
                        obb:Rotate(target:GetAngles())
                        _f:SetPos(target:GetPos() + obb)
                        _f:SetAngles(target:GetAngles())
                        _f:SetRelative(true)
                        _f:SetOperator(operator)
                        _f:SetRelation(target)
                        _f:SetTitle(mdl:match("([^/\\]+)$"))
                        _f:SetIcon("icon16/database_gear.png")
                        _f:SetSize(file.Size(mdl, "GAME"))
                        _f:Activate()
                        _f:Spawn()
                        function _f:PhysicsCollide( data, phys )
                            if data.HitEntity == target then
                                self:Remove()
                            end
                        end
                        function _f:OnRemove()
                            if not IsValid(target) then return end
                            target:SetModel(mdl)
                        end
                        local phys = _f:GetPhysicsObject()
                        if IsValid(phys) then
                            phys:EnableMotion(true)
                            phys:Wake()
                            phys:ApplyForceCenter(VectorRand(-2000, 2000))
                            phys:AddAngleVelocity(VectorRand(-300, 300))
                        end
                        target:SetModel("error.mdl")
                    end
                    context:Close()
                end, "database_go")]]
                
                self:AddOption("Dismantle", function(invoker, operator, context, cursor, target)
                    operator.Helpers.Extract(target, operator)

                    for i=1, 10 do
                        operator.Helpers.Annihilate(invoker, target, 10000)
                    end

                    if IsValid(target) then
                        if target:IsPlayer() then
                            target:UnLock()
                            target:SetMoveType(MOVETYPE_WALK)
                            target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                            target:KillSilent()
                        elseif target:IsNPC() or target:IsNextBot() or target.Health then
                            target:Dissolve()
                        end
                    end

                    context:Close()
                end, "database_delete")
            end

            if entity:GetClass() ~= "snaptic_archive" then
                if not entity.Snaptic then
                    self:AddOption("Archive", function(invoker, operator, context, cursor, target)
                        local archive = ents.Create("snaptic_archive")
                        archive:SetOperator(operator)
                        local obb = target:OBBCenter()
                        obb:Rotate(target:GetAngles())
                        archive:SetPos(target:GetPos() + obb)
                        archive:SetAngles(target:GetAngles())
                        archive:Activate()
                        archive:Spawn()
                        if not archive:Compress(target, operator.Trace) then
                            archive:Remove()
                            context:Close()
                            return
                        end
                        local phys = archive:GetPhysicsObject()
                        if IsValid(phys) then
                            phys:EnableMotion(true)
                            phys:Wake()
                        end
                        if target:IsPlayer() then
                            target:UnLock()
                            target:SetMoveType(MOVETYPE_WALK)
                            target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                        end
                        context:Close()
                    end, "package_add")
                end
            else
                self:AddOption("UnArchive", function(invoker, operator, context, cursor, target)
                    target:Remove()
                    context:Close()
                end, "package_delete")
            end

            self:AddOption("Boxify", function(invoker, operator, context, cursor, target)
                operator.Helpers.Boxify(target)
                for i=1, 10 do
                    operator.Helpers.Annihilate(invoker, target, 10000)
                end
                if IsValid(target) then
                    if target:IsPlayer() then
                        target:UnLock()
                        target:SetMoveType(MOVETYPE_WALK)
                        target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                        target:KillSilent()
                    elseif target:IsNPC() or target:IsNextBot() or target.Health then
                        target:Dissolve()
                    end
                end
                context:Close()
            end, "asterisk_yellow")
        end

        return #self.options ~= 0
    end
    return false
end

function ENT:RePosition()
    local origin = self:GetPos()
    local up = self:GetAngles():Up()
    local size = -1 + self:OBBMins().z
    local tr = util.TraceLine({
        start = origin,
        endpos = origin + up * size,
        filter = self,
        mask = MASK_SHOT
    })

    if tr.Hit then
        self:SetPos(origin + (up * (1-tr.Fraction) * -size))
    end
end

function ENT:Initialize()
    if self.Initialized then return end

    self:SetColor(Color(255, 255, 255))
    local contexts = ENT.Contexts
    if not contexts[self] then
        contexts[#contexts+1] = self
        contexts[self] = true
    end

    self.options = {}
    if not self:Populate() and SERVER then
        self:Remove()
    end

    do
        local mins, maxs = self:Bounds()

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

    local contexts = ENT.Contexts
    if not contexts[self] then
        contexts[#contexts+1] = self
        contexts[self] = true
    end

    if self:GetMoveType() ~= MOVETYPE_VPHYSICS then
        self:SetMoveType(MOVETYPE_VPHYSICS)
    end

    if self:GetCollisionGroup() ~= COLLISION_GROUP_WORLD then
        self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) and phys:IsMotionEnabled() then
        phys:EnableMotion(false)
    end

    local entity = self:GetTarget()
    if not IsValid(entity) then
        if SERVER then self:Close() end
        return
    end

    if SERVER then
        if entity == self:GetCursor() then
            entity = operator:GetOwner()
        end
        local center = operator.Helpers.OBBCenter(entity)
        local self_radius = operator.Helpers.OBBRadius(entity)

        if self:GetPos():Distance(center) > self_radius + 250 then
            self:Remove()
            return
        end
    end
end

if SERVER then
    include("server.lua")
    AddCSLuaFile("client.lua")
else
    include("client.lua")
end

scripted_ents.Register(_ENT, "snaptic_context_handle"); _ENT = nil

print("[Snaptic] Contexts are ready.")