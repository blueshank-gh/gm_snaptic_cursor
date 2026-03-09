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

local mat_cache = {}
local default_material = Material("icon16/page_white.png")
function ENT:Draw()
    draw_corners(self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs(), color_white, true)
    local operator = self:GetOperator()
    if IsValid(operator) then
        local context = operator:GetContext()
        if IsValid(context) and context:GetTarget() == self then
            local relation = self:GetRelation()
            if IsValid(relation) then
                local obb = relation:OBBCenter()
                obb:Rotate(relation:GetAngles())
                render.DrawLine(self:GetPos(), relation:GetPos() + obb, color_white, true)
            end
        end
    end

    local ep = EyePos() local ea = EyeAngles()
    local er = (self:GetPos() - ep):Angle()
    local view_angle = Angle(0, er.y - 90, 90 - er.p)

    local icon = self:GetIcon()
    if not mat_cache[icon] and file.Exists("materials/" .. icon, "GAME") then
        mat_cache[icon] = Material(icon)
    end

    cam.Start3D2D(self:GetPos(), view_angle, 0.15)
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(mat_cache[icon] or default_material)
        surface.DrawTexturedRectRotated(0, 0, 100, 100, 0)

        --[[do  
            local durability = self:GetDurability()
            local seg_width = 100
            local seg_height = 5
            local spacing = 2

            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(-seg_width / 2, -55 -seg_height / 2, seg_width, seg_height)

            local x = -seg_width / 2
            local fillFrac = 1
            local w = seg_width * math.Clamp(durability / self:GetSize(), 0, 1)

            surface.SetDrawColor(60, 60, 60, 220)
            surface.DrawRect(x, -55 -seg_height / 2, seg_width, seg_height)

            surface.SetDrawColor(0, 200, 0, 255)
            surface.DrawRect(x, -55 -seg_height / 2, w, seg_height)
        end]]

        local t = self:GetTitle()
        local _, hh = draw.SimpleTextOutlined(t, "DermaDefault", 0, 58, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
        draw.SimpleTextOutlined("Size: " .. file_size(self:GetSize()), "DermaDefault", 55, 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
    cam.End3D2D()
end