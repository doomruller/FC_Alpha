local addon = LibStub("AceAddon-3.0"):GetAddon("FusedCouncilAlpha");
local lootPopup = addon:NewModule("FC_LootPopup", "AceTimer-3.0", "AceComm-3.0", "AceSerializer-3.0");

local lootPopupFrame;
local popupItems;
local responseTimers;
local db;


function lootPopup:OnEnable()
	lootPopupFrame = lootPopup:createLootPopupFrame();
	responseTimers = {};
	popupItems = {};
	db = addon:getDBProfile();
	if db.popupSaved then
		self:addPopupItems(db.popupItemBank);
	end
end

function lootPopup:OnDisable()


end

function lootPopup:addPopupItems(itemBank)
	for i=1, #itemBank do
		table.insert(popupItems, itemBank[i]);
	end
	lootPopup:update();
end

function lootPopup:update()
	if #popupItems > 0 then
		lootPopupFrame:Show();
		self:saveToDB();
		for i=1, 5 do
			getglobal("FC_Popup" .. i):Hide();
			getglobal("FC_Popup" .. i.. "NoteBox"):SetText("");
			getglobal("FC_Popup" .. i .. "IconFrame" .."ItemCountText"):SetText("");
		end
		if #popupItems <= 5 then
			  for i=1, #popupItems do
				lootPopup:populatePopup(i, popupItems[i]);
			  end
			else
			  for i=1, 5 do
				lootPopup:populatePopup(i, popupItems[i]);
			  end
			end
	else
		lootPopupFrame:Hide();
		self:clear();
	end

end

function lootPopup:saveToDB()
	db.popupItemBank = popupItems;
	db.popupSaved = true;
end

function lootPopup:clear()
	responseTimers = {};
	popupItems = {};
	db.popupSaved = false;
end

function lootPopup:populatePopup(index, item)
	getglobal("FC_Popup" .. index):Show();
	getglobal("FC_Popup" .. index.. "ItemLabel"):SetText(item["itemLink"]);
	getglobal("FC_Popup" .. index.. "IlvlLabel"):SetText("ilvl: " .. item["itemLevel"]);
	local loc = _G[item["itemEquipLoc"]] or "";
 	getglobal("FC_Popup" .. index.. "ItemTypeLabel"):SetText(item["itemSubType"] .. " " .. loc );
 	getglobal("FC_Popup" .. index .. "IconFrame" .."Texture"):SetTexture(item["itemTexture"]);
	getglobal("FC_Popup" .. index .. "IconFrame" .."ItemCountText"):SetText(item["count"]);
 	local frame = getglobal("FC_Popup" .. index .. "IconFrame");
	frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(item["itemLink"]);
		GameTooltip:Show()
	end);
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end);
	
	local options = addon:getOptions();
	local popupFrame = getglobal("FC_Popup" .. index);
	for i=1, options["numOfResponseButtons"]do
		local button = popupFrame.buttons[i];
		button:Show();
		button:SetText(options["responseButtonNames"][i]);
		button:SetScript("OnClick", function() 
			table.remove(popupItems, index);
			for k=1, 7 do
			  popupFrame.buttons[k]:Hide();
			end
			popupFrame:Hide();
			
			
			local response = lootPopup:createResponse(item, button:GetText(), getglobal("FC_Popup" .. index .. "NoteBox"):GetText());
			
			lootPopup:sendResponse(response);
			lootPopup:update();
		end);
		
		
	end
end

function lootPopup:reciveResponseACK(payload, sender)
	for i=#responseTimers, 1, -1 do
		if payload["item"] == responseTimers[i]["item"] and payload["sessionID"] == responseTimers[i]["sessionID"] then
			for k=#responseTimers[i]["sendList"], 1, -1 do
				if responseTimers[i]["sendList"][k] == sender then
					self:CancelTimer(responseTimers[i]["timer"]);
					table.remove(responseTimers[i]["sendList"], k);
				end				
			end
		end
	end

end

function lootPopup:sendResponse(response)
	local payload = {cmd="response", response= response, sessionID = addon:getSessionID()};
	local serializedPayload = lootPopup:Serialize(payload);
	lootPopup:SendCommMessage(addon:getPrefix(),serializedPayload, "RAID");
	
	local tempTable = {timer = 0, count =0, item= response["itemLink"], sessionID = addon:getSessionID(), sendList= addon:getOptions()["lootCouncilMembers"]};
	
	tempTable["timer"] = self:ScheduleRepeatingTimer(function() 
			tempTable["count"] = tempTable["count"] +1;
			for i=1, #tempTable["sendList"] do
					for k=1, GetNumGroupMembers() do
						local name, _, _,_,_,_,_,online = GetRaidRosterInfo(k);
						if tempTable["sendList"][i] == name and online then							
							lootPopup:SendCommMessage(addon:getPrefix(),serializedPayload, "WHISPER", name);
							addon:dbug("resending response " .. tempTable["item"] .. " to " .. name .. " " .. tempTable["count"]);
						end
					end
			end
			if tempTable["count"] == 4 then
			  self:CancelTimer(tempTable["timer"]);
			  for i=#responseTimers,1 ,-1 do
					if addon:getSessionID() ~= responseTimers[i]["sessionID"] then
						addon:dbug("removing timer because mismatching sess Ids");
						table.remove(responseTimers, i);
					else
						if responseTimers[i]["item"] == tempTable["item"] then
							table.remove(responseTimers, i);
						end
					end
			  end
			  
			end
		  
		  
		  
		  end, 2);
	table.insert(responseTimers, tempTable);
end


function lootPopup:createResponse(item, response, note)
	local response ={
          type="response",
          itemLink = item["itemLink"],
          player = {type="player",
            name = UnitName("player"),
            ilvl = math.floor(select(2, GetAverageItemLevel())+0.5),
            score = 0,
            guildRank = select(2, GetGuildInfo("player")) or "No Guild",
            class = select(2, UnitClass("player"))
          },
          response = response,
          note = note,
		  sessionID = addon:getSessionID(),
          currentItems = lootPopup:getPlayersCurrentItem(item),
          votes ={}, 
		  
    };
	return response;
end

local INVTYPE_Slots = {
  INVTYPE_HEAD        = "HeadSlot",
  INVTYPE_NECK        = "NeckSlot",
  INVTYPE_SHOULDER      = "ShoulderSlot",
  INVTYPE_CLOAK       = "BackSlot",
  INVTYPE_CHEST       = "ChestSlot",
  INVTYPE_WRIST       = "WristSlot",
  INVTYPE_HAND        = "HandsSlot",
  INVTYPE_WAIST       = "WaistSlot",
  INVTYPE_LEGS        = "LegsSlot",
  INVTYPE_FEET        = "FeetSlot",
  INVTYPE_SHIELD        = "SecondaryHandSlot",
  INVTYPE_ROBE        = "ChestSlot",
  INVTYPE_2HWEAPON      = {"MainHandSlot","SecondaryHandSlot"},
  INVTYPE_WEAPONMAINHAND  = "MainHandSlot",
  INVTYPE_WEAPONOFFHAND = {"SecondaryHandSlot",["or"] = "MainHandSlot"},
  INVTYPE_WEAPON        = {"MainHandSlot","SecondaryHandSlot"},
  INVTYPE_THROWN        = {"SecondaryHandSlot", ["or"] = "MainHandSlot"},
  INVTYPE_RANGED        = {"SecondaryHandSlot", ["or"] = "MainHandSlot"},
  INVTYPE_RANGEDRIGHT   = {"SecondaryHandSlot", ["or"] = "MainHandSlot"},
  INVTYPE_FINGER        = {"Finger0Slot","Finger1Slot"},
  INVTYPE_HOLDABLE      = {"SecondaryHandSlot", ["or"] = "MainHandSlot"},
  INVTYPE_TRINKET       = {"TRINKET0SLOT", "TRINKET1SLOT"}
}


function lootPopup:getPlayersCurrentItem(item)
  local itemTable = {};
  local itemLink1, itemLink2;
  local slot = INVTYPE_Slots[item["itemEquipLoc"]];
  if not slot then
    return nil;
  end
  itemLink1 = GetInventoryItemLink("player", GetInventorySlotInfo(slot[1] or slot));

  if not itemLink1 and slot["or"] then
    itemLink1 = GetInventoryItemLink("player", GetInventorySlotInfo(slot['or']));
  end

  if slot[2] then
    itemLink2 = GetInventoryItemLink("player", GetInventorySlotInfo(slot[2]));
  end

  local item1 = addon:createItem(itemLink1);  
  table.insert(itemTable, item1 );
  
  if itemLink2 then
    local item2 = addon:createItem(itemLink2);
    table.insert(itemTable, item2 );
  end

  return itemTable;
end

function lootPopup:createLootPopupFrame()
	local tempMain = CreateFrame("Frame", nil, UIParent, "FC_LootPopupFrame");
	
	local tempFrame = CreateFrame("Frame", "FC_Popup1", tempMain, "FC_ResponseFrame");
	tempFrame:SetPoint("Topleft");
	tempFrame.buttons = {};
	for i=1, 7 do
		local button = CreateFrame("Button", nil, tempFrame, "UIPanelButtonTemplate");
		button:Hide();
		button:SetPoint("bottomleft", 70 + (95 * (i -1)), 35);
		button:SetSize(80, 25);
		table.insert(tempFrame.buttons, button);	
	end
	
	for i=2, 5 do
		tempFrame = CreateFrame("Frame", "FC_Popup" .. i, tempMain, "FC_ResponseFrame");
		tempFrame:SetPoint("Top","FC_Popup" .. (i-1), "Bottom");
		tempFrame.buttons = {};
		for k=1, 7 do
		  local button = CreateFrame("Button", nil, tempFrame, "UIPanelButtonTemplate");
		  button:Hide();
		  button:SetPoint("bottomleft", 70 + (95 * (k-1)), 35);
		  button:SetSize(80,25);
		  table.insert(tempFrame.buttons, button);
		end
	end
	return tempMain;

end