--[[
    Title: AWG Factions
    Author: Anzu
    Org: http://www.AnzusWarGames.info
    Version: 0.01
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
    -- Receive table with faction members in format: {[steamid] = {"FactionName", Color(1,2,3)}}
    print("Initializing AWGFactions clientside factionTags.lua...")
    --Network:Subscribe("FactionMembers", function(args) factionMembers = args end)
    Network:Subscribe("FactionMembers", self, self.ReceiveMembers)
    Events:Subscribe( "Render", self, self.RenderTag)
end

function AWGFactions:ReceiveMembers(args)
    print("Receiving list of all online faction players")
    factionMembers = args
    --for k,v in pairs(factionMembers) do
    --    print(k .. " : { " .. v[1])
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

function AWGFactions:DrawFactionTag(playerPos,dist,faction,color)
    local pos = playerPos + Vector3( 0, 2.5, 0 )
    local angle = Angle( Camera:GetAngle().yaw, 0, math.pi ) * Angle( math.pi, 0, 0 )

    local text = "[" .. faction .. "]"
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

    self:DrawShadowedText( Vector3( 0, 0, 0 ), text, color, TextSize.Default )
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
                    self:DrawFactionTag(playerPos,dist,factionMembers[steamid][1],factionMembers[steamid][2])
                end
            end
        end
    end
end

local factionTags = AWGFactions()