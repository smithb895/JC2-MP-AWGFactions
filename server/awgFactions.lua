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
    
    -- Init tables
    SQL:Execute("CREATE TABLE IF NOT EXISTS awg_members (steamid VARCHAR UNIQUE, faction VARCHAR, rank INTEGER, last_seen DATETIME DEFAULT CURRENT_TIMESTAMP)")
    SQL:Execute("CREATE TABLE IF NOT EXISTS awg_factions (faction VARCHAR UNIQUE, color VARCHAR, num_members INTEGER, banned VARCHAR, allies VARCHAR, enemies VARCHAR, passwd VARCHAR DEFAULT NULL, salt VARCHAR, created_on DATETIME DEFAULT CURRENT_TIMESTAMP)")
        
    -- Indices supported???
    --SQL:Execute("CREATE INDEX steamid_index ON awg_factions(steamid)")
    
    Events:Subscribe("PlayerChat", self, self.ParseChat)
end

function AWGFactions:WipeDB()
    -- Wipe the database
    -- This can be run from server console by typing "lua awgfactions AWGFactions:WipeDB()"
    -- You must reload the module after doing this, otherwise you're going to get errors :P
    print("Wiping database...")
    SQL:Execute("DROP TABLE IF EXISTS awg_members")
    SQL:Execute("DROP TABLE IF EXISTS awg_factions")
    print("Database wiped.")
    return true
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
        self.queryListFactions = SQL:Query("SELECT faction,num_members FROM awg_factions")
        self.queryFactionEst = SQL:Query("SELECT created_on FROM awg_factions WHERE faction = (?)")
        self.queryGetMembers = SQL:Query("SELECT steamid FROM awg_members WHERE faction = (?)")
        self.queryCountMembers = SQL:Query("SELECT num_members FROM awg_factions WHERE faction = (?)")
        self.queryGetLeader = SQL:Query("SELECT steamid FROM awg_members WHERE rank = (?) AND faction = (?)")
        -- Transactions
        self.querySetPass = SQL:Command("UPDATE awg_factions SET passwd = (?) WHERE faction = (?)")
        self.querySetRank = SQL:Command("UPDATE awg_members SET rank = (?) WHERE steamid = (?)")
        self.queryAddMember = SQL:Command("INSERT OR REPLACE INTO awg_members (steamid,faction,rank) VALUES (?,?,?)")
        self.queryNewFaction = SQL:Command("INSERT INTO awg_factions (faction,passwd,salt) VALUES (?,?,?)")
        self.queryDelMember = SQL:Command("DELETE FROM awg_members WHERE steamid = (?)")
        self.queryDelFaction = SQL:Command("DELETE FROM awg_factions WHERE faction = (?)")
        self.queryDelMembers = SQL:Command("DELETE FROM awg_members WHERE faction = (?)")
        self.queryUpdateNumMembers = SQL:Command("UPDATE awg_factions SET num_members = (SELECT COUNT(steamid) FROM awg_members WHERE faction = (:faction)) WHERE faction = (:faction)")
        
        if msg[2] == "join" then
            if table.count(msg) > 4 then
                args.player:SendChatMessage(
                    "There are too many spaces. Faction names and passwords must NOT contain spaces! Press F5 for help.",
                    awgColors["neonorange"] )
            elseif table.count(msg) > 2 then
                local factionName = msg[3]
                -- Should not contain non alphanumeric chars
                if factionName:match("%W") then
                    args.player:SendChatMessage(
                        "Faction name contains invalid chars. Only alphanumeric allowed!",
                        awgColors["neonorange"] )
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
                                print("INFO: " .. myName .. " tried to join private faction " .. factionName .. " without supplying a password")
                                args.player:SendChatMessage(
                                    "There is a password required to join this faction. You must provide the correct password to join. Usage: Usage: /f join <faction> <password>",
                                    awgColors["neonorange"] )
                            else
                                local factionPass = msg[4]
                                if factionPass:match("%W") then
                                    args.player:SendChatMessage(
                                        "Faction password contains invalid chars. Only alphanumeric allowed!",
                                        awgColors["neonorange"] )
                                else
                                    factionPass = SHA256.ComputeHash(salt .. factionPass)
                                    if factionPass == dbPass then
                                        if self:JoinFaction(factionName,mySteamID,rank) then
                                            print("INFO: " .. myName .. " successfully joined private faction " .. factionName)
                                            args.player:SendChatMessage(
                                                "Successfully joined private faction: " .. factionName,
                                                awgColors["neonlime"] )
                                        else
                                            print("ERROR: " .. myName .. " was unable to join private faction " .. factionName .. " . But the password was correct")
                                            args.player:SendChatMessage(
                                                "ERROR: Failed to join " .. factionName,
                                                awgColors["red"] )
                                        end
                                    else
                                        print("WARN: " .. myName .. " supplied the wrong password for private faction " .. factionName)
                                        args.player:SendChatMessage(
                                            "Wrong faction password! Get lost punk!",
                                            awgColors["neonorange"] )
                                    end
                                end
                            end
                        else -- No password, go ahead and join
                            if self:JoinFaction(factionName,mySteamID,rank) then
                                print("INFO: " .. myName .. " successfully joined public faction " .. factionName)
                                args.player:SendChatMessage(
                                    "Successfully joined public faction: " .. factionName,
                                    awgColors["neonlime"] )
                            else
                                print("ERROR: " .. myName .. " was unable to join public faction " .. factionName)
                                args.player:SendChatMessage(
                                    "ERROR: Failed to join public faction: " .. factionName,
                                    awgColors["red"] )
                            end
                        end
                    else -- Faction doesn't exist, create it, with password
                        if table.count(msg) > 3 then
                            local plaintextPass = msg[4]
                            if plaintextPass:match("%W") then
                                args.player:SendChatMessage(
                                    "Faction password contains invalid chars. Only alphanumeric allowed!",
                                    awgColors["neonorange"] )
                            else
                                local salt = self.RandString()
                                factionPass = SHA256.ComputeHash(salt .. plaintextPass)
                                if self:AddFaction(factionName,factionPass,mySteamID,salt) then
                                    print("INFO: " .. myName .. " successfully created private faction " .. factionName)
                                    args.player:SendChatMessage(
                                        "Successfully created private faction: " .. factionName .. " Password: " .. plaintextPass,
                                        awgColors["neonlime"] )
                                else
                                    print("ERROR: " .. myName .. " was unable to create private faction " .. factionName)
                                    args.player:SendChatMessage(
                                        "ERROR: Failed to create new private faction: " .. factionName,
                                        awgColors["red"] )
                                end
                            end
                        else
                            local factionPass = ""
                            local factionSalt = ""
                            if self:AddFaction(factionName,factionPass,mySteamID,factionSalt) then
                                print("INFO: " .. myName .. " successfully created public faction " .. factionName)
                                args.player:SendChatMessage(
                                    "Successfully created public faction: " .. factionName,
                                    awgColors["neonlime"] )
                            else
                                print("ERROR: " .. myName .. " was unable to create private faction " .. factionName)
                                args.player:SendChatMessage(
                                    "ERROR: Failed to create new public faction: " .. factionName,
                                    awgColors["red"] )
                            end
                        end
                    end
                end
            else -- Show usage help for "/f join"
                args.player:SendChatMessage(
                    "Join a faction. If faction does not exist, it is created. Password is optional. Usage: /f join <faction> <password>",
                    awgColors["aquamarine"] )
            end
        elseif msg[2] == "leave" then
            self.queryInFaction:Bind(1, mySteamID)
            local result = self.queryInFaction:Execute()
            if #result > 0 then -- If any rows are returned, player is in a faction
                local myFaction = result[1].faction
                if self:QuitFaction(mySteamID,myFaction) then
                    print("INFO: " .. myName .. " left faction " .. myFaction)
                    args.player:SendChatMessage(
                        "You left " .. myFaction,
                        awgColors["neonlime"] )
                else
                    print("ERROR: " .. myName .. " was unable to leave faction " .. myFaction)
                    args.player:SendChatMessage(
                        "ERROR: Failed to leave faction " .. myFaction,
                        awgColors["red"] )
                end
            else
                args.player:SendChatMessage(
                    "You are not currently in any faction!",
                    awgColors["neonorange"] )
            end
        elseif msg[2] == "setrank" then -- check 2 args (player, rank)
            -- Use Command Manager here
            print("Not done yet")
        elseif msg[2] == "players" then -- list online faction members
            self.queryInFaction:Bind(1, mySteamID)
            local result = self.queryInFaction:Execute()
            if #result > 0 then
                local myFaction = result[1].faction
                local theMembers = self:GetMembersOnline(myFaction)
                if #theMembers > 0 then
                    args.player:SendChatMessage("****** Online Members ******", awgColors["neonlime"] )
                    self:ShowList(theMembers,args.player,awgColors["mediumturquoise"])
                else
                    print("Error, unable to find any members online")
                end
            else
                args.player:SendChatMessage("ERROR: You are not in a faction, there is no member list to view!", awgColors["neonorange"] )
            end
        elseif msg[2] == "list" then -- list online faction members
            --self.queryInFaction:Bind(1, mySteamID)
            local result = self.queryListFactions:Execute()
            if #result > 0 then
                args.player:SendChatMessage("****** AWG Factions ******", awgColors["neonlime"] )
                local factionList = {}
                for i = 1, #result do
                    table.insert(factionList, result[i].faction .. " (" .. result[i].num_members .. ")")
                end
                self:ShowList(factionList,args.player,awgColors["mediumturquoise"])
            else
                args.player:SendChatMessage("No factions found!", awgColors["neonorange"] )
            end
        else -- If not a faction command, treat as faction chat
            local msg = string.gsub(args.text, "/f ", "")
            self.queryInFaction:Bind(1, mySteamID)
            local result = self.queryInFaction:Execute()
            if #result > 0 then
                local myFaction = result[1].faction
                if not self:ChatFaction(myName,myFaction,msg) then
                    print("ERROR: " .. myName .. " was unable to use faction chat for faction: " .. myFaction)
                    args.player:SendChatMessage(
                        "ERROR: Error sending faction chat message",
                        awgColors["red"] )
                end
            else
                args.player:SendChatMessage(
                    "You are trying to use faction chat, but you are not in a faction! Press F5 for help",
                    awgColors["neonorange"] )
            end
        end
        return false
    elseif args.text == "/f" then -- Show usage help
        args.player:SendChatMessage(
            "AWG Factions Mod. Press F5 for detailed help. Example Usage: /f join <faction> <password>",
            awgColors["aquamarine"] )
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
    local rank = #awgRanks
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
    -- Update awg_factions.num_players
    self.queryUpdateNumMembers:Bind(':faction', faction)
    self.queryUpdateNumMembers:Execute()
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
        -- Update awg_factions.num_players
        self.queryUpdateNumMembers:Bind(':faction', faction)
        self.queryUpdateNumMembers:Execute()
        --transaction:Commit()
    end
    return true
end

-- Return table
function AWGFactions:GetMembersOnline(faction)
    local factionMembers = self:GetMemberIDs(faction)
    local memberNames = {}
    for p in Server:GetPlayers() do
        if factionMembers[p:GetSteamId().id] then -- add online members' names to table
            table.insert(memberNames, p:GetName())
        end
    end
    return memberNames
end

-- Return table (steamids stored as keys)
function AWGFactions:GetMemberIDs(faction)
    self.queryGetMembers:Bind(1, faction)
    local result = self.queryGetMembers:Execute()
    local factionMembers = {}
    
    for i = 1, #result do
        --print(tostring(result[i].steamid))
        factionMembers[result[i].steamid] = true
    end
    return factionMembers
end

-- Return INT - SteamId().id or 0
function AWGFactions:GetLeader(faction)
    local leaderRank = #awgRanks
    self.queryGetLeader:Bind(1, leaderRank)
    self.queryGetLeader:Bind(2, faction)
    local result = self.queryGetLeader:Execute()
    if #result > 0 then
        return result[1].steamid
    end
    return 0
end

-- Return bool
function AWGFactions:ChatFaction(myName,myFaction,msg)
    local factionMembers = self:GetMemberIDs(myFaction)
    for p in Server:GetPlayers() do
        if factionMembers[p:GetSteamId().id] then -- send message to faction members
            p:SendChatMessage(
                "[" .. myFaction .. "] " .. myName .. ": " .. msg,
                awgColors["white"] )
        end
    end
    return true
end

function AWGFactions:ShowList(list,player,color)
    local cnt = 0
    local numLeft = #list
    local line = ""
    for i = 1, #list do
        --print("iterating list")
        cnt = cnt + 1
        numLeft = numLeft - 1
        if i == #list then
            line = line .. list[i]
        else
            --print("Adding member to line")
            line = line .. list[i] .. ", "
        end
        if cnt == 5 or numLeft == 0 then
            --print("Count reached 5")
            cnt = 0
            player:SendChatMessage(line, color)
            line = ""
        end
    end
end

-- Returns pseudorandom 16 byte string
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