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
    -- Some init stuph could go here :3
    self.red = Color(255,0,0)
    self.blue = Color(0,0,255)
    self.green = Color(0,255,0)
    self.white = Color(255,255,255)
    
    -- Init tables
    SQL:Execute("CREATE TABLE IF NOT EXISTS awg_members (steamid VARCHAR UNIQUE, faction VARCHAR, rank INTEGER, last_seen DATETIME DEFAULT CURRENT_TIMESTAMP)")
    SQL:Execute("CREATE TABLE IF NOT EXISTS awg_factions (faction VARCHAR UNIQUE, num_members INTEGER, passwd VARCHAR DEFAULT NULL, salt VARCHAR, created_on DATETIME DEFAULT CURRENT_TIMESTAMP)")
        
    -- Indices supported???
    --SQL:Execute("CREATE INDEX steamid_index ON awg_factions(steamid)")
    
    Events:Subscribe("PlayerChat", self, self.ParseChat)
end

function AWGFactions:ParseChat(args)
    if args.text:sub(1,3) == "/f " then
        --local msg = string.gsub(args.text, "/f ", "")
        local msg = string.split(args.text, " ")
        local mySteamID = args.player:GetSteamId().id
        local myName = args.player:GetName()
        
        -- Queries
        self.queryPassSalt = SQL:Query("SELECT passwd,salt FROM awg_factions WHERE faction = (?)")
        self.queryGetRank = SQL:Query("SELECT rank FROM awg_members WHERE steamid = (?)")
        self.queryLastSeen = SQL:Query("SELECT last_seen FROM awg_members WHERE steamid = (?)")
        self.queryIsFaction = SQL:Query("SELECT rowid FROM awg_factions WHERE faction = (?)")
        self.queryInFaction = SQL:Query("SELECT faction FROM awg_members WHERE steamid = (?)")
        self.queryFactionEst = SQL:Query("SELECT created_on FROM awg_factions WHERE faction = (?)")
        self.queryGetMembers = SQL:Query("SELECT steamid FROM awg_members WHERE faction = (?)")
        self.queryCountMembers = SQL:Query("SELECT num_members FROM awg_factions WHERE faction = (?)")
        -- Transactions
        self.querySetPass = SQL:Command("UPDATE awg_factions SET passwd = (?) WHERE faction = (?)")
        self.querySetRank = SQL:Command("UPDATE awg_members SET rank = (?) WHERE steamid = (?)")
        self.queryAddMember = SQL:Command("INSERT OR REPLACE INTO awg_members (steamid,faction,rank) VALUES (?,?,?)")
        self.queryNewFaction = SQL:Command("INSERT INTO awg_factions (faction,passwd,salt) VALUES (?,?,?)")
        self.queryDelMember = SQL:Command("DELETE FROM awg_members WHERE steamid = (?)")
        self.queryDelFaction = SQL:Command("DELETE FROM awg_factions WHERE faction = (?)")
        self.queryDelMembers = SQL:Command("DELETE FROM awg_members WHERE faction = (?)")
        
        if msg[2] == "join" then
            if table.count(msg) > 4 then
                args.player:SendChatMessage(
                    "There are too many spaces. Faction names and passwords must NOT contain spaces! Press F5 for help.",
                    self.red )
            elseif table.count(msg) > 2 then
                local factionName = msg[3]
                -- Should not contain non alphanumeric chars
                if factionName:match("%W") then
                    args.player:SendChatMessage(
                        "Faction name contains invalid chars. Only alphanumeric allowed!",
                        self.red )
                else
                    self.queryIsFaction:Bind(1, factionName)
                    local result = self.queryIsFaction:Execute()
                    if #result > 0 then -- Faction exists
                        local rank = 1
                        self.queryPassSalt:Bind(1, factionName)
                        result = self.queryPassSalt:Execute()
                        local dbPass = result[1].passwd
                        local salt = result[1].salt
                        if string.len(dbPass) > 0 then -- There's a faction password
                            if table.count(msg) ~= 4 then
                                print("INFO: " .. args.player:GetSteamId().string .. " tried to join private faction " .. factionName .. " without supplying a password")
                                args.player:SendChatMessage(
                                    "There is a password required to join this faction. You must provide the correct password to join. Usage: Usage: /f join <faction> <password>",
                                    self.red )
                            else
                                local factionPass = msg[4]
                                if factionPass:match("%W") then
                                    args.player:SendChatMessage(
                                        "Faction password contains invalid chars. Only alphanumeric allowed!",
                                        self.red )
                                else
                                    factionPass = SHA256.ComputeHash(salt .. factionPass)
                                    if factionPass == dbPass then
                                        if self:JoinFaction(factionName,mySteamID,rank) then
                                            print("INFO: " .. args.player:GetSteamId().string .. " successfully joined private faction " .. factionName)
                                            args.player:SendChatMessage(
                                                "Successfully joined " .. factionName,
                                                self.green )
                                        else
                                            print("ERROR: " .. args.player:GetSteamId().string .. " was unable to join private faction " .. factionName .. " . But the password was correct")
                                            args.player:SendChatMessage(
                                                "ERROR: Failed to join " .. factionName,
                                                self.red )
                                        end
                                    else
                                        print("WARN: " .. args.player:GetSteamId().string .. " supplied the wrong password for private faction " .. factionName)
                                        args.player:SendChatMessage(
                                            "Wrong faction password! Get lost punk!",
                                            self.red )
                                    end
                                end
                            end
                        else -- No password, go ahead and join
                            if self:JoinFaction(factionName,mySteamID,rank) then
                                print("INFO: " .. args.player:GetSteamId().string .. " successfully joined public faction " .. factionName)
                                args.player:SendChatMessage(
                                    "Successfully joined " .. factionName,
                                    self.green )
                            else
                                print("ERROR: " .. args.player:GetSteamId().string .. " was unable to join public faction " .. factionName)
                                args.player:SendChatMessage(
                                    "ERROR: Failed to join " .. factionName,
                                    self.red )
                            end
                        end
                    else -- Faction doesn't exist, create it, with password
                        if table.count(msg) > 3 then
                            local plaintextPass = msg[4]
                            if plaintextPass:match("%W") then
                                args.player:SendChatMessage(
                                    "Faction password contains invalid chars. Only alphanumeric allowed!",
                                    self.red )
                            else
                                local salt = self.RandString()
                                factionPass = SHA256.ComputeHash(salt .. plaintextPass)
                                if self:AddFaction(factionName,factionPass,mySteamID,salt) then
                                    print("INFO: " .. args.player:GetSteamId().string .. " successfully created private faction " .. factionName)
                                    args.player:SendChatMessage(
                                        "Successfully created private faction: " .. factionName .. " Password: " .. plaintextPass,
                                        self.green )
                                else
                                    print("ERROR: " .. args.player:GetSteamId().string .. " was unable to create private faction " .. factionName)
                                    args.player:SendChatMessage(
                                        "ERROR: Failed to create new private faction: " .. factionName,
                                        self.red )
                                end
                            end
                        else
                            local factionPass = ""
                            local factionSalt = ""
                            if self:AddFaction(factionName,factionPass,mySteamID,factionSalt) then
                                print("INFO: " .. args.player:GetSteamId().string .. " successfully created public faction " .. factionName)
                                args.player:SendChatMessage(
                                    "Successfully created public faction: " .. factionName,
                                    self.green )
                            else
                                print("ERROR: " .. args.player:GetSteamId().string .. " was unable to create private faction " .. factionName)
                                args.player:SendChatMessage(
                                    "ERROR: Failed to create new public faction: " .. factionName,
                                    self.red )
                            end
                        end
                    end
                end
            else -- Show usage help for "/f join"
                args.player:SendChatMessage(
                    "Join a faction. If faction does not exist, it is created. Password is optional. Usage: /f join <faction> <password>",
                    self.blue )
            end
        elseif msg[2] == "leave" then
            local checkID = args.player:GetSteamId().id
            self.queryInFaction:Bind(1, checkID)
            local result = self.queryInFaction:Execute()
            if #result > 0 then -- If any rows are returned, player is in a faction
                local myFaction = result[1].faction
                if self:QuitFaction(mySteamID,myFaction) then
                    print("INFO: " .. args.player:GetSteamId().string .. " left faction " .. myFaction)
                    args.player:SendChatMessage(
                        "You left " .. myFaction,
                        self.green )
                else
                    print("ERROR: " .. args.player:GetSteamId().string .. " was unable to leave faction " .. myFaction)
                    args.player:SendChatMessage(
                        "ERROR: Failed to leave faction " .. myFaction,
                        self.red )
                end
            else
                args.player:SendChatMessage(
                    "You are not currently in any faction!",
                    self.red )
            end
        elseif msg[2] == "setrank" then -- check 2 args (player, rank)
            -- Use Command Manager here
            print("Not done yet")
        else -- If not a faction command, treat as faction chat
            local msg = string.gsub(args.text, "/f ", "")
            local checkID = args.player:GetSteamId().id
            self.queryInFaction:Bind(1, checkID)
            local result = self.queryInFaction:Execute()
            if #result > 0 then
                local myFaction = result[1].faction
                if not self:ChatFaction(myName,myFaction,msg) then
                    print("ERROR: " .. args.player:GetSteamId().string .. " was unable to use faction chat for faction: " .. myFaction)
                    args.player:SendChatMessage(
                        "ERROR: Error sending faction chat message",
                        self.red )
                end
            else
                args.player:SendChatMessage(
                    "You are trying to use faction chat, but you are not in a faction! Press F5 for help",
                    self.red )
            end
        end
        return false
    elseif args.text == "/f" then -- Show usage help
        args.player:SendChatMessage(
            "AWG Factions Mod. Press F5 for detailed help. Example Usage: /f join <faction> <password>",
            self.blue )
        return false
    end
end

-- Returns bool
function AWGFactions:AddFaction(faction,passwd,steamid,salt)
    --local transaction = SQL:Transaction()
    self.queryNewFaction:Bind(1, faction)
    self.queryNewFaction:Bind(2, passwd)
    self.queryNewFaction:Bind(3, salt)
    self.queryNewFaction:Execute()
    --transaction:Commit()
    local rank = 3
    if self:JoinFaction(faction,steamid,rank) then
        print("INFO: " .. tostring(steamid) .. " joined newly created faction " .. faction .. " as leader")
    else
        print("ERROR: " .. tostring(steamid) .. " failed to join newly create faction " .. faction .. " as leader")
    end
    return true
end

-- Returns bool
function AWGFactions:DelFaction(faction)
    --local transaction = SQL:Transaction()
    self.queryDelFaction:Bind(1, faction)
    self.queryDelFaction:Execute()
    -- Delete all members of factions as well
    self.queryDelMembers:Bind(1, faction)
    self.queryDelMembers:Execute()
    --transaction:Commit()
    return true
end

-- Return bool
function AWGFactions:JoinFaction(faction,steamid,rank)
    --local transaction = SQL:Transaction()
    self.queryInFaction:Bind(1, steamid)
    local result = self.queryInFaction:Execute()
    if #result > 0 then -- player is already in a faction, so remove them from it
        self:QuitFaction(steamid,faction)
    end
    self.queryAddMember:Bind(1, steamid)
    self.queryAddMember:Bind(2, faction)
    self.queryAddMember:Bind(3, rank)
    self.queryAddMember:Execute()
    --transaction:Commit()
    return true
end

-- Return bool
function AWGFactions:QuitFaction(steamid,faction)
    if self:GetRank(steamid) == 3 then -- player is faction leader, so delete faction too
        if self:DelFaction(faction) then
            print("INFO: Deleted faction (Leader left faction): " .. faction)
        else
            print("ERROR: Unable to delete faction (Leader left faction): " .. faction)
        end
    else
        --local transaction = SQL:Transaction()
        self.queryDelMember:Bind(1, steamid)
        self.queryDelMember:Execute()
        --transaction:Commit()
    end
    return true
end

-- Return bool
function AWGFactions:ChatFaction(myName,myFaction,msg)
    self.queryGetMembers:Bind(1, myFaction)
    local result = self.queryGetMembers:Execute()
    local factionMembers = {}
    for i = 1, #result do
        --print(tostring(result[i].steamid))
        factionMembers[result[i].steamid] = true
    end
    for p in Server:GetPlayers() do
        if factionMembers[p:GetSteamId().id] then -- send message to faction members
            p:SendChatMessage(
                "[" .. myFaction .. "] " .. myName .. ": " .. msg,
                self.white )
        end
    end
    return true
end

function AWGFactions:RandString()
    math.randomseed(os.time())
    local randString = ""
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    for i = 1, 16 do
        rnd = math.random(#chars)
        randString = randString.. string.sub(chars, rnd, rnd)
    end
    return randString
end

-- Return bool
function AWGFactions:SetRank(args)
    -- TODO
    print("SetRank not done yet")
    return true
end

-- Return INT
function AWGFactions:GetRank(steamid)
    self.queryGetRank:Bind(1, steamid)
    local result = self.queryGetRank:Execute()
    if #result > 0 then
        return tonumber(result[1].rank)
    end
    return 0
end

awgFactions = AWGFactions()