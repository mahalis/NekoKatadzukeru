require "points"

local grid = {} -- 2D grid of cat IDs
local cats = {} -- list of cats by ID
local justBoxedCats = {}

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
local catBodyStartImage = nil
local catCornerImage = nil
local catButtImage = nil
local catTailImages = {}
local backgroundSegmentImage = nil
local tubeImage = nil
local tubeTopImage = nil
local tubeBottomImage = nil
local handImageRegular = nil
local handImageGrabby = nil
local boxImage = nil
local timerIconImage = nil
local boxIconImage = nil
local lidImage = nil
local notPlayingBackgroundImage = nil

local titleImage = nil
local subtitleImage = nil
local instruction1Image = nil
local instruction2Image = nil
local beginImage = nil

local gameOverImage = nil
local completedImage = nil
local boxOfCatsImage = nil
local boxesOfCatsImage = nil
local highScoreImage = nil
local tryAgainImage = nil

local elapsedTime = 0
local lastBoxCompletedTime = nil

local score = 0
local currentTimer = nil
local thisBoxStartedTime = nil
local catSpawnedTime = nil
local gameStartedTime = nil
local gameEndedTime = nil
local lastHighScore = nil

local CAT_TUBE_APPEAR_DURATION = 0.7
local BOX_LID_DROP_DURATION = 0.6
local BOX_OUT_DURATION = 0.5
local BOX_IN_DURATION = BOX_OUT_DURATION
local BOX_TOTAL_DURATION = BOX_LID_DROP_DURATION + BOX_OUT_DURATION + BOX_IN_DURATION

local START_SCREEN_OUT_DURATION = 0.6
local END_SCREEN_IN_DURATION = 1.2
local NOT_PLAYING_SCREEN_INSET_X = 0
local NOT_PLAYING_SCREEN_INSET_Y = 50
local FINAL_SCORE_PADDING = 5

local MINIMUM_MEOW_INTERVAL = 2
local MEOW_CHANCE = 0.6

local uiFont = nil
local finalScoreFont = nil

local catSounds = {}
local tubeSound = nil
local pickSound = nil
local placeSound = nil
local shiftSound = nil
local successSound = nil
local failureSound = nil

local catShader = nil
local catColorPairs = { {{0.54, 0.58, 0.6}, {0.66, 0.69, 0.7}}, {{0.92, 0.68, 0.23}, {0.93, 0.8, 0.51}}, {{0.3, 0.29, 0.27}, {0.4, 0.38, 0.36}}, {{0.98, 0.98, 0.95}, {1, 1, 1}} }

function love.load()
	math.randomseed(os.time())
	love.graphics.setBackgroundColor(60, 100, 150, 255)

	isHighDPI = (love.window.getPixelScale() > 1)
	catHeadImage = loadImage("head")
	catBodyImage = loadImage("body")
	catBodyStartImage = loadImage("body start")
	catCornerImage = loadImage("corner")
	catButtImage = loadImage("butt")
	for i = 1, 4 do
		catTailImages[i] = loadImage("tail " .. tostring(i))
	end

	backgroundSegmentImage = loadImage("background segment")
	tubeImage = loadImage("tube")
	tubeTopImage = loadImage("tube top")
	tubeBottomImage = loadImage("tube bottom")
	handImageRegular = loadImage("hand regular")
	handImageGrabby = loadImage("hand grabby")
	boxImage = loadImage("box")
	timerIconImage = loadImage("timer")
	boxIconImage = loadImage("box icon")
	lidImage = loadImage("lid")
	notPlayingBackgroundImage = loadImage("not playing")

	titleImage = loadImage("text/title")
	subtitleImage = loadImage("text/subtitle")
	instruction1Image = loadImage("text/instruction 1")
	instruction2Image = loadImage("text/instruction 2")
	beginImage = loadImage("text/begin")

	gameOverImage = loadImage("text/game over")
	completedImage = loadImage("text/you completed")
	boxOfCatsImage = loadImage("text/box of cats")
	boxesOfCatsImage = loadImage("text/boxes of cats")
	highScoreImage = loadImage("text/high score")
	tryAgainImage = loadImage("text/again")


	backgroundMusic = love.audio.newSource("sound/background.mp3")
	backgroundMusic:setLooping(true)
	backgroundMusic:play()

	uiFont = love.graphics.newFont("font/weblysleekuisl.ttf", 36)
	finalScoreFont = love.graphics.newFont("font/weblysleekuisl.ttf", 60)

	for i = 1, 7 do
		catSounds[i] = love.audio.newSource("sound/cat " .. tostring(i) .. ".wav", "static")
	end
	shiftSound = love.audio.newSource("sound/shift.wav", "static")
	tubeSound = love.audio.newSource("sound/tube 2.wav", "static")
	placeSound = love.audio.newSource("sound/place.wav", "static")
	pickSound = love.audio.newSource("sound/pick.wav", "static")
	successSound = love.audio.newSource("sound/success.wav", "static")
	failureSound = love.audio.newSource("sound/failure.wav", "static")

	catShader = love.graphics.newShader("cat.fsh")
	love.mouse.setVisible(false)

	reset()
end

function loadImage(pathName) -- omit “graphics/” and “.png”
	local desiredPath = "graphics/" .. pathName .. (isHighDPI and "@2x" or "") .. ".png"

	return love.graphics.newImage(desiredPath)
end

function reset()
	clearGrid()
	cats = {}
	justBoxedCats = {}
	playing = false
	gameOver = false
	grabbedCat = nil
	shiftingCat = nil
	catOccupyingTube = nil

	setScore(0)
	lastBoxCompletedTime = nil
end

function setScore(newScore)
	score = newScore
	currentTimer = round(math.max(20, 42 - 2 * score) / 2) * 2
end

function clearGrid()
	grid = {}
	for i = 1, PLACEMENT_GRID_COLUMNS do
		local column = {}
		for j = 1, PLACEMENT_GRID_ROWS do
			column[#column + 1] = makeCatGridCell(nil, 0)
		end
		grid[#grid + 1] = column
	end
end

function boxGridCats()
	clearGrid()
	local offGridCats = {}
	justBoxedCats = {}
	for i = 1, #cats do
		local cat = cats[i]
		if cat.isOnGrid then
			justBoxedCats[#justBoxedCats + 1] = cat
		else
			offGridCats[#offGridCats + 1] = cat
			cat.identifier = #offGridCats
		end
	end
	cats = offGridCats

	lastBoxCompletedTime = elapsedTime
	thisBoxStartedTime = lastBoxCompletedTime + BOX_TOTAL_DURATION
	setScore(score + 1)
	successSound:rewind()
	successSound:play()
end

function start()
	playing = true
	gameStartedTime = elapsedTime
	thisBoxStartedTime = elapsedTime + CAT_TUBE_APPEAR_DURATION
end

function catSpawnProgress()
	if catOccupyingTube == nil or elapsedTime > catSpawnedTime + CAT_TUBE_APPEAR_DURATION then return 1 end
	return (elapsedTime - catSpawnedTime) / CAT_TUBE_APPEAR_DURATION
end

function endGame()
	playing = false
	gameOver = true
	gameEndedTime = elapsedTime
	grabbedCat = nil
	shiftingCat = nil
	failureSound:rewind()
	failureSound:play()
end

function love.draw()
	local w, h = love.window.getDimensions()

	local pixelScale = love.window.getPixelScale()
	love.graphics.scale(pixelScale)

	local imageScale = 1 / pixelScale
	local backgroundXOffset = math.fmod(elapsedTime * 0.5, 1)
	love.graphics.setColor(255, 255, 255, 255)
	for i = 0, 16 do
		love.graphics.draw(backgroundSegmentImage, (i - 1 + backgroundXOffset) * 60, 0, 0, imageScale)
	end
	love.graphics.push()
	love.graphics.translate(w / 2 + GRID_OFFSET_X, h / 2)

	local tubeCenterX = -GRID_CELL_SIZE * 10.5
	drawCenteredImage(tubeImage, tubeCenterX, 0, imageScale)

	local animatingBoxOut = (lastBoxCompletedTime ~= nil and elapsedTime < lastBoxCompletedTime + BOX_TOTAL_DURATION)
	local boxX = 0
	if animatingBoxOut then
		boxX = 400 * math.pow(math.max(0, math.min(1, (elapsedTime - (lastBoxCompletedTime + BOX_LID_DROP_DURATION)) / BOX_OUT_DURATION)), 2)
	end
	drawCenteredImage(boxImage, boxX, 0, imageScale)

	if animatingBoxOut then
		love.graphics.push()
		love.graphics.translate(boxX, 0)

		love.graphics.setScissor((w / 2 + GRID_OFFSET_X - GRID_CELL_SIZE * PLACEMENT_GRID_COLUMNS * 0.5 + boxX) * pixelScale, (h / 2 - GRID_CELL_SIZE * PLACEMENT_GRID_ROWS * 0.5) * pixelScale, GRID_CELL_SIZE * PLACEMENT_GRID_COLUMNS * pixelScale, GRID_CELL_SIZE * PLACEMENT_GRID_ROWS * pixelScale)
		love.graphics.setShader(catShader)
		for i = 1, #justBoxedCats do
			drawCat(justBoxedCats[i], imageScale)
		end
		love.graphics.setShader()
		love.graphics.setScissor()
		
		local lidProgress = math.pow(1 - math.max(0, math.min(1, (elapsedTime - lastBoxCompletedTime) / BOX_LID_DROP_DURATION)), 3)
		drawCenteredImage(lidImage, 0, -480 * lidProgress, imageScale)
		love.graphics.pop()

		local boxInProgress = math.pow(1 - math.max(0, math.min(1, (elapsedTime - (lastBoxCompletedTime + BOX_LID_DROP_DURATION + BOX_OUT_DURATION)) / BOX_IN_DURATION)), 4)
		drawCenteredImage(boxImage, 0, 480 * boxInProgress, imageScale)
	end

	love.graphics.setShader(catShader)
	for i = 1, #cats do
		local cat = cats[i]
		local isSpawningCat = (cat == catOccupyingTube)
		if isSpawningCat then
			love.graphics.push()
			local t = catSpawnProgress()
			love.graphics.translate(0, round(400 * math.pow(t - 1, 4)))
		end
		drawCat(cats[i], imageScale)
		if isSpawningCat then
			love.graphics.pop()
		end
	end
	love.graphics.setShader()

	love.graphics.setColor(255, 255, 255, 255)
	drawCenteredImage(tubeTopImage, tubeCenterX, -220, imageScale)
	drawCenteredImage(tubeImage, tubeCenterX, 380, imageScale)
	drawCenteredImage(tubeBottomImage, tubeCenterX, 220, imageScale)

	if playing then
		local mouseX, mouseY = mouseScreenPosition()
		drawCenteredImage((love.mouse.isDown("l") or grabbedCat or shiftingCat) and handImageGrabby or handImageRegular, mouseX, mouseY, imageScale)
	end
	love.graphics.pop()

	drawCenteredImage(boxIconImage, w - 64, 68, imageScale)
	drawText(tostring(score), w - 100, 44, true)
	local timerX, timerY = w - 240, 68
	drawCenteredImage(timerIconImage, timerX, timerY, imageScale)
	local remainingTime = math.min(currentTimer, round(currentTimer - (playing and (elapsedTime - thisBoxStartedTime) or 0)))
	drawText("0:" .. (remainingTime < 10 and "0" or "" ) .. tostring(remainingTime), w - 280, 44, true)
	love.graphics.setColor(0, 0, 0, 255)
	local timeAngle = 2 * math.pi * (remainingTime / 60)
	local timeLineRadius = 12
	timerY = timerY + 3
	local timeLineX, timeLineY = math.sin(timeAngle) * timeLineRadius, -math.cos(timeAngle) * timeLineRadius
	love.graphics.setLineWidth(3)
	love.graphics.line(timerX, timerY, timerX + timeLineX, timerY + timeLineY)
	love.graphics.setColor(255, 255, 255, 255)

	local notPlayingVisibility = 0
	if playing then
		notPlayingVisibility = 1 - math.max(0, math.min(1, (elapsedTime - gameStartedTime) / START_SCREEN_OUT_DURATION))
	else
		if gameOver then
			notPlayingVisibility = math.max(0, math.min(1, (elapsedTime - gameEndedTime) / END_SCREEN_IN_DURATION))
		else
			notPlayingVisibility = 1
		end
	end
	if notPlayingVisibility > 0 then
		local offsetY = h * math.pow(1 - notPlayingVisibility, 4)
		love.graphics.setScissor(NOT_PLAYING_SCREEN_INSET_X * pixelScale, (offsetY + NOT_PLAYING_SCREEN_INSET_Y) * pixelScale, (w - 2 * NOT_PLAYING_SCREEN_INSET_X) * pixelScale, (h - 2 * NOT_PLAYING_SCREEN_INSET_Y) * pixelScale)
		drawCenteredImage(notPlayingBackgroundImage, w / 2, h / 2, imageScale)
		love.graphics.translate(w / 2, offsetY)
		if not gameOver then
			drawCenteredImage(titleImage, 0, 130, imageScale)
			drawCenteredImage(subtitleImage, 0, 212, imageScale)
			drawCenteredImage(instruction1Image, 0, 330, imageScale)
			drawCenteredImage(instruction2Image, 0, 420, imageScale)
			drawCenteredImage(beginImage, 0, 500, imageScale)
		else
			drawCenteredImage(gameOverImage, 0, 140, imageScale)

			local scoreText = tostring(score)
			local scoreWidth = finalScoreFont:getWidth(scoreText)
			local boxesImage = score == 1 and boxOfCatsImage or boxesOfCatsImage
			local completedWidth = completedImage:getWidth() * imageScale
			local boxesWidth = boxesImage:getWidth() * imageScale
			local centeringXOffset = (completedWidth - boxesWidth) / 2

			local scoreY = 220

			love.graphics.setColor(0, 53, 115, 255)
			drawText(scoreText, centeringXOffset, scoreY, false)
			love.graphics.setColor(255, 255, 255, 255)
			local scoreTextMargin = scoreWidth / 2 + 10
			love.graphics.draw(completedImage, -scoreTextMargin - completedWidth + centeringXOffset, scoreY + 43, 0, imageScale)
			love.graphics.draw(boxesImage, scoreTextMargin + centeringXOffset, scoreY + 43, 0, imageScale)
			
			if lastHighScore and score > lastHighScore then
				drawCenteredImage(highScoreImage, 0, 340, imageScale)
			end

			drawCenteredImage(tryAgainImage, 0, 460, imageScale)
		end
		
		love.graphics.setScissor()
	end
end

function drawText(text, x, y, isUIText)
	local font = isUIText and uiFont or finalScoreFont
	love.graphics.setFont(font)
	local textWidth = font:getWidth(text)
	local textXOrigin = isUIText and textWidth or textWidth / 2
	if isUIText then
		love.graphics.setColor(0, 0, 0, 180)
		love.graphics.print(text, x, y + 2, 0, 1, 1, textXOrigin)
		love.graphics.setColor(255, 255, 255, 255)
	end
	love.graphics.print(text, x, y, 0, 1, 1, textXOrigin)
end

function drawCat(cat, imageScale)
	local catPoints = cat.points
	local catPosition = cat.gridPosition
	
	local alpha = (cat.isPlaced or canPlaceCat(cat)) and 1 or 0.7
	love.graphics.setColor(255, 255, 255, 255 * alpha)
	local colorPair = catColorPairs[cat.colorIndex]
	catShader:send("color1", colorPair[1])
	catShader:send("color2", colorPair[2])
	for i = 1, #catPoints do
		local point = catPoints[i]
		local gridPoint = pAdd(point, catPosition)
		local centerX, centerY = gridPoint.x * GRID_CELL_SIZE, gridPoint.y * GRID_CELL_SIZE
		
		-- TODO: probably need a way to package up the list of segments so’s to be able to draw shadows, selection highlights, etc., assuming I get around to those (hah!)
		if i == 1 then
			local angle = angleForPointDirection(pSub(catPoints[i + 1], point))
			drawCenteredImage(catHeadImage, centerX, centerY, imageScale, angle)
		elseif i == #catPoints then
			local direction = pSub(point, catPoints[i - 1])
			local angle = angleForPointDirection(direction)
			local tailX, tailY = centerX + direction.x * GRID_CELL_SIZE * 0.7, centerY + direction.y * GRID_CELL_SIZE * 0.7
			drawCenteredImage(catTailImages[cat.tailIndex], tailX, tailY, imageScale * 0.8, angle)
			drawCenteredImage(catButtImage, centerX, centerY, imageScale, angle)
		else
			local lastPoint = catPoints[i - 1]
			local nextPoint = catPoints[i + 1]
			local image, angle = nil, 0
			if math.abs(lastPoint.x) == math.abs(nextPoint.x) or math.abs(lastPoint.y) == math.abs(nextPoint.y) then
				image = (i == 2 and catBodyStartImage or catBodyImage)
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
	if playing and elapsedTime > thisBoxStartedTime + currentTimer then
		endGame()
		return
	end

	if playing and elapsedTime > gameStartedTime + START_SCREEN_OUT_DURATION * 0.8 and #cats == 0 then makeCat() end

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
		shiftSound:rewind()
		shiftSound:play()
	end

	--[[
	if key == "q" then
		boxGridCats()
	end
	if key == "e" then
		endGame()
	end
	]]
end

function love.mousepressed(x, y, button)
	if playing then
		local gridPoint = mouseGridPoint()
		if grabbedCat == nil and shiftingCat == nil then
			local cat, segment = findCatAtPosition(gridPoint)
			if cat then
				if (segment == 1 or segment == #cat.points) and not (cat == catOccupyingTube) then
					shiftingCat = cat
					shiftingCatEnd = (segment == 1) and 0 or 1
				else
					pickUpCatAtPosition(gridPoint)
				end
			end
		else
			if grabbedCat ~= nil and attemptToPlaceCat(grabbedCat) then
				grabbedCat = nil
			elseif shiftingCat then
				shiftingCat = nil
			end
		end
	end
end

function love.mousereleased(x, y, button)
	if not playing then
		if gameOver then
			if elapsedTime > gameEndedTime + END_SCREEN_IN_DURATION + 0.25 then
				if lastHighScore == nil or score > lastHighScore then lastHighScore = score end
				reset()
			end
		else
			start()
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

	shiftSound:rewind()
	shiftSound:play()

	maybeMeow(cat)

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
		return false
	end
	if cat == catOccupyingTube and elapsedTime < catSpawnedTime + CAT_TUBE_APPEAR_DURATION then
		return false
	end
	local catPoints = cat.points

	for i = 1, #catPoints do
		local pointOnGrid = catPositionToGridSpace(catPoints[i], cat)
		setGridCell(pointOnGrid, makeEmptyCatGridCell())
	end

	cat.isOnGrid = false
	cat.isPlaced = false
	grabbedCat = cat
	grabbedCatSegmentIndex = index

	pickSound:rewind()
	pickSound:play()

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
			boxGridCats()
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
	if catOccupyingTube == nil then
		if cat.gridPosition.x < -9 then
			catOccupyingTube = cat
		else
			makeCat()
		end
	end
	placeSound:rewind()
	placeSound:play()

	maybeMeow(cat)
end

function maybeMeow(cat)
	if math.random() < MEOW_CHANCE and elapsedTime > cat.lastMeow + MINIMUM_MEOW_INTERVAL then
		local meow = catSounds[math.random(#catSounds)]
		meow:rewind()
		meow:setPitch(1.7 + math.random() * 0.5)
		meow:play()
		cat.lastMeow = elapsedTime
	end
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
	if remainingGridSpace == 7 then maxLength = 4 end
	if remainingGridSpace == 6 then maxLength = 3 end
	if remainingGridSpace < 6 then
		minLength = math.max(minLength, remainingGridSpace)
		maxLength = minLength
	end
	return minLength, maxLength
end

-- cat members: points, identifier, gridPosition, isPlaced, isOnGrid, lastMeow, colorIndex
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
	cat.lastMeow = -MINIMUM_MEOW_INTERVAL
	cat.colorIndex = math.random(#catColorPairs)
	cat.tailIndex = math.random(#catTailImages)

	cats[identifier] = cat
	catOccupyingTube = cat
	catSpawnedTime = elapsedTime

	tubeSound:rewind()
	tubeSound:play()

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
