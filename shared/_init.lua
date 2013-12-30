--[[
    Title: AWG Factions
    Author: Anzu
    Org: http://www.AnzusWarGames.info
    Version: 0.02
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

factionMembers = {}
awgRanks = {"Member","Officer","Leader"}
awgColors = { 
    ["lightpink"] = Color(255,182,193),
    ["pink"] = Color(255,192,203),
    ["crimson"] = Color(220,20,60),
    ["lavenderblush"] = Color(255,240,245),
    ["palevioletred"] = Color(219,112,147),
    ["hotpink"] = Color(255,105,180),
    ["deeppink"] = Color(255,20,147),
    ["mediumvioletred"] = Color(199,21,133),
    ["orchid"] = Color(218,112,214),
    ["thistle"] = Color(216,191,216),
    ["plum"] = Color(221,160,221),
    ["violet"] = Color(238,130,238),
    ["fuchsia"] = Color(255,0,255),
    ["darkmagenta"] = Color(139,0,139),
    ["purple"] = Color(128,0,128),
    ["mediumorchid"] = Color(186,85,211),
    ["darkviolet"] = Color(148,0,211),
    ["darkorchid"] = Color(153,50,204),
    ["indigo"] = Color(75,0,130),
    ["blueviolet"] = Color(138,43,226),
    ["mediumpurple"] = Color(147,112,219),
    ["mediumslateblue"] = Color(123,104,238),
    ["slateblue"] = Color(106,90,205),
    ["darkslateblue"] = Color(72,61,139),
    ["ghostwhite"] = Color(248,248,255),
    ["lavender"] = Color(230,230,250),
    ["blue"] = Color(0,0,255),
    ["mediumblue"] = Color(0,0,205),
    ["darkblue"] = Color(0,0,139),
    ["navy"] = Color(0,0,128),
    ["midnightblue"] = Color(25,25,112),
    ["royalblue"] = Color(65,105,225),
    ["cornflowerblue"] = Color(100,149,237),
    ["lightsteelblue"] = Color(176,196,222),
    ["lightslategray"] = Color(119,136,153),
    ["slategray"] = Color(112,128,144),
    ["dodgerblue"] = Color(30,144,255),
    ["aliceblue"] = Color(240,248,255),
    ["steelblue"] = Color(70,130,180),
    ["lightskyblue"] = Color(135,206,250),
    ["skyblue"] = Color(135,206,235),
    ["deepskyblue"] = Color(0,191,255),
    ["lightblue"] = Color(173,216,230),
    ["powderblue"] = Color(176,224,230),
    ["cadetblue"] = Color(95,158,160),
    ["darkturquoise"] = Color(0,206,209),
    ["azure"] = Color(240,255,255),
    ["lightcyan"] = Color(224,255,255),
    ["paleturquoise"] = Color(175,238,238),
    ["aqua"] = Color(0,255,255),
    ["darkcyan"] = Color(0,139,139),
    ["teal"] = Color(0,128,128),
    ["darkslategray"] = Color(47,79,79),
    ["mediumturquoise"] = Color(72,209,204),
    ["lightseagreen"] = Color(32,178,170),
    ["turquoise"] = Color(64,224,208),
    ["aquamarine"] = Color(127,255,212),
    ["mediumaquamarine"] = Color(102,205,170),
    ["mediumspringgreen"] = Color(0,250,154),
    ["mintcream"] = Color(245,255,250),
    ["springgreen"] = Color(0,255,127),
    ["mediumseagreen"] = Color(60,179,113),
    ["seagreen"] = Color(46,139,87),
    ["honeydew"] = Color(240,255,240),
    ["darkseagreen"] = Color(143,188,143),
    ["palegreen"] = Color(152,251,152),
    ["lightgreen"] = Color(144,238,144),
    ["limegreen"] = Color(50,205,50),
    ["neonlime"] = Color(163,255,71),
    ["neonorange"] = Color(255,51,0),
    ["brightgreen"] = Color(0,255,0),
    ["forestgreen"] = Color(34,139,34),
    ["green"] = Color(0,128,0),
    ["darkgreen"] = Color(0,100,0),
    ["lawngreen"] = Color(124,252,0),
    ["chartreuse"] = Color(127,255,0),
    ["greenyellow"] = Color(173,255,47),
    ["darkolivegreen"] = Color(85,107,47),
    ["yellowgreen"] = Color(154,205,50),
    ["olivedrab"] = Color(107,142,35),
    ["ivory"] = Color(255,255,240),
    ["beige"] = Color(245,245,220),
    ["lightyellow"] = Color(255,255,224),
    ["lightgoldenrodyellow"] = Color(250,250,210),
    ["yellow"] = Color(255,255,0),
    ["olive"] = Color(128,128,0),
    ["darkkhaki"] = Color(189,183,107),
    ["palegoldenrod"] = Color(238,232,170),
    ["lemonchiffon"] = Color(255,250,205),
    ["khaki"] = Color(240,230,140),
    ["gold"] = Color(255,215,0),
    ["cornsilk"] = Color(255,248,220),
    ["goldenrod"] = Color(218,165,32),
    ["darkgoldenrod"] = Color(184,134,11),
    ["floralwhite"] = Color(255,250,240),
    ["oldlace"] = Color(253,245,230),
    ["wheat"] = Color(245,222,179),
    ["orange"] = Color(255,165,0),
    ["moccasin"] = Color(255,228,181),
    ["papayawhip"] = Color(255,239,213),
    ["blanchedalmond"] = Color(255,235,205),
    ["navajowhite"] = Color(255,222,173),
    ["antiquewhite"] = Color(250,235,215),
    ["tan"] = Color(210,180,140),
    ["burlywood"] = Color(222,184,135),
    ["darkorange"] = Color(255,140,0),
    ["bisque"] = Color(255,228,196),
    ["linen"] = Color(250,240,230),
    ["peru"] = Color(205,133,63),
    ["peachpuff"] = Color(255,218,185),
    ["sandybrown"] = Color(244,164,96),
    ["chocolate"] = Color(210,105,30),
    ["saddlebrown"] = Color(139,69,19),
    ["seashell"] = Color(255,245,238),
    ["sienna"] = Color(160,82,45),
    ["lightsalmon"] = Color(255,160,122),
    ["coral"] = Color(255,127,80),
    ["orangered"] = Color(255,69,0),
    ["darksalmon"] = Color(233,150,122),
    ["tomato"] = Color(255,99,71),
    ["salmon"] = Color(250,128,114),
    ["mistyrose"] = Color(255,228,225),
    ["lightcoral"] = Color(240,128,128),
    ["snow"] = Color(255,250,250),
    ["rosybrown"] = Color(188,143,143),
    ["indianred"] = Color(205,92,92),
    ["red"] = Color(255,0,0),
    ["brown"] = Color(165,42,42),
    ["firebrick"] = Color(178,34,34),
    ["darkred"] = Color(139,0,0),
    ["maroon"] = Color(128,0,0),
    ["white"] = Color(255,255,255),
    ["whitesmoke"] = Color(245,245,245),
    ["gainsboro"] = Color(220,220,220),
    ["lightgrey"] = Color(211,211,211),
    ["silver"] = Color(192,192,192),
    ["darkgray"] = Color(169,169,169),
    ["gray"] = Color(128,128,128),
    ["dimgray"] = Color(105,105,105),
    ["black"] = Color(0,0,0)
}