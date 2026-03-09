local ENT = _ENT
if not ENT then
    print("[Snaptic] to reload this file, please reload the shared.lua")
    return
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
end

local material_archive = Material("materials/snaptic/archive.png")
function ENT:Draw()
    render.SetMaterial(material_archive)
    render.DrawSprite(self:GetPos(), 15, 15, color_white)
    render.DrawWireframeBox(self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs(), color_white, true)
    local operator = self:GetOperator()
    if IsValid(operator) then
        local context = operator:GetContext()
        if IsValid(context) and context:GetTarget() == self then
            if self:GetActive() then
                render.DrawWireframeBox(self:GetPos(), Angle(0, self:GetAngles().y, 0), self:GetMin(), self:GetMax(), color_white, true)
            end
        end
    end

    local ep = EyePos() local ea = EyeAngles()
    local view_angle = Angle(0, ea.y - 90, 90 - ea.p)

    cam.Start3D2D(self:GetPos(), view_angle, 0.15)
        local t = "unknown.rar"
        if IsValid(self:GetPlayer()) then
            t = self:GetPlayer():Name():sub(1, 16) .. ".rar"
        else
            t = "archive.rar"
        end
        draw.SimpleTextOutlined(t, "DermaDefault", 0, 55, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
    cam.End3D2D()
end