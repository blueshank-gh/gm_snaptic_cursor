resource.AddWorkshop("3591904868")

function SWEP:CreateCursor()
    local cursors = self.Cursors
    local cursor = ents.Create("snaptic_cursor_handle")
    cursor:SetOperator(self)
    cursor:SetPos(self:GetPos())
    cursor:Activate()
    cursor:Spawn()
    if self:GetOwner():GetActiveWeapon() ~= self then
        cursor:Hide()
    end
    cursors[#cursors+1] = cursor
    cursors[cursor] = true
    return cursor
end

function SWEP:CleanCursors()
    local cursors = self.Cursors
    for i=1, #cursors do
        local cursor = cursors[i]
        if IsValid(cursor) then
            cursor:Remove()
        end
    end
    self.Cursors = {}
end

function SWEP:CreateContext(cursor, target)
    self:ContextRelease()
    if hook.Run("Snaptic.Context", self:GetOwner(), self, target) == false then
        return
    end
    local context = ents.Create("snaptic_context_handle")
    context:SetOperator(self)
    context:SetCursor(cursor)
    context:SetTarget(target or false)
    context:SetPos(cursor:GetPos() - cursor:GetAngles():Forward() * 10)
    context:SetAngles(cursor:GetAngles())
    context:Activate()
    context:Spawn()
    if not IsValid(context) then
        return
    end
    context:RePosition()
    self:SetContext(context)
    return context
end

function SWEP:ContextRelease()
    local ctx = self:GetContext()
    if IsValid(ctx) then
        if not self:GetDrag() then
            self:SetDragCursor(nil)
        end
        
        if IsValid(ctx) then
            ctx:Remove()
        end
        
        self:SetContext(NULL)
    end
end

function SWEP:PrimaryAttack()
    self.dragging_debounce = false
    local current = self:GetContext()
    local owner = self:GetOwner()
    local aim_vector = owner:GetAimVector()

    if IsValid(current) then
        owner:LagCompensation(true)
        local ep = owner:EyePos()
        local tr = self:TraceLine({
            start = ep,
            endpos = ep + aim_vector * 50000,
            mask = MASK_SHOT
        })
        owner:LagCompensation(false)

        if tr.Entity == current then
            current:Interact(tr.HitPos)
        else
            self:ContextRelease()
        end
    end

    if IsValid(self:GetDragCursor()) then
        local drag_cursor = self:GetDragCursor()
        if drag_cursor:GetType() == "unavail" then
            EmitSound("snaptic/win7_error.mp3", drag_cursor:GetPos(), 0, CHAN_AUTO, 1, 75, 0, 100)
        end
    end
end

function SWEP:SecondaryAttack()
    if self:GetDrag() then
        local entity = self:IsDragging()
        if entity then
            local isPlayer = entity:IsPlayer()
            local bone = self:GetDragPhysBone()
            local phys = isPlayer and entity:GetPhysicsObject() or entity:GetPhysicsObjectNum(bone)
            if entity ~= self:GetOwner() then
                self.Helpers.Click(entity:GetPos())
                if isPlayer then
                    entity:Lock()
                    entity:SetMoveType(MOVETYPE_NONE)
                    entity:SetCollisionGroup(COLLISION_GROUP_WORLD)
                elseif phys then
                    phys:EnableMotion(false)
                end
            end
            self:DragRelease()
            self.dragging_debounce = true -- debounce for waiting on next attack
        elseif IsValid(self:GetDragCursor()) then
            local drag_cursor = self:GetDragCursor()
            local owner = self:GetOwner()
            local aim_vector = owner:GetAimVector()
            local current = self:GetContext()

            owner:LagCompensation(true)
            local ep = owner:EyePos()
            local tr = self:TraceLine({
                start = ep,
                endpos = ep + aim_vector * 50000,
                mask = MASK_SHOT
            }, owner, current)
            owner:LagCompensation(false)
            
            do
                local min = owner:OBBMins()
                local max = owner:OBBMaxs()
                max.z = 10
                min.z = -10
                local localPos = owner:WorldToLocal(tr.HitPos)
                if localPos.x >= min.x and localPos.x <= max.x and
                    localPos.y >= min.y and localPos.y <= max.y and
                    localPos.z >= min.z and localPos.z <= max.z then
                    tr.Entity = owner
                    tr.HitPos = owner:GetPos() + owner:OBBCenter()
                    tr.PhysicsBone = 0
                end
            end

            if IsValid(current) and current:GetTarget() == tr.Entity then
                self:ContextRelease()
            else
                self:ContextRelease()
                if tr.Hit and IsValid(tr.Entity) and self:CanDrag(tr.Entity) then
                    self.Helpers.Click(drag_cursor:GetPos() + drag_cursor:OBBCenter())
                    self.Trace = tr
                    local ctx = self:CreateContext(drag_cursor, tr.Entity)
                    if IsValid(ctx) and tr.Entity == owner then
                        local ea = owner:EyeAngles()
                        ea.p = 0
                        ea.r = 0
                        local self_radius = self.Helpers.OBBRadius(owner)
                        ctx:SetPos(owner:GetPos() + owner:OBBCenter() + ea:Forward() * (self_radius + 20))
                        ctx:SetAngles((ctx:GetPos() - owner:EyePos()):Angle())
                        local obb = ctx:OBBCenter()
                        obb:Rotate(ctx:GetAngles())
                        ctx:SetPos(ctx:GetPos() - obb)
                    end
                end
            end
        end
    end
end

function SWEP:Reload()
    if self.IN_RELOAD then return end
    self.IN_RELOAD = true
    local owner = self:GetOwner()
    if not self:IsDragging() then
        local previous_ctx = self:GetContext()
        if IsValid(previous_ctx) then
            if not self:GetDrag() then
                self:SetDragCursor(nil)
            end
            self.Helpers.Click(previous_ctx:GetPos())
            previous_ctx:Close()
            self:Calculate(true)
            return
        end

        if self.Cursors[1] then
            local drag_cursor = self.Cursors[1]
            local ctx = self:CreateContext(drag_cursor, self)
            if not ctx then return end
            self:SetDragCursor(drag_cursor)
            self:Calculate(true)
            local ea = owner:EyeAngles()
            ea.p = 0
            ea.r = 0

            local self_radius = self.Helpers.OBBRadius(owner)
            ctx:SetPos(owner:GetPos() + owner:OBBCenter() + ea:Forward() * (self_radius + 20))
            ctx:SetAngles((ctx:GetPos() - owner:EyePos()):Angle())
            local obb = ctx:OBBCenter()
            obb:Rotate(ctx:GetAngles())
            self.Helpers.Click(ctx:GetPos())
            ctx:SetPos(ctx:GetPos() - obb)
        end
    end
end

function SWEP:Holster(other)
    if not self.Active then return end
    self.Active = false
    self:ContextRelease()

    if IsValid(self:GetDragCursor()) then
        local cursor = self:GetDragCursor()
        self:SetDragCursor(nil)
        if IsValid(cursor) then
            self:DragRelease(cursor)
        end
    end

    if not self:GetAlways() or IsValid(self:GetOwner():GetObserverTarget()) then
        self.Deferred_Logon = false
        local cursors = self.Cursors
        for i=1, #cursors do
            local cursor = cursors[i]
            if IsValid(cursor) then
                cursor:Hide()
            end
        end
    end
    
    return true
end

function SWEP:Deploy()
    if self.Active then return end
    self.Active = true
    if not self:GetAlways() then
        self.Deferred_Logon = false
    end
    self:ContextRelease()

    local cursors = self.Cursors
    for i=1, #cursors do
        local cursor = cursors[i]
        if IsValid(cursor) then
            cursor:Show()
        end
    end
end

function SWEP:OnRemove()
    self:ContextRelease()
    
    if IsValid(self:GetDragCursor()) then
        local cursor = self:GetDragCursor()
        self:SetDragCursor(nil)
        if IsValid(cursor) then
            self:DragRelease(cursor)
        end
    end

    local cursors = self.Cursors
    for i=1, #cursors do
        local cursor = cursors[i]
        if IsValid(cursor) then
            cursor:Remove()
        end
    end
    
    local operators = Snaptic.Operators
    for i=1, #operators do
        if operators[i] == self then
            table.remove(operators, i)
            operators[self] = nil
            break
        end
    end
end

do -- DragLogic
    hook.Add("PlayerNoClip", "Snaptic.Dragging", function(invoker, state)
        if state and invoker.Snaptic_Dragging then
            return false
        end
    end)

    hook.Add("CanPlayerSuicide", "Snaptic.Dragging", function(invoker)
        if invoker.Snaptic_Dragging then
            return false
        end
    end)

    function SWEP:OnDraggingStart(cursor, entity)
        cursor:SetInterpolate(false)
        self.Helpers.Click_Meme(cursor:GetPos())
        if IsValid(entity) then
            entity.Snaptic_Dragging = true -- simple flag
            if entity:IsPlayer() then
                entity:UnLock()
                entity:SetMoveType(MOVETYPE_WALK)
                entity:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            end
        end
        self.dragging_velocity = entity:GetVelocity()
    end

    function SWEP:OnDraggingStop(cursor, entity)
        if IsValid(cursor) then
            cursor:SetInterpolate(true)
        end
        if IsValid(entity) then
            entity.Snaptic_Dragging = false
        end
    end

    local sv_gravity = GetConVar("sv_gravity")
    function SWEP:OnDragging(cursor, entity)
        if not entity:IsValid() then return end

        local owner = self:GetOwner()
        local isPlayer = entity:IsPlayer()

        local bone = self:GetDragPhysBone()
        local matrix = entity:GetBoneMatrix(entity:TranslatePhysBoneToBone(bone))
        local phys = isPlayer and entity:GetPhysicsObject() or entity:GetPhysicsObjectNum(bone)
        local movetype = entity:GetMoveType()
        if movetype == MOVETYPE_CUSTOM or movetype == MOVETYPE_WALK or movetype == MOVETYPE_STEP then
            phys = nil 
        end
        if not phys or isPlayer then
            bone = 0
            matrix = false
        end

        local isValidPhysics = IsValid(phys)

        local distance = self:GetDragDistance()
        local lpos = self:GetDragLocalPos()
        local lang = self:GetDragLocalAng()

        if owner:KeyDown(IN_USE) and owner:KeyDown(IN_SPEED) then
            lang = lang * 1
            lang.x = math.Round(lang.x / 45) * 45
            lang.y = math.Round(lang.y / 45) * 45
            lang.z = math.Round(lang.z / 45) * 45
        end

        local apos = owner:GetShootPos() + owner:GetAimVector() * distance
        local pos = matrix and LocalToWorld(lpos, lang, matrix:GetTranslation(), matrix:GetAngles()) or LocalToWorld(lpos, lang, entity:GetPos(), entity:GetAngles())
        if isPlayer then
            pos = LocalToWorld(lpos, lang, entity:GetPos(), Angle())
        end

        cursor:SetType("move")
        if entity ~= owner then
            cursor:SetPos(pos)
            if not isPlayer then
                lpos:Rotate(matrix and matrix:GetAngles() or entity:GetAngles())
            end
        else
            local center = owner:GetPos() + owner:OBBCenter()
            apos = center + owner:GetAimVector() * distance
            cursor:SetPos(center)
        end
        local wish = apos - lpos

        local shadowParams = {
            pos = wish,
            angle = lang,
            maxangular = 15000,
            maxangulardamp = 10000,
            maxspeed = 10000,
            maxspeeddamp = 10000,
            dampfactor = 0.8,
            teleportdistance = 0,
            deltatime = engine.TickInterval()
        }

        local current_velocity = entity:GetVelocity()
        local previous_velocity = self.dragging_velocity
        self.dragging_velocity = current_velocity

        if not phys or isPlayer then
            -- Alternative to ShadowControl
            entity:SetGroundEntity()

            if isPlayer then
                entity:SetMoveType(MOVETYPE_WALK)
            end

            local current_position = entity:GetPos()
            local current_angle = entity:EyeAngles()

            local target_position = wish
            local target_angle = lang

            local position_difference = target_position - current_position
            local dist = position_difference:Length()

            local stiffness = shadowParams.maxspeed * 0.025
            local damping   = (shadowParams.maxspeeddamp * 2) * shadowParams.dampfactor * 0.002

            local accel = position_difference * stiffness - current_velocity * damping
            local new_velocity = current_velocity + accel * shadowParams.deltatime

            local max_velocity = shadowParams.maxspeed
            local velocity_length = new_velocity:Length()
            if velocity_length > max_velocity then
                new_velocity = new_velocity:GetNormalized() * max_velocity
            end
            local wish_velocity = new_velocity - current_velocity
            entity:SetVelocity(wish_velocity)

            --[[local angle_difference = (target_angle - current_angle)
            angle_difference:Normalize()

            local angle_velocity = entity:GetLocalAngularVelocity()
            local angle_stiffness = shadowParams.maxangular * 0.02
            local angle_dampening   = shadowParams.maxangulardamp * shadowParams.dampfactor * 0.002

            local angle_acceleration = angle_difference * angle_stiffness - angle_velocity * angle_dampening
            local newangle_velocity = angle_velocity + angle_acceleration * shadowParams.deltatime

            local maxangle_velocity = shadowParams.maxangular
            local angle_velocityLen = math.sqrt(newangle_velocity.p ^ 2 + newangle_velocity.y ^ 2 + newangle_velocity.r ^ 2)
            if angle_velocityLen > maxangle_velocity then
                newangle_velocity:Normalize()
                newangle_velocity = newangle_velocity * maxangle_velocity
            end

            entity:SetEyeAngles(current_angle + newangle_velocity * shadowParams.deltatime)]]
        else
            phys:Wake()
            phys:ComputeShadowControl(shadowParams)
        end

        local can_damage = ((entity.Health and entity:Health() > 0) or (entity.Alive and entity:Alive()))
        if (entity ~= owner or self.CVAR_Ragdoll_Self:GetBool()) and can_damage then -- Slam Detection
            local dt = shadowParams.deltatime
            local start_position = entity:GetPos()
            local end_position = start_position + (previous_velocity / 2) * dt
            local mins, maxs = entity:OBBMins(), entity:OBBMaxs()

            local tr = util.TraceHull{
                start   = start_position,
                endpos  = end_position,
                mins    = mins,
                maxs    = maxs,
                filter  = entity,
                mask    = MASK_SHOT
            }

            local slammed = tr.Hit
            local normal = tr.HitNormal or Vector(0,0,0)
            local gForce = 0
            if slammed then
                local impactSpeed = previous_velocity:Length() - current_velocity:Length()
                gForce = (impactSpeed / 3) / ((9.81 / 0.0254) * dt)
                if gForce > 25 then
                    local center = entity:GetPos() + entity:OBBCenter()
                    local damage = (gForce - 25) * self.CVAR_Damage:GetFloat() / 100
                    local d = DamageInfo()
                    d:SetDamage(damage)
                    d:SetDamagePosition(center)
                    d:SetDamageForce(previous_velocity * 50)
                    d:SetAttacker(owner)
                    d:SetInflictor(cursor)
                    d:SetDamageCustom(6969)
                    d:SetDamageType(DMG_CRUSH)
                    entity:TakeDamageInfo(d)
                    if damage > self.CVAR_Damage_Ragdoll_Heavy:GetInt() then
                        EmitSound("Flesh.Break", center)
                        if self.CVAR_Damage_Ragdoll:GetBool() and isPlayer and entity:Health() > 0 then
                            self.Ragdoll.Start(entity, owner, previous_velocity, self.CVAR_Ragdoll_Duration:GetFloat())
                            self:DragRelease(cursor)
                        end
                    elseif damage > self.CVAR_Damage_Ragdoll_Light:GetInt() then
                        EmitSound("Flesh.ImpactHard", center)
                        if self.CVAR_Damage_Ragdoll:GetBool() and isPlayer and entity:Health() > 0 then
                            self.Ragdoll.Start(entity, owner, previous_velocity, self.CVAR_Ragdoll_Duration:GetFloat())
                            self:DragRelease(cursor)
                        end
                    else
                        EmitSound("Flesh.ImpactSoft", center)
                    end
                end
            end
        end

        if entity ~= owner and entity:IsPlayer() and can_damage and self.CVAR_Damage_Constant:GetInt() > 0 then
            if not self._Last_DMG_Constant or self._Last_DMG_Constant + (self.CVAR_Damage_Rate:GetFloat() / 1000) < SysTime() then
                self._Last_DMG_Constant = SysTime()
                local center = entity:GetPos() + entity:OBBCenter()
                local d = DamageInfo()
                d:SetDamage(self.CVAR_Damage_Constant:GetInt())
                d:SetDamagePosition(center)
                d:SetAttacker(owner)
                d:SetInflictor(cursor)
                d:SetDamageCustom(6969)
                d:SetDamageType(DMG_CRUSH)
                entity:TakeDamageInfo(d)
                if entity:Health() <= 0 or not entity:Alive() then
                    self.Helpers.Boxify(entity)
                    self:DragRelease(cursor)
                end
                EmitSound("snaptic/skype_message_sent.mp3", center, 0, CHAN_AUTO, 1, 75, 0, 100 + math.random(-25, 25))
            end
        end

        if isPlayer and not entity:Alive() then
            self:DragRelease(cursor)
        end
    end

    function SWEP:DragRelease(cursor)
        local drag_cursor = self:GetDragCursor()
        if not IsValid(drag_cursor) then drag_cursor = nil end
        cursor = cursor or drag_cursor
        local e = self:GetDragEntity()
        if self:CanDrag(e) then
            self:OnDraggingStop(cursor, e)
            self:SetDragEntity()
        end
    end

    -- grab detection code based on newtphysgun @ bonyoze
    function SWEP:DragLogic(cursor)
        local owner = self:GetOwner()
        local aim_vector = owner:GetAimVector()

        owner:LagCompensation(true)
        local ep = owner:EyePos()
        local tr = self:TraceLine({
            start = ep,
            endpos = ep + aim_vector * 50000,
            mask = MASK_SHOT
        })
        local offset
        if IsValid(tr.Entity) then
            offset = tr.HitPos - tr.Entity:GetPos()
        end
        owner:LagCompensation(false)
        if offset then
            tr.HitPos = tr.Entity:GetPos() + offset
        end

        local target = tr.Entity

        do
            local min = owner:OBBMins()
            local max = owner:OBBMaxs()
            max.z = 10
            min.z = -10
            local localPos = owner:WorldToLocal(tr.HitPos)
            if localPos.x >= min.x and localPos.x <= max.x and
                localPos.y >= min.y and localPos.y <= max.y and
                localPos.z >= min.z and localPos.z <= max.z then
                target = owner
                tr.Entity = owner
                tr.HitPos = owner:GetPos() + owner:OBBCenter()
                tr.PhysicsBone = 0
            end
        end
        local validated = self:CanDrag(target)
        local context = self:GetContext()
        if IsValid(context) then
            if context == tr.Entity then
                context:Process(tr.HitPos)
                validated = false
            else
                context:Process(false)
            end
        end

        if cursor:GetImmunity() > CurTime() then
            validated = false
            self.dragging_debounce = true
            self:ContextRelease()
        else
            cursor:SetPos(tr.HitPos)
            cursor:SetAngles(aim_vector:Angle())
        end

        local dragging = self:GetDragEntity()
        if not self:CanDrag(dragging) then
            self:DragRelease(cursor)
            dragging = false
        end

        if not dragging then
            if IsValid(target) then
                if not validated and context ~= tr.Entity then
                    cursor:SetType("unavail")
                else
                    cursor:SetType("link")
                end
            else
                cursor:SetType("arrow")
            end
        end

        if not self:GetDrag() then
            if self:CanDrag(dragging) then
                self:DragRelease(cursor)
                dragging = false
            end
            return
        end

        if SERVER then
            if owner:KeyDown(IN_ATTACK) and not self.dragging_debounce then
                if not self:CanDrag(dragging) and validated then
                    local target_ = target:GetPhysicsObjectCount() <= 1 and self.Helpers.GetTargetEntity(target) or target
                    if self:CanDrag(target_) then
                        local isPlayer = target_:IsPlayer()
                        local bone = target == target_ and tr.PhysicsBone or 0 -- use the first physobj if the entity is parented
                        local matrix = target == target_ and target:GetBoneMatrix(target:TranslatePhysBoneToBone(bone)) -- don't use bone matrix if the entity is parented
                        local phys = isPlayer and target_:GetPhysicsObject() or target_:GetPhysicsObjectNum(bone)
                        if not phys or isPlayer then
                            bone = -1
                            matrix = false
                        end

                        local pos = tr.HitPos
                        local ang = aim_vector:Angle()

                        self:SetDragEntity(target_)
                        self:SetDragPhysBone(bone)
                        if target_ == owner then
                            self:SetDragDistance(0)
                            self:SetDragLocalPos(owner:OBBCenter())
                            self:SetDragLocalAng(Angle())
                        elseif isPlayer then
                            self:SetDragDistance(ep:Distance(pos))
                            self:SetDragLocalPos(WorldToLocal(pos, Angle(), target_:GetPos(), Angle()))
                            self:SetDragLocalAng(Angle())
                        else
                            self:SetDragDistance(ep:Distance(pos))
                            self:SetDragLocalPos(matrix
                                and WorldToLocal(pos, ang, matrix:GetTranslation(), matrix:GetAngles())
                                or WorldToLocal(pos, ang, target_:GetPos(), target_:GetAngles())
                            )
                            self:SetDragLocalAng(matrix
                                and matrix:GetAngles()
                                or target_:GetAngles()
                            )
                        end

                        local deny = self:OnDraggingStart(cursor, target_)
                        if deny == false then
                            self:SetDragEntity()
                            dragging = false
                        else
                            local phys = target_:GetPhysicsObjectNum(bone)
                            if IsValid(phys) then
                                phys:EnableMotion(true)
                            end
                            dragging = target_
                        end
                    end
                end
            elseif self:IsDragging() then
                self:DragRelease(cursor)
            end
        end

        if dragging and not self.dragging_debounce then
            self:OnDragging(cursor, dragging)
        end
    end
end

function SWEP:AutoLogic()
    local cursors = self.Cursors
    local owner = self:GetOwner()
    local ct = CurTime()
    local st = SysTime()
    local ft = FrameTime()

    for i=1, #cursors do
        local cursor = cursors[i]
        local redir = cursor:GetRedirected()
        if redir + 0.5 > ct then
            continue
        end
        if not cursor.last_auto then
            continue
        end
        if cursor.last_auto + 10 < st then
            cursor.last_auto = nil
            cursor:SetInterpolate(true)
            cursor:SetPos(owner:GetPos() + owner:OBBCenter())
            continue
        end
        if cursor:GetImmunity() > ct then
            cursor.last_auto = nil
            cursor:SetInterpolate(true)
            continue
        end
        local delta = 1 - ((10 + cursor.last_auto - st) / 10)
        local attacker = cursor.last_attacker
        if not IsValid(attacker) or attacker == owner then continue end
        if attacker.Alive and not attacker:Alive() then
            cursor.last_auto = nil
            cursor:SetInterpolate(true)
            cursor:SetPos(owner:GetPos() + owner:OBBCenter())
            continue
        end
        if attacker.Health and attacker:Health() <= 0 then
            cursor.last_auto = nil
            cursor:SetInterpolate(true)
            cursor:SetPos(owner:GetPos() + owner:OBBCenter())
            continue
        end
        if not attacker.Alive and not attacker.Health then
            cursor.last_auto = nil
            cursor:SetInterpolate(true)
            cursor:SetPos(owner:GetPos() + owner:OBBCenter())
            continue
        end

        cursor:SetInterpolate(false)
        cursor:SetType("link")
        cursor.idle_temp = false -- we are attacking.
        
        local position = cursor:GetPos()
        local velocity = math.max(1, attacker:GetVelocity():Length() / 1000)
        local center = attacker:GetPos() + attacker:OBBCenter()
        if attacker:GetMoveType() == MOVETYPE_NOCLIP then
            cursor:SetPos(LerpVector(ft * (1 + (delta * 50 * velocity)), position, center))
        else
            cursor:SetPos(LerpVector(ft * (1 + (delta * 25 * velocity)), position, center))
        end
        cursor:SetAngles((center - position):Angle())

        local maxs = owner:OBBMaxs()
        local mins = owner:OBBMins()
        local minimal = math.min(
            math.abs(maxs.x),
            math.abs(maxs.y),
            math.abs(mins.x),
            math.abs(mins.y)
        )

        position = cursor:GetPos()
        if position:Distance(center) < minimal / 2 then
            self.Helpers.Click_Meme(position)
            cursor:SetPos(center + VectorRand(-minimal/3, minimal/3))
            self.Helpers.Annihilate(owner, attacker, 25)
        end
    end
end

function SWEP:IdleLogic()
    local self_radius = 0
    local self_height = 0
    local owner = self:GetOwner()
    local ct = CurTime()
    local cursors = self.Cursors
    local position = owner:GetPos()
    local center = position + owner:OBBCenter()
    local scale = owner:GetModelScale()

    do
        local maxs = owner:OBBMaxs()
        local mins = owner:OBBMins()

        self_radius = math.min(
            math.abs(maxs.x),
            math.abs(maxs.y),
            math.abs(mins.x),
            math.abs(mins.y)
        )

        self_height = math.min(
            math.abs(maxs.z),
            math.abs(mins.z)
        )
    end

    local orbit_radius = self_radius + (15 * scale)
    local global_rot = ct * 60
    local count = #cursors
    local velocity = owner:GetVelocity()
    local length = velocity:Length()
    local last_vector = center
    local chaining = false

    local ctx = self:GetContext()
    if IsValid(ctx) then
        ctx:SetDebug(self:GetDebug())
    end

    local c = 0
    for i=1, count do
        local cursor = cursors[i]
        cursor:SetIdle(cursor.idle_temp)
        cursor:SetDebug(self:GetDebug())

        if not cursor.idle_temp then -- cursors not marked with idle means they are in-use
            c = c + 1
            continue
        end

        if not cursor:GetInterpolate() then
            cursor:SetInterpolate(true)
        end

        local redir = cursor:GetRedirected()
        if redir and redir + 1 > ct then
            local redir_offset = cursor:GetRedirection()
            cursor:SetType("unavail")
            cursor:SetPos(center + redir_offset)
            c = c + 1
            continue
        end

        local idx = i - c
        local count = count - c
        local angle = (((idx - 1) / count) * 360) + global_rot
        local rad = math.rad(angle)
        local x = math.cos(rad) * orbit_radius
        local y = math.sin(rad) * orbit_radius
        local z = self_height * 0.5 + (40 + math.sin((ct * 3.5) + (idx * (5/count))) * 4) * scale
        local wish = position + Vector(x, y, z)
        local cur_pos = cursor:GetPos()
        local dist = cur_pos:Distance(last_vector)
        
        if length >= owner:GetRunSpeed() - 5 or dist > (chaining and (40 * scale) or orbit_radius + (20 * scale)) or chaining then
            local dir = last_vector - cur_pos
            cursor:SetPos(LerpVector(FrameTime() * 7.5, cur_pos, cur_pos + dir))
            cursor:SetAngles(dir:Angle())
            last_vector = cursor:GetPos()
            chaining = true
        else
            cursor:SetPos(wish)
            cursor:SetAngles(Angle(0, angle, 0))
        end
        cursor:SetType("arrow")
    end
end

function SWEP:OnDamage(cdmg)
    local st = SysTime()
    local ct = CurTime()
    local position = cdmg:GetDamagePosition()
    local owner = self:GetOwner()
    local center = owner:GetPos() + owner:OBBCenter()
    local obb = owner:OBBMaxs()
    local width = math.min(obb.x, obb.y) + 15
    local attacker = cdmg:GetAttacker()

    self:SetBalance(ct)

    if position:Distance(center) > 50 then
        if IsValid(attacker) then
            local invoker_position = attacker:EyePos()
            local direction = invoker_position - center
            if direction:Length() == 0 then
                position = VectorRand(-5,5) + center + VectorRand():GetNormalized() * width
            else
                position = VectorRand(-5,5) + center + direction:GetNormalized() * width
            end
        else
            position = center + VectorRand():GetNormalized() * width
        end
    else
        if IsValid(attacker) then
            local invoker_position = attacker:EyePos()
            position = position + (invoker_position - position):GetNormalized() * 10
        end
        position = center + (position - center)
    end
    local cursors = self.Cursors
    local cursor

    local shuffle = {}
    for i=1, #cursors do
        local select = cursors[i]
        if not select:GetIdle() then continue end
        if select:GetRedirected() + engine.TickInterval() > ct then continue end
        shuffle[#shuffle+1] = select
    end
    local cursor = shuffle[math.random(1, #shuffle)]
    if not cursor then return end

    cursor:SetRedirection(position - center)
    cursor:SetRedirected(ct)

    if self:GetAuto() then
        local already = false
        for i=1, #cursors do
            local select = cursors[i]
            if select.last_attacker == attacker and select.last_auto then
                already = true
                break
            end
        end
        if not already then
            cursor.last_attacker = attacker
            if attacker ~= owner then
                cursor.last_auto = st
            end
        end
    else
        cursor.last_attacker = attacker
    end

    EmitSound("snaptic/skype_message_sent.mp3", position, 0, CHAN_AUTO, 1, 75, 0, 100 + math.random(-25, 25))
    return true -- block damage
end

function SWEP:OnDrag(state)
    if not state then
        self:SetDragCursor(nil)
        self:DragRelease()
        self:ContextRelease()
    end
end

function SWEP:OnAuto(state)
    if not state then
        local cursors = self.Cursors
        for i=1, #cursors do
            local cursor = cursors[i]
            cursor.last_auto = nil
        end
    end
end

function SWEP:Calculate(active)
    if not self.GetDrag then
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

    local ct = CurTime()
    local st = SysTime()
    local owner = self:GetOwner()

    if IsValid(owner) then
        local access = false

        -- check for cvars if they should be granted (console can only change these so these take precedence)
        if self.CVAR_SuperAdmin:GetBool() and owner:IsSuperAdmin() then
            access = true
        elseif self.CVAR_Admin:GetBool() and owner:IsAdmin() then
            access = true
        end

        -- await for CAMI support, I guess some adminmods don't cache permissions...
        if not access then
            if CAMI and self.CAMI_ACCESS == nil and not self.CAMI_PENDING then
                self.CAMI_PENDING = true
                CAMI.PlayerHasAccess(owner, "snaptic_cursor", function(state)
                    self.CAMI_ACCESS = state or false
                    self.CAMI_PENDING = false 
                end)
            end
            if self.CAMI_PENDING then return end
            if self.CAMI_ACCESS then access = true end
        end

        -- check if any lua may modify access
        if not access then access = hook.Run("Snaptic.Access", owner, self) end

        if access ~= true then
            self:Remove()
            self.Helpers.Boxify(owner)
            local rnd = {
                '"The oldest trick in the book" be like: X + Δ + R2',
                'Prank em John -> *gets turned into boxes*',
                'sudo rm -rf "' .. owner:Name() .. '"',
                '!boxify "' .. owner:Name() .. '"',
                'you will get access I swear, its an RNG process just keep trying...',
            }
            owner:ChatPrint(rnd[math.random(1, #rnd)])
            owner:KillSilent()
            return
        end
    else
        self:Remove()
        return
    end
    
    if not self.Deferred_Spawn then
        self.Deferred_Spawn = true
        for i=1, 3 do
            self:CreateCursor()
        end
    end

    if not self.Deferred_Logon then
        self.Deferred_Logon = true
        self:EmitSound("snaptic/win7_logon.mp3")
    end

    local operators = Snaptic.Operators
    if not operators[self] then
        operators[#operators+1] = self
        operators[self] = true
    end

    local cursors = self.Cursors
    for i=#cursors, 1, -1 do
        local cursor = cursors[i]
        if not IsValid(cursor) then
            table.remove(cursors, i)
            cursors[cursor] = nil
            continue
        end
        cursor:SetSize(20 * owner:GetModelScale())
        cursor.idle_temp = true -- mark initially as idle, any logic should override this
    end

    local drag = self:GetDrag()
    if drag ~= self.last_drag then
        self:OnDrag(drag)
        self.last_drag = drag
    end

    local auto = self:GetAuto()
    if auto ~= self.last_auto then
        self:OnAuto(auto)
        self.last_auto = auto
    end

    if active then
        if self.IN_RELOAD and not owner:KeyDown(IN_RELOAD) then
            self.IN_RELOAD = false
        end
        
        if self:GetDrag() then
            self:SetHoldType("magic")
        else
            self:SetHoldType("idle")
        end
        
        if self:GetDrag() or IsValid(self:GetContext()) then
            local first = cursors[1]
            if first then
                first.idle_temp = false
                self:SetDragCursor(first)
                self:DragLogic(first)
            elseif self:IsDragging() then
                self:DragRelease(first)
            end
        elseif self:IsDragging() then
            self:DragRelease()
        end
    end

    if self:GetAuto() then
        self:AutoLogic()
    end

    self:IdleLogic()
end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local operators = Snaptic.Operators
    if not operators[self] then
        operators[#operators+1] = self
        operators[self] = true
        self:CleanCursors()
        for i=1, 3 do self:CreateCursor() end
    end

    local dragging = self:GetDragEntity()
    if dragging and not self.dragging_debounce then
        local wheel = owner:GetCurrentCommand():GetMouseWheel()
        if wheel ~= 0 then
            local distance = self:GetDragDistance()
            local MIN_DIST = self.Helpers.MIN_DIST
            if dragging == owner then MIN_DIST = 0 end
            distance = math.min(math.max(distance + wheel * owner:GetInfoNum("physgun_wheelspeed", 10), MIN_DIST), self.Helpers.MAX_DIST)
            self:SetDragDistance(distance)
        end

        if owner:KeyDown(IN_USE) then
            local angle = self:GetDragLocalAng()
            local cmd = owner:GetCurrentCommand()
            local mx, my = cmd:GetMouseX(), cmd:GetMouseY()
            local viewAng = owner:EyeAngles()
            local right = viewAng:Right()
            local up = viewAng:Up()
            angle:RotateAroundAxis(up, mx / 25)
            angle:RotateAroundAxis(right, my / 25)
            self:SetDragLocalAng(angle)
        end
    end
end

hook.Add("PostCleanupMap", "Snaptic.Regenerate", function()
    local operators = Snaptic.Operators
    for i=#operators, 1, -1 do
        local operator = operators[i]
        if not IsValid(operator) then
            table.remove(operators, i)
            operators[operator] = nil
            continue
        end
        operator:CleanCursors()
        for i=1, 3 do operator:CreateCursor() end
    end
end)

hook.Add("Think", "Snaptic.Hibernate", function()
    local operators = Snaptic.Operators
    for i=#operators, 1, -1 do
        local operator = operators[i]
        if not IsValid(operator) then
            table.remove(operators, i)
            operators[operator] = nil
            continue
        end
        local invoker = operator:GetOwner()
        if not IsValid(invoker) then continue end
        local active = invoker:GetActiveWeapon()
        local state = active == operator
        local spectate = IsValid(invoker:GetObserverTarget())

        if spectate then
            state = false
        end

        if not spectate and (operator:GetAlways() or state) then
            operator:Calculate(state)
            if not operators[operator] then
                continue
            end
        end

        if state ~= operator.Active then
            if not state then
                operator:Holster() -- sometimes holster isn't called...
            else
                operator:Deploy()
            end
            operator.Active = state
        end
    end
end)

hook.Add("DoPlayerDeath", "Snaptic.Boxify", function(invoker, attacker, dmg)
    local inflictor = dmg:GetInflictor()
    if IsValid(inflictor) and inflictor:GetClass() == "snaptic_cursor_handle" then
        Snaptic.Helpers.Boxify(invoker)
        return
    end

    local operator = invoker:GetWeapon("snaptic_cursor")
    local active = invoker:GetActiveWeapon()
    if not IsValid(operator) then return end
    if operator:GetAlways() or active == operator then
        invoker:EmitSound("snaptic/win7_start.mp3")
        operator.Helpers.Boxify(invoker)
    end
end)

hook.Add("EntityTakeDamage", "Snaptic.Damage", function(invoker, cdmg)
    if not IsValid(invoker) or not invoker:IsPlayer() then return end
    local operator = invoker:GetWeapon("snaptic_cursor")
    local active = invoker:GetActiveWeapon()
    if not IsValid(operator) then return end
    if operator:GetAlways() or active == operator then
        if operator:OnDamage(cdmg) then return true end
    end
end)