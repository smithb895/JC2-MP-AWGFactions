--[[
    Title: AWG Factions
    Author: Anzu
    Org: http://www.AnzusWarGames.info
    Version: 0.03
    Description: This factions mod was written from scratch by Anzu, with 
                inspiration coming from the original factions mod written by
                Philpax and the JC2-MP dev team. This script was meant for 
                public use amongst the JC2-MP community. Anyone is free to use
                and modify this as long as they give me credit for the code 
                I've written and don't try to commercialize it. It's a free
                mod after all, right? :) If you want to help code more features
                and fix bugs, please clone it on Github!
                    https://github.com/smithb895/JC2-MP-AWGFactions
--]]

class 'AWGFactions'


function AWGFactions:__init()
    print("Initializing AWGFactions clientside factionTags.lua...")
    --Network:Subscribe("FactionMembers", function(args) factionMembers = args end)
    self.mySteamID = LocalPlayer:GetSteamId().id
    
    -- Receive table with faction members in format: {[steamid] = {"FactionName", Color(1,2,3)}}
    Network:Subscribe("FactionMembers", self, self.ReceiveMembers)
    -- Receive table with allied factions in format: {[faction] = {["Faction1"] = true,["Faction2"] = true}}
    Network:Subscribe("AlliedFactions", self, self.ReceiveAllies)
    -- Receive table with enemy factions in format: {[faction] = {["Faction1"] = true,["Faction2"] = true}}
    Network:Subscribe("EnemyFactions", self, self.ReceiveEnemies)
    -- Render Faction tags
    Events:Subscribe( "Render", self, self.RenderTag)
    
    Events:Subscribe("LocalPlayerExplosionHit", self, self.HandleDamage)
    Events:Subscribe("LocalPlayerBulletHit", self, self.HandleDamage)
    Events:Subscribe("LocalPlayerForcePulseHit", self, self.HandleDamage)
end

function AWGFactions:ReceiveMembers(args)
    --print("Receiving list of all online faction players")
    factionMembers = args
    --for k,v in pairs(factionMembers) do
    --    print(k .. " : { " .. v[1])
    --end
end

function AWGFactions:ReceiveAllies(args)
    --print("Receiving list of allied factions")
    alliedFactions = args
    --for k,v in pairs(alliedFactions) do
    --    print(k .. " allies:")
    --    for i,d in pairs(v) do
    --        print(i)
    --    end
    --end
end

function AWGFactions:ReceiveEnemies(args)
    --print("Receiving list of enemy factions")
    enemyFactions = args
    --for k,v in pairs(enemyFactions) do
    --    print(k .. " enemies:")
    --    for i,d in pairs(v) do
    --        print(i)
    --    end
    --end
end

function AWGFactions:DrawShadowedText( pos, text, colour, size, scale )
    if scale == nil then scale = 1.0 end
    if size == nil then size = TextSize.Default end

    local shadow_colour = Color( 0, 0, 0, colour.a )
    shadow_colour = shadow_colour * 0.4

    Render:DrawText( pos + Vector3( 1, 1, 0 ), text, shadow_colour, size, scale )
    Render:DrawText( pos, text, colour, size, scale )
end

function AWGFactions:DrawFactionTag(playerPos,dist,text,color,scaleText)
    local scaleText = scaleText or 1.0
    local pos = playerPos + Vector3( 0, 2.5, 0 )
    local angle = Angle( Camera:GetAngle().yaw, 0, math.pi ) * Angle( math.pi, 0, 0 )

    local text_size = Render:GetTextSize( text, TextSize.Default )
    
    local worldRange = 300
    local scaleRange = 0.016
    local scaleMin = 0.005
    
    local scale = ((dist * scaleRange) / worldRange) + scaleRange
    
    if dist <= 50 then
        --scale = ((math.clamp( dist, 1, 50 ) - 1)/1) * scaleRange
    elseif dist >= 200 then
        --scale = (1 - (math.clamp( dist, 200, 800 ) - 1)/1) * scaleRange
    end

    local t = Transform3()
    t:Translate( pos )
    t:Scale( scale )
    t:Rotate( angle )
    t:Translate( -Vector3( text_size.x, text_size.y, 0 )/2 )

    Render:SetTransform( t )

    --local alpha_factor = 255

    --if dist <= 250 then
    --    alpha_factor = ((math.clamp( dist, 1, 250 ) - 1)/1) * 255
    --elseif dist >= 600 then
    --    alpha_factor = (1 - (math.clamp( dist, 600, 800 ) - 1)/1) * 255
    --end

    self:DrawShadowedText( Vector3( 0, 0, 0 ), text, color, TextSize.Default, scaleText )
end

function AWGFactions:ClientGetFaction(steamid)
    local theFaction = ""
    if factionMembers[steamid] ~= nil then
        theFaction = factionMembers[steamid][1]
    end
    return theFaction
end

function AWGFactions:IsMyAlly(steamid)
    local myFaction = self:ClientGetFaction(LocalPlayer:GetSteamId().id)
    local theirFaction = self:ClientGetFaction(steamid)
    if myFaction:len() > 0 and theirFaction:len() > 0 then
        local myAllies = alliedFactions[myFaction]
        if myAllies[theirFaction] or theirFaction == myFaction then
            --print(myFaction .. " is allies with " .. theirFaction)
            return true
        end
    end
    return false
end

function AWGFactions:IsMyEnemy(steamid)
    local myFaction = self:ClientGetFaction(LocalPlayer:GetSteamId().id)
    local theirFaction = self:ClientGetFaction(steamid)
    if myFaction:len() > 0 and theirFaction:len() > 0 then
        local myEnemies = enemyFactions[myFaction]
        if myEnemies[theirFaction] then
            --print(myFaction .. " is enemies with " .. theirFaction)
            return true
        end
    end
    return false
end

function AWGFactions:HandleDamage(args)
    local attacker = args.attacker:GetSteamId().id
    if factionMembers[attacker] then
        if self:IsMyAlly(attacker) then
            return false
        end
    end
    return true
end

function AWGFactions:RenderTag()
    if Game:GetState() ~= GUIState.Game then return end
    --if LocalPlayer:GetWorld() ~= DefaultWorld then return end
    for ply in Client:GetPlayers() do
        if factionMembers[ply:GetSteamId().id] ~= nil then -- If in factionMembers table, draw tag
            local playerPos = ply:GetPosition()
            if playerPos ~= nil then
                local dist = playerPos:Distance2D( Camera:GetPosition() )
                if dist < 800 then
                    local steamid = ply:GetSteamId().id
                    self:DrawFactionTag(playerPos,dist,"[" .. factionMembers[steamid][1] .. "]",factionMembers[steamid][2])
                    if self:IsMyAlly(steamid) then
                        local tagPos = playerPos + Vector3(0,0.3,0)
                        self:DrawFactionTag(tagPos,dist,"(Ally)",awgColors["brightgreen"],0.8)
                    elseif self:IsMyEnemy(steamid) then
                        local tagPos = playerPos + Vector3(0,0.3,0)
                        self:DrawFactionTag(tagPos,dist,"(Enemy)",awgColors["red"],0.8)
                    end
                end
            end
        end
    end
end

local factionTags = AWGFactions()