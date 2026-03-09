local Ragdoll = Snaptic.Ragdoll or {}
Snaptic.Ragdoll = Ragdoll

function Ragdoll.GetController(entity)
    if not IsValid(entity) or entity:GetClass() ~= "prop_ragdoll" then return false end
    local controller = entity:GetNW2Entity("snaptic.ragdoll")
    if not IsValid(controller) then return false end
    return controller
end

function Ragdoll.GetRagdoll(entity)
    if not IsValid(entity) or not entity:IsPlayer() then return false end
    local controller = entity:GetNW2Entity("snaptic.ragdoll")
    if not IsValid(controller) then return false end
    return controller
end

if SERVER then
    include("server.lua")
    AddCSLuaFile("client.lua")
else
    include("client.lua")
end

print("[Snaptic] Ragdolls are ready.")