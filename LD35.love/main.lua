require "points"

local grid = {} -- 2D grid of cat IDs
local cats = {} -- list of cats by ID

local PLACEMENT_GRID_COLUMNS = 7
local PLACEMENT_GRID_ROWS = 7

local GRID_CELL_SIZE = 40
local GRID_CELL_PADDING = 1

local grabbedCat = nil
local grabbedCatSegmentIndex = 1

function love.load()
	math.randomseed(os.time())
	
	for i = 1, PLACEMENT_GRID_COLUMNS do
		local column = {}
		for j = 1, PLACEMENT_GRID_ROWS do
			column[#column + 1] = makeCatGridCell(0, 0)
		end
		grid[#grid + 1] = column
	end

	makeCat(5)
	placeCatAtPosition(cats[1], p(0, 0))
end

function love.draw()
	local w, h = love.window.getDimensions()

	local pixelScale = love.window.getPixelScale()
	love.graphics.scale(pixelScale)

	local imageScale = 1 / pixelScale

	love.graphics.translate(w / 2, h / 2)

	local gridStartX, gridStartY = -PLACEMENT_GRID_COLUMNS * GRID_CELL_SIZE / 2, -PLACEMENT_GRID_ROWS * GRID_CELL_SIZE / 2
	for i = 1, PLACEMENT_GRID_COLUMNS do
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

	local catPoints = cats[1].points
	for i = 1, #catPoints do
		local point = catPoints[i]
		if i == 1 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(255, 255, 255, 150)
		end
		love.graphics.circle("fill", point.x * 40, point.y * 40, GRID_CELL_SIZE * 0.45)
	end

	local mousePoint = mouseGridPoint()
	love.graphics.circle("line", mousePoint.x * GRID_CELL_SIZE, mousePoint.y * GRID_CELL_SIZE, GRID_CELL_SIZE / 2)
end

function love.update(dt)

end

function love.keypressed(key)
	if key == "escape" then love.event.quit() end
	if key == "left" then
		currentCat = rotateCat(currentCat, -1)
	end
	if key == "right" then
		currentCat = rotateCat(currentCat, 1)
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
	mouseX = (mouseX / pixelScale - w / 2)
	mouseY = (mouseY / pixelScale - h / 2)
	return mouseX, mouseY
end

-- end is 0 or 1 for head or tail (2 is right out); newPosition must be a position on the grid adjacent to the specified end
function shiftCat(cat, whichEnd, newPosition)
	local points = cat.points
	local newPointInCatSpace = gridPositionToCatSpace(newPosition, cat)
	if pointListContainsPoint(points, newPointInCatSpace) then return false end
	local currentEndpoint = points[whichEnd == 0 and 1 or #points]
	local dx, dy = math.abs(newPointInCatSpace.x - currentEndpoint.x), math.abs(newPointInCatSpace.y - currentEndpoint.y)
	if dx > 1 or dy > 1 or dx + dy > 1 then return false end

	-- TODO: if the cat is on the grid (grid, grid, grid, grid…), update the relevant points to contain the new end and not-contain the former other end
	if whichEnd == 0 then
		table.insert(points, 1, newPointInCatSpace)
		table.remove(points, #points)
	else
		table.remove(points, 1)
		table.insert(points, newPointInCatSpace) -- append
	end

	-- rearrange things so the head is 0,0 in cat space
	local headOffset = points[1]
	for i = 1, #points do
		points[i] = pSub(points[i], headOffset)
	end
	cat.gridPosition = pAdd(cat.gridPosition, headOffset)

	return true
end

function pickUpCatAtPosition(catPosition)
	local identifier = grid[catPosition.x][catPosition.y].id
	if identifier == 0 then return 0 end
	local cat = cats[identifier]
	local catPoints = cat.points
	for i = 1, #catPoints do
		local catPoint = catPoints[i]
		local pointOnGrid = pAdd(catPosition, catPoint)
		setGridCell(pointOnGrid, makeCatGridCell(0, 0))
	end
	cat.isPlaced = false

	return identifier
end

function placeCatAtPosition(cat, position)
	if not canPlaceCatAtPosition(cat, position) then return false end

	local catPoints = cat.points
	for i = 1, #catPoints do
		local catPoint = catPoints[i]
		local pointOnGrid = pAdd(position, catPoint)
		local cellType = (i == 1 and 0 or (i == #catPoints and 1 or 2))
		setGridCell(pointOnGrid, makeCatGridCell(identifier, cellType))
	end
	cat.gridPosition = position
	cat.isPlaced = true

	return true
end

function canPlaceCatAtPosition(cat, position)
	local catPoints = cat.points
	for i = 1, #catPoints do
		local catPoint = catPoints[i]
		local pointOnGrid = pAdd(position, catPoint)
		local gridCell = getGridCell(pointOnGrid)
		if gridCell == nil or gridCell.id ~= 0 then
			return false
		end
	end
	return true
end

-- cat members: points, identifier, gridPosition, isPlaced
-- TODO: appearance (color / pattern / whatever), time of last movement, etc.
function makeCat(length)
	local identifier = #cats + 1
	local lastPoint = p(0, 0)
	local points = { lastPoint }
	
	local availableDirections = { p(-1, 0), p(1, 0), p(0, -1), p(0, 1) }

	for i = 1, length do
		local potentialPoints = {}
		for potentialIndex = 1, 4 do
			potentialPoints[#potentialPoints + 1] = pAdd(lastPoint, availableDirections[potentialIndex])
		end
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

function rotateCat(cat, direction) -- direction is 1 for clockwise or -1 for counter
	local points = cat.points
	for i = 1, #points do
		points[i] = pRot(points[i], direction)
	end
	cat.points = points
end

function gridPositionToCatSpace(gridPosition, cat)
	local catGridPosition = cat.gridPosition
	return pSub(gridPosition, catGridPosition)
end

function catPositionToGridSpace(catPosition, cat)
	local catGridPosition = cat.gridPosition
	return pAdd(catPosition, catGridPosition)
end

-- cell members: id, type
function makeCatGridCell(identifier, cellType) -- 0: head, 1: tail, 2: body
	local cell = {}
	cell.id = identifier
	cell.type = cellType
	return cell
end

function pointListContainsPoint(list, point)
	for i = 1, #list do
		if pEq(point, list[i]) then return true end
	end

	return false
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
