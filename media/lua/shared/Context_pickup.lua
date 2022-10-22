if FPHC == nil then FPHC = {} end

function FPHC.asPos(positionAtrievableObject)
    return {
        x = positionAtrievableObject:getX(),
        y = positionAtrievableObject:getY(),
        z = positionAtrievableObject:getZ(),
        sqrMagnitude = function(self)
            return self.x^2 + self.y^2 + self.z^2
        end,
        magnitude = function(self)
            return math.sqrt(self.sqrMagnitude)
        end
    }
end

function FPHC.distanceAB(posA, posB)
    return {
        x = posB.x - posA.x,
        y = posB.y - posA.y,
        z = posB.z - posB.z,
        sqrMagnitude = posA.sqrMagnitude,
        magnitude = posA.magnitude
    }
end

function FPHC.getTotalWeight(inventoryItem)
    return inventoryItem:getActualWeight() + inventoryItem:getContentsWeight()
end

function FPHC.getAllItemsIn(isoGridSquare)
    local items = {}
    local centerX, centerY, centerZ = isoGridSquare:getX(), isoGridSquare:getY(), isoGridSquare:getZ()
    local cell = getWorld():getCell()
    for x=centerX-1, centerX+1 do
        for y=centerY-1, centerY+1 do
            local itemsInSquare = cell:getGridSquare(x,y,centerZ):getWorldObjects()
            for i=0, itemsInSquare:size()-1 do
                table.insert(items, itemsInSquare:get(i))
            end
        end
    end
    return items
end

function FPHC.getFirstHeavyContainerFromWorldItem(allItems, weightThreshold)
    for _, item in ipairs(allItems) do
        local inventoryItem = item:getItem()
        if (FPHC.getTotalWeight(inventoryItem) >= weightThreshold) and (instanceof(inventoryItem, "InventoryContainer")) then
            return inventoryItem
        end
    end
end

function FPHC.ContextOptionPickupWorld(isoWorldInventoryObject, pIndex, inventoryItem)
    --prepare values
    local pObject = getSpecificPlayer(pIndex)
    local pInventory = pObject:getInventory()

    --remove from world
    isoWorldInventoryObject:getSquare():transmitRemoveItemFromSquare(isoWorldInventoryObject)
    isoWorldInventoryObject:removeFromWorld()
    isoWorldInventoryObject:removeFromSquare()
    isoWorldInventoryObject:setSquare(nil)

    inventoryItem:setWorldItem(nil)
    inventoryItem:setJobDelta(0.0)

    --add to player inventory
    pInventory:setDrawDirty(true)
    pInventory:AddItem(inventoryItem)
end

function FPHC.ContextOptionPickupInventory(inventoryContainer, pObject)
    --prepare values
    local pItemContainer = pObject:getInventory()

    --remove from world
    local wi = inventoryContainer:getWorldItem()
    wi:getSquare():transmitRemoveItemFromSquare(wi)
    wi:removeFromWorld()
    wi:removeFromSquare()
    wi:setSquare(nil)
    inventoryContainer:setWorldItem(nil)
    inventoryContainer:setJobDelta(0.0)

    --add to player inventory
    pItemContainer:setDrawDirty(true)
    pItemContainer:AddItem(inventoryContainer)
    inventoryContainer:setContainer(pItemContainer)
end

function FPHC.WorldObjectContextMenu(pIndex, iSContextMenu, isoWorldInventoryObjects, bTest)
    --just in case
    if isoWorldInventoryObjects == nil then return end

    local pObject = getSpecificPlayer(pIndex)
    local isoGridSquare = isoWorldInventoryObjects[1]:getSquare()

    --if the item isnt close enough to a character, do not show context.
    local distance = FPHC.distanceAB(FPHC.asPos(pObject), FPHC.asPos(isoGridSquare))
    if distance:sqrMagnitude() >= 1 then return end  --this '1' has to be 1^1, but thats effectively the same so leave as 1.

    local allItems = FPHC.getAllItemsIn(isoGridSquare)
    local pInventory = pObject:getInventory()
    local currentMaxItemWeight = pInventory:getCapacity() - pObject:getInventoryWeight()
    local firstHeavyItem = FPHC.getFirstHeavyContainerFromWorldItem(allItems, currentMaxItemWeight)

    if firstHeavyItem == nil then return end

    local selectOption = iSContextMenu:addOption("Force Pickup Heavy Object", firstHeavyItem:getWorldItem(), FPHC.ContextOptionPickupWorld, pIndex, firstHeavyItem)
end

function FPHC.InventoryObjectContextMenu(pIndex, iSContextMenu, itemsAsTable)
    local inventoryContainer = itemsAsTable[1]

    --if item is not a container, return
    if not instanceof(inventoryContainer, "InventoryContainer") then inventoryContainer = inventoryContainer.items[1] end
    if not instanceof(inventoryContainer, "InventoryContainer") then return end

    --if item is not on the ground, return
    if inventoryContainer:getWorldItem() == nil then return end

    --if item does not exceed player's maximum capacity, return
    local pObject = getSpecificPlayer(pIndex)
    local pInventory = pObject:getInventory()
    local currentMaxItemWeight = pInventory:getCapacity() - pObject:getInventoryWeight()
    if FPHC.getTotalWeight(inventoryContainer) < currentMaxItemWeight then return end

    local selectOption = iSContextMenu:addOption("Force Pickup Heavy Object", inventoryContainer, FPHC.ContextOptionPickupInventory, pObject)
end

Events.OnFillWorldObjectContextMenu.Add(FPHC.WorldObjectContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(FPHC.InventoryObjectContextMenu)    