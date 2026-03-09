local ENT = _ENT
if not ENT then
    print("[Snaptic] to reload this file, please reload the shared.lua")
    return
end

do
    local timescale_cvar = GetConVar('host_timescale')
    function ENT:Draw()
        if self:GetHidden() then return end
        if self:GetDebug() then
            render.DrawWireframeBox(self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs())
        end
        -- cannot draw cursor here even with IgnoreZ, still clips with things...
    end

    function ENT:GetPredictedPos()
        local operator = self:GetOperator()
        local lp = LocalPlayer()
        if operator:GetOwner() == lp then
            if operator:Predictable(self) then
                return self.predicted_position or self:GetPos()
            end
        end
        return self:GetPos()
    end

    function ENT:SetPredictedPos(vec)
        self.predicted_position = vec
    end

    function ENT:Render()
        if self:GetHidden() then return end

        local ct = CurTime()
        local st = SysTime()
        local ft = FrameTime()
        local tr = engine.TickInterval() / timescale_cvar:GetFloat()
        local operator = self:GetOperator()
        if not IsValid(operator) then return end
        local position = self:GetPredictedPos() + self:OBBCenter()
        local owner = operator:GetOwner()
        if not IsValid(owner) then return end

        -- raw blending via interpolation
        self.position_blended = LerpVector(ft * (1/tr)/3, self.position_blended or position, position)

        if self:GetInterpolate() then
            self.position = self.position_blended
        else
            self.position = position
        end

        local position = self.position
        if not position then return end
        local size = self:GetSize()
        local color = self:GetColor()
        local type = self:GetType()
        local material = self.Types[type]
        if not material then material = self.Types.arrow end

        if self:GetEmote() + 1 > ct and self.Types.hand_open then
            material = self.Types.hand_open
        end

        if self:GetImmunity() > ct then
            color = Color(255, 0, 0)
            local rnd = self.Types_RND
            local select = 1 + (math.Round(ct * 25) % #rnd)
            local id = rnd[select]
            material = self.Types[id]
            position = position + VectorRand(-2, 2)
        end

        render.SetMaterial(material)
        local ep = EyePos()
        local ignorez = true

        if self:GetIdle() then
            ignorez = false
        elseif operator.IsDragging then
            ignorez = not operator:TraceLine({
                start = ep,
                endpos = position + (ep - position):GetNormalized() * 15,
                mask = MASK_SHOT
            }, LocalPlayer(), operator:IsDragging()).Hit
        end

        do
            local center = operator.Helpers.OBBCenter(owner)
            local self_radius = operator.Helpers.OBBRadius(owner)
            local scale = owner:GetModelScale()
            local center = owner:GetPos() + owner:OBBCenter()
            local dist = math.max((self.position - center):Length() - self_radius + (15 * scale), 0)
            size = math.max(math.min(dist / 25, 50), size)
        end

        cam.IgnoreZ(ignorez)
        render.DrawSprite(position, size, size, color)
        cam.IgnoreZ(false)

        local lives = self:GetLives()
        local durability = self:GetDurability()
        if self.last_lives ~= lives or self.last_durability ~= durability then
            self.last_lives = lives
            self.last_durability = durability
            self.show_durability = ct + 5
        end

        if self:GetDebug() then
            local angle = ( self:GetPos() - EyePos() ):GetNormalized():Angle()
            angle = Angle( 0, angle.y, 0 )
            angle:RotateAroundAxis( angle:Up(), -90 )
            angle:RotateAroundAxis( angle:Forward(), 90 )
            cam.Start3D2D(self:GetPos() + Vector(0, 0, 5), angle, 0.1)
                surface.SetFont("DermaDefault")
                local vars = Snaptic.Helpers.DebugVariables(self)
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
            render.DrawLine(self:GetPos(), position, color_white, true)
        elseif self.show_durability > ct then
            local ep = EyePos() local ea = EyeAngles()
            local view_angle = Angle(0, ea.y - 90, 90 - ea.p)

            cam.Start3D2D(position + Vector(0,0,1), view_angle, 0.1)
                surface.SetAlphaMultiplier(math.Clamp(self.show_durability - ct, 0, 1))

                local seg_width = 15
                local seg_height = 5
                local spacing = 2

                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawRect(-((seg_width + spacing) * lives) / 2, -seg_height / 2, (seg_width + spacing) * lives, seg_height)

                for i = 1, lives do
                    local x = -((seg_width + spacing) * lives) / 2 + (i - 1) * (seg_width + spacing)
                    local fillFrac = 1
                    if i == lives then
                        fillFrac = math.Clamp(durability / self.CVAR_Durability:GetFloat(), 0, 1)
                    end
                    local w = seg_width * fillFrac

                    surface.SetDrawColor(60, 60, 60, 220)
                    surface.DrawRect(x, -seg_height / 2, seg_width, seg_height)

                    surface.SetDrawColor(0, 200, 0, 255)
                    surface.DrawRect(x, -seg_height / 2, w, seg_height)
                end

                surface.SetAlphaMultiplier(1)
            cam.End3D2D()
        end
    end

    hook.Add("PostDrawTranslucentRenderables", "Snaptic.Cursors", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
        if bDrawingSkybox then return end
        local cursors = ENT.Cursors
        local c = 0
        for i=1, #cursors do
            local cursor = cursors[i-c]
            if not IsValid(cursor) then
                table.remove(cursor, i-c) c = c + 1
                cursors[cursor] = nil
                continue
            end
            if cursor:IsDormant() then continue end
            cursor:Render()
        end
    end)
end