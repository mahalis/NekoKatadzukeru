require "points"

local grid = {} -- 2D grid of cat IDs

local GRID_SIZE = 5

local currentCat = nil

function love.load()
	math.randomseed(os.time())
	
	for i = 1, GRID_SIZE do
		local column = {}
		for j = 1, GRID_SIZE do
			column[#column + 1] = 0
		end
		grid[#grid + 1] = column
	end

	currentCat = makeCat(5, 0)
end

function love.draw()
	local w, h = love.window.getDimensions()

	local pixelScale = love.window.getPixelScale()
	love.graphics.scale(pixelScale)

	local imageScale = 1 / pixelScale

	love.graphics.translate(w / 2, h / 2)

	local catPoints = currentCat.points
	for i = 1, #catPoints do
		local point = catPoints[i]
		love.graphics.circle("fill", point.x * 40, point.y * 40, 15)
	end
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

-- cat members: points, identifier
-- TODO: appearance (color / pattern / whatever), time of last movement, etc.
function makeCat(length, identifier)
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

	return cat
end

function rotateCat(cat, direction) -- returns a new cat; direction is 1 for clockwise or -1 for counter
	local points = cat.points
	for i = 1, #points do
		points[i] = pRot(points[i], direction)
	end
	cat.points = points

	return cat
end