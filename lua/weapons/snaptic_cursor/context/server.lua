local ENT = _ENT
if not ENT then
    print("[Snaptic] to reload this file, please reload the shared.lua")
    return
end

function ENT:Interact(input_position)
    local option, index = self:SelectOption(input_position)
    if not option then return end
    if option.callback then
        local operator = self:GetOperator()
        local cursor = self:GetCursor()
        local target = self:GetTarget()
        local invoker = operator:GetOwner()
        operator.Helpers.Click(cursor:GetPos() + cursor:OBBCenter())
        option.callback(invoker, operator, self, cursor, target)
    end
end

function ENT:Process(input_position)
    if not input_position then
        self:SetOption(0)
        return
    end
    local option, index = self:SelectOption(input_position)
    if option then
        self:SetOption(index)
    else
        self:SetOption(0)
    end
end

function ENT:Close()
    local operator = self:GetOperator()
    operator:ContextRelease()
    operator.dragging_debounce = true
end