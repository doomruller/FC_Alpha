FusedCouncil = LibStub("AceAddon-3.0"):NewAddon("FusedCouncil","AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceHook-3.0", "AceTimer-3.0");
local LibDialog = LibStub("LibDialog-1.0");

-- Session var
local lootedSessUnit;
local sessionID;
local ML;

-- session item var
local currentItem;
local itemBank;
local givenItemBank;
local sessOptions;
local itemBankTimer;
local itemBankRecivers;
local voteTimers;
local giveTimers;
local clearTimers;
local clearedSessionID;
local lastItemRecived;

-- Addon Settings
local usingAddon;
local dbug;
local dbProfile;
local testing;
local addonPrefix = "FCPREFIX";
local dbDefaults = {

	profile = {
		  options = {
			numOfResponseButtons = 7,
			responseButtonNames = {"Bis", "Major","Minor", "Reroll", "OffSpec", "Transmog", "Pass"},
			lootCouncilMembers = {UnitName("player")},
		  },
		lootedSessUnit = "asd",
		sessionID = "",
		ML = "",
		currentItem = nil,
		itemBank = {},
		givenItemBank = {},
		itemBankRecivers = {},
		voteTimers = {},
		usingAddon = false,
		testing = false,
		dbug = true,
		initializeFromDB = false,
		popupSaved = false,
		
    },

};

--UI components
local mainCouncilFrame;


function FusedCouncil:OnInitialize()
	-- initialize DB with defaults
	self.db = LibStub("AceDB-3.0"):New("FusedCouncilDB",dbDefaults, true);
	self.db:RegisterDefaults(dbDefaults);
	dbProfile = self.db.profile;
	-- UI components
	mainCouncilFrame = FusedCouncil:createMainCouncilFrame();
	
	-- initialize all veriables.
	
		lootedSessUnit = "";
		sessionID = "";
		ML = "";
		
		-- session item var
		currentItem = nil;
		itemBank = {};
		givenItemBank = {};
		itemBankRecivers = {};
		voteTimers = {};
		giveTimers = {};
		clearTimers = {};
		clearedSessionID = "";
		lastItemRecived = 0;
		
		-- Addon Settings
		usingAddon = false;
		testing = false;
		dbug = true;
		
	if dbProfile.initializeFromDB then
		self:loadFromDB();
		mainCouncilFrame:Show();
		self:update();
	end
	
	
	
	
end


function FusedCouncil:OnEnable()
	
	-- register world events
	self:RegisterEvent("LOOT_OPENED", function()  
		local lootMethod, isML = GetLootMethod();
		local lootedUnit = UnitName("target");
		
		if lootMethod =="master" and isML == 0 and usingAddon then
			if sessionID ~= "" then
				-- if we do not have a fresh sessionID
				if lootedUnit ~= lootedSessUnit then
					-- we have a new body being looted
					FusedCouncil:prossessLootedBody(sessionID);					
				else
					-- we don't have a new body being looted				
				end			
			else
				-- we have a fresh sessionID
				lootedSessUnit = lootedUnit;
				ML = UnitName("player");
				sessionID = tostring(math.floor(GetTime())) .. UnitName("player");				
				FusedCouncil:prossessLootedBody(sessionID);
		
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
		else
			usingAddon = false;
		end	
	end);
	
	
	self:RegisterEvent("CHAT_MSG_LOOT", function(_,msg,sender)  
			local leng = string.find(msg, ":");
			print( string.sub(msg,1, leng))
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
		text = "Fused Council \n\n Item: could not be given to " ,
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



function FusedCouncil:OnDisable()


end

--------------------------------------------------------------------
-------------             MY Functions  		-------------------
--------------------------------------------------------------------



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
				self:dbug("recived itemBank. sessionID is ".. payload["sessionID"]);
				self:sendACK("itemBank", sender, payload["sessionID"]);
				if sessionID == "" or (self:isML() and sessionID == payload["sessionID"]) then
					dbProfile.initializeFromDB = true;
					self:dbug("new local Session")
					sessionID = payload["sessionID"];
					testing = payload["testing"];
					ML = payload["ML"];					
					FusedCouncil:sendACK("itemBank", sender, sessionID);
					sessOptions = payload["options"];
					self:GetModule("FC_LootPopup"):addPopupItems(payload["itemBank"]);
					
					if FusedCouncil:isCouncilMember() and not self:isML() then
						self:dbug("you are on council")
						mainCouncilFrame:Show();
						itemBank = payload["itemBank"];
						FusedCouncil:update();
					else
					self:dbug("you are not on council")
					end
				elseif payload["sessionID"] ~= sessionID then
					-- new session has started and prev session wasn't cleared
				end -- end checking sessID within ITEMBANK
				
			end
			if payload["cmd"] == "response" then
				
				if sessionID == payload["sessionID"] then
					if self:isCouncilMember() then
						
						if not self:findResponse(self:findItem(payload["response"]["itemLink"], itemBank), sender) then
							self:dbug("recived response from " .. sender .. " about " .. payload["response"]["itemLink"]);
							local item = self:findItem(payload["response"]["itemLink"], itemBank);
							table.insert(item["responses"], payload["response"]);
							FusedCouncil:sendACK("response", sender, sessionID,payload["response"]["itemLink"] );
							FusedCouncil:update();
						else
							self:dbug("already got this response dropping data");
						end
					end -- end council member check				
				end -- end checking sessID within Response
			end
			if payload["cmd"] == "vote" then
				if sessionID == payload["sessionID"] then
					if self:isCouncilMember() then
						self:dbug("recived vote from " .. sender .. " for " .. payload["vote"]["item"]["itemLink"]);
						local response = self:findResponse(self:findItem(payload["vote"]["item"]["itemLink"], itemBank), payload["vote"]["to"]);
						table.insert(response["votes"], payload["vote"]["from"]);
						FusedCouncil:sendACK("vote", sender, sessionID,payload["vote"]["itemLink"] );
						FusedCouncil:update();
					end-- end council member check				
				end -- end checking sessID within vote			
			end
			if payload["cmd"] == "unvote" then
				if sessionID == payload["sessionID"] then
						if self:isCouncilMember() then
							self:dbug("recived unvote from " .. sender .. " for " .. payload["vote"]["item"]["itemLink"]);
							local response = self:findResponse(self:findItem(payload["vote"]["item"]["itemLink"], itemBank), payload["vote"]["to"]);
							for i=#response["votes"], 1, -1 do
								if response["votes"][i] == payload["vote"]["from"] then
									table.remove(response["votes"], i);
								end
							end
							FusedCouncil:sendACK("unvote", sender, sessionID,payload["vote"]["itemLink"] );
							FusedCouncil:update();
						end-- end council member check				
				end -- end checking sessID within unvote	
			end
			
			if payload["cmd"] == "give" then
				print("recived give cmd")
				-- might need to change this to a table b/c fast items recived
				if self:getIdFromLink( payload["item"]["itemLink"]) == lastItemRecived then
					self:sendACK("give", sender, sessionID, payload["item"]);
				end
			end
			if payload["cmd"] == "ack" then
				
				if payload["type"] == "itemBank" then
					self:dbug("recived itemBank Ack from " .. sender);
					-- iterate back to frunt so we can remove as we go
					for i=#itemBankRecivers, 1, -1 do
						if itemBankRecivers[i] == sender then
							self:dbug("removed " .. sender)
							table.remove(itemBankRecivers, i);
						end
					end
					if #itemBankRecivers == 0 then
						self:dbug("no itemBankRecivers remain canceling timer");
						self:CancelTimer(itemBankTimer);
					end					
				end
				if payload["type"] == "response" then
					self:dbug("recived Response ack from " .. sender .. " for " .. payload["item"]);
					self:GetModule("FC_LootPopup"):reciveResponseACK(payload, sender);
				end
				if payload["type"] == "vote" then
					self:dbug("got vote ack from " .. sender);
					for i=#voteTimers, 1, -1 do
						if payload["item"] == voteTimers[i]["item"] and payload["sessionID"] == voteTimers[i]["sessionID"] and payload["type"] == voteTimers[i]["vote"] then
							for k=#voteTimers[i]["sendList"], 1, -1 do
								if voteTimers[i]["sendList"][k] == sender then
									self:dbug("removing vote timer b/c ack from ".. sender)
									table.remove(voteTimers[i]["sendList"], k);
								end				
							end
						end
					end
				end
				if payload["type"] == "unvote" then
					self:dbug("got unvote ack from " .. sender);
					for i=#voteTimers, 1, -1 do
						if payload["item"] == voteTimers[i]["item"] and payload["sessionID"] == voteTimers[i]["sessionID"] and payload["type"] == voteTimers[i]["vote"] then
							for k=#voteTimers[i]["sendList"], 1, -1 do
								if voteTimers[i]["sendList"][k] == sender then
									self:dbug("removing unvote timer b/c ack from ".. sender)
									table.remove(voteTimers[i]["sendList"], k);
								end				
							end
						end
					end				
				end
				if payload["type"] == "clear" then
					self:dbug("recived clear ack from " .. sender);
					for i=#clearTimers, 1 , -1 do
						for k=#clearTimers[i]["sendList"], 1, -1 do
							if  clearTimers[i]["sendList"][k] == sender then
								table.remove(clearTimers[i]["sendList"],k);
							end
							if  #clearTimers[i]["sendList"] == 0 then
								self:CancelTimer(clearTimers[i]["timer"]);
								table.remove(clearTimers, i );
							end
						end
						
					end
				end
				if payload["type"] == "give" then
					self:dbug("recived give ack from " .. sender);
					for i=#giveTimers, 1 , -1 do
						print(giveTimers[i]["item"]["itemLink"])
						print(payload["item"]["itemLink"])
						if self:getIdFromLink(giveTimers[i]["item"]["itemLink"]) == self:getIdFromLink(payload["item"]["itemLink"] )and giveTimers[i]["player"] == sender then
							 self:CancelTimer(giveTimers[i]["timer"]);
							 table.remove(giveTimers, i);
							 print("removed give ack timer")
						end
					end
					
					-- switch to new item
					if #givenItemBank == 0 then		
						local tempItem = self:copyItem(payload["item"]);
						table.insert(givenItemBank, tempItem);
						table.insert(tempItem["givenTo"], playername);
					else
					
						for i=1, #givenItemBank do
							local item = self:findItem(payload["item"]["itemLink"], givenItemBank);
							if item then
								item["count"] = item["count"] + 1;
								table.insert(item["givenTo"], playername);
							else
								-- may need to copy item instead
								local tempItem = self:copyItem(payload["item"]);
								table.insert(givenItemBank, tempItem);
								table.insert(tempItem["givenTo"], playername);
							end
						end
					
					
					
					end
					if payload["item"]["count"] == 1 then
						for i=#itemBank, 1, -1 do
							if itemBank[i]["itemLink"] == payload["item"]["itemLink"] then
								table.remove(itemBank, i);			
							end
						end
					else
						payload["item"]["count"] = payload["item"]["count"] -1;
					end
					
					if #itemBank > 0 then
						currentItem = itemBank[1];
					end
					
					-- TODO may have to change this to add other update also
					self:update();
				end
			end
		
			if payload["cmd"] == "clear" then
				self:sendACK("clear", sender, sessionID);
				self:clear();
			end
		end -- end if deserialize success
	
	end -- end if prefix matches
	

end

function FusedCouncil:clear()
	mainCouncilFrame:Hide();
	if self:isML() then
		self:sendClear();
	end
	clearedSessionID = sessionID;
	-- Session var
	lootedSessUnit = "";
	sessionID = "";
	ML = "";
	testing = false;
	
	-- session item var
	currentItem = nil;
	itemBank = {};
	givenItemBank = {};
	itemBankRecivers = {};
	for i=#voteTimers, 1, -1 do
		self:CancelTimer(voteTimers["timer"]);
		table.remove(voteTimers, i);
	end
	for i=#giveTimers, 1, -1 do
		self:CancelTimer(giveTimers["timer"]);
		table.remove(giveTimers, i);
	end
	-- Session var
	dbProfile.lootedSessUnit = "";
	dbProfile.sessionID = "";
	dbProfile.ML = "";
	-- session item var
	dbProfile.currentItem = nil;
	dbProfile.itemBank = {};
	dbProfile.givenItemBank = {};
	dbProfile.itemBankRecivers = {};
	dbProfile.voteTimers = {};
	dbProfile.giveTimers = {};
	-- Addon Settings
	dbProfile.testing = false;
	dbProfile.initializeFromDB = false;
	self:GetModule("FC_LootPopup"):clear();
			
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
				self:giveItem(currentItem, getglobal("FC_entry" .. i .."CharName"));
			
			end
		
		end );
		entryFrame:Hide();
	end
	
	return tempMain
end

function FusedCouncil:dbug(msg)
	if dbug then 
		print(msg);
	end

end
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
function FusedCouncil:getOptions()
	return sessOptions;
end
function FusedCouncil:getSessionID()
	return sessionID;
end
function FusedCouncil:getPrefix()
	return addonPrefix;
end
function FusedCouncil:getDBProfile()
	return dbProfile;
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
			self:dbug("gave " .. itemIn["itemLink"] .. " to " .. playername);
			self:sendGivePacket(itemIn, playername);
		end
	end
 
end

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
function FusedCouncil:isCouncilMember()
	if sessOptions then
		for i=1, #sessOptions["lootCouncilMembers"] do			
			if UnitName("player") == sessOptions["lootCouncilMembers"][i] then
				return true;
			end
		end
	else
		return false;
	end
end
function FusedCouncil:isML()
	return ML == UnitName("player");
end
function FusedCouncil:loadFromDB()
		lootedSessUnit = dbProfile.lootedSessUnit;
		sessionID = dbProfile.sessionID;
		ML = dbProfile.ML;
		
		-- session item var
		currentItem = dbProfile.currentItem;
		itemBank = dbProfile.itemBank;
		givenItemBank = dbProfile.givenItemBank;
		itemBankRecivers = dbProfile.itemBankRecivers;
		voteTimers = dbProfile.voteTimers;
		giveTimers = dbProfile.giveTimers;
		clearedSessionID = dbProfile.clearedSessionID;
		clearTimers = dbProfile.clearTimers;
		-- Addon Settings
		usingAddon = dbProfile.usingAddon;
		testing = dbProfile.testing;
		dbug = dbProfile.dbug;
		
end
function FusedCouncil:prossessLootedBody(sessID)
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
		-- if we have items to be MLed
		for i=1, #MLItems do
			local item = FusedCouncil:findItem(MLItems[i], sendItems);
			if item then
				item["count"] = item["count"] + 1;
			else
				table.insert(sendItems, FusedCouncil:createItem(MLItems[i]));
			end
		end
		
		-- get a list of people that we should expect to get the loot list
		for i=1, GetNumGroupMembers() do			
			local name = select(1, GetMasterLootCandidate(1,i));
			if name then
				table.insert(itemBankRecivers, name);
			end
		end
		
		itemBank = sendItems;
		--sessionID = sessID;
		FusedCouncil:sendItemBank(sendItems, sessID);		
		FusedCouncil:update();
	end
end

function FusedCouncil:saveToDB()
		dbProfile.initializeFromDB = true;
		-- Session var
		dbProfile.lootedSessUnit = lootedSessUnit;
		dbProfile.sessionID = sessionID;
		dbProfile.ML = ML;
		
		-- session item var
		dbProfile.currentItem = currentItem;
		dbProfile.itemBank = itemBank;
		dbProfile.givenItemBank = givenItemBank;
		dbProfile.itemBankRecivers = itemBankRecivers;
		dbProfile.voteTimers = voteTimers;
		dbProfile.giveTimers = giveTimers;
		dbProfile.clearTimers = clearTimers;
		dbProfile.clearedSessionID = clearedSessionID;
		-- Addon Settings
		dbProfile.usingAddon = usingAddon;
		dbProfile.testing = testing;
		dbProfile.dbug = dbug;
		
end
function FusedCouncil:sendItemBank(sendItems, sessID)
	local payload = {cmd="itemBank", ML= ML, itemBank = sendItems, sessionID = sessID, options = dbProfile.options, testing = testing};
	local serPayload = FusedCouncil:Serialize(payload);
	self:SendCommMessage(addonPrefix, serPayload, "RAID");
	self:dbug("sent itemBank sessid " .. sessID);
	local itemBankTimerCount = 0;
	-- resend items to itemBankRecivers every 4 sec untill they are removed
	itemBankTimer = self:ScheduleRepeatingTimer(function()
		itemBankTimerCount = itemBankTimerCount + 1;
		
		for i=1, #itemBankRecivers do
			-- check to see if they are online
			for k=1, GetNumGroupMembers() do
				local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
				if itemBankRecivers[i] == name and online then
					FusedCouncil:SendCommMessage(addonPrefix,serPayload, "WHISPER", itemBankRecivers[i]);
					self:dbug("resending itemBank to " .. itemBankRecivers[i] .. " " .. itemBankTimerCount);
				end
			end		
		end
		
		if itemBankTimerCount == 4 then
			self:dbug("itemBank timer timed out");
			for k in pairs (itemBankRecivers) do
				itemBankRecivers[k] = nil
			end
			itemBankTimerCount = 0;
			self:CancelTimer(itemBankTimer);
		end
	
	end, 4);
	
end
function FusedCouncil:sendGivePacket(item, player)
	local payload = {cmd="give", item=item, player = player, sessionID = sessionID};
	local serializedPayload = FusedCouncil:Serialize(payload);
	FusedCouncil:SendCommMessage(addonPrefix,serializedPayload,  "WHISPER", player);
	self:dbug("sent give cmd to " .. player);
	local tempTable = {timer = 0, count =0, item= item, sessionID = sessionID, player = player};
	
	tempTable["timer"] = self:ScheduleRepeatingTimer(function() 
			tempTable["count"] = tempTable["count"] +1;
			for k=1, GetNumGroupMembers() do
						local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
						if player == name and online then							
							FusedCouncil:SendCommMessage(addonPrefix,serializedPayload, "WHISPER", player);
						end
			end
			self:dbug("given timer count " .. tempTable["count"]);
			if tempTable["count"] == 4 then
			  self:CancelTimer(tempTable["timer"]);
			  for i=#giveTimers,1 ,-1 do
					if sessionID ~= giveTimers[i]["sessionID"] then
						self:dbug("removing timer because mismatching sess Ids");
						table.remove(giveTimers, i);
					else
						if giveTimers[i]["item"] == tempTable["item"] and giveTimers[i]["player"] == tempTable["player"]   then
							table.remove(giveTimers, i);
						end
					end
			  end
			  LibDialog:Spawn("FC_Given_Toast",item, playername);
			end
		  end, 2);
	table.insert(giveTimers, tempTable);
end
function FusedCouncil:sendACK(type, destination, sessionID, item)
	self:dbug("sent ack for " .. type .. " to " .. destination)
	local ack = {cmd="ack", type=type, sessionID=sessionID, item = item};
	local serializedAck = FusedCouncil:Serialize(ack);
	FusedCouncil:SendCommMessage(addonPrefix, serializedAck, "WHISPER", destination);
end
function FusedCouncil:sendVote(cmd, i)
	local payload = {cmd=cmd, vote = {from = UnitName("player"), to = currentItem["responses"][i]["player"]["name"], item = currentItem }, sessionID = sessionID};
	local serializedPayload = FusedCouncil:Serialize(payload);
	FusedCouncil:SendCommMessage(addonPrefix,serializedPayload, "RAID");
	
	local tempTable = {timer = 0, count =0, item= currentItem, sessionID = sessionID, sendList= self:getOptions()["lootCouncilMembers"], vote=cmd};
	
	tempTable["timer"] = self:ScheduleRepeatingTimer(function() 
			tempTable["count"] = tempTable["count"] +1;
			for i=1, #tempTable["sendList"] do
					for k=1, GetNumGroupMembers() do
						local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
						if tempTable["sendList"][i] == name and online then							
							FusedCouncil:SendCommMessage(addonPrefix,serializedPayload, "WHISPER", name);
							addon:dbug("resending vote " .. tempTable["item"] .. " to " .. name .. " " .. tempTable["count"]);
						end
					end
			end
			if tempTable["count"] == 4 then
			  self:CancelTimer(tempTable["timer"]);
			  for i=#voteTimers,1 ,-1 do
					if sessionID ~= voteTimers[i]["sessionID"] then
						addon:dbug("removing timer because mismatching sess Ids");
						table.remove(voteTimers, i);
					else
						if voteTimers[i]["item"] == tempTable["item"] and voteTimers[i]["vote"] == tempTable["vote"] then
							table.remove(voteTimers, i);
						end
					end
			  end
			  
			end
		  end, 2);
	table.insert(voteTimers, tempTable);
	

end
function FusedCouncil:sendClear()
	local payload = {cmd="clear", sessionID = sessionID};
	local serializedPayload = FusedCouncil:Serialize(payload);
	FusedCouncil:SendCommMessage(addonPrefix,serializedPayload, "RAID");
	
	local raidMembers = {};
	for k=1, GetNumGroupMembers() do
		local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
		if online then							
			table.insert(raidMembers, name);
		end
	end
	
	local tempTable = {timer = 0, count =0,  sessionID = sessionID, sendList= raidMembers};
	
	tempTable["timer"] = self:ScheduleRepeatingTimer(function() 
			tempTable["count"] = tempTable["count"] +1;
			for i=1, #tempTable["sendList"] do
					for k=1, GetNumGroupMembers() do
						local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
						if tempTable["sendList"][i] == name and online then							
							FusedCouncil:SendCommMessage(addonPrefix,serializedPayload, "WHISPER", name);
							addon:dbug("resending clear to " .. name .. " " .. tempTable["count"]);
						end
					end
			end
			if tempTable["count"] == 4 then
			  self:CancelTimer(tempTable["timer"]);
			  for i=#clearTimers,1 ,-1 do
					if sessionID ~= clearTimers[i]["sessionID"] then
						addon:dbug("removing timer because mismatching sess Ids");
						table.remove(clearTimers, i);
					else
						table.remove(clearTimers, i);
					end
			  end
			  
			end
		  end, 2);
	table.insert(clearTimers, tempTable);
end
function FusedCouncil:sort(sortFunc, isResponse)
	if currentItem then
		  local table = currentItem["responses"];
		  -- if the table is alreaded sorted isSorted will stay true
		  local isSorted = true;

		  if isResponse == nil then
			for i=1, #table-1 do
			  local j=i;
			  while j > 0 and sortFunc(table[j], table[j+1]) do
				isSorted = false;
				local temp = table[j];
				table[j] = table[j+1];
				table[j+1] = temp;
				j=j-1;
			  end
			end

		  else

			for i=1, #table-1 do
			  local j=i;
			  while j > 0 and sortFunc(table[j], table[j+1], localOptions) do
				isSorted = false;
				local temp = table[j];
				table[j] = table[j+1];
				table[j+1] = temp;
				j=j-1;
			  end
			end
		  end
		  -- if it was already sorted reverse the list
		  if isSorted then
			for i=1, #table/2 do
			  local temp = table[i];
			  table[i] = table[#table - (i-1)]
			  table[#table - (i-1)] = temp;
			end
		  end
	end

end
function FusedCouncil:update()
  -- main window stuff
	self:saveToDB();
	 if not currentItem and #itemBank > 0 then
		currentItem = itemBank[1];
	 end
  
	 if #itemBank == 0 and #clearTimers == 0 then
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
          FusedCouncil:sendVote("vote", i);
        end
      else
        FusedCouncil:sendVote("unvote",i);
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

