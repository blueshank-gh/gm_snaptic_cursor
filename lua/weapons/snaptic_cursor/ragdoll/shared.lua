local Ragdoll = Snaptic.Ragdoll or {}
Snaptic.Ragdoll = Ragdoll

Ragdoll.CVAR_Ragdoll_Struggle = CreateConVar(
    "snaptic_cursor_ragdoll_struggle",
    "0.5",
    { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
    "How long (in seconds, tick-based) a player can keyboard mash before breaking free from ragdoll.",
    0, 60
)

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