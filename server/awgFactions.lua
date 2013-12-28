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
    self.timer = Timer()
    self.numTicks = 0
    self.delay = 10
    print("Initializing serverside awgFactions.lua...")
    -- Init tables
    SQL:Execute("CREATE TABLE IF NOT EXISTS awg_members (steamid VARCHAR UNIQUE, faction VARCHAR, rank INTEGER, last_seen DATETIME DEFAULT CURRENT_TIMESTAMP)")
    SQL:Execute("CREATE TABLE IF NOT EXISTS awg_factions (faction VARCHAR UNIQUE, color VARCHAR, num_members INTEGER, banned VARCHAR, allies VARCHAR, enemies VARCHAR, passwd VARCHAR DEFAULT NULL, salt VARCHAR, created_on DATETIME DEFAULT CURRENT_TIMESTAMP)")
        
    -- Indices supported???
    --SQL:Execute("CREATE INDEX steamid_index ON awg_factions(steamid)")
    
    
    -- SQL
    self.sqlPassSalt = "SELECT passwd,salt FROM awg_factions WHERE faction = (?)"
    self.sqlLastSeen = "SELECT last_seen FROM awg_members WHERE steamid = (?)"
    self.sqlIsFaction = "SELECT rowid FROM awg_factions WHERE faction = (?)"
    self.sqlListFactions = "SELECT faction,num_members FROM awg_factions"
    --self.sqlFactionEst = "SELECT created_on FROM awg_factions WHERE faction = (?)"
    --self.sqlCountMembers = "SELECT num_members FROM awg_factions WHERE faction = (?)"
    self.sqlSetPass = "UPDATE awg_factions SET passwd = (:pass), salt = (:salt) WHERE faction = (:faction)"
    self.sqlSetRank = "UPDATE awg_members SET rank = (?) WHERE steamid = (?)"
    self.sqlGetRank = "SELECT rank FROM awg_members WHERE steamid = (?)"
    self.sqlUpdateNumMembers = "UPDATE awg_factions SET num_members = (SELECT COUNT(steamid) FROM awg_members WHERE faction = (:faction)) WHERE faction = (:faction)"
    self.sqlNewFaction = "INSERT INTO awg_factions (faction,passwd,salt,color) VALUES (?,?,?,?)"
    self.sqlDelFaction = "DELETE FROM awg_factions WHERE faction = (?)"
    self.sqlDelMembers = "DELETE FROM awg_members WHERE faction = (?)"
    self.sqlAddMember = "INSERT OR REPLACE INTO awg_members (steamid,faction,rank) VALUES (?,?,?)"
    self.sqlDelMember = "DELETE FROM awg_members WHERE steamid = (?)"
    self.sqlInFaction = "SELECT m.faction,f.color FROM awg_members m JOIN awg_factions f ON m.faction=f.faction WHERE m.steamid = (?)"
    self.sqlGetMembers = "SELECT steamid FROM awg_members WHERE faction = (?)"
    self.sqlGetLeader = "SELECT steamid FROM awg_members WHERE rank = (?) AND faction = (?)"
    self.sqlSetColor = "UPDATE awg_factions SET color = (:color) WHERE faction = (:faction)"
    self.sqlIsColorUsed = "SELECT faction FROM awg_factions WHERE color = (?)"
    self.sqlAllMembers = "SELECT m.steamid,m.faction,f.color FROM awg_members m JOIN awg_factions f ON m.faction=f.faction"
    self.sqlGetBans = "SELECT banned FROM awg_factions WHERE faction = (?)"
    self.sqlSetBans = "UPDATE awg_factions SET banned = (:bans) WHERE faction = (:faction)"
    --self.queryLastSeen = SQL:Query(self.sqlLastSeen)
    --self.queryFactionEst = SQL:Query(self.sqlFactionEst)
    --self.queryCountMembers = SQL:Query(self.sqlCountMembers)

    Events:Subscribe("PlayerChat", self, self.ParseChat)
    Events:Subscribe("PlayerJoin", self, self.BroadcastMembers)
    Events:Subscribe("PlayerQuit", self, self.BroadcastMembers)
    Events:Subscribe("ModulesLoad", self, self.BroadcastMembers)
    Events:Subscribe("ModuleLoad", self, self.BroadcastMembers)
    self.initialDelay = Events:Subscribe("PreTick", self, self.InitialDelay)
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
                    self.queryIsFaction = SQL:Query(self.sqlIsFaction)
                    self.queryIsFaction:Bind(1, factionName)
                    local result = self.queryIsFaction:Execute()
                    if #result > 0 then -- Faction exists
                        local rank = 1
                        self.queryPassSalt = SQL:Query(self.sqlPassSalt)
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
                                        local result = self:GetFaction(mySteamID)
                                        if #result > 0 then -- if result > 0, player is in a faction already
                                            self:QuitFaction(mySteamID,result[1].faction,myName)
                                            local leaveMsg = myName .. " has left the faction!"
                                            self:MsgFaction(factionName, leaveMsg, awgColors["deeppink"])
                                        end
                                        if not self:IsBanned(mySteamID,factionName) then
                                            if self:JoinFaction(factionName,mySteamID,rank,myName) then
                                                print("INFO: " .. myName .. " successfully joined private faction " .. factionName)
                                                args.player:SendChatMessage("Successfully joined private faction: " .. factionName,
                                                    awgColors["neonlime"] )
                                            else
                                                print("ERROR: " .. myName .. " was unable to join private faction " .. factionName .. " . But the password was correct")
                                                args.player:SendChatMessage("ERROR: Failed to join " .. factionName,awgColors["red"] )
                                            end
                                        else
                                            args.player:SendChatMessage("You are banned from faction: " .. factionName,awgColors["red"] )
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
                            if not self:IsBanned(mySteamID,factionName) then
                                local result = self:GetFaction(mySteamID)
                                if #result > 0 then -- if result > 0, player is in a faction already
                                    self:QuitFaction(mySteamID,result[1].faction,myName)
                                    local leaveMsg = myName .. " has left the faction!"
                                    self:MsgFaction(factionName, leaveMsg, awgColors["deeppink"])
                                end
                                if self:JoinFaction(factionName,mySteamID,rank,myName) then
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
                            else
                                args.player:SendChatMessage("You are banned from faction: " .. factionName,awgColors["red"] )
                            end
                        end
                    else -- Faction doesn't exist, create it
                        if table.count(msg) > 3 then -- password supplied
                            local plaintextPass = msg[4]
                            if plaintextPass:match("%W") then
                                args.player:SendChatMessage(
                                    "Faction password contains invalid chars. Only alphanumeric allowed!",
                                    awgColors["neonorange"] )
                            else
                                local salt = self.RandString()
                                factionPass = SHA256.ComputeHash(salt .. plaintextPass)
                                if self:AddFaction(factionName,factionPass,mySteamID,salt,myName) then
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
                        else -- no password supplied, give it a blank password
                            local factionPass = ""
                            local factionSalt = ""
                            if self:AddFaction(factionName,factionPass,mySteamID,factionSalt,myName) then
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
            local result = self:GetFaction(mySteamID)
            if #result > 0 then -- If any rows are returned, player is in a faction
                local myFaction = result[1].faction
                if self:QuitFaction(mySteamID,myFaction,myName) then
                    print("INFO: " .. myName .. " left faction " .. myFaction)
                    args.player:SendChatMessage(
                        "You left " .. myFaction,
                        awgColors["neonlime"] )
                    local leaveMsg = myName .. " has left the faction!"
                    self:MsgFaction(myFaction, leaveMsg, awgColors["deeppink"])
                else
                    print("ERROR: " .. myName .. " was unable to leave faction " .. myFaction)
                    args.player:SendChatMessage(
                        "ERROR: Failed to leave faction " .. myFaction,
                        awgColors["red"] )
                end
            else
                print("Is this printing twice")
                args.player:SendChatMessage(
                    "You are not currently in any faction!",
                    awgColors["neonorange"] )
            end
        elseif msg[2] == "setrank" then -- check 2 args (rank, playername)
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                if mySteamID == self:GetLeader(myFaction) then
                    if #msg > 3 then
                        local numRank = msg[3]--:gsub('%D','')
                        if numRank:match('%D') then
                            args.player:SendChatMessage(
                                    "Invalid rank number specified. Rank must be a number between 1 (lowest rank) and " .. tostring(#awgRanks) .. " (Leader rank). Press F5 for detailed help.",
                                    awgColors["neonorange"] )
                        else
                            numRank = tonumber(numRank)
                            if numRank > 0 and numRank <= #awgRanks then
                                table.remove(msg, 3)
                                table.remove(msg, 2)
                                table.remove(msg, 1)
                                local memberName = table.concat(msg, " ")
                                local memberObj = self:GetPlayerByName(memberName)
                                if memberObj ~= nil then -- Make sure player is online
                                    local memberSteamID = memberObj:GetSteamId().id
                                    local myFactionMembers = self:GetMemberIDs(myFaction)
                                    if myFactionMembers[memberSteamID] then
                                        if numRank == #awgRanks then -- player is transferring leadership
                                            local myNewRank = #awgRanks - 1
                                            self:SetRank(memberSteamID,numRank)
                                            self:SetRank(mySteamID,myNewRank)
                                            local transferMsg = myName .. " has transferred leadership of " .. myFaction .. " to " .. memberName
                                            self:MsgFaction(myFaction,transferMsg,awgColors["neonlime"])
                                            print(myName .. " has transferred leadership of " .. myFaction .. " to " .. memberName)
                                        else
                                            self:SetRank(memberSteamID,numRank)
                                            memberObj:SendChatMessage(myName .. " just set your rank to: " .. awgRanks[numRank],
                                            awgColors["neonlime"] )
                                            args.player:SendChatMessage(memberName .. " is now rank: " .. awgRanks[numRank],
                                            awgColors["neonlime"] )
                                            print(myName .. " has set a new rank for " .. memberName .. " : " .. awgRanks[numRank])
                                        end
                                    else
                                        args.player:SendChatMessage("Specified player is not in your faction! You can only set the rank of your own faction members!", awgColors["neonorange"] )
                                    end
                                else
                                    args.player:SendChatMessage("Specified player is not online! Player must be online to change their rank!", awgColors["neonorange"] )
                                end
                            else
                                args.player:SendChatMessage(
                                        "Invalid rank number specified. Rank must be a number between 1 (lowest rank) and " .. tostring(#awgRanks) .. " (Leader rank). Press F5 for detailed help.",
                                        awgColors["neonorange"] )
                            end
                        end
                    else
                        args.player:SendChatMessage("You must specify a desired rank (number) and a faction member's name.  Press F5 for detailed help.  Usage: /f setrank <rank> <playername>", awgColors["neonorange"] )
                    end
                else
                    args.player:SendChatMessage("You are not the faction leader! Only the faction leader can set ranks for members!", awgColors["neonorange"] )
                end
            else
                args.player:SendChatMessage("You are not in a faction!", awgColors["neonorange"] )
            end
        elseif msg[2] == "players" then -- list online faction members
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                local theMembers = self:GetMembersOnline(myFaction)
                if #theMembers > 0 then
                    args.player:SendChatMessage("****** " .. myFaction .. " ******", awgColors["neonlime"] )
                    args.player:SendChatMessage("------ Online Members ------", awgColors["neonlime"] )
                    self:ShowList(theMembers,args.player,awgColors["mediumturquoise"])
                else
                    print("ERROR: Unable to find any members online for faction: " .. myFaction)
                end
            else
                args.player:SendChatMessage("You are not in a faction, there is no member list to view!", awgColors["neonorange"] )
            end
        elseif msg[2] == "list" then -- list online faction members
            self.queryListFactions = SQL:Query(self.sqlListFactions)
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
        elseif msg[2] == "goto" then -- teleport to faction member
            --self.queryInFaction:Bind(1, mySteamID)
            --local result = self.queryInFaction:Execute()
            local result = self:GetFaction(mySteamID)
            if #result > 0 then -- If any rows are returned, player is in a faction
                local myFaction = result[1].faction
                if #msg < 3 then
                    args.player:SendChatMessage("No faction member specified. Press F5 for detailed help. Usage: /f goto <player name>",
                    awgColors["neonorange"] )
                else
                    table.remove(msg, 2)
                    table.remove(msg, 1)
                    local gotoName = table.concat(msg, " ")
                    local found = false
                    for op in Server:GetPlayers() do
                        if op:GetName() == gotoName then
                            found = true
                            local myMembers = self:GetMemberIDs(myFaction)
                            if myMembers[op:GetSteamId().id] then -- Selected player is in their faction
                                local gotoPos = op:GetPosition()
                                args.player:SetPosition(gotoPos)
                                args.player:SendChatMessage("Teleported to " .. gotoName, awgColors["neonlime"] )
                            else -- Selected player is not in their faction
                                args.player:SendChatMessage(gotoName .. " is not in your faction! You can only teleport to your own faction members!",
                                awgColors["neonorange"] )
                            end
                        end
                    end
                    if not found then
                        args.player:SendChatMessage("No online player found with name: " .. gotoName, awgColors["neonorange"] )
                    end
                end
            else
                args.player:SendChatMessage(
                    "You are not currently in any faction! You must be in a faction to use /f goto. Press F5 for detailed help.",
                    awgColors["neonorange"] )
            end
        elseif msg[2] == "setcolor" then -- set faction color
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                if mySteamID == self:GetLeader(myFaction) then
                    local setColor = msg[3]
                    if awgColors[setColor] ~= nil then
                        if self:IsColorUsable(setColor) then
                            if self:SetColor(myFaction,setColor) then
                                args.player:SendChatMessage("You've successfully changed your faction color to " .. setColor .. "!", awgColors["neonlime"] )
                            else
                                args.player:SendChatMessage("ERROR: There was an error setting your faction color.", awgColors["red"] )
                            end
                        else
                            args.player:SendChatMessage("That color is already being used by another faction!", awgColors["neonorange"] )
                        end
                    else
                        args.player:SendChatMessage("That is not a valid color! To see a list of valid colors, press F5 and check out the AWG Factions tab.", awgColors["neonorange"] )
                    end
                else
                    args.player:SendChatMessage("You are not the faction leader! Only the faction leader can set the faction color!", awgColors["neonorange"] )
                end
            else
                args.player:SendChatMessage("You are not in a faction!", awgColors["neonorange"] )
            end
        elseif msg[2] == "setpass" then -- change faction password
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                if mySteamID == self:GetLeader(myFaction) then
                    if #msg == 3 then
                        local plaintextPass = msg[3]
                        if plaintextPass:match("%W") then
                            args.player:SendChatMessage(
                                "Faction password contains invalid chars. Only alphanumeric allowed!",
                                awgColors["neonorange"] )
                        else
                            local salt = self.RandString()
                            factionPass = SHA256.ComputeHash(salt .. plaintextPass)
                            if self:SetPass(myFaction,factionPass,salt) then
                                print(myName .. " successfully set a new password for faction: " .. myFaction)
                                args.player:SendChatMessage(
                                    "Successfully set a new password for faction: " .. myFaction .. " Password: " .. plaintextPass,
                                    awgColors["neonlime"] )
                            else
                                print("ERROR: " .. myName .. " was unable to set a new password for faction: " .. myFaction)
                                args.player:SendChatMessage(
                                    "ERROR: Failed to set a new password for faction: " .. myFaction,
                                    awgColors["red"] )
                            end
                        end
                    else
                        args.player:SendChatMessage("Set a faction password. Password must NOT contain spaces. Usage: /f setpass <password>", awgColors["neonorange"] )
                    end
                else
                    args.player:SendChatMessage("You are not the faction leader! Only the faction leader can set the faction password!", awgColors["neonorange"] )
                end
            else
                args.player:SendChatMessage("You are not in a faction!", awgColors["neonorange"] )
            end
        elseif msg[2] == "kick" then -- kick player from faction
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                if mySteamID == self:GetLeader(myFaction) then
                    if #msg > 2 then
                        table.remove(msg, 2)
                        table.remove(msg, 1)
                        local memberName = table.concat(msg, " ")
                        local memberObj = self:GetPlayerByName(memberName)
                        if memberObj ~= nil then -- Make sure player is online
                            local memberSteamID = memberObj:GetSteamId().id
                            local myFactionMembers = self:GetMemberIDs(myFaction)
                            if myFactionMembers[memberSteamID] then
                                local kickMsg = myName .. " has kicked " .. memberName .. " from " .. myFaction
                                self:QuitFaction(memberSteamID,myFaction,memberName)
                                self:MsgFaction(myFaction,kickMsg,awgColors["neonlime"])
                                memberObj:SendChatMessage("You were kicked from the faction!",awgColors["neonlime"])
                                print(myName .. " kicked " .. memberName .. " from faction: " .. myFaction)
                            else
                                args.player:SendChatMessage("Specified player is not in your faction!", awgColors["neonorange"])
                            end
                        else
                            args.player:SendChatMessage("Specified player is not online!", awgColors["neonorange"] )
                        end
                    else
                        args.player:SendChatMessage("Kick member from faction. You must specify a faction member's name. Press F5 for detailed help.  Usage: /f kick <playername>", awgColors["neonorange"] )
                    end
                else
                    args.player:SendChatMessage("You are not the faction leader! Only the faction leader can do this!", awgColors["neonorange"] )
                end
            else
                args.player:SendChatMessage("You are not in a faction!", awgColors["neonorange"] )
            end
        elseif msg[2] == "ban" then -- ban player from faction
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                if mySteamID == self:GetLeader(myFaction) then
                    if #msg > 2 then
                        table.remove(msg, 2)
                        table.remove(msg, 1)
                        local memberName = table.concat(msg, " ")
                        local memberObj = self:GetPlayerByName(memberName)
                        if memberObj ~= nil then -- Make sure player is online
                            local memberSteamID = memberObj:GetSteamId().id
                            local myFactionMembers = self:GetMemberIDs(myFaction)
                            if myFactionMembers[memberSteamID] then
                                local kickMsg = myName .. " has banned " .. memberName .. " from " .. myFaction
                                self:QuitFaction(memberSteamID,myFaction,memberName)
                                if self:AddBan(memberSteamID,myFaction) then
                                    self:MsgFaction(myFaction,kickMsg,awgColors["neonlime"])
                                    memberObj:SendChatMessage("You were banned from the faction!",awgColors["neonlime"])
                                    print(myName .. " banned " .. memberName .. " from faction: " .. myFaction)
                                else
                                    args.player:SendChatMessage("Specified player is already banned from your faction!", awgColors["neonorange"])
                                end
                            else
                                args.player:SendChatMessage("Specified player is not in your faction!", awgColors["neonorange"])
                            end
                        else
                            args.player:SendChatMessage("Specified player is not online!", awgColors["neonorange"] )
                        end
                    else
                        args.player:SendChatMessage("Ban member from faction. You must specify a faction member's name. Press F5 for detailed help.  Usage: /f ban <playername>", awgColors["neonorange"] )
                    end
                else
                    args.player:SendChatMessage("You are not the faction leader! Only the faction leader can do this!", awgColors["neonorange"] )
                end
            else
                args.player:SendChatMessage("You are not in a faction!", awgColors["neonorange"] )
            end
        elseif msg[2] == "unban" then -- unban player from faction
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                if mySteamID == self:GetLeader(myFaction) then
                    if #msg > 2 then
                        table.remove(msg, 2)
                        table.remove(msg, 1)
                        local memberName = table.concat(msg, " ")
                        local memberObj = self:GetPlayerByName(memberName)
                        if memberObj ~= nil then -- Make sure player is online
                            local memberSteamID = memberObj:GetSteamId().id
                            local myFactionMembers = self:GetMemberIDs(myFaction)
                            local unbanMsg = myName .. " has unbanned " .. memberName .. " from " .. myFaction
                            if self:DelBan(memberSteamID,myFaction) then
                                self:MsgFaction(myFaction,unbanMsg,awgColors["neonlime"])
                                memberObj:SendChatMessage("You were unbanned from the faction: " .. myFaction,awgColors["neonlime"])
                                print(myName .. " unbanned " .. memberName .. " from faction: " .. myFaction)
                            else
                                args.player:SendChatMessage("Specified player is not banned from your faction!", awgColors["neonorange"])
                            end
                        else
                            args.player:SendChatMessage("Specified player is not online!", awgColors["neonorange"] )
                        end
                    else
                        args.player:SendChatMessage("Unban member from faction. You must specify a player's name. Press F5 for detailed help.  Usage: /f unban <playername>", awgColors["neonorange"] )
                    end
                else
                    args.player:SendChatMessage("You are not the faction leader! Only the faction leader can do this!", awgColors["neonorange"] )
                end
            else
                args.player:SendChatMessage("You are not in a faction!", awgColors["neonorange"] )
            end
        else -- If not a faction command, treat as faction chat
            local msg = string.gsub(args.text, "/f ", "")
            --self.queryInFaction:Bind(1, mySteamID)
            --local result = self.queryInFaction:Execute()
            local result = self:GetFaction(mySteamID)
            if #result > 0 then
                local myFaction = result[1].faction
                local factionColor = awgColors[result[1].color]
                msg = "[" .. myFaction .. "] " .. myName .. ": " .. msg
                if not self:MsgFaction(myFaction,msg,factionColor) then
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

-- Return player object or nil
function AWGFactions:GetPlayerByName(name)
    for p in Server:GetPlayers() do
        if name == p:GetName() then
            return p
        end
    end
    return nil
end

-- Return player object or nil
function AWGFactions:GetPlayerBySteamID(steamid)
    for p in Server:GetPlayers() do
        if steamid == p:GetSteamId().id then
            return p
        end
    end
    return nil
end

function AWGFactions:IsColorUsable(color)
    self.queryIsColorUsed = SQL:Query(self.sqlIsColorUsed)
    self.queryIsColorUsed:Bind(1, color)
    local result = self.queryIsColorUsed:Execute()
    if #result > 0 then
        return false
    end
    return true
end

-- Returns bool
function AWGFactions:AddFaction(faction,passwd,steamid,salt,myName)
    --local transaction = SQL:Transaction()
    local color = self:GetRandomColor()
    self.queryNewFaction = SQL:Command(self.sqlNewFaction)
    self.queryNewFaction:Bind(1, faction)
    self.queryNewFaction:Bind(2, passwd)
    self.queryNewFaction:Bind(3, salt)
    self.queryNewFaction:Bind(4, color)
    self.queryNewFaction:Execute()
    --transaction:Commit()
    local rank = #awgRanks
    if self:JoinFaction(faction,steamid,rank,myName) then
        print("INFO: " .. myName .. " joined newly created faction " .. faction .. " as leader")
    else
        print("ERROR: " .. myName .. " failed to join newly create faction " .. faction .. " as leader")
    end
    return true
end

-- Returns bool
function AWGFactions:DelFaction(faction)
    local disbandMsg = faction .. " has been disbanded!"
    self:MsgFaction(faction, disbandMsg, awgColors["tomato"])
    --local transaction = SQL:Transaction()
    self.queryDelFaction = SQL:Command(self.sqlDelFaction)
    self.queryDelFaction:Bind(1, faction)
    self.queryDelFaction:Execute()
    -- Delete all members of factions as well
    self.queryDelMembers = SQL:Command(self.sqlDelMembers)
    self.queryDelMembers:Bind(1, faction)
    self.queryDelMembers:Execute()
    --transaction:Commit()
    return true
end

-- Return bool
function AWGFactions:JoinFaction(faction,steamid,rank,name)
    --local transaction = SQL:Transaction()
    local joinMsg = name .. " has joined the faction!"
    self:MsgFaction(faction, joinMsg, awgColors["hotpink"])
    self.queryAddMember = SQL:Command(self.sqlAddMember)
    self.queryAddMember:Bind(1, steamid)
    self.queryAddMember:Bind(2, faction)
    self.queryAddMember:Bind(3, rank)
    self.queryAddMember:Execute()
    -- Update awg_factions.num_players
    self.queryUpdateNumMembers = SQL:Command(self.sqlUpdateNumMembers)
    self.queryUpdateNumMembers:Bind(':faction', faction)
    self.queryUpdateNumMembers:Execute()
    self:BroadcastMembers()
    --transaction:Commit()
    return true
end

-- Return bool
function AWGFactions:QuitFaction(steamid,faction,name)
    if self:GetRank(steamid) == #awgRanks then -- player is faction leader, so delete faction too
        local leaderQuitMsg = "Faction Leader " .. name .. " has quit the faction!"
        self:MsgFaction(faction, leaderQuitMsg, awgColors["firebrick"])
        if self:DelFaction(faction) then
            print("INFO: Deleted faction (Leader left faction): " .. faction .. "  Player: " .. name)
        else
            print("ERROR: Unable to delete faction (Leader left faction): " .. faction .. "  Player: " .. name)
        end
    else
        --local transaction = SQL:Transaction()
        self.queryDelMember = SQL:Command(self.sqlDelMember)
        self.queryDelMember:Bind(1, steamid)
        self.queryDelMember:Execute()
        -- Update awg_factions.num_players
        self.queryUpdateNumMembers = SQL:Command(self.sqlUpdateNumMembers)
        self.queryUpdateNumMembers:Bind(':faction', faction)
        self.queryUpdateNumMembers:Execute()
        self:BroadcastMembers()
        --transaction:Commit()
    end
    return true
end

-- Return table
function AWGFactions:GetFaction(steamid)
    self.queryInFaction = SQL:Query(self.sqlInFaction)
    self.queryInFaction:Bind(1, steamid)
    local result = self.queryInFaction:Execute()
    return result
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
    --print("Within GetMemberIDs function")
    self.queryGetMembers = SQL:Query(self.sqlGetMembers)
    self.queryGetMembers:Bind(1, faction)
    local result = self.queryGetMembers:Execute()
    local factionMembers = {}
    for i = 1, #result do
        factionMembers[result[i].steamid] = true
    end
    return factionMembers
end

-- Return INT - SteamId().id or 0
function AWGFactions:GetLeader(faction)
    local leaderRank = #awgRanks
    self.queryGetLeader = SQL:Query(self.sqlGetLeader)
    self.queryGetLeader:Bind(1, leaderRank)
    self.queryGetLeader:Bind(2, faction)
    local result = self.queryGetLeader:Execute()
    if #result > 0 then
        return result[1].steamid
    end
    return 0
end

-- Return bool
function AWGFactions:MsgFaction(myFaction,msg,color)
    local factionMembers = self:GetMemberIDs(myFaction)
    for p in Server:GetPlayers() do
        if factionMembers[p:GetSteamId().id] then -- send message to faction members
            p:SendChatMessage(msg, color)
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
function AWGFactions:SetPass(faction,pass,salt)
    self.querySetPass = SQL:Command(self.sqlSetPass)
    self.querySetPass:Bind(':pass', pass)
    self.querySetPass:Bind(':salt', salt)
    self.querySetPass:Bind(':faction', faction)
    self.querySetPass:Execute()
    return true
end

-- Return bool
function AWGFactions:SetRank(steamid,rank)
    self.querySetRank = SQL:Command(self.sqlSetRank)
    self.querySetRank:Bind(1, rank)
    self.querySetRank:Bind(2, steamid)
    self.querySetRank:Execute()
    return true
end

-- Return INT
function AWGFactions:GetRank(steamid)
    self.queryGetRank = SQL:Query(self.sqlGetRank)
    self.queryGetRank:Bind(1, steamid)
    local result = self.queryGetRank:Execute()
    if #result > 0 then
        return tonumber(result[1].rank)
    end
    return 0
end

-- Return table of faction banned steamids
function AWGFactions:GetBans(faction)
    local banned = {}
    self.queryGetBans = SQL:Query(self.sqlGetBans)
    self.queryGetBans:Bind(1, faction)
    local result = self.queryGetBans:Execute()
    if #result > 0 then
        local bannedString = result[1].banned
        if bannedString ~= nil then
            local bannedTmp = bannedString:split(',')
            for i=1,#bannedTmp do
                if string.len(bannedTmp[i]) > 1 then
                    banned[bannedTmp[i]] = true
                end
            end
        end
    end
    return banned
end

-- Return bool, input bans is a TABLE
function AWGFactions:SetBans(faction,bans)
    --print("In SetBans")
    local bannedString = ""
    for k,v in pairs(bans) do
        bannedString = bannedString .. k .. ","
    end
    self.querySetBans = SQL:Command(self.sqlSetBans)
    self.querySetBans:Bind(':bans', bannedString)
    self.querySetBans:Bind(':faction', faction)
    self.querySetBans:Execute()
    --print("String: " .. bannedString)
    return true
end

-- Return bool
function AWGFactions:IsBanned(steamid,faction)
    local banned = self:GetBans(faction)
    if banned[steamid] then
        return true
    end
    return false
end

-- Return bool
function AWGFactions:AddBan(steamid,faction) -- Adding 2 extra , before ID ??????
    if not self:IsBanned(steamid,faction) then
        local banned = self:GetBans(faction)
        banned[steamid] = true
        self:SetBans(faction,banned)
        --print("AddBan() setting ban for " .. steamid .. " to: " .. tostring(banned[steamid]))
        return true
    end
    return false
end

-- Return bool
function AWGFactions:DelBan(steamid,faction)
    if self:IsBanned(steamid,faction) then
        print("Player is definitely banned.")
        local banned = self:GetBans(faction)
        banned[steamid] = nil
        self:SetBans(faction,banned)
        return true
    end
    return false
end

-- Return bool
function AWGFactions:SetColor(faction,color)
    self.querySetColor = SQL:Command(self.sqlSetColor)
    self.querySetColor:Bind(':faction', faction)
    self.querySetColor:Bind(':color', color)
    self.querySetColor:Execute()
    print(faction .. " changed their color to " .. color)
    self:BroadcastMembers()
    return true
end

-- Return STRING
function AWGFactions:GetRandomColor()
    local colorList = self:GetColorList()
    local n = math.random(1,#colorList)
    return colorList[n]
end

-- Return table
function AWGFactions:GetColorList()
    local colorList = {}
    for k,_ in pairs(awgColors) do
        table.insert(colorList, k)
    end
    return colorList
end

-- Return factionMembers table
function AWGFactions:GetAllFactionMembers()
    local allMembers = {}
    self.queryAllMembers = SQL:Query(self.sqlAllMembers)
    local result = self.queryAllMembers:Execute()
    if #result > 0 then
        local onlineSteamIDs = {}
        for ply in Server:GetPlayers() do
            onlineSteamIDs[ply:GetSteamId().id] = true
        end
        for i = 1, #result do
            if onlineSteamIDs[result[i].steamid] then
                local factionColor = awgColors[result[i].color]
                allMembers[result[i].steamid] = {result[i].faction, factionColor}
            end
        end
    end
    return allMembers
end

-- Broadcast factionMembers table to all players
function AWGFactions:BroadcastMembers()
    local allMembers = self:GetAllFactionMembers()
    Network:Broadcast("FactionMembers", allMembers)
end

-- Send factionMembers table to a player
function AWGFactions:SendMembers(args)
    local allMembers = self:GetAllFactionMembers()
    Network:Send(args.player, "FactionMembers", allMembers)
end

function AWGFactions:InitialDelay(args)
    self.numTicks = self.numTicks + 1
    if self.timer:GetSeconds() > self.delay then
        print("Firing off BroadcastMembers after initial delay")
        self:BroadcastMembers()
        self.timer:Restart()
        numTicks = 0
        Events:Unsubscribe(self.initialDelay)
    end
end

awgFactions = AWGFactions()

