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

local units = {"B", "KB", "MB", "GB", "TB", "PB", "EB"}
local file_size = function(bytes) -- TODO: to be moved to helpers
    local unitIndex = 1

    while bytes >= 1024 and unitIndex < #units do
        bytes = bytes / 1024
        unitIndex = unitIndex + 1
    end

    return string.format("%.2f %s", bytes, units[unitIndex])
end

local function draw_corners(position, angle, mins, maxs, color, zorder)
    local corners = {
        Vector(mins.x, mins.y, mins.z),
        Vector(mins.x, mins.y, maxs.z),
        Vector(mins.x, maxs.y, mins.z),
        Vector(mins.x, maxs.y, maxs.z),
        Vector(maxs.x, mins.y, mins.z),
        Vector(maxs.x, mins.y, maxs.z),
        Vector(maxs.x, maxs.y, mins.z),
        Vector(maxs.x, maxs.y, maxs.z),
    }
    for i = 1, 8 do
        local v = corners[i]
        corners[i] = position + (angle:Forward() * v.x + angle:Right() * v.y + angle:Up() * v.z)
    end
    local edges = {
        {1, 2}, {1, 3}, {1, 5},
        {2, 4}, {2, 6},
        {3, 4}, {3, 7},
        {4, 8},
        {5, 6}, {5, 7},
        {6, 8},
        {7, 8}
    }
    for _, edge in ipairs(edges) do
        local p1 = corners[edge[1]]
        local p2 = corners[edge[2]]
        local dir = (p2 - p1):GetNormalized()
        local length = corner_length
        render.DrawLine(p1, p1 + dir * 2, color, true)
        render.DrawLine(p2, p2 - dir * 2, color, true)
    end
end

local material_archive = Material("materials/snaptic/archive.png")
function ENT:Draw()
    draw_corners(self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs(), color_white, true)
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
    local er = (self:GetPos() - ep):Angle()
    local view_angle = Angle(0, er.y - 90, 90 - er.p)

    cam.Start3D2D(self:GetPos(), view_angle, 0.15)
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(material_archive)
        surface.DrawTexturedRectRotated(0, 0, 100, 100, 0)

        local t = "unknown.rar"
        if IsValid(self:GetPlayer()) then
            t = self:GetPlayer():Name():sub(1, 16) .. ".rar"
        else
            t = "archive.rar"
        end
        local _, hh = draw.SimpleTextOutlined(t, "DermaDefault", 0, 55, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
        draw.SimpleTextOutlined("Files: " .. self:GetFiles(), "DermaDefault", 55, 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
        draw.SimpleTextOutlined("Folders: " .. self:GetFolders(), "DermaDefault", 55, hh, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
        draw.SimpleTextOutlined("Size: " .. file_size(self:GetSize()), "DermaDefault", 55, hh * 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
    cam.End3D2D()
end