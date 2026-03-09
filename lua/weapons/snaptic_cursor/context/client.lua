local ENT = _ENT
if not ENT then
    print("[Snaptic] to reload this file, please reload the shared.lua")
    return
end

surface.CreateFont("Snaptic.Context", {
    font = "Arial",
    size = 24,
    weight = 500,
})

do
    function ENT:Draw()
        if self:GetHidden() then return end
        if self:GetDebug() then
            render.DrawWireframeBox(self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs())
        end
    end

    function ENT:Render()
        if self:GetHidden() then return end
        local ct = CurTime()
        local st = SysTime()
        local ft = FrameTime()
        local position = self:GetPos()
        local operator = self:GetOperator()
        local target = self:GetTarget()
        if not IsValid(target) or not IsValid(operator) then return end
        local angle = self:GetAngles()
        angle:RotateAroundAxis(angle:Up(), -90)
        angle:RotateAroundAxis(angle:Forward(), 90)

        if target ~= operator:GetOwner() and target ~= self:GetCursor() then
            render.DrawLine(position, target:GetPos() + target:OBBCenter(), color_white, true)
        end

        local cursor = self:GetCursor()
        if IsValid(cursor) and cursor:GetZipped() then
            if not self.zipped_position then
                self.zipped_position = cursor:GetPredictedPos()
            end
            render.DrawLine(position, self.zipped_position, color_white, true)
            render.DrawWireframeBox(self.zipped_position, Angle(0, cursor:GetAngles().y, 0), cursor:GetZippedMin(), cursor:GetZippedMax(), true)
        end

        local spacing = self.RenderSpacing
        cam.Start3D2D(position, angle, self.RenderScale)
            surface.SetFont("Snaptic.Context")
            local w, h = 0, 0
            local y = 0
            local options = self.options
            for i=1, #options do
                local option = options[i]
                local type = option.type
                if option.type == "option" then
                    local tw, th = surface.GetTextSize(option.name)
                    if option.icon then
                        tw = tw + 16 + 4
                    end
                    w = math.max(w, tw + 8)
                    y = y + th + spacing
                elseif option.type == "spacer" then
                    y = y + 1 + spacing
                end
            end
            h = y - spacing

            surface.SetDrawColor(96, 96, 96)
            surface.DrawRect(-2, -2, w+4, h+4)
            surface.SetDrawColor(255, 255, 255)
            surface.DrawRect(-1, -1, w+2, h+2)
            local option_index = self:GetOption()

            local y = 0
            for i=1, #options do
                local option = options[i]
                local type = option.type
                if option.type == "option" then
                    local tw, th = surface.GetTextSize(option.name)
                    if option.icon then
                        if not option.material then
                            option.material = Material("materials/icon16/" .. option.icon .. ".png")
                        end
                        tw = tw + 16 + 4
                    end

                    surface.SetDrawColor(255, 255, 255)
                    surface.DrawRect(0, y, tw + 4, th)
                        
                    if option_index == i then
                        surface.SetDrawColor(104, 156, 248, 128)
                        surface.DrawRect(0, y, w, th)

                        surface.SetDrawColor(104, 156, 248, 255)
                        surface.DrawOutlinedRect(0, y, w, th, 1)
                    end

                    if option.material then
                        surface.SetDrawColor(255, 255, 255)
                        surface.SetMaterial(option.material)
                        surface.DrawTexturedRect(4, y + 3, 16, 16)
                        surface.SetTextPos(2 + 16 + 6, y)
                    else
                        surface.SetTextPos(2, y)
                    end
                    surface.SetTextColor(0, 0, 0)
                    surface.DrawText(option.name, false)
                    y = y + th + spacing
                elseif option.type == "spacer" then
                    surface.SetDrawColor(96, 96, 96)
                    surface.DrawRect(2, y, w - 4, 1)
                    y = y + 1 + spacing
                end
            end
        cam.End3D2D()

        if self:GetDebug() then
            local angle = ( self:GetPos() - EyePos() ):GetNormalized():Angle()
            angle = Angle( 0, angle.y, 0 )
            angle:RotateAroundAxis( angle:Up(), -90 )
            angle:RotateAroundAxis( angle:Forward(), 90 )
            cam.Start3D2D(self:GetPos() + Vector(0, 0, 2), angle, 0.1)
                surface.SetFont("DermaDefault")
                local vars = Snaptic.Helpers.DebugVariables(self)
                local toffset = 0
                for k, v in pairs(vars) do
                    local str = k .. ": " .. tostring(v)
                    local tw, th = surface.GetTextSize(str)
                    surface.SetTextPos(2, -toffset)
                    toffset = toffset + th + 1
                    surface.SetTextColor(255, 255, 255)
                    surface.DrawText(str, false)
                end
            cam.End3D2D()
        end
    end

    hook.Add("PostDrawTranslucentRenderables", "Snaptic.Contexts", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
        if bDrawingSkybox then return end
        local contexts = ENT.Contexts
        local c = 0
        for i=1, #contexts do
            local context = contexts[i-c]
            if not IsValid(context) then
                table.remove(contexts, i-c) c = c + 1
                contexts[context] = nil
                continue
            end
            if context:IsDormant() then continue end
            context:Render()
        end
    end)
end