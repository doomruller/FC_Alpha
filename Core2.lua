FusedCouncil = LibStub("AceAddon-3.0"):NewAddon("FusedCouncil","AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceHook-3.0", "AceTimer-3.0");
local LibDialog = LibStub("LibDialog-1.0");


-- current session vars
local sessID;
local sessIDML;
local ML;
local lootedSessUnit;
local sessOptions;
local timers;

-- current session item vars
local currentItem;
local itemBank;
local givenItemBank;

-- prev session vars
local lastSessID;
local lastItemRecived;

-- UI components
local mainCouncilFrame;

-- Addon Settings
local usingAddon;
local version = "7.0.3-v.91";
local dbProfile;
local addonPrefix = "FCPREFIX";
local dbDefaults = {

	profile = {
		  options = {
			numOfResponseButtons = 7,
			responseButtonNames = {"Bis", "Major","Minor", "Reroll", "OffSpec", "Transmog", "Pass"},
			lootCouncilMembers = {UnitName("player")},
		  },		
		  initializeFromDB = false;
    },

};


function FusedCouncil:OnInitialize()
	-- initialize DB with defaults
	self.db = LibStub("AceDB-3.0"):New("FusedCouncilDB",dbDefaults, true);
	self.db:RegisterDefaults(dbDefaults);
	dbProfile = self.db.profile;
	
	-- UI components
	mainCouncilFrame = FusedCouncil:createMainCouncilFrame();

	-- initialize all veriables.
	if dbProfile.initializeFromDB then
		self:loadFromDB();
		mainCouncilFrame:Show();
		self:update();
	else
		self:initializeVars();
	end
	
end

function FusedCouncil:OnEnable()
	
	-- register world events
	self:RegisterEvent("LOOT_OPENED", function()  
		local lootMethod, isML = GetLootMethod();
		local lootedUnit = UnitName("target");
		
		if lootMethod =="master" and self:isML() and usingAddon then
			if sessIDML ~= "" then
				-- if we do not have a fresh sessIDML
				if lootedUnit ~= lootedSessUnit then
					-- we have a new body being looted
					
					-- check if itemLinks are =?
					FusedCouncil:prossessLootedBody(sessIDML);					
				else
					-- we don't have a new body being looted				
				end			
			else
				-- we have a fresh sessIDML
				lootedSessUnit = lootedUnit;
				ML = UnitName("player");
				sessIDML = tostring(math.floor(GetTime())) .. UnitName("player");				
				FusedCouncil:prossessLootedBody(sessIDML);
		
			end
		
		
		end
	
	end);
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()  
		local isInstance, instanceType = IsInInstance();
		if isInstance  and UnitIsGroupLeader("player") and not dbProfile.initializeFromDB and not usingAddon then
			--toast to see if using addon
			-- and instanceType == "raid"
			LibDialog:Spawn("FC_CONFIRM_USAGE");
		end	
	end);
	self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED", function()  
		if GetLootMethod() == "master" and self:isML()  then
			--toast to see if using addon
			LibDialog:Spawn("FC_CONFIRM_USAGE");
		end	
	end);
	
	
	self:RegisterEvent("CHAT_MSG_LOOT", function(_,msg,sender)  
			local leng = string.find(msg, ":");
			if string.sub(msg,1, leng) == "You receive loot:" then
				local itemLink =string.sub(msg,string.find(msg, "%|.+%|r"));				
				local _,_, _, ltype, id =string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?");
				local _, _, itemRarity = GetItemInfo(id);
				if itemRarity >= GetLootThreshold() then
					lastItemRecived = id;
				end
			end
	end);
	
	-- register communications
	self:RegisterComm(addonPrefix, "CommHandler");
	-- Toast settup with libdialog
	LibDialog:Register("FC_CONFIRM_USAGE", {
		text = "Fused Council \n\n Would you like to use Master Loot in this raid?",
		buttons = {
			{	text = "Yes",
				on_click = function()
					usingAddon = true;
					if GetLootMethod() ~= "master" then
						SetLootMethod("master", UnitName("player"));	
					end
				end,
			},
			{	text = "No",
				on_click = function()
					usingAddon = false;
				end,
			},
		},
		hide_on_escape = true,
		show_while_dead = true,
	});
	
	LibDialog:Register("FC_Given_Toast", {
		text = "Fused Council \n\n Item: could not be given to "  ,
		buttons = {
			{	text = "OK",
				on_click = function()
					
				end,
			},
			
		},
		hide_on_escape = true,
		show_while_dead = true,
	})

	-- Set up slash cmds
	self:RegisterChatCommand("fc", function(input)
		local args = {strsplit(" ", input)};
		
		if args[1] ~= nil then
			if args[1] == "dbug" then
				if args[2] == "on" then
					print("dbug mode on");
					dbug=true;
				elseif args[2] == "off" then
					print("dbug mode on");
					dbug=false;
				else
					print("dbug on or off");
				end
			end
			if args[1] == "clear" then
				self:clear();
			end
			if args[1] == "vcheck" then
				print("FusedCouncil version :"..version);
				if args[2] == "raid" then
					-- sendTCP
				end
			end
		else
			print("No cmd was entered");
		end
	end);
	
	-- Setup addon options
	local options = {
		name ="FusedCouncil",
		type="group",
		-- can have set and get defined to get from DB
		args = {
		  global = {
			order =1,
			name = "General config",
			type ="group",

			args = {
			  help = {
				order=0,
				type = "description",
				name = "FusedCouncil is an in game loot distribution system."

			  },

			  buttons = {
				order =1,
				type = "group",
				guiInline = true,
				name = "Response Buttons",
				args = {
				  help = {
					order =0,
					type="description",
					name = "Allows the configuration of response buttons"

				  },
				  numButtons = {
					type = "range",
					width = 'full',
					order = 1,
					name = "Amount of buttons to display:",
					min = 1,
					max = 7,
					step = 1,
					set = function(info, val)  dbProfile.options.numOfResponseButtons = val end,
					get = function(info) return dbProfile.options.numOfResponseButtons end,
				  },
				  button1 = {
					type = "input",
					name = "button1",

					order = 2,
					set = function(info, val) dbProfile.options.responseButtonNames[1] = val end,
					get  = function(info, val) return dbProfile.options.responseButtonNames[1] end,
				  },
				  button2 = {
					type = "input",
					name = "button2",
					order = 3,
					hidden = function () return dbProfile.options.numOfResponseButtons < 2 end,
					set = function(info, val) dbProfile.options.responseButtonNames[2] = val end,
					get  = function(info, val) return dbProfile.options.responseButtonNames[2] end,

				  },
				  button3 = {
					type = "input",
					name = "button3",

					order = 4,
					hidden = function () return dbProfile.options.numOfResponseButtons < 3 end,
					set = function(info, val) dbProfile.options.responseButtonNames[3] = val end,
					get  = function(info, val) return dbProfile.options.responseButtonNames[3] end,

				  },
				  button4 = {
					type = "input",
					name = "button4",

					order = 5,
					hidden = function () return dbProfile.options.numOfResponseButtons < 4 end,
					set = function(info, val) dbProfile.options.responseButtonNames[4] = val end,
					get  = function(info, val) return dbProfile.options.responseButtonNames[4] end,
				  },
				  button5 = {
					type = "input",
					name = "button5",
					order = 6,
					hidden = function () return dbProfile.options.numOfResponseButtons < 5 end,
					set = function(info, val) dbProfile.options.responseButtonNames[5] = val end,
					get  = function(info, val) return dbProfile.options.responseButtonNames[5] end,
				  },
				  button6 = {
					type = "input",
					name = "button6",
					order = 7,
					hidden = function () return dbProfile.options.numOfResponseButtons < 6 end,
					set = function(info, val) dbProfile.options.responseButtonNames[6] = val end,
					get  = function(info, val) return dbProfile.options.responseButtonNames[6] end,
				  },
				  button7 = {
					type = "input",
					name = "button7",
					order = 8,
					hidden = function () return dbProfile.options.numOfResponseButtons < 7 end,
					set = function(info, val) dbProfile.options.responseButtonNames[7] = val end,
					get  = function(info, val) return dbProfile.options.responseButtonNames[7] end,
				  },
				},
			  },
			  lootCouncilGroup = {
				order =2,
				type = "group",
				guiInline = true,
				name = "Loot Council",
				args = {
				  help = {
					order =0,
					type="description",
					name = "Allows the configuration of the members on council"

				  },
				  councilInput = {
					type = "input",
					name = "Loot Council Member",
					order = 1,
					width = "full",
					set = function(info, val)
					  -- get string convert to array store array
					  -- { multple values } instantly creates an array with those values
					  dbProfile.options.lootCouncilMembers = {strsplit(",", val)};
					end,
					get  = function(info, val)
					  -- take stored array convert to string and return string
					  local tempString = "";
					  for i=1, #dbProfile.options.lootCouncilMembers do
						if i == 1 then
						  tempString = dbProfile.options.lootCouncilMembers[i];
						else
						  tempString = tempString .. "," .. dbProfile.options.lootCouncilMembers[i];
						end

					  end

					  return tempString;
					end,
				  },

				},
			  },
			  resetDB = {
				type = "execute",
				name = "reset salved DB",
				func = function() FusedCouncil:clearForNextUse(); end,


			  },
			  resetProfile = {
				type = "execute",
				name = "reset defaults",
				func = function() FusedCouncil.db:ResetProfile(); end,


			  },

			},
		  },
		},

	  };

	LibStub("AceConfig-3.0"):RegisterOptionsTable("FusedCouncil Options", options);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FusedCouncil Options", "FusedCouncil", nil, 'global');

end


--------------------------------------------------------------------
-------------             MY Functions  		-------------------
--------------------------------------------------------------------

-------
-- A --
-------

-------
-- B --
-------

-------
-- C --
-------
function FusedCouncil:clear()
	mainCouncilFrame:Hide();
	if self:isML() then
		local raidMembers = {};
		for k=1, GetNumGroupMembers() do
			local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
			if online then							
				table.insert(raidMembers, name);
			end
		end
		local clearPL = {sessionID = sessID};
		self:sendTCP("clear",clearPL,"RAID",raidMembers,sessID);
	end
	
	-- prev session vars
	lastSessID = sessID;
	
	-- reset all other Vars
	self:initializeVars();	
	
	dbProfile.initializeFromDB = false;
	self:GetModule("FC_LootPopup"):clear();			
end
function FusedCouncil:copyItem(orig)
 local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[self:copyItem(orig_key)] = self:copyItem(orig_value)
        end
        setmetatable(copy, self:copyItem(getmetatable(orig)))
		copy["isGiven"] = true;
		copy["count"] = 1;
    else -- number, string, boolean, etc
        copy = orig
    end
	
    return copy

end

function FusedCouncil:CommHandler(prefix, message, distrubtuion, sender)
	if prefix == addonPrefix then
		local success, payload = self:Deserialize(message);
		
		if success then
			if payload["cmd"] == "itemBank" then
				--{itemBank = sendItems, sessionID = sessID, ML = ML, options = dbProfile.options}
				
				if sessID == ""  then
					self:sendACK("itemBank", sender, payload["contents"]["sessionID"]);
					dbProfile.initializeFromDB = true;
					sessID = payload["contents"]["sessionID"];
					ML = payload["contents"]["ML"];
					sessOptions = payload["contents"]["options"];
					self:GetModule("FC_LootPopup"):addPopupItems(payload["contents"]["itemBank"]);
					if FusedCouncil:isCouncilMember() and not self:isML() then
						mainCouncilFrame:Show();
						itemBank = payload["contents"]["itemBank"];
						FusedCouncil:update();
					end
				elseif payload["sessionID"] == sessID then
					-- added more loot
				elseif payload["sessionID"] ~= sessID then
					-- new session has started and prev session wasn't cleared
				end
			end
			
			if payload["cmd"] == "response" then
				self:dbug(sessID .. " recived response cmd " ..  payload["contents"]["sessionID"]);
				if sessID == payload["contents"]["sessionID"] and self:isCouncilMember() then
					local item = self:findItem(payload["contents"]["response"]["itemLink"], itemBank);
					if not self:findResponse(item, sender) then
							self:dbug("recived response from " .. sender .. " about " .. payload["contents"]["response"]["itemLink"]);
							table.insert(item["responses"], payload["contents"]["response"]);
							FusedCouncil:sendACK("response", sender, sessID,payload["contents"]["response"]["itemLink"] );
							FusedCouncil:update();
					else
						self:dbug("already got this response dropping data");
					end
				end
			end
			
			if payload["cmd"] == "vote" then
			print(sessID .. " " ..  payload["contents"]["sessionID"])
				if sessID == payload["contents"]["sessionID"] and self:isCouncilMember() then 
					local item = self:findItem(payload["contents"]["item"]["itemLink"], itemBank);
					local response = self:findResponse(item, payload["contents"]["to"]);
					if not self:hasVoteFrom(item,sender) then
						table.insert(response["votes"], sender);
					end					
					self:sendACK("vote",sender, sessID, payload["contents"]["item"]["itemLink"]);
					self:update();
				end
			
			end
			
			if payload["cmd"] == "unvote" then
				if sessID == payload["contents"]["sessionID"] and self:isCouncilMember() then 
					local item = self:findItem(payload["contents"]["item"]["itemLink"], itemBank);
					local response = self:findResponse(item, payload["contents"]["to"]);
					for i=#response["votes"], 1, -1 do
						if response["votes"][i] == sender then
							table.remove(response["votes"], i);
						end
					end
					self:sendACK("unvote",sender, sessID, payload["contents"]["item"]["itemLink"]);
					self:update();
				end
			end
			
			if payload["cmd"] == "give" then
				if self:getIdFromLink( payload["contents"]["item"]["itemLink"]) == lastItemRecived then
					self:sendACK("give", sender, sessID, payload["contents"]["item"]["itemLink"]);
				end
			end			
			
			if payload["cmd"] == "clear" then
				self:sendACK("clear",sender, sessID);
				if not self:isML() then
					local localSessNum, localSessName = string.find(payload["contents"]["sessionID"], "?(%d+)?(%a+)");
					local sessNum, sessName = string.find(sessID, "?(%d+)?(%a+)");
					if localSessName == sessName and localSessNum > sessNum then
						-- we are getting old clear from prev session ignore it						
					else
						self:clear();
					end
					
				end
				
			end
			
			if payload["cmd"] == "vcheck" then
				--TODO
			end
			
			if payload["cmd"] == "ack" then
				-- {cmd="ack", type=type, sessionID=sessionID, identifer = identifer}
				 for i=#timers,1 ,-1 do
					if payload["sessionID"] == timers[i]["sessionID"] and   timers[i]["cmd"] == payload["type"]  then
						if payload["identifer"] then
							if timers[i]["identifer"] and timers[i]["identifer"] == payload["identifer"]then
								-- found right timer
								for k=#timers[i]["sendList"], 1, -1 do
									if timers[i]["sendList"][k] == sender then
										table.remove(timers[i]["sendList"], k );
										self:dbug("recived " .. payload["type"] .. sender );
									end
								end
							
							end
						else
							-- found right timer
							for k=#timers[i]["sendList"], 1, -1 do
								if timers[i]["sendList"][k] == sender then
									table.remove(timers[i]["sendList"], k );
									self:dbug("recived " .. payload["type"] .." ack from ".. sender );
								end
							end
						end
						
						
					end
					if #timers[i]["sendList"] == 0 then
						self:CancelTimer(timers[i]["timer"]);
						table.remove(timers, i);
						self:dbug("recived all " .. payload["type"] .. " acks. timer canceled" );
						
					end
					
				end
			
			end
			
			
			
			
		end-- end success
	end
end

function FusedCouncil:createItem(itemLink)
	local itemName, _ , _, itemLevel, _, itemType, itemSubType, _, itemEquipLoc, itemTexture = GetItemInfo(itemLink);
	local item = {
		type = "item",
		itemName = itemName,
		itemLink = itemLink,
		itemLevel = itemLevel,
		itemType = itemType,
		itemSubType = itemSubType or "unknown",
		itemEquipLoc = itemEquipLoc or "unknown",
		itemTexture = itemTexture,
		-- What the addon also needs inside an item
		count = 1,
		isGiven = false,
		givenTo = {},
		responses = {}
	  };
  
	return item;
end

function FusedCouncil:createMainCouncilFrame()
	local tempMain = CreateFrame("Frame", nil, UIParent, "FC_MainCouncilFrame");
	tempMain:Hide();
	local curItemFrame = getglobal("FC_currentItemFrame");
	
	curItemFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(curItemFrame,"ANCHOR_RIGHT");
		if currentItem then
			GameTooltip:SetHyperlink(currentItem["itemLink"]);
			GameTooltip:Show();		
		end		
	end);
	
	curItemFrame:SetScript("OnLeave", function() 
		GameTooltip:Hide();	
	end);
	
	
	local windowFrame = CreateFrame("Frame", "FC_windowFrame1", tempMain, "FC_ItemFrame");
	windowFrame:SetPoint("bottomleft",10,-50);
	getglobal("FC_windowFrame1GivenTexture"):SetTexture("Interface\\FullScreenTextures\\LowHealth");
	getglobal("FC_windowFrame1GivenTexture"):Hide();
	windowFrame:Hide();

	for i=2, 10 do
		windowFrame = CreateFrame("Frame", "FC_windowFrame"..i, tempMain, "FC_ItemFrame");
		windowFrame:SetPoint("Left","FC_windowFrame" .. (i-1), "Right", 10,0);
		getglobal("FC_windowFrame"..i.."GivenTexture"):SetTexture("Interface\\FullScreenTextures\\LowHealth");
		getglobal("FC_windowFrame"..i.."GivenTexture"):Hide();
		windowFrame:Hide();
	end
	
	
	
	tempMain.responseWindow = getglobal("FC_responseWindow");
	local responseChild = CreateFrame("Frame", nil, tempMain.responseWindow);
	tempMain.responseWindow:SetScrollChild(responseChild);
	
	local entryFrame = CreateFrame("Frame", "FC_entry1", responseChild, "FC_ResponseEntry");
	entryFrame:SetPoint("TopLeft",10,-10);
	local giveButton = getglobal("FC_entry1GiveButton");
	giveButton:SetScript("OnClick", function() 
		if currentItem then
			if self:isML() then
				self:giveItem(currentItem, getglobal("FC_entry1CharName"):GetText());
			end
		end
	
	end );
	entryFrame:Hide();

	for i=2, 40 do
		entryFrame = CreateFrame("Frame", "FC_entry"..i, responseChild, "FC_ResponseEntry");
		entryFrame:SetPoint("Top","FC_entry" .. (i-1), "Bottom");
		local giveButton = getglobal("FC_entry" .. i .. "GiveButton");
		giveButton:SetScript("OnClick", function() 
			if currentItem then
				if self:isML() then
					self:giveItem(currentItem, getglobal("FC_entry" .. i .."CharName"):GetText());
				end
			end
		
		end );
		entryFrame:Hide();
	end
	
	return tempMain
end

-------
-- D --
-------
function FusedCouncil:dbug(msg)
		print(msg);

end
-------
-- E --
-------

-------
-- F --
-------
function FusedCouncil:findItem(itemLink, itemTable)
	for i=1, #itemTable do
		if itemTable[i]["itemLink"] == itemLink then
			return itemTable[i];
		end
	end
	return nil;	
end
function FusedCouncil:findResponse(item, name)
	for i=1, #item["responses"] do
		if item["responses"][i]["player"]["name"] == name then
			return item["responses"][i];
		end
	end
	return nil;
end

-------
-- G --
-------
function FusedCouncil:getDBProfile()
	return dbProfile;
end
function FusedCouncil:getOptions()
	-- have to return copy of options table and idk why
	return self:copyItem(sessOptions);
end
function FusedCouncil:getSessionID()
	return sessID;
end
function FusedCouncil:getIdFromLink(itemLink)
	local _,_, _, ltype, id =string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?");
	return id;
	
end
function FusedCouncil:giveItem(itemIn, playername)
 -- TODO Actually give the item
	-- find the item on the body
	local itemIndex =0;
	for i=1, GetNumLootItems() do
		local itemLink = GetLootSlotLink(i);
		if itemLink == itemIn["itemLink"] then
			itemIndex = i;
		end		
	end
	-- find the player
	for i=1, GetNumGroupMembers() do
		
		local name = select(1, GetMasterLootCandidate(itemIndex,i));
		if name and name == playername then
			-- give the item
			GiveMasterLoot(itemIndex, i);
			local givePL = {item= itemIn};
			self:sendTCP("give", givePL, "WHISPER", {playername}, sessID,itemIn["itemLink"]);
		end
	end
 
end


-------
-- H --
-------
function FusedCouncil:hasVoteFrom(item, player)
  for i=1, #item["responses"] do
    for k=1, #item["responses"][i]["votes"] do
      if item["responses"][i]["votes"][k] == player then
        return true;
      end
    end
  end
  return false;
end
-------
-- I --
-------
function FusedCouncil:initializeVars()
	-- current session vars
	sessID = "";
	sessIDML = "";
	ML = "";
	lootedSessUnit = "";
	sessOptions = {};
	timers = {};

	-- current session item vars
	currentItem = nil;
	itemBank = {};
	givenItemBank = {};
	
	
	
	-- current session vars
	dbProfile.sessID = "";
	dbProfile.sessIDML = "";
	dbProfile.ML = "";
	dbProfile.lootedSessUnit = "";
	dbProfile.sessOptions = {};
	dbProfile.timers = {};

	-- current session item vars
	dbProfile.currentItem = nil;
	dbProfile.itemBank = {};
	dbProfile.givenItemBank = {};
	
end
function FusedCouncil:isCouncilMember()
	if sessOptions then
		for i=1, #sessOptions["lootCouncilMembers"] do	
			if UnitName("player") == sessOptions["lootCouncilMembers"][i] then
				return true;
			end
		end
		return false;
	else
		return false;
	end
end

function FusedCouncil:isML()
	local _, isML = GetLootMethod();
	return isML ==0;
end

-------
-- J --
-------

-------
-- K --
-------

-------
-- L --
-------
function FusedCouncil:loadFromDB()
	-- current session vars
	sessID = dbProfile.sessID;
	ML = dbProfile.ML;
	lootedSessUnit = dbProfile.lootedSessUnit;
	sessOptions = dbProfile.sessOptions;
	timers = dbProfile.timers;
	
	-- current session item vars
	currentItem = dbProfile.currentItem;
	itemBank = dbProfile.itemBank;
	givenItemBank = dbProfile.givenItemBank;

	-- prev session vars
	lastSessID = dbProfile.lastSessID;
	lastItemRecived = dbProfile.lastItemRecived;

	-- Addon Settings
	usingAddon = dbProfile.usingAddon;		
end
-------
-- M --
-------

-------
-- N --
-------

-------
-- O --
-------

-------
-- P --
-------
function FusedCouncil:prossessLootedBody(sessIDML)
	local MLItems = {};
	local sendItems = {};
	local threshold = GetLootThreshold();
	-- do we have any items that need to be MLed?
	for i=1, GetNumLootItems() do
		local path, name, quantity, rarity =  GetLootSlotInfo(i);
		if rarity and  rarity >= threshold then
			table.insert(MLItems, GetLootSlotLink(i));
		end
	end	
	
	if #MLItems > 0 then
		-- we have items to be MLed
		for i=1, #MLItems do
			local item = FusedCouncil:findItem(MLItems[i], sendItems);
			if item then
				item["count"] = item["count"] + 1;
			else
				table.insert(sendItems, FusedCouncil:createItem(MLItems[i]));
			end
		end
		local itemBankRecivers = {};
		-- get a list of people that we should expect to get the loot list
		for i=1, GetNumGroupMembers() do			
			local name = select(1, GetMasterLootCandidate(1,i));
			if name then
				table.insert(itemBankRecivers, name);
			end
		end
		
		itemBank = sendItems;
		local itemBankPL = {itemBank = sendItems, sessionID = sessIDML, ML = ML, options = dbProfile.options};
		FusedCouncil:sendTCP("itemBank",itemBankPL,"RAID",itemBankRecivers, sessIDML );		
		FusedCouncil:update();
	end
end

-------
-- Q --
-------

-------
-- R --
-------

-------
-- S --
-------
function FusedCouncil:saveToDB()
	dbProfile.initializeFromDB = true;
	-- current session vars
	 dbProfile.sessID = sessID;
	 dbProfile.ML = ML;
	 dbProfile.lootedSessUnit = lootedSessUnit;
	 dbProfile.sessOptions = sessOptions;
	 dbProfile.timers = timers;

	-- current session item vars
	dbProfile.currentItem = currentItem;
	dbProfile.itemBank = itemBank;
	dbProfile.givenItemBank = givenItemBank;

	-- prev session vars
	dbProfile.lastSessID = lastSessID;
	dbProfile.lastItemRecived = lastItemRecived;

	-- Addon Settings
	dbProfile.usingAddon = usingAddon;
		
end

function FusedCouncil:sendACK(type, destination, sessionID, identifer)
	self:dbug("sent ack for " .. type .. " to " .. destination)
	local ack = {cmd="ack", type=type, sessionID=sessionID, identifer = identifer};
	local serializedAck = FusedCouncil:Serialize(ack);
	FusedCouncil:SendCommMessage(addonPrefix, serializedAck, "WHISPER", destination);
end

function FusedCouncil:sendTCP(cmd, contents, channel, targets, insessID, identifer)
	local payload = {cmd=cmd, contents = contents};
	local serPayload = FusedCouncil:Serialize(payload);
	if channel == "RAID" then
		self:SendCommMessage(addonPrefix, serPayload, "RAID");
	elseif channel == "WHISPER" then
		for i=1, #targets do
			self:SendCommMessage(addonPrefix, serPayload, "WHISPER", targets[i]);
		end
	end
	
	local tempTable = {timer = 0, count =0, cmd = cmd,  sessionID = insessID, sendList= targets, identifer = identifer};
	tempTable["timer"] = self:ScheduleRepeatingTimer(function() 
			tempTable["count"] = tempTable["count"] +1;
			for i=1, #tempTable["sendList"] do
					for k=1, GetNumGroupMembers() do
						local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
						if tempTable["sendList"][i] == name and online then							
							FusedCouncil:SendCommMessage(addonPrefix,serPayload, "WHISPER", name);
							self:dbug("resending ".. cmd .. " to " .. name .. " " .. tempTable["count"]);
						end
					end
			end
			if tempTable["count"] == 4 then
			  self:CancelTimer(tempTable["timer"]);
			  self:dbug("timer ".. cmd ..  "canceled");
			  for i=#timers,1 ,-1 do
					if tempTable["sessionID"] == timers[i]["sessionID"] and   timers[i]["cmd"] == tempTable["cmd"] and timers[i]["identifer"] == tempTable["identifer"] then
						self:dbug("removing timer ".. cmd .." because time out");
						table.remove(timers, i);
					end
					if timers[i]["sessionID"] ~= sessID then
						self:dbug("removing timer ".. timers[i]["cmd"]  .. " because mismatch sessID");
						table.remove(timers, i);
					end
			  end
			  
			end
		  end, 2);
	table.insert(timers, tempTable);
	
	
end
-------
-- T --
-------

-------
-- U --
-------
function FusedCouncil:update()
	-- main window stuff
	self:saveToDB();
	
	 if not currentItem and #itemBank > 0 then
		currentItem = itemBank[1];
	 end
  
	 if #itemBank == 0 and #timers["clearTimers"] == 0 then
		self:clear();
	else 
		mainCouncilFrame:Show();
	 end
	
	if currentItem then
		getglobal("FC_CurrentItemLabel"):SetText(currentItem["itemLink"]);
		getglobal("FC_CurrentItemIlvlLabel"):SetText("ilvl: " .. currentItem["itemLevel"]);
		local loc = _G[currentItem["itemEquipLoc"]] or "";
		getglobal("FC_CurrentItemTypeLabel"):SetText(currentItem["itemSubType"] .. " " .. loc);
		getglobal("FC_currentItemFrameTexture"):SetTexture(currentItem["itemTexture"]);
		getglobal("FC_currentItemFrameItemCountText"):SetText(currentItem["count"]);
		if currentItem["isGiven"] then
			getglobal("FC_currentItemFrameGivenTexture"):Show();
		else
			getglobal("FC_currentItemFrameGivenTexture"):Hide();
		end
		FusedCouncil:updateEntrys();

	else
		getglobal("FC_CurrentItemLabel"):SetText("Current Item Label");
		getglobal("FC_CurrentItemIlvlLabel"):SetText("ilvl: 865");
		getglobal("FC_CurrentItemTypeLabel"):SetText("Item Type");
		getglobal("FC_currentItemFrameTexture"):SetTexture();
		getglobal("FC_currentItemFrameItemCountText"):SetText("");

	end
	
	FusedCouncil:updateItemsWindow();
end

function FusedCouncil:updateEntrys()
  for i=1, 40 do
    getglobal("FC_entry" .. i):Hide();
    getglobal("FC_entry" .. i .. "ItemFrame"):Hide();
    getglobal("FC_entry" .. i .. "ItemFrameDuo1"):Hide();
    getglobal("FC_entry" .. i .. "ItemFrameDuo2"):Hide();
    getglobal("FC_entry" .. i .."NoteFrameNoteTexture"):SetTexture("Interface\\CHATFRAME\\UI-ChatIcon-Chat-Disabled");
    getglobal("FC_entry" .. i .. "VoteButton"):SetText("Vote");
	getglobal("FC_entry" .. i .. "VoteButton"):Show();
	getglobal("FC_entry" .. i .. "GiveButton"):Show();
  end
  mainCouncilFrame.responseWindow:GetScrollChild():SetSize(800, 30 * #currentItem["responses"] );
  for i=1, #currentItem["responses"] do
	getglobal("FC_entry" .. i):Show();
	if currentItem["isGiven"] then
		getglobal("FC_entry" .. i .. "GiveButton"):Hide();
		getglobal("FC_entry" .. i .. "VoteButton"):Hide();
	end

    local votesFrame = getglobal("FC_entry" .. i .. "VotesFrame");
    votesFrame:SetScript("OnEnter", function()
      GameTooltip:SetOwner(votesFrame, "ANCHOR_RIGHT")
      if currentItem then
        local votes ="";

        for k=1, #currentItem["responses"][i]["votes"] do
          if k > 1 then
            votes = votes .. ", " .. currentItem["responses"][i]["votes"][k];
          else
            votes = votes ..currentItem["responses"][i]["votes"][k];
          end

        end
        GameTooltip:SetText(votes);
        GameTooltip:Show()
      end

    end);
    votesFrame:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end);

    getglobal("FC_entry" .. i .. "VotesFrameVotesString"):SetText(#currentItem["responses"][i]["votes"]);


    for k=1, #currentItem["responses"][i]["votes"] do
      if currentItem["responses"][i]["votes"][k] == UnitName("player") then
        getglobal("FC_entry" .. i .. "VoteButton"):SetText("Unvote");

      end

    end

    getglobal("FC_entry" .. i .. "VoteButton"):SetScript("OnClick", function(self)
	if self:GetText() == "Vote" then
		if not FusedCouncil:hasVoteFrom(currentItem, UnitName("player")) then
			local votePL = {item = currentItem, to = currentItem["responses"][i]["player"]["name"], sessionID = sessID};
						--sendTCP(cmd, contents, channel, targets, insessID, identifer)
			print("sessID is :" .. sessID);
			FusedCouncil:sendTCP("vote", votePL, "RAID", sessOptions["lootCouncilMembers"], sessID, currentItem["itemLink"]);
		end
      else
		local votePL = {item = currentItem, to = currentItem["responses"][i]["player"]["name"], sessionID = sessID};
							--sendTCP(cmd, contents, channel, targets, insessID, identifer)
		print("sessID is :" .. sessID);
		--self:getOptions()["lootCouncilMembers"]
		FusedCouncil:sendTCP("unvote", votePL, "RAID", sessOptions["lootCouncilMembers"], sessID, currentItem["itemLink"]);
      end


    end);


    getglobal("FC_entry" .. i .."NoteFrame");
    if currentItem["responses"][i]["note"] ~= "" then
      local noteFrame = getglobal("FC_entry" .. i .."NoteFrame");
      getglobal("FC_entry" .. i .."NoteFrameNoteTexture"):SetTexture("Interface\\CHATFRAME\\UI-ChatIcon-Chat-Up");

      noteFrame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(noteFrame, "ANCHOR_RIGHT")
        if currentItem then
          GameTooltip:SetText(currentItem["responses"][i]["note"]);
          GameTooltip:Show()
        end

      end);
      noteFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end);


    end




    getglobal("FC_entry" .. i .. "ClassIcon"):SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES");
    local coords = CLASS_ICON_TCOORDS[currentItem["responses"][i]["player"]["class"]];
    getglobal("FC_entry" .. i .. "ClassIcon"):SetTexCoord(unpack(coords));

    getglobal("FC_entry" .. i .. "CharName"):SetText(currentItem["responses"][i]["player"]["name"]);
    getglobal("FC_entry" .. i .. "Ilvl"):SetText(currentItem["responses"][i]["player"]["ilvl"]);
    getglobal("FC_entry" .. i .. "Score"):SetText(currentItem["responses"][i]["player"]["score"]);
    getglobal("FC_entry" .. i .. "Rank"):SetText(currentItem["responses"][i]["player"]["guildRank"]);
    getglobal("FC_entry" .. i .. "Response"):SetText(currentItem["responses"][i]["response"]);

	if currentItem["responses"][i]["currentItems"] then
		if #currentItem["responses"][i]["currentItems"] == 1 then
		  local itemFrame = getglobal("FC_entry" .. i .. "ItemFrame");
		  itemFrame:Show();
		  getglobal("FC_entry" .. i .. "ItemFrameTexture"):SetTexture(currentItem["responses"][i]["currentItems"][1]["itemTexture"]);


		  itemFrame:SetScript("OnEnter", function()
			GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
			if currentItem then
			  GameTooltip:SetHyperlink(currentItem["responses"][i]["currentItems"][1]["itemLink"]);
			  GameTooltip:Show()
			end

		  end);
		  itemFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		  end);
		elseif #currentItem["responses"][i]["currentItems"] == 2 then
		  local itemFrame = getglobal("FC_entry" .. i .. "ItemFrameDuo1");
		  itemFrame:Show();
		  getglobal("FC_entry" .. i .. "ItemFrameDuo1Texture"):SetTexture(currentItem["responses"][i]["currentItems"][1]["itemTexture"]);


		  itemFrame:SetScript("OnEnter", function()
			GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
			if currentItem then
			  GameTooltip:SetHyperlink(currentItem["responses"][i]["currentItems"][1]["itemLink"]);
			  GameTooltip:Show()
			end

		  end);
		  itemFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		  end);

		  itemFrame = getglobal("FC_entry" .. i .. "ItemFrameDuo2");
		  itemFrame:Show();
		  getglobal("FC_entry" .. i .. "ItemFrameDuo2Texture"):SetTexture(currentItem["responses"][i]["currentItems"][2]["itemTexture"]);


		  itemFrame:SetScript("OnEnter", function()
			GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
			if currentItem then
			  GameTooltip:SetHyperlink(currentItem["responses"][i]["currentItems"][2]["itemLink"]);
			  GameTooltip:Show()
			end

		  end);
		  itemFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		  end);




		else
		  getglobal("FC_entry" .. i .. "ItemFrameTexture"):SetTexture("Interface\\InventoryItems\\WowUnknownItem01");

		end
	end
	
	
  end

end

function FusedCouncil:updateItemsWindow()
  for i=1, 10 do
    getglobal("FC_windowFrame"..i):Hide();
	getglobal("FC_windowFrame"..i.."GivenTexture"):Hide();
	getglobal("FC_windowFrame"..i.."ItemCountText"):SetText("");
  end
  
  for i=1, #itemBank do
	getglobal("FC_windowFrame"..i .. "Texture"):SetTexture(itemBank[i]["itemTexture"]);
	getglobal("FC_windowFrame"..i.."ItemCountText"):SetText(itemBank[i]["count"]);
    local frame = getglobal("FC_windowFrame"..i);
    frame:Show();
    frame:SetScript("OnEnter", function()
      GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(itemBank[i]["itemLink"]);
      GameTooltip:Show()
    end);
    frame:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end);

    frame:SetScript("OnMouseDown", function()
      currentItem = itemBank[i];
      FusedCouncil:update();
    end);

  end
  
  for i=1, #givenItemBank do
	getglobal("FC_windowFrame"..i + #itemBank .. "Texture"):SetTexture(givenItemBank[i]["itemTexture"]);
	getglobal("FC_windowFrame"..i + #itemBank.."GivenTexture"):Show();
	getglobal("FC_windowFrame"..i + #itemBank.."ItemCountText"):SetText(givenItemBank[i]["count"]);
    local frame = getglobal("FC_windowFrame"..i+ #itemBank);
	
    frame:Show();
    frame:SetScript("OnEnter", function()
      GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(givenItemBank[i]["itemLink"]);
      GameTooltip:Show()
    end);
    frame:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end);

    frame:SetScript("OnMouseDown", function()
      currentItem = givenItemBank[i];
      FusedCouncil:update();
    end);
  end

end


-------
-- V --
-------

-------------
-- W,X,Y,Z --
-------------

