require "points"

local grid = {} -- 2D grid of cat IDs
local cats = {} -- list of cats by ID

local PLACEMENT_GRID_COLUMNS = 11
local PLACEMENT_GRID_ROWS = 5

local GRID_CELL_SIZE = 60
local GRID_CELL_PADDING = 1
local GRID_OFFSET_X = 85 -- 0,0 on the grid is this many points offset from the center of the screen

local grabbedCat = nil
local grabbedCatSegmentIndex = 1

local shiftingCat = nil
local shiftingCatEnd = 0

local isHighDPI = false
local catHeadImage = nil
local catBodyImage = nil
local catCornerImage = nil
local catButtImage = nil

function love.load()
	math.randomseed(os.time())
	love.graphics.setBackgroundColor(60, 100, 150, 255)
	
	for i = 1, PLACEMENT_GRID_COLUMNS do
		local column = {}
		for j = 1, PLACEMENT_GRID_ROWS do
			column[#column + 1] = makeCatGridCell(nil, 0)
		end
		grid[#grid + 1] = column
	end

	makeCat(5)
	makeCat(7)
	cats[2].gridPosition = p(-7, 2)
	placeCat(cats[1])

	isHighDPI = (love.window.getPixelScale() > 1)
	catHeadImage = loadImage("head")
	catBodyImage = loadImage("body")
	catCornerImage = loadImage("corner")
	catButtImage = loadImage("butt")
end

function loadImage(pathName) -- omit “graphics/” and “.png”
	local desiredPath = "graphics/" .. pathName .. (isHighDPI and "@2x" or "") .. ".png"

	return love.graphics.newImage(desiredPath)
end

function love.draw()
	local w, h = love.window.getDimensions()

	local pixelScale = love.window.getPixelScale()
	love.graphics.scale(pixelScale)

	local imageScale = 1 / pixelScale

	love.graphics.translate(w / 2 + GRID_OFFSET_X, h / 2)

	local gridStartX, gridStartY = -PLACEMENT_GRID_COLUMNS * GRID_CELL_SIZE / 2, -PLACEMENT_GRID_ROWS * GRID_CELL_SIZE / 2
	for i = 1, PLACEMENT_GRID_COLUMNS do
		if i ~= math.ceil(PLACEMENT_GRID_COLUMNS / 2) then
			local column = grid[i]
			for j = 1, PLACEMENT_GRID_ROWS do
				local cell = column[j]
				local cellType = cell.type
				local cellOriginX = gridStartX + (i - 1) * GRID_CELL_SIZE
				local cellOriginY = gridStartY + (j - 1) * GRID_CELL_SIZE
				if cell.id ~= 0 then
					if cellType == 0 then
						love.graphics.setColor(100, 180, 255, 180)
					elseif cellType == 1 then
						love.graphics.setColor(255, 180, 100, 180)
					else
						love.graphics.setColor(255, 255, 255, 100)
					end
					love.graphics.rectangle("fill", cellOriginX, cellOriginY, GRID_CELL_SIZE, GRID_CELL_SIZE)
				end
				love.graphics.setColor(255, 255, 255, 255)
				love.graphics.rectangle("line", cellOriginX + GRID_CELL_PADDING, cellOriginY + GRID_CELL_PADDING, GRID_CELL_SIZE - 2 * GRID_CELL_PADDING, GRID_CELL_SIZE - 2 * GRID_CELL_PADDING)
			end
		end
	end

	for i = 1, #cats do
		local cat = cats[i]
		local catPoints = cat.points
		local catPosition = cat.gridPosition
		
		local alpha = cat.isPlaced and 1 or 0.7
		love.graphics.setColor(255, 255, 255, 255 * alpha)

		for i = 1, #catPoints do
			local point = catPoints[i]
			local gridPoint = pAdd(point, catPosition)
			local centerX, centerY = gridPoint.x * GRID_CELL_SIZE, gridPoint.y * GRID_CELL_SIZE
			
			if i == 1 then
				local angle = angleForPointDirection(pSub(catPoints[i + 1], point))
				drawCenteredImage(catHeadImage, centerX, centerY, imageScale, angle)
			elseif i == #catPoints then
				local angle = angleForPointDirection(pSub(point, catPoints[i - 1]))
				drawCenteredImage(catButtImage, centerX, centerY, imageScale, angle)
			else
				local lastPoint = catPoints[i - 1]
				local nextPoint = catPoints[i + 1]
				local image, angle = nil, 0
				if math.abs(lastPoint.x) == math.abs(nextPoint.x) or math.abs(lastPoint.y) == math.abs(nextPoint.y) then
					image = catBodyImage
					angle = angleForPointDirection(pSub(nextPoint, point))
				else
					image = catCornerImage
					local lastDelta = pSub(lastPoint, point)
					local nextDelta = pSub(nextPoint, point)
					if pointPairMatches(lastDelta, nextDelta, p(0, -1), p(1, 0)) then
						angle = 0
					elseif pointPairMatches(lastDelta, nextDelta, p(1, 0), p(0, 1)) then
						angle = 0.25
					elseif pointPairMatches(lastDelta, nextDelta, p(0, 1), p(-1, 0)) then
						angle = 0.5
					else
						angle = 0.75
					end
				end
				drawCenteredImage(image, centerX, centerY, imageScale, angle)
			end
			
		end
	end

	love.graphics.setColor(255, 255, 255, 220)
	local mousePoint = mouseGridPoint()
	love.graphics.circle("fill", mousePoint.x * GRID_CELL_SIZE, mousePoint.y * GRID_CELL_SIZE, 5)
end

function pointPairMatches(p1, p2, testPoint1, testPoint2)
	return (pEq(p1, testPoint1) and pEq(p2, testPoint2)) or (pEq(p1, testPoint2) and pEq(p2, testPoint1))
end

function angleForPointDirection(direction)
	if pEq(direction, p(0, 1)) then return 0 end
	if pEq(direction, p(-1, 0)) then return 0.25 end
	if pEq(direction, p(0, -1)) then return 0.5 end
	if pEq(direction, p(1, 0)) then return 0.75 end
end

function drawCenteredImage(image, x, y, scale, angle)
	local w, h = image:getWidth(), image:getHeight()
	scale = scale or 1
	angle = angle or 0
	love.graphics.draw(image, x, y, angle * math.pi * 2, scale, scale, w / 2, h / 2)
end

function love.update(dt)
	local mousePoint = mouseGridPoint()
	if grabbedCat ~= nil then
		local grabPoint = catPositionToGridSpace(grabbedCat.points[grabbedCatSegmentIndex], grabbedCat)
		if not pEq(mousePoint, grabPoint) then
			grabbedCat.gridPosition = pAdd(grabbedCat.gridPosition, pSub(mousePoint, grabPoint))
		end
	end
	if shiftingCat ~= nil then
		local catPoints = shiftingCat.points
		local endPoint = catPositionToGridSpace(catPoints[shiftingCatEnd == 0 and 1 or #catPoints], shiftingCat)
		
		if not pEq(mousePoint, endPoint) then
			shiftCat(shiftingCat, shiftingCatEnd, mousePoint)
		end
	end
end

function love.keypressed(key)
	if key == "escape" then love.event.quit() end
	if key == " " then
		rotateGrabbedCat()
	end
end

function love.mousepressed(x, y, button)
	local gridPoint = mouseGridPoint()
	if grabbedCat == nil then
		local cat, segment = findCatAtPosition(gridPoint)
		if cat then
			if segment == 1 or segment == #cat.points then
				shiftingCat = cat
				shiftingCatEnd = (segment == 1) and 0 or 1
			else
				-- TODO: clicking on the body should only highlight the cat, should have to release to pick it up
				pickUpCatAtPosition(gridPoint)
			end
		end
	else
		if placeCat(grabbedCat) then -- TODO: feedback if you can't place the cat there
			grabbedCat = nil
		end
	end
end

function love.mousereleased(x, y, button)
	if shiftingCat then
		shiftingCat = nil
	end
end

function mouseGridPoint()
	local mouseX, mouseY = mouseScreenPosition()
	return p(round(mouseX / GRID_CELL_SIZE), round(mouseY / GRID_CELL_SIZE))
end

function mouseScreenPosition()
	local w, h = love.window.getDimensions()
	local pixelScale = love.window.getPixelScale()
	local mouseX, mouseY = love.mouse.getPosition()
	mouseX = (mouseX / pixelScale - w / 2 - GRID_OFFSET_X)
	mouseY = (mouseY / pixelScale - h / 2)
	return mouseX, mouseY
end

-- end is 0 or 1 for head or tail (2 is right out)
function shiftCat(cat, whichEnd, gridPosition)
	local points = cat.points
	local newPointInCatSpace = gridPositionToCatSpace(gridPosition, cat)
	local currentEndpoint = points[whichEnd == 0 and 1 or #points]

	local potentialPoints = neighborsOfPoint(currentEndpoint)
	local closestPotentialPoint, closestDistance = nil, nil
	for i = 1, #potentialPoints do
		local distance = pDist(potentialPoints[i], newPointInCatSpace)
		if closestDistance == nil or distance < closestDistance then
			closestPotentialPoint = potentialPoints[i]
			closestDistance = distance
		end
	end

	newPointInCatSpace = closestPotentialPoint
	gridPosition = catPositionToGridSpace(newPointInCatSpace, cat)

	if pointListContainsPoint(points, newPointInCatSpace) then return false end

	if findCatAtPosition(gridPosition) then return false end

	local isOffGrid = catIsOffGrid(cat)
	local gridCell = getGridCell(catPositionToGridSpace(newPointInCatSpace, cat))
	if (gridCell == nil) ~= isOffGrid then return false end

	if whichEnd == 0 then
		setGridCell(catPositionToGridSpace(points[#points], cat), makeEmptyCatGridCell())
		table.insert(points, 1, newPointInCatSpace)
		table.remove(points, #points)
	else
		setGridCell(catPositionToGridSpace(points[1], cat), makeEmptyCatGridCell())
		table.remove(points, 1)
		table.insert(points, newPointInCatSpace) -- append
	end

	rearrangeCat(cat)
	setGridCellsForCat(cat)

	return true
end

-- shift all points and the cat's gridPosition so the head is (0,0)
function rearrangeCat(cat)
	local points = cat.points
	local headOffset = points[1]
	for i = 1, #points do
		points[i] = pSub(points[i], headOffset)
	end
	cat.gridPosition = pAdd(cat.gridPosition, headOffset)
end

function pickUpCatAtPosition(gridPosition) -- returns bool
	local cat, index = findCatAtPosition(gridPosition)
	if cat == nil then
		print("no cat found")
		return false
	end
	local catPoints = cat.points
	if index == 1 or index == #catPoints then
		print("can't grab by the ends")
		return false
	end -- can't pick up by the ends

	for i = 1, #catPoints do
		local pointOnGrid = catPositionToGridSpace(catPoints[i], cat)
		setGridCell(pointOnGrid, makeEmptyCatGridCell())
	end
	cat.isPlaced = false
	grabbedCat = cat
	grabbedCatSegmentIndex = index

	return true
end

function findCatAtPosition(gridPosition) -- returns (cat, segment index)
	for i = #cats, 1, -1 do -- frontmost first
		local cat = cats[i]
		local pointIndex = pointListContainsPoint(cat.points, gridPositionToCatSpace(gridPosition, cat))
		if pointIndex then
			return cat, pointIndex
		end
	end
	return nil, nil
end

function placeCat(cat)
	if canPlaceCat(cat) then
		setGridCellsForCat(cat)
		cat.isPlaced = true
		return true
	elseif catIsOffGrid(cat) then
		cat.isPlaced = true
		return true
	end

	return false
end

function setGridCellsForCat(cat)
	local catPoints = cat.points
	for i = 1, #catPoints do
		local pointOnGrid = catPositionToGridSpace(catPoints[i], cat)
		local cellType = (i == 1 and 0 or (i == #catPoints and 1 or 2))
		setGridCell(pointOnGrid, makeCatGridCell(cat, cellType))
	end
end

function canPlaceCat(cat)
	local position = cat.gridPosition
	local catPoints = cat.points
	for i = 1, #catPoints do
		local catPoint = catPoints[i]
		local gridCell = getGridCell(catPositionToGridSpace(catPoint, cat))
		if gridCell == nil or gridCell.id ~= 0 then
			return false
		end
	end
	return true
end

function catIsOffGrid(cat)
	local position = cat.gridPosition
	local points = cat.points
	for i = 1, #points do
		if getGridCell(catPositionToGridSpace(points[i], cat)) ~= nil then return false end
	end
	return true
end

-- cat members: points, identifier, gridPosition, isPlaced
-- TODO: appearance (color / pattern / whatever), time of last movement, etc.
function makeCat(length) -- returns cat
	local identifier = #cats + 1
	local lastPoint = p(0, 0)
	local points = { lastPoint }
	
	for i = 1, length - 1 do
		local potentialPoints = neighborsOfPoint(lastPoint)
		if i > 1 then
			for j = 1, i - 1 do
				local existingPoint = points[j]
				for k = 1, #potentialPoints do
					if pEq(potentialPoints[k], existingPoint) then
						table.remove(potentialPoints, k)
						break
					end
				end
			end
		end
		if #potentialPoints > 0 then
			lastPoint = potentialPoints[math.random(#potentialPoints)]
			points[#points + 1] = lastPoint
		else
			break
		end
	end

	local cat = {}
	cat.points = points
	cat.identifier = identifier
	cat.isPlaced = false
	cat.gridPosition = p(0, 0)

	cats[identifier] = cat

	return cat
end

function neighborsOfPoint(point)
	local availableDirections = { p(-1, 0), p(1, 0), p(0, -1), p(0, 1) }
	local neighbors = {}
	for i = 1, 4 do
		neighbors[#neighbors + 1] = pAdd(point, availableDirections[i])
	end
	return neighbors
end

function rotateGrabbedCat()
	if grabbedCat then
		local points = grabbedCat.points
		local aboutPoint = points[grabbedCatSegmentIndex]
		for i = 1, #points do
			points[i] = pAdd(pRot(pSub(points[i], aboutPoint), 1), aboutPoint)
		end
		rearrangeCat(grabbedCat)
	end
end

function gridPositionToCatSpace(gridPosition, cat)
	local catGridPosition = cat.gridPosition
	return pSub(gridPosition, catGridPosition)
end

function catPositionToGridSpace(catPosition, cat)
	local catGridPosition = cat.gridPosition
	return pAdd(catPosition, catGridPosition)
end

-- cell members: id, type (0: head, 1: tail, 2: body)
function makeCatGridCell(cat, cellType)
	local cell = {}
	cell.id = cat ~= nil and cat.identifier or 0
	cell.type = cellType
	return cell
end

function makeEmptyCatGridCell()
	return makeCatGridCell(nil, 0)
end

function pointListContainsPoint(list, point) -- returns index or nil
	for i = 1, #list do
		if pEq(point, list[i]) then return i end
	end

	return nil
end

function setGridCell(gridPoint, gridCell)
	local storagePoint = gridStoragePointForPoint(gridPoint)
	if storagePoint then
		grid[storagePoint.x][storagePoint.y] = gridCell
		return true
	end

	return false
end

function getGridCell(gridPoint)
	if gridPoint.x ~= 0 then
		local storagePoint = gridStoragePointForPoint(gridPoint)
		if storagePoint then
			return grid[storagePoint.x][storagePoint.y]
		end
	end
	return nil
end

function gridStoragePointForPoint(gridPoint)
	local storageX = gridPoint.x + math.ceil(PLACEMENT_GRID_COLUMNS / 2)
	local storageY = gridPoint.y + math.ceil(PLACEMENT_GRID_ROWS / 2)
	if storageX < 1 or storageX > PLACEMENT_GRID_COLUMNS or storageY < 1 or storageY > PLACEMENT_GRID_ROWS then return nil end

	return p(storageX, storageY)
end

function round(x)
	return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end
