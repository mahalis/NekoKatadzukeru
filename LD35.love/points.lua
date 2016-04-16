function p(x, y)
	local point = {}
	point.x = x
	point.y = y
	return point
end

function pAdd(p1, p2) return p(p1.x + p2.x, p1.y + p2.y) end

function pSub(p1, p2) return p(p1.x - p2.x, p1.y - p2.y) end

function pRot(p1, r)
	if r == 1 then return p(-p1.y, p1.x) end
	if r == -1 then return p(p1.y, -p1.x) end
	return p1
end

function pEq(p1, p2)
	return (p1.x == p2.x and p1.y == p2.y)
end

function pDist(p1, p2)
	local dx, dy = p1.x - p2.x, p1.y - p2.y
	return math.sqrt(dx * dx + dy * dy)
end

function pStr(p1)
	if p1 == nil then
		return "NIL"
	end
	return "(" .. tostring(p1.x) .. "," .. tostring(p1.y) .. ")"
end