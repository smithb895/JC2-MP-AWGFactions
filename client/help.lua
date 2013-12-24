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
    self.active = true

    Events:Subscribe( "ModuleLoad", self, self.ModulesLoad )
    Events:Subscribe( "ModulesLoad", self, self.ModulesLoad )
    Events:Subscribe( "ModuleUnload", self, self.ModuleUnload )
end


function AWGFactions:ModulesLoad()
    Events:FireRegisteredEvent( "HelpAddItem",
        {
            name = "AWG Factions",
            text = 
                "This factions mod was written from scratch by Anzu of www.AnzusWarGames.info,\n" ..
                "with inspiration for the script coming from the original factions mod written by\n" ..
                "Philpax and the JC2-MP dev team. Commands are essentially the same as their mod.\n" ..
                "See usage details below. When using '/f join', if the specified faction name does\n" ..
                "not already exist, it is created. The password is optional when creating a new \n" ..
                "faction, but required to join one that has a password.  When a faction leader leaves\n" ..
                "the faction, it is deleted and all its members are disbanded.\n\n" ..
                "Usage:\n Joining/Creating a faction:\n  /f join <faction> <password>\n" ..
                " Leaving a faction:\n  /f leave\n" ..
                " Using faction chat:\n  /f <chat message>\n" ..
                "\nMore features coming soon! :)"
        } )
end

function AWGFactions:ModuleUnload()
    Events:FireRegisteredEvent( "HelpRemoveItem",
        {
            name = "AWG Factions"
        } )
end



local awgFactions = AWGFactions()
