require "points"

local grid = {} -- 2D grid of cat IDs
local cats = {} -- list of cats by ID

local PLACEMENT_GRID_COLUMNS = 5
local PLACEMENT_GRID_ROWS = 5

local GRID_CELL_SIZE = 60
local GRID_CELL_PADDING = 1
local GRID_OFFSET_X = 265 -- 0,0 on the grid is this many points offset from the center of the screen

local grabbedCat = nil
local grabbedCatSegmentIndex = 1

local shiftingCat = nil
local shiftingCatEnd = 0

local catOccupyingTube = nil

local isHighDPI = false
local catHeadImage = nil
local catBodyImage = nil
local catCornerImage = nil
local catButtImage = nil
local backgroundSegmentImage = nil
local tubeImage = nil
local tubeTopImage = nil
local tubeBottomImage = nil
local handImageRegular = nil
local handImageGrabby = nil
local boxImage = nil

local elapsedTime = 0

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

	isHighDPI = (love.window.getPixelScale() > 1)
	catHeadImage = loadImage("head")
	catBodyImage = loadImage("body")
	catCornerImage = loadImage("corner")
	catButtImage = loadImage("butt")
	backgroundSegmentImage = loadImage("background segment")
	tubeImage = loadImage("tube")
	tubeTopImage = loadImage("tube top")
	tubeBottomImage = loadImage("tube bottom")
	handImageRegular = loadImage("hand regular")
	handImageGrabby = loadImage("hand grabby")
	boxImage = loadImage("box")

	backgroundMusic = love.audio.newSource("sound/background.mp3")
	backgroundMusic:setLooping(true)
	backgroundMusic:play()

	love.mouse.setVisible(false)
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
	local backgroundXOffset = math.fmod(elapsedTime * 0.5, 1)
	for i = 0, 16 do
		love.graphics.draw(backgroundSegmentImage, (i - 1 + backgroundXOffset) * 60, 0, 0, imageScale)
	end

	love.graphics.translate(w / 2 + GRID_OFFSET_X, h / 2)

	local tubeCenterX = -GRID_CELL_SIZE * 10.5
	drawCenteredImage(tubeImage, tubeCenterX, 0, imageScale)


	drawCenteredImage(boxImage, 0, 0, imageScale)

	for i = 1, #cats do
		local cat = cats[i]
		local catPoints = cat.points
		local catPosition = cat.gridPosition
		
		local alpha = (cat.isPlaced or canPlaceCat(cat)) and 1 or 0.7
		love.graphics.setColor(255, 255, 255, 255 * alpha)

		for i = 1, #catPoints do
			local point = catPoints[i]
			local gridPoint = pAdd(point, catPosition)
			local centerX, centerY = gridPoint.x * GRID_CELL_SIZE, gridPoint.y * GRID_CELL_SIZE
			
			-- TODO: probably need a way to package up the list of segments so’s to be able to draw shadows, selection highlights, etc., assuming I get around to those (hah!)
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

	love.graphics.setColor(255, 255, 255, 255)
	drawCenteredImage(tubeTopImage, tubeCenterX, -220, imageScale)
	drawCenteredImage(tubeBottomImage, tubeCenterX, 220, imageScale)

	local mouseX, mouseY = mouseScreenPosition()
	drawCenteredImage((love.mouse.isDown("l") or grabbedCat or shiftingCat) and handImageGrabby or handImageRegular, mouseX, mouseY, imageScale)
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
	elapsedTime = elapsedTime + dt
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
	if catOccupyingTube == nil then
		makeCat() -- TODO: delay, animation, etc.
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
	if grabbedCat == nil and shiftingCat == nil then
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
		if grabbedCat ~= nil and attemptToPlaceCat(grabbedCat) then -- TODO: feedback if you can't place the cat there
			grabbedCat = nil
		elseif shiftingCat then
			shiftingCat = nil
		end
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

	local isOffGrid = isValidOffGridPoint(gridPosition)
	local gridCell = getGridCell(gridPosition)
	if not (isOffGrid or gridCell) then return false end

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

	cat.isOnGrid = false
	cat.isPlaced = false
	grabbedCat = cat
	grabbedCatSegmentIndex = index

	return true
end

function getRemainingGridSpace()
	local remainingGridSpace = PLACEMENT_GRID_COLUMNS * PLACEMENT_GRID_ROWS
	for i = 1, #cats do
		local cat = cats[i]
		if cat.isOnGrid then remainingGridSpace = remainingGridSpace - #(cat.points) end
	end
	return math.max(0, remainingGridSpace)
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

function attemptToPlaceCat(cat)
	if canPlaceCatOnGrid(cat) then
		setGridCellsForCat(cat)
		cat.isOnGrid = true
		finishCatPlacement(cat)
		
		if getRemainingGridSpace() == 0 then
			-- TODO: trigger next box
		end
	
		return true
	elseif catIsInValidOffGridPosition(cat) then
		finishCatPlacement(cat)
		return true
	end

	return false
end

function finishCatPlacement(cat)
	cat.isPlaced = true
	if cat == catOccupyingTube and cat.gridPosition.x > -10 then catOccupyingTube = nil end
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
	return canPlaceCatOnGrid(cat) or catIsInValidOffGridPosition(cat)
end

function canPlaceCatOnGrid(cat)
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

function isValidOffGridPoint(gridPoint)
	if gridPoint.x > -4 or gridPoint.x == -9 or gridPoint.x == -12 then return false end
	if (gridPoint.x == -10 or gridPoint.x == -11) and (gridPoint.y > 3 or gridPoint.y < -3) then return false end
	return true
end

function catIsInValidOffGridPosition(cat)
	local points = cat.points
	for i = 1, #points do
		local gridPosition = catPositionToGridSpace(points[i], cat)
		-- TODO: check other cats, can't overlap them
		if not isValidOffGridPoint(gridPosition) then return false end
	end
	return true
end

function getNextCatLengthConstraint()
	local remainingGridSpace = getRemainingGridSpace()
	local minLength, maxLength = 3, 7
	if remainingGridSpace == 6 then maxLength = 3 end
	if remainingGridSpace < 5 then maxLength = math.max(minLength, remainingGridSpace) end
	return minLength, maxLength
end

-- cat members: points, identifier, gridPosition, isPlaced, isOnGrid
-- TODO: appearance (color / pattern / whatever), time of last movement, etc.
function makeCat() -- returns cat
	local minLength, maxLength = getNextCatLengthConstraint()
	local length = math.random(minLength, maxLength)
	local identifier = #cats + 1
	local lastPoint = p(0, 0)
	local points = { lastPoint }
	local hasGoneLeft, hasGoneRight = false, false
	local xExtent = 0
	local minY, maxY = 0, 0
	for i = 1, length - 1 do
		local potentialPoints = neighborsOfPoint(lastPoint, hasGoneLeft, hasGoneRight)
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
			local newPoint = potentialPoints[math.random(#potentialPoints)]
			if newPoint.x < lastPoint.x then hasGoneLeft = true end
			if newPoint.x > lastPoint.x then hasGoneRight = true end
			if math.abs(newPoint.x) > 0 then xExtent = newPoint.x end
			if newPoint.y > maxY then maxY = newPoint.y end
			if newPoint.y < minY then minY = newPoint.y end
			points[#points + 1] = newPoint
			lastPoint = newPoint
		else
			break
		end
	end

	local cat = {}
	cat.points = points
	cat.identifier = identifier
	cat.isPlaced = true
	cat.gridPosition = p(xExtent > 0 and -11 or -10, 0)
	cat.isOnGrid = false

	cats[identifier] = cat
	catOccupyingTube = cat

	return cat
end

function neighborsOfPoint(point, excludeLeft, excludeRight)
	local availableDirections = { p(0, -1), p(0, 1) }
	
	if not excludeRight then
		table.insert(availableDirections, p(1, 0))
	end
	if not excludeLeft then
		table.insert(availableDirections, p(-1, 0))
	end

	local neighbors = {}
	for i = 1, #availableDirections do
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
	local storagePoint = gridStoragePointForPoint(gridPoint)
	if storagePoint then
		return grid[storagePoint.x][storagePoint.y]
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
