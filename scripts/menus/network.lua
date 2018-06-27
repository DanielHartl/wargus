--       _________ __                 __
--      /   _____//  |_____________ _/  |______     ____  __ __  ______
--      \_____  \\   __\_  __ \__  \\   __\__  \   / ___\|  |  \/  ___/
--      /        \|  |  |  | \// __ \|  |  / __ \_/ /_/  >  |  /\___ \
--     /_______  /|__|  |__|  (____  /__| (____  /\___  /|____//____  >
--             \/                  \/          \//_____/            \/
--  ______________________                           ______________________
--                        T H E   W A R   B E G I N S
--         Stratagus - A free fantasy real time strategy game engine
--
--      network.lua - Define the menu for network game.
--
--      (c) Copyright 2005-2016 by François Beerten, Jimmy Salmon, Pali Rohár
--								   and Cybermind.
--
--      This program is free software; you can redistribute it and/or modify
--      it under the terms of the GNU General Public License as published by
--      the Free Software Foundation; either version 2 of the License, or
--      (at your option) any later version.
--
--      This program is distributed in the hope that it will be useful,
--      but WITHOUT ANY WARRANTY; without even the implied warranty of
--      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--      GNU General Public License for more details.
--
--      You should have received a copy of the GNU General Public License
--      along with this program; if not, write to the Free Software
--      Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--

function bool2int(boolvalue)
  if boolvalue == true then
    return 1
  else
    return 0
  end
end

function int2bool(int)
  if int == 0 then
    return false
  else
    return true
  end
end

function ErrorMenu(errmsg)
  local menu = WarMenu(nil, panel(4), false)
  menu:setSize(288, 128)
  menu:setPosition((Video.Width - 288) / 2, (Video.Height - 128) / 2)
  menu:setDrawMenusUnder(true)

  menu:addLabel(_("Error:"), 144, 11)

  local l = MultiLineLabel(errmsg)
  l:setFont(Fonts["large"])
  l:setAlignment(MultiLineLabel.CENTER)
  l:setVerticalAlignment(MultiLineLabel.CENTER)
  l:setLineWidth(270)
  l:setWidth(270)
  l:setHeight(41)
  l:setBackgroundColor(dark)
  menu:add(l, 9, 38)

  menu:addHalfButton("~!OK", "o", 92, 80, function() menu:stop() end)

  menu:run()
end



function addPlayersList(menu, numplayers, isserver, isdedicated)
  local i
  local players_name = {}
  local players_state = {}
  local sx = Video.Width / 20
  local sy = Video.Height / 20
  local numplayers_text
  local ainumber
  local ainumberCb
  local ainumberlist = {}
  local updateAInumberList
  local requestedNumberOfAI

  menu:writeText(_("AIs:"), sx, sy*11+75)

  if isserver then
    updateAInumberList = function(connected_players)
      -- create list with number of available slots for computer players
      ainumberlist = {}
      local maxAIplayers = numplayers - 1 - connected_players
	  if isdedicated then
	    numplayers = numplayers + 1
	  end	  
      for i=0,maxAIplayers do
        table.insert(ainumberlist, tostring(i) .. _(" AI player(s)"))
      end
    end

    updateAInumberList(0)
    ainumber = menu:addDropDown(ainumberlist, sx + 100, sy*11+75, function() end)
    requestedNumberOfAI = function()
      -- parse the requested number of AI players as integer
      return tonumber(string.gmatch(ainumberlist[ainumber:getSelected() + 1], "%d+")())
    end
    ainumberCb = function()
      ServerSetupState.Opponents = requestedNumberOfAI()
      GameSettings.Opponents = ServerSetupState.Opponents
      NetworkServerResyncClients()
    end

    ainumber:setActionCallback(ainumberCb)
    ainumber:setSize(190, 20)
  else
    ainumber = menu:writeText(tostring(ServerSetupState.Opponents), sx + 100, sy*11+75)
    ainumberCb = function()
      ainumber:setCaption(tostring(ServerSetupState.Opponents))
      ainumber:adjustSize()
    end
  end

  menu:writeLargeText(_("Players"), sx * 11, sy*3)
  for i=1,8 do
    players_name[i] = menu:writeText(_("Player")..i, sx * 11, sy*4 + i*18)
    players_state[i] = menu:writeText(_("Preparing"), sx * 11 + 80, sy*4 + i*18)
  end
  if isserver then
    numplayers_text = menu:writeText(_("Open slots : ") .. numplayers - 1, sx *11, sy*4 + 144)
  end

  local function updatePlayers()
    local connected_players = 0
    local ready_players = 0
    players_state[1]:setCaption(_("Creator"))
    players_name[1]:setCaption(Hosts[0].PlyName)
    players_name[1]:adjustSize()
    for i=2,8 do
      if Hosts[i-1].PlyName == "" then
        players_name[i]:setCaption("")
        players_state[i]:setCaption("")
      else
	connected_players = connected_players + 1
	if ServerSetupState.Ready[i-1] == 1 then
          ready_players = ready_players + 1
          players_state[i]:setCaption(_("Ready"))
        else
          players_state[i]:setCaption(_("Preparing"))
        end
        players_name[i]:setCaption(Hosts[i-1].PlyName)
        players_name[i]:adjustSize()
      end
    end
    local currentAInumber = 0
    if isserver then
      updateAInumberList(connected_players)
      currentAInumber = requestedNumberOfAI()
      ainumber:setList(ainumberlist)
      ainumber:setSelected(currentAInumber)
    else
      ainumberCb()
    end
    if isserver then
      local openSlots = numplayers - 1 - connected_players
      openSlots = openSlots - ServerSetupState.Opponents
      if isdedicated then
        numplayers = numplayers + 1
      end
      numplayers_text:setCaption(_("Open slots : ") .. openSlots)
      numplayers_text:adjustSize()
    end

    -- only 1 player in this map or
    -- all connected players are ready or
    -- we could play against AI
    return numplayers == 1 or (connected_players > 0 and ready_players == connected_players) or (connected_players == 0 and currentAInumber ~= 0)
  end

  return updatePlayers
end

function RunJoiningMapMenu(optRace, optReady)
  local menu
  local listener
  local sx = Video.Width / 20
  local sy = Video.Height / 20
  local numplayers = 3
  local state
  local d

  menu = WarMenu(_("Joining game: Map"))

  menu:writeLargeText(_("Map"), sx, sy*3)
  menu:writeText(_("File:"), sx, sy*3+30)
  local maptext = menu:writeText(NetworkMapName, sx+50, sy*3+30)
  menu:writeText(_("Players:"), sx, sy*3+50)
  local players = menu:writeText(numplayers, sx+70, sy*3+50)
  menu:writeText(_("Description:"), sx, sy*3+70)
  local descr = menu:writeText("", sx+20, sy*3+90)

  local fow = menu:addImageCheckBox(_("Fog of war"), sx, sy*3+120, offi, offi2, oni, oni2, function() end)
  fow:setMarked(true)
  ServerSetupState.FogOfWar = 1
  ServerSetupState.Opponents = 0
  GameSettings.Opponents = 0
  fow:setEnabled(false)
  local revealmap = menu:addImageCheckBox(_("Reveal map"), sx, sy*3+150, offi, offi2, oni, oni2, function() end)
  revealmap:setEnabled(false)

  menu:writeText(_("~<Your Race:~>"), sx, sy*11)
  local race = menu:addDropDown({_("Map Default"), _("Human"), _("Orc")}, sx + 100, sy*11, function(dd) end)
  local raceCb = function(dd)
    GameSettings.Presets[NetLocalHostsSlot].Race = race:getSelected()
    LocalSetupState.Race[NetLocalHostsSlot] = race:getSelected()
  end
  race:setActionCallback(raceCb)
  race:setSize(190, 20)

  menu:writeText(_("Units:"), sx, sy*11+25)
  local units = menu:addDropDown({_("Map Default"), _("One Peasant Only")}, sx + 100, sy*11+25,
    function(dd) end)
  units:setSize(190, 20)
  units:setEnabled(false)

  menu:writeText(_("Resources:"), sx, sy*11+50)
  local resources = menu:addDropDown({_("Map Default"), _("Low"), _("Medium"), _("High")}, sx + 100, sy*11+50,
    function(dd) end)
  resources:setSize(190, 20)
  resources:setEnabled(false)

  local OldPresentMap = PresentMap
  PresentMap = function(desc, nplayers, w, h, id)
    descr:setCaption(desc)
    descr:adjustSize()
    OldPresentMap(desc, nplayers, w, h, id)
  end
  local oldDefinePlayerTypes = DefinePlayerTypes
  DefinePlayerTypes = function(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16)
    local ps = {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16}
    playerCount = 0

    for _, s in pairs(ps) do
      if s == "person" then
        playerCount = playerCount + 1
      end
    end
    players:setCaption(""..playerCount)
    players:adjustSize()
    oldDefinePlayerTypes(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16)
  end

  -- Security: The map name is checked by the stratagus engine.
  Load(NetworkMapName)
  local function readycb(dd)
    LocalSetupState.Ready[NetLocalHostsSlot] = bool2int(dd:isMarked())
  end
  local readycheckbox = menu:addImageCheckBox(_("~!Ready"), sx*11, sy*14, offi, offi2, oni, oni2, readycb)

  local updatePlayersList = addPlayersList(menu, numplayers, false, false)

  local joincounter = 0
  local delay = 4
  local function listen()
    NetworkProcessClientRequest()
    fow:setMarked(int2bool(ServerSetupState.FogOfWar))
    GameSettings.NoFogOfWar = not int2bool(ServerSetupState.FogOfWar)
    revealmap:setMarked(int2bool(ServerSetupState.RevealMap))
    GameSettings.RevealMap = ServerSetupState.RevealMap
    units:setSelected(ServerSetupState.UnitsOption)
    GameSettings.NumUnits = ServerSetupState.UnitsOption
    resources:setSelected(ServerSetupState.ResourcesOption)
    GameSettings.Resources = ServerSetupState.ResourcesOption
    GameSettings.Opponents = ServerSetupState.Opponents
    updatePlayersList()
    state = GetNetworkState()
    -- FIXME: don't use numbers

    if delay > 0 then
      delay = delay - 1
    elseif delay == 0 then
      if (optRace == "human" or optRace == "Human") then
        race:setSelected(1)
        raceCb(race)
        optRace = ""
      elseif (optRace == "orc" or optRace == "Orc") then
        race:setSelected(2)
        raceCb(race)
        optRace = ""
      end
    end

    if (state == 15) then -- ccs_started, server started the game
      SetThisPlayer(1)
      joincounter = joincounter + 1
      if (joincounter == 30) then
        SetFogOfWar(fow:isMarked())
        if revealmap:isMarked() == true then
          RevealMap()
        end
        NetworkGamePrepareGameSettings()
        RunMap(NetworkMapName)
	PresentMap = OldPresentMap
        DefinePlayerTypes = oldDefinePlayerTypes
        MetaClient:Close()
        menu:stop()
      end
    elseif (state == 10) then -- ccs_unreachable
      ErrorMenu(_("Cannot reach server"))
      MetaClient:Close()
      menu:stop()
    end
  end
  listener = LuaActionListener(listen)
  menu:addLogicCallback(listener)

  if (optReady) then
    LocalSetupState.Ready[NetLocalHostsSlot] = bool2int(true)
    readycheckbox:setMarked(true)
  end

  menu:addFullButton(_("~!Cancel"), "c", Video.Width / 2 - 100, Video.Height - 100,
    function() NetworkDetachFromServer(); MetaClient:Close(); menu:stop() end)

  menu:run()
end

function RunJoiningGameMenu(optRace, optReady, optExtraLabel, optStopDirect)
  local menu = nil
  if (optRace and optReady) then
    menu = WarMenu(_("Joining Game"))
  else
    menu = WarMenu(nil, panel(4), false)
    menu:setSize(288, 128)
    menu:setPosition((Video.Width - 288) / 2, (Video.Height - 128) / 2)
    menu:setDrawMenusUnder(true)
  end

  if optExtraLabel then
    menu:addLabel(optExtraLabel, 144, 11)
  else
    menu:addLabel(_("Connecting to server"), 144, 11)
  end

  local percent = 0

  local sb = StatBoxWidget(258, 30)
  sb:setCaption(_("Connecting..."))
  sb:setPercent(percent)
  menu:add(sb, 15, 38)
  sb:setBackgroundColor(dark)

  local function checkconnection()
    NetworkProcessClientRequest()
    percent = percent + 100 / (24 * GetGameSpeed()) -- 24 seconds * fps
    sb:setPercent(percent)
    local state = GetNetworkState()
    -- FIXME: do not use numbers
    if (state == 3) then -- ccs_mapinfo
      -- got ICMMap => load map
      RunJoiningMapMenu(optRace, optReady)
      if (optExtraLabel ~= nil) then
	 menu:stop(1) -- joining through metaserver menu
      else
	 menu:stop(0) -- joining through local server menu
      end
    elseif (state == 4) then -- ccs_badmap
      ErrorMenu(_("Map not available"))
      menu:stop(1)
    elseif (state == 10) then -- ccs_unreachable
      if optStopDirect then
        menu:stop(1)
      else
        ErrorMenu(_("Cannot reach server"))
        menu:stop(1)
      end
    elseif (state == 12) then -- ccs_nofreeslots
      ErrorMenu(_("Server is full"))
      menu:stop(1)
    elseif (state == 13) then -- ccs_serverquits
      ErrorMenu(_("Server gone"))
      menu:stop(1)
    elseif (state == 16) then -- ccs_incompatibleengine
      ErrorMenu(_("Incompatible engine version"))
      menu:stop(1)
    elseif (state == 17) then -- ccs_incompatibleluafiles
      ErrorMenu(_("Incompatible lua files"))
      menu:stop(1)
    end
  end
  local listener = LuaActionListener(checkconnection)
  menu:addLogicCallback(listener)

  menu:addHalfButton(_("Cancel (~<Esc~>)"), "escape", 92, 80,
    function() menu:stop(1) end)

  return menu:run()
end

function RunJoinIpMenu()
  local menu = WarMenu(nil, panel(5), false)
  local serverlist
  menu:setSize(352, 352)
  menu:setPosition((Video.Width - 352) / 2, (Video.Height - 352) / 2)
  menu:setDrawMenusUnder(true)
  menu:addLabel(_("Servers: "), 176, 20)
  local servers = {}
  local function ServerListUpdate()
    serverlist = nil
    servers = {}
    if (wc2.preferences.ServerList ~= nil) then
      for i=1,table.getn(wc2.preferences.ServerList)/2 do
        servers[i]=tostring(wc2.preferences.ServerList[(i-1)*2+1].." | "..tostring(wc2.preferences.ServerList[(i-1)*2+2]))
      end
    end
    serverlist = menu:addImageListBox(20, 50, 300, 120, servers)
  end
  ServerListUpdate()
  menu:addFullButton(_("Co~!nnect"), "n", 60, 180, function()
      NetworkSetupServerAddress(wc2.preferences.ServerList[serverlist:getSelected()*2+1])
      NetworkInitClientConnect()
      if (RunJoiningGameMenu() ~= 0) then
        -- connect failed, don't leave this menu
        return
      end
    end)
  menu:addFullButton(_("~!Add server"), "a", 60, 210, function() RunAddServerMenu(); ServerListUpdate() end)
  -- We need to stop this from loading when there are no servers.
  menu:addFullButton(_("~!Edit server"), "a", 60, 240, function()
      if serverlist:getSelected() ~= nil then
        RunEditServerMenu(serverlist:getSelected()); ServerListUpdate()
      end
    end)
  menu:addFullButton(_("~!Delete server"), "d", 60, 270, function()
      if serverlist:getSelected() ~= nil then
        table.remove(wc2.preferences.ServerList, serverlist:getSelected()*2+1)
        table.remove(wc2.preferences.ServerList, serverlist:getSelected()*2+1)
        SavePreferences()
        ServerListUpdate()
      end
    end)
  menu:addFullButton(_("~!Cancel"), "c", 60, 300, function() menu:stop() end)
  menu:run()
end

function RunJoiningMetaServerMenu()
   local menu = WarMenu(nil, panel(4), false)
   menu:setSize(288, 128)
   menu:setPosition((Video.Width - 288) / 2, (Video.Height - 128) / 2)
   menu:setDrawMenusUnder(true)

   menu:addLabel(_("Enter meta server address:"), 144, 11)
   local server = menu:addTextInputField(wc2.preferences.MetaServer..":"..tostring(wc2.preferences.MetaPort), 40, 38, 212)
   local conn_label = menu:addLabel(_("Connecting..."), 40, 60, Fonts["game"], false)
   conn_label:setVisible(false)

   local ok_button = menu:addHalfButton("~!OK", "o", 24, 80, function(s) end)
   local cancel_button = menu:addHalfButton(_("~!Cancel"), "c", 154, 80, function() menu:stop() end)
   ok_button:setActionCallback(
      function(s)
	 if string.len(server:getText()) > 0 then
	    conn_label:setVisible(true)
	    conn_label:setCaption(_("Connecting..."))
	    conn_label:adjustSize()
	    local ip = string.find(server:getText(), ":")
	    if ip ~= nil then
	       wc2.preferences.MetaServer = string.sub(server:getText(), 1, ip - 1)
	       wc2.preferences.MetaPort = tonumber(string.sub(server:getText(), ip + 1))
	       if (wc2.preferences.MetaPort == 0) then wc2.preferences.MetaPort = 7775 end
	    else
	       wc2.preferences.MetaServer = string.sub(server:getText(), 1)
	       wc2.preferences.MetaPort = 7775
	    end
	    ok_button:setEnabled(false)
	    cancel_button:setEnabled(false)
	    MetaClient:SetMetaServer(wc2.preferences.MetaServer, wc2.preferences.MetaPort)
	    if (MetaClient:Init() == -1) then
	       conn_label:setCaption(_("Unable to connect"))
	       conn_label:adjustSize()
	       ok_button:setEnabled(true)
	       cancel_button:setEnabled(true)
	    else
	       -- connected
	       RunJoinOnlineMenu()
	       menu:stop(0)
	    end

	 end
      end
   )

   menu:run()
end

function RunJoinOnlineMenu()
  local menu = WarMenu(nil, panel(5), false)
  local serverlist
  menu:setSize(352, 352)
  menu:setPosition((Video.Width - 352) / 2, (Video.Height - 352) / 2)
  menu:setDrawMenusUnder(true)
  menu:addLabel(_("Open Games: "), 176, 20)
  local servers = {}

  local function ServerListUpdate()
     serverlist = nil
     servers = {}
     local idx = 1
     MetaClient:Send("LISTGAMES")
     if (MetaClient:Recv() ~= -1) then
	local log = MetaClient:GetLastMessage().entry
	if string.find(log, "LISTGAMES_OK") then
	   -- we're done
	elseif string.find(log, "LISTGAMES") then
	   servers[idx] = log
	else
	   -- what?
	end
     end
     serverlist = menu:addImageListBox(20, 50, 300, 120, servers)
  end
  ServerListUpdate()
  menu:addFullButton(_("Co~!nnect"), "n", 60, 180, function()
      local stringlist = {}
      local idx = 1
      for i in string.gmatch(servers[serverlist:getSelected() + 1], "%S+") do
	 stringlist[idx] = i
	 idx = idx + 1
      end
      local id = stringlist[2]
      local iplocal = stringlist[table.getn(stringlist) - 1]
      local portlocal = tonumber(stringlist[table.getn(stringlist)])
      MetaClient:Send("JOINGAME " .. tostring(id))
      local ip = "0.0.0.0"
      local port = 0
      while (MetaClient:Recv() ~= -1) do
	 local log = MetaClient:GetLastMessage().entry
	 stringlist = {}
	 if string.find(log, "JOINGAME_OK") then
	    local i
	    idx = 1
	    for i in string.gmatch(log, "%S+") do
	       stringlist[idx] = i
	       idx = idx + 1
	    end
	    ip = stringlist[table.getn(stringlist) - 1]
	    port = tonumber(stringlist[table.getn(stringlist)])
	    NetworkSetupServerAddress(iplocal, portlocal)
	    NetworkInitClientConnect()
	    -- try the global ip first, so any clients outside the network may be able to do p2p later on
	    if (RunJoiningGameMenu(nil, nil, _("Connecting via " .. tostring(iplocal) .. " (first try)"), true) ~= 0) then
	       -- cannot connect to server-global ip address, try the local one
	       NetworkSetupServerAddress(ip, port)
	       NetworkInitClientConnect()
	       if (RunJoiningGameMenu(nil, nil, _("Connecting via " .. tostring(ip) .. " (second try)"), false) ~= 0) then
		  -- connect failed, don't leave this menu
		  return
	       end
	    end
	 end
      end
      return
    end)
  menu:addFullButton(_("~!Cancel"), "c", 60, 300, function()
      MetaClient:Close()
      menu:stop()
  end)
  menu:run()
end

function RunEditServerMenu(number)
  local menu = WarMenu(nil, panel(2), false)
  menu:setSize(288, 256)
  menu:setPosition((Video.Width - 288) / 2, (Video.Height - 256) / 2)
  menu:setDrawMenusUnder(true)
  menu:addLabel(_("Edit server"), 144, 11)
  menu:addLabel(_("Server IP: "), 20, 31, Fonts["game"], false)
  local serverIp = menu:addTextInputField("localhost", 30, 51, 212)
  serverIp:setText(wc2.preferences.ServerList[number*2+1])
  menu:addLabel(_("Description: "), 20, 81, Fonts["game"], false)
  local serverDescr = menu:addTextInputField("", 30, 101, 212)
  serverDescr:setText(wc2.preferences.ServerList[number*2+2])
  menu:addHalfButton("~!OK", "o", 15, 210, function(s)
      if (NetworkSetupServerAddress(serverIp:getText()) ~= 0) then
        ErrorMenu(_("Invalid server name"))
        return
      end
      wc2.preferences.ServerList[number*2+1] = serverIp:getText()
      wc2.preferences.ServerList[number*2+2] = serverDescr:getText()
      SavePreferences()
      menu:stop()
    end)
  menu:addHalfButton(_("~!Cancel"), "c", 164, 210, function() menu:stop() end)
  menu:run()
end

function RunAddServerMenu()
  local menu = WarMenu(nil, panel(2), false)
  menu:setSize(288, 256)
  menu:setPosition((Video.Width - 288) / 2, (Video.Height - 256) / 2)
  menu:setDrawMenusUnder(true)
  menu:addLabel(_("Add server"), 144, 11)
  menu:addLabel(_("Server IP: "), 20, 31, Fonts["game"], false)
  local serverIp = menu:addTextInputField("localhost", 30, 51, 212)
  menu:addLabel(_("Description: "), 20, 81, Fonts["game"], false)
  local serverDescr = menu:addTextInputField("", 30, 101, 212)
  menu:addHalfButton("~!OK", "o", 15, 210, function(s)
      if (NetworkSetupServerAddress(serverIp:getText()) ~= 0) then
        ErrorMenu(_("Invalid server name"))
        return
      end
      table.insert(wc2.preferences.ServerList, serverIp:getText())
      table.insert(wc2.preferences.ServerList, serverDescr:getText())
      SavePreferences()
      menu:stop()
    end)
  menu:addHalfButton(_("~!Cancel"), "c", 164, 210, function() menu:stop() end)
  menu:run()
end

function RunServerMultiGameMenu(map, description, numplayers, options)

  local menu
  local sx = Video.Width / 20
  local sy = Video.Height / 20
  local startgame
  local d

  options = options or {}
  local optRace = options.race
  local optResources = options.resources
  local optUnits = options.units
  local optAiPlayerNum = options.aiPlayerNum
  local optAutostartNum = options.autostartNum
  local optDedicated = options.dedicated
  local optOnline = options.online
  if optOnline == nil then
     optOnline = true
  end

  menu = WarMenu(_("Create MultiPlayer game"))

  menu:writeLargeText(_("Map"), sx, sy*3)
  menu:writeText(_("File:"), sx, sy*3+30)
  local maptext = menu:writeText(map, sx+50, sy*3+30)
  menu:writeText(_("Players:"), sx, sy*3+50)
  local players = menu:writeText(numplayers, sx+70, sy*3+50)
  menu:writeText(_("Description:"), sx, sy*3+70)
  local descr = menu:writeText(_("Unknown map"), sx+20, sy*3+90)

  local function fowCb(dd)
    ServerSetupState.FogOfWar = bool2int(dd:isMarked())
    NetworkServerResyncClients()
    GameSettings.NoFogOfWar = not dd:isMarked()
  end
  local fow = menu:addImageCheckBox(_("Fog of war"), sx, sy*3+120, offi, offi2, oni, oni2, fowCb)
  fow:setMarked(true)
  local function revealMapCb(dd)
    ServerSetupState.RevealMap = bool2int(dd:isMarked())
    NetworkServerResyncClients()
    GameSettings.RevealMap = bool2int(dd:isMarked())
  end
  local revealmap = menu:addImageCheckBox(_("Reveal map"), sx, sy*3+150, offi, offi2, oni, oni2, revealMapCb)

  menu:writeText(_("Race:"), sx, sy*11)
  local race = menu:addDropDown({_("Map Default"), _("Human"), _("Orc")}, sx + 100, sy*11, function() end)
  local raceCb = function()
    GameSettings.Presets[0].Race = race:getSelected()
    ServerSetupState.Race[0] = race:getSelected()
    LocalSetupState.Race[0] = race:getSelected()
    NetworkServerResyncClients()
  end
  race:setActionCallback(raceCb)
  race:setSize(190, 20)

  menu:writeText(_("Units:"), sx, sy*11+25)
  local units=menu:addDropDown({_("Map Default"), _("One Peasant Only")}, sx + 100, sy*11+25, function() end)
  local unitsCb = function()
    GameSettings.NumUnits = units:getSelected()
    ServerSetupState.UnitsOption = GameSettings.NumUnits
    NetworkServerResyncClients()
  end
  units:setActionCallback(unitsCb)
  units:setSize(190, 20)

  menu:writeText(_("Resources:"), sx, sy*11+50)
  local resources=menu:addDropDown({_("Map Default"), _("Low"), _("Medium"), _("High")}, sx + 100, sy*11+50, function() end)
  local resourcesCb = function()
    GameSettings.Resources = resources:getSelected()
    ServerSetupState.ResourcesOption = GameSettings.Resources
    NetworkServerResyncClients()
  end
  resources:setActionCallback(resourcesCb)
  resources:setSize(190, 20)

  menu:writeText(_("Dedicated AI Server:"), sx, sy*12+75)
  local dedicatedCb = function (dd)
    if dd:isMarked() then
      -- 2 == closed
      ServerSetupState.CompOpt[0] = 2
    else
      -- 0 == available
      ServerSetupState.CompOpt[0] = 0
    end
    NetworkServerResyncClients()
  end
  local dedicated = menu:addImageCheckBox("", sx + 200, sy*12+75, offi, offi2, oni, oni2, dedicatedCb)
  local onlineLabelTxt = _("Meta-Server")
  local onlineLabel = menu:writeText(onlineLabelTxt, sx, sy*13+75)
  local server = menu:addTextInputField(
     wc2.preferences.MetaServer..":"..tostring(wc2.preferences.MetaPort), sx, sy*14+75, 200)
  local serverCb = function (dd)
     if string.len(server:getText()) > 0 then
	local ip = string.find(server:getText(), ":")
	if ip ~= nil then
	   wc2.preferences.MetaServer = string.sub(server:getText(), 1, ip - 1)
	   wc2.preferences.MetaPort = tonumber(string.sub(server:getText(), ip + 1))
	   if (wc2.preferences.MetaPort == 0) then wc2.preferences.MetaPort = 7775 end
	else
	   wc2.preferences.MetaServer = string.sub(server:getText(), 1)
	   wc2.preferences.MetaPort = 7775
	end
	SavePreferences()
	MetaClient:SetMetaServer(wc2.preferences.MetaServer, wc2.preferences.MetaPort)
     end
  end
  serverCb(server)
  local onlineCb = function (dd)
     serverCb(server)
     if (dd:isMarked()) then
	server:setEnabled(false)
	if (MetaClient:Init() == -1) then
	   onlineLabel:setCaption(_("(metaserver down)"))
	   onlineLabel:adjustSize()
	   dd:setMarked(false)
	   server:setEnabled(true)
	else
	   if (MetaClient:CreateGame(description .. ":" .. wc2.preferences.PlayerName, map, "" .. numplayers) == -1) then
	      onlineLabel:setCaption(_("(metaserver error)"))
	      onlineLabel:adjustSize()
	      dd:setMarked(false)
	      server:setEnabled(true)
	      MetaClient:Close()
	   else
	      onlineLabel:setCaption(onlineLabelTxt)
	      onlineLabel:adjustSize()
	   end
	end
     else
	server:setEnabled(true)
	MetaClient:Send("CANCELGAME")
	MetaClient:Close()
     end
  end
  local online = menu:addImageCheckBox("", sx + 200, sy*13+75, offi, offi2, oni, oni2, onlineCb)

  local updatePlayers = addPlayersList(menu, numplayers, true, optDedicated)

  NetworkMapName = map
  NetworkInitServerConnect(numplayers)
  ServerSetupState.FogOfWar = 1
  ServerSetupState.Opponents = optAiPlayerNum
  GameSettings.Opponents = optAiPlayerNum
  local function startFunc(s)
    SetFogOfWar(fow:isMarked())
    if revealmap:isMarked() == true then
      RevealMap()
    end
    NetworkServerStartGame()
    print("Metaserver stargame...")
    MetaClient:Send("STARTGAME") -- only the host's message will actually be processed
    print("...metaserver game started")
    NetworkGamePrepareGameSettings()
    RunMap(map)
    MetaClient:Send("ENDGAME finished") -- only the host's message will actually be processed
    MetaClient:Close()
    menu:stop()
  end
  local startgame = menu:addFullButton(_("~!Start Game"), "s", sx * 11, sy*14, startFunc)
  startgame:setVisible(false)
  local waitingtext = menu:writeText(_("Waiting for players"), sx*11, sy*14)
  local startIn = -10
  local function updateStartButton(ready)
    local readyplayers = 1
    for i=2,8 do
      if ServerSetupState.Ready[i-1] == 1 then
        readyplayers = readyplayers + 1
      end
    end
    if startIn < -1 then
      startIn = startIn + 1
    else
      if optDedicated then
        dedicated:setMarked(true)
        dedicatedCb(dedicated)
        optDedicated = false
      elseif optOnline then
        online:setMarked(true)
        onlineCb(online)
        optOnline = false
      elseif (optRace == "human" or optRace == "Human") then
        race:setSelected(1)
        raceCb(race)
        optRace = ""
      elseif (optRace == "orc" or optRace == "Orc") then
        race:setSelected(2)
        raceCb(race)
        optRace = ""

      elseif (optResources == "low" or optResources == "Low") then
        resources:setSelected(1)
        resourcesCb(resources)
        optResources = ""
      elseif (optResources == "medium" or optResources == "Medium") then
        resources:setSelected(2)
        resourcesCb(resources)
        optResources = ""
      elseif (optResources == "high" or optResources == "High") then
        resources:setSelected(3)
        resourcesCb(resources)
        optResources = ""

      elseif (optUnits == "1") then
        units:setSelected(1)
        unitsCb(resources)
        optUnits= ""

      elseif (options.fow == 0) then
        fow:setMarked(false)
        fowCb(fow)
        options.fow = -1
      elseif (options.revealmap == 1) then
        revealmap:setMarked(true)
        revealMapCb(revealmap)
        options.revealmap = -1
      elseif (optAutostartNum) then
        if (optAutostartNum <= readyplayers) then
          if (startIn < 0) then
            startIn = 100
          else
            startIn = startIn - 1
            if (startIn == 0) then
              startFunc()
            end
          end
          waitingtext:setCaption("Starting in " .. startIn / 2)
          print("Starting in " .. startIn / 2)
        end
      else
        startgame:setVisible(ready)
        waitingtext:setVisible(not ready)
      end
    end
  end

  local listener = LuaActionListener(function(s) updateStartButton(updatePlayers()) end)
  menu:addLogicCallback(listener)
  updateStartButton(updatePlayers())

  menu:addFullButton(_("~!Cancel"), "c", Video.Width / 2 - 100, Video.Height - 100,
		     function()
			InitGameSettings()
			-- the MetaClient message will not be processed if this
			-- game is not registered. For the host, the server will
			-- also ensure the entire game is marked as cancelled.
			print("Leaving metaserver...")
			MetaClient:Send("PARTGAME")
			MetaClient:Close()
			print("...left")
			menu:stop()
  end)

  menu:run()
end

function RunCreateMultiGameMenu(s)
  local menu
  local map = "No Map"
  local description = "No map"
  local mapfile = "maps/skirmish/multiplayer/(2)timeless-isle.smp.gz"
  local playerCount = 1
  local sx = Video.Width / 20
  local sy = Video.Height / 20

  menu = WarMenu(_("Create MultiPlayer game"))

  menu:writeText(_("File:"), sx, sy*3+30)
  local maptext = menu:writeText(mapfile, sx+50, sy*3+30)
  menu:writeText(_("Players:"), sx, sy*3+50)
  local players = menu:writeText(playerCount, sx+70, sy*3+50)
  menu:writeText(_("Description:"), sx, sy*3+70)
  local descr = menu:writeText(description, sx+20, sy*3+90)

  local OldPresentMap = PresentMap
  PresentMap = function(desc, nplayers, w, h, id)
    description = desc
    descr:setCaption(desc)
    descr:adjustSize()
    OldPresentMap(desc, nplayers, w, h, id)
  end
  local oldDefinePlayerTypes = DefinePlayerTypes
  DefinePlayerTypes = function(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16)
    local ps = {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16}
    playerCount = 0

    for _, s in pairs(ps) do
      if s == "person" then
        playerCount = playerCount + 1
      end
    end
    players:setCaption(""..playerCount)
    players:adjustSize()
    oldDefinePlayerTypes(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16)
  end
  Load(mapfile)
  local browser = menu:addBrowser("maps/", "^.*%.smp%.?g?z?$", sx*10, sy*2+20, sx*8, sy*11)
  local function cb(s)
    mapfile = browser.path .. browser:getSelectedItem()
    Load(mapfile)
    maptext:setCaption(mapfile)
    maptext:adjustSize()
  end
  browser:setActionCallback(cb)

  menu:addFullButton(_("~!Create Game"), "c", sx, sy*11,
    function(s)
      if (browser:getSelected() < 0) then
        return
      end
      RunServerMultiGameMenu(mapfile, description, playerCount)
      menu:stop()
    end
  )

  menu:addFullButton(_("Cancel (~<Esc~>)"), "escape", sx, sy*12+25,
    function() menu:stop() end)

  menu:run()
  PresentMap = OldPresentMap
  DefinePlayerTypes = oldDefinePlayerTypes
end

function RunMultiPlayerGameMenu(s)
  local menu = WarMenu()
  local offx = (Video.Width - 640) / 2
  local offy = ((Video.Height - 480) / 2) - 70
  local nick

  local function FixMusic()
    wargus.playlist = { "music/Orc Briefing" .. wargus.music_extension }
    SetDefaultRaceView()

    if not (IsMusicPlaying()) then
      PlayMusic("music/Orc Briefing" .. wargus.music_extension)
    end
  end
  InitGameSettings()
  InitNetwork1()

  if (wargus.tales == false) then
    menu:addLabel(wargus.Name .. " V" .. wargus.Version .. ", " .. wargus.Copyright, offx + 320, (Video.Height - 90) + 18*4, Fonts["small"]) -- Copyright information.
  end

  menu:addLabel(_("~<Multiplayer Network Game~>"), offx + 640/2 + 12, offy + 192)

  menu:writeText(_("Nickname :"), 208 + offx, 248 + offy)
  nick = menu:addTextInputField(GetLocalPlayerName(), offx + 298, 244 + offy)

  menu:addFullButton(_("~!Join Local Game"), "j", 208 + offx, 298 + (36 * 0) + offy,
    function()
      if nick:getText() ~= GetLocalPlayerName() then
        SetLocalPlayerName(nick:getText())
        wc2.preferences.PlayerName = nick:getText()
        SavePreferences()
      end
      RunJoinIpMenu()
      FixMusic()
    end)
  menu:addFullButton(_("Join ~!Online Game"), "o", 208 + offx, 298 + (36 * 1) + offy,
    function()
      if nick:getText() ~= GetLocalPlayerName() then
        SetLocalPlayerName(nick:getText())
        wc2.preferences.PlayerName = nick:getText()
        SavePreferences()
      end
      RunJoiningMetaServerMenu()
      FixMusic()
    end)
  menu:addFullButton(_("~!Create Game"), "c", 208 + offx, 298 + (36 * 2) + offy,
    function()
      if nick:getText() ~= GetLocalPlayerName() then
        SetLocalPlayerName(nick:getText())
        wc2.preferences.PlayerName = nick:getText()
        SavePreferences()
      end
      RunCreateMultiGameMenu()
      FixMusic()
    end)

  menu:addFullButton(_("~!Previous Menu"), "p", 208 + offx, 298 + (36 * 3) + offy,
    function() menu:stop() end)

  menu:run()

  ExitNetwork1()
end
