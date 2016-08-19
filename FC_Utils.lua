FC_Utils ={
  nameCompare = function(response1, response2)
    return response1["player"]["name"] > response2["player"]["name"];

  end;

  ilvlCompare = function(response1, response2)
    return response1["player"]["ilvl"] > response2["player"]["ilvl"];
  end;

  scoreCompare = function(response1, response2)
    return response1["player"]["score"] > response2["player"]["score"];
  end;

  itemCompare = function(response1, response2)
    local response1ilvl;
    local response2ilvl;
    if #response1["currentItems"] > 1 then
      local itemlvl1 = select(4,GetItemInfo(response1["currentItems"][1]));
      local itemlvl2 = select(4,GetItemInfo(response1["currentItems"][2]));
      if itemlvl1 == nil or itemlvl2 == nil then
        response1ilvl = 0;
      else
        response1ilvl = itemlvl1 /itemlvl2;
      end

    else
      response1ilvl = select(4,GetItemInfo(response1["currentItems"][1])) or  0;
    end

    if #response2["currentItems"] > 1 then
      local itemlvl1 = select(4,GetItemInfo(response1["currentItems"][1]));
      local itemlvl2 = select(4,GetItemInfo(response1["currentItems"][2]));
      if itemlvl1 == nil or itemlvl2 == nil then
        response2ilvl = 0;
      else
        response2ilvl = itemlvl1 /itemlvl2;
      end

    else
      response2ilvl = select(4,GetItemInfo(response1["currentItems"][1])) or  0;
    end

    return response1ilvl > response2ilvl;

  end;

  rankCompare = function(response1, response2)
    -- possible break, api function returns nil if target is in loading screen
    local playerRank1 = select(3, GetGuildInfo(response1["player"]["name"]));
    local playerRank2 = select(3, GetGuildInfo(response2["player"]["name"]));
    -- GM is rank 0 lowest rank should be highest num
    print(playerRank1.. " " ..playerRank2)
    return playerRank1 < playerRank2;

  end;

  responseCompare = function(response1, response2, options)
    -- prob need to do options here?
    local index1 = options.numOfResponseButtons;
    local index2 = options.numOfResponseButtons;
    for i=1, options.numOfResponseButtons do
      if response1["response"] == options.responseButtonNames[i] then
        index1 = i;
      end
      if response2["response"] == options.responseButtonNames[i] then
        index2 = i;
      end
    end
    return index1 < index2;
  end;

  noteCompare = function(response1, response2)
    return response1["note"] ~= "" and response2["note"] == "";
  end;

  votesCompare = function(response1,response2)
    return #response1["votes"] > #response2["votes"];
  end;

  tableContains = function(table,element)
    local flag  = false;
    for i=1, #table do
      if table[i] == element then
        flag = true;
      end
    end
    return flag;
  end;

};