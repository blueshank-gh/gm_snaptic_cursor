function SWEP:Holster(other)
    return true
end

function SWEP:OnDrag(state) end
function SWEP:OnAuto(state) end
function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end

do -- Drag Logic
    local last_view = nil
    local last_mx = 0
    local last_my = 0

    hook.Add("InputMouseApply", "Snaptic.Drag", function(cmd, mx, my, oang)
        last_mx = mx
        last_my = my
        local invoker = LocalPlayer()
        local weapon = invoker:GetActiveWeapon()
        if not IsValid(weapon) then return end
        if weapon:GetClass() ~= "snaptic_cursor" then return end
        if not weapon.IsDragging or not weapon:IsDragging() then return end
        if invoker:KeyDownLast(IN_USE) then
            cmd:SetMouseX(0)
            cmd:SetMouseY(0)
            return true
        end
    end)

    hook.Add("CreateMove", "Snaptic.Drag", function(cmd)
        local invoker = LocalPlayer()
        local weapon = invoker:GetActiveWeapon()
        if not IsValid(weapon) then last_view = nil return end
        if weapon:GetClass() ~= "snaptic_cursor" then last_view = nil return end
        if not weapon.IsDragging or not weapon:IsDragging() then last_view = nil return end
        if cmd:KeyDown(IN_USE) then
            if not last_view then
                last_view = cmd:GetViewAngles()
            end
            cmd:SetMouseX(last_mx)
            cmd:SetMouseY(last_my)
            cmd:SetForwardMove(0)
            cmd:SetSideMove(0)
            cmd:SetUpMove(0)
            cmd:SetViewAngles(last_view)
            return true
        else
            last_view = nil
        end
    end)

    local mWheelBtns = {
        [MOUSE_WHEEL_UP] = true,
        [MOUSE_WHEEL_DOWN] = true
    }

    hook.Add("PlayerBindPress", "Snaptic.Scroll", function(ply, _, _, code)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return end
        if mWheelBtns[code] and weapon:GetClass() == "snaptic_cursor" then
            if weapon:IsDragging() then
                return true
            end
        end
    end)
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

    local c = 0
    for i=1, count do
        local cursor = cursors[i]
        if not cursor:GetIdle() then -- cursors not marked with idle means they are in-use
            c = c + 1
            continue
        end

        local redir = cursor:GetRedirected()
        if redir and redir + 1 > ct then
            local redir_offset = cursor:GetRedirection()
            cursor:SetType("unavail")
            cursor:SetPredictedPos(center + redir_offset)
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
        local cur_pos = cursor:GetPredictedPos()
        local dist = cur_pos:Distance(last_vector)

        if length >= owner:GetRunSpeed() - 5 or dist > (chaining and (40 * scale) or orbit_radius + (20 * scale)) or chaining then
            local dir = last_vector - cur_pos
            cursor:SetPredictedPos(LerpVector(FrameTime() * 7.5, cur_pos, cur_pos + dir))
            cursor:SetAngles(dir:Angle())
            last_vector = cursor:GetPredictedPos()
            chaining = true
        else
            cursor:SetPredictedPos(wish)
            cursor:SetAngles(Angle(0, angle, 0))
        end
        cursor:SetType("arrow")
    end
end

function SWEP:DragLogic()
    local cursor = self:GetDragCursor()
    if not IsValid(cursor) then return end
    local entity = self:GetDragEntity()

    if IsValid(entity) and not entity:IsWorld() then
        local owner = self:GetOwner()
        local isPlayer = entity:IsPlayer()
        local bone = self:GetDragPhysBone()
        local matrix = entity:GetBoneMatrix(entity:TranslatePhysBoneToBone(bone))
        -- local phys = isPlayer and entity:GetPhysicsObject() or entity:GetPhysicsObjectNum(bone)
        -- ^ doesn't work properly on ragdolls
        if isPlayer then
            bone = 0
            matrix = false
        end
        local lpos = self:GetDragLocalPos()
        local lang = self:GetDragLocalAng()
        local pos = matrix and LocalToWorld(lpos, lang, matrix:GetTranslation(), matrix:GetAngles()) or LocalToWorld(lpos, lang, entity:GetPos(), entity:GetAngles())
        if entity ~= owner then
            cursor:SetPredictedPos(pos)
        else
            cursor:SetPredictedPos(owner:GetPos() + owner:OBBCenter())
        end
        return
    end

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

    if cursor:GetImmunity() <= CurTime() then
        cursor:SetPredictedPos(tr.HitPos)
        cursor:SetAngles(aim_vector:Angle())
    end
end

function SWEP:Predictable(cursor)
    local owner = self:GetOwner()
    if cursor:GetIdle() then
        return true
    end
    if self:GetDrag() and self:GetDragCursor() == cursor then
        return true
    end
    return false
end

function SWEP:Prediction(active)

end

function SWEP:Think()
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

    local operators = Snaptic.Operators
    if not operators[self] then
        operators[#operators+1] = self
        operators[self] = true
    end
end

function SWEP:Calculate(active)
    local cursors = self.Cursors

    for i=#cursors, 1, -1 do
        local cursor = cursors[i]
        if not IsValid(cursor) then
            table.remove(cursors, i)
            cursors[cursor] = nil
            continue
        end
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

    self:DragLogic()
    self:IdleLogic()
end

function SWEP:Render()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if self:GetDebug() then
        local radius = self.Helpers.OBBRadius(owner) + (15 * owner:GetModelScale())
        local position = owner:GetPos() + owner:OBBCenter()
        local angle_e = owner:EyeAngles()
        angle_e.p = 0
        angle_e.r = 0
        position = position + angle_e:Forward() * radius

        local angle = ( position - owner:EyePos() ):GetNormalized():Angle()
        angle = Angle( angle.p, angle.y, 0 )
        angle:RotateAroundAxis( angle:Up(), -90 )
        angle:RotateAroundAxis( angle:Forward(), 90 )

        cam.Start3D2D(position - Vector(0, 0, 5), angle, 0.1)
            surface.SetFont("DermaDefault")
            local vars = self.Helpers.DebugVariables(self)
            local toffset = 0
            local twmax = 0
            for k, v in pairs(vars) do
                local tw, th = surface.GetTextSize(k .. ": " .. tostring(v))
                twmax = math.max(twmax, tw)
            end
            for k, v in pairs(vars) do
                local str = k .. ": " .. tostring(v)
                local tw, th = surface.GetTextSize(str)
                surface.SetTextPos(-twmax/2, -toffset)
                toffset = toffset + th + 1
                surface.SetTextColor(255, 255, 255)
                surface.DrawText(str, false)
            end
        cam.End3D2D()
    end
end

hook.Add("SetupMove", "Snaptic.Hibernate", function(invoker, mv, cmd)
    local weapon = invoker:GetWeapon("snaptic_cursor")
    local active = invoker:GetActiveWeapon()
    if not IsValid(weapon) then return end
    if not weapon.DTSetup then return end
    if (active ~= weapon and weapon:GetAlways()) or active == weapon then
        weapon:Prediction(active == weapon)
    end
end)

hook.Add("Think", "Snaptic.Hibernate", function()
    local invoker = LocalPlayer()
    local weapon = invoker:GetWeapon("snaptic_cursor")
    local active = invoker:GetActiveWeapon()
    if not IsValid(weapon) then return end
    if not weapon.DTSetup then return end
    if (active ~= weapon and weapon:GetAlways()) or active == weapon then
        weapon:Calculate(active == weapon)
    end
end)

hook.Add("PostDrawTranslucentRenderables", "Snaptic.Render", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
    if bDrawingSkybox then return end
    local operators = Snaptic.Operators
    for i=#operators, 1, -1 do
        local operator = operators[i]
        if not IsValid(operator) then
            table.remove(operators, i)
            operators[operator] = nil
            continue
        end
        if operator:IsDormant() then continue end
        operator:Render()
    end
end)

function SWEP:OnRemove()
    local operators = Snaptic.Operators
    for i=1, #operators do
        if operators[i] == self then
            table.remove(operators, i)
            operators[self] = nil
            break
        end
    end
end