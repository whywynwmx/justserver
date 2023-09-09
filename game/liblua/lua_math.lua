local skynet = require "skynet"
local lua_util = require "lua_util"
local lua_math = {}

function lua_math.distance(point1,point2)
	local disx = point1.x - point2.x
	local disy = point1.y - point2.y
	return math.sqrt(disx * disx + disy * disy)
end

--判断圆形
function lua_math.incircle(point,mid,range)
	local dis = lua_math.distance(point,mid)
	return dis <= range
end

--判断扇形待优化 TODO
function lua_math.insector(point,midp,tarp,range,theta)
	local result = lua_math.incircle(point,midp,range)
	if result == false then
		return false
	end
	local len1 = lua_math.distance(tarp,midp)
	local len2 = lua_math.distance(point,midp)
	local dx1 = point.x - midp.x
	local dy1 = point.y - midp.y
	local dx2 = tarp.x - midp.x
	local dy2 = tarp.y - midp.y
	local angle = math.acos((dx1*dx2 + dy1*dy2)/(len1*len2))
	return angle < theta*math.pi/180
end

--判断凸多边形
function lua_math.inpolygon(point,points)
	local len = table.length(points)
	if len < 3 then
		return false
	end
	local bLeft
	if (point.y - points[1].y)*(points[2].x - points[1].x) - 
		(point.x - points[1].x)*(points[2].y -points[1].y) >= 0 then
		bLeft = true
	else
		bLeft = false
	end
	
	for i = 2,#points do
		local bTemp
		local next = i + 1
		if i == #points then
			next = 1
		end
		if (point.y - points[i].y)*(points[next].x - points[i].x) - 
			(point.x - points[i].x)*(points[next].y -points[i].y) >= 0 then
			bTemp = true
		else
			bTemp = false
		end

		if bLeft ~= bTemp then
			return false
		end
	end
	return true
end

--线段和圆形相交检测
--copy from chatgpt
function lua_math.segmentCircleIntersection(x1, y1, x2, y2, cx, cy, r)
	-- 计算线段的长度和方向
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local dirx, diry = dx / len, dy / len
	
	-- 计算线段起点到圆心的向量
	local cx1, cy1 = cx - x1, cy - y1
	
	-- 计算线段起点到圆心的投影长度
	local projection = cx1 * dirx + cy1 * diry
	
	-- 如果投影长度小于0，则圆心在线段起点的左侧，直接判断圆心距离线段起点的距离是否小于半径
	if projection < 0 then
		return cx1 * cx1 + cy1 * cy1 < r * r
	end
	
	-- 如果投影长度大于线段长度，则圆心在线段终点的右侧，直接判断圆心距离线段终点的距离是否小于半径
	if projection > len then
		local cx2, cy2 = cx - x2, cy - y2
		return cx2 * cx2 + cy2 * cy2 < r * r
	end
	
	-- 如果圆心投影在线段上，则计算圆心到线段的距离
	local dist = (cx1 - projection * dirx) ^ 2 + (cy1 - projection * diry) ^ 2
	return dist < r * r
end

--判断点是否在多边形内。 	from chatgpt
function lua_math.pointInPolygon(x, y, vertices)
    -- 判断点是否在多边形内
    local n = #vertices
    local inside = false
    local j = n

    for i = 1, n do
        if ((vertices[i][2] < y and vertices[j][2] >= y) or (vertices[j][2] < y and vertices[i][2] >= y)) then
            if (vertices[i][1] + (y - vertices[i][2]) / (vertices[j][2] - vertices[i][2]) * (vertices[j][1] - vertices[i][1]) < x) then
                inside = not inside
            end
        end
        j = i
    end

    return inside
end

--判断圆形和多边形相交。 	from chatgpt
function lua_math.circlePolygonIntersect(cx, cy, r, vertices)
    -- 判断圆心是否在多边形内
    if lua_math.pointInPolygon(cx, cy, vertices) then
        return true
    end

    -- 判断圆与多边形边界是否有交点
    local n = #vertices
    for i = 1, n do
        local x1, y1 = vertices[i][1], vertices[i][2]
        local x2, y2 = vertices[i % n + 1][1], vertices[i % n + 1][2]
        if lua_math.segmentCircleIntersection(x1, y1, x2, y2, cx, cy, r) then
            return true
        end
    end

    -- 圆与多边形无交点
    return false
end

function lua_math.lineCircleIntersect(x1, y1, x2, y2, cx, cy, r)
    -- 判断线段与圆是否有交点
    local dx, dy = x2 - x1, y2 - y1
    local a = dx * dx + dy * dy
    local b = 2 * (dx * (x1 - cx) + dy * (y1 - cy))
    local c = (x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy) - r * r
    local delta = b * b - 4 * a * c
    if delta < 0 then
        return false
    end
    local t1 = (-b + math.sqrt(delta)) / (2 * a)
    local t2 = (-b - math.sqrt(delta)) / (2 * a)
    if (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1) then
        return true
    end
    return false
end

function lua_math.pointInSector(x, y, angle, startAngle, endAngle, r)
    -- 判断点是否在扇形内
    local dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
    if dist > r then
        return false
    end
    local angleDiff = angle - math.atan2(y - cy, x - cx)
    angleDiff = (angleDiff % (2 * math.pi) + 2 * math.pi) % (2 * math.pi)
    if angleDiff >= startAngle and angleDiff <= endAngle then
        return true
    end
    return false
end

-- 判断圆形和扇形是否相交
function lua_math.circleSectorIntersect(cx, cy, r, sectorCenterX, sectorCenterY, sectorRadius, sectorStartRadian, sectorEndRadian)
    -- 计算圆心到扇形中心点的距离
    local distance = math.sqrt((cx - sectorCenterX) ^ 2 + (cy - sectorCenterY) ^ 2)

    -- 如果圆心到扇形中心点的距离大于圆形半径+扇形半径，则两者不相交
    if distance > r + sectorRadius then
        return false
    end

    -- 如果圆心到扇形中心点的距离小于圆形半径，则扇形中心在圆形内
    if distance < r then
        return true
    end

    -- 计算圆心和扇形中心点的连线与扇形起始边和结束边的夹角
    local angle = math.atan2(cy - sectorCenterY, cx - sectorCenterX)
	if angle < 0 then
		angle = angle + math.pi * 2
	end

    -- 如果圆心在扇形内，或者圆心和扇形边界相交，则两者相交
    if (sectorStartRadian < sectorEndRadian and angle >= sectorStartRadian and angle <= sectorEndRadian) or
		(sectorStartRadian > sectorEndRadian and (angle >= sectorStartRadian or angle <= sectorEndRadian)) then
        return true
    else
        local bx1, by1 = sectorCenterX + sectorRadius * math.cos(sectorStartRadian), sectorCenterY + sectorRadius * math.sin(sectorStartRadian)
        local bx2, by2 = sectorCenterX + sectorRadius * math.cos(sectorEndRadian), sectorCenterY + sectorRadius * math.sin(sectorEndRadian)

        if lineCircleIntersect(bx1, by1, bx2, by2, cx, cy, r) then
            return true
        end

        return false
    end
end

-- 判断圆形和扇形是否相交
function lua_math.circleSectorIntersect(cx, cy, r, sectorCenterX, sectorCenterY, sectorTargetX, sectorTargetY, sectorRadius, sectorTheta)
	local angle = math.atan2(sectorTargetY, sectorTargetX)
	if angle < 0 then angle = angle + math.pi * 2	end

	local startAngle = angle - sectorTheta / 2
	local endAngle = angle + sectorTheta / 2
	if startAngle < 0 then startAngle = startAngle + math.pi * 2 end
	if endAngle > math.pi * 2 then endAngle = endAngle - math.pi * 2 end
end

local function mid(point1,point2)
	local dx = point2.posX - point1.posX
	local dy = point2.posY - point1.posY
	local point = {}
	point.posX = point1.posX + dx
	point.posY = point1.posY + dy
	return point
end

function lua_math.midpoint(ar)
	assert(#ar <= 3)
	if #ar == 1 then
		return ar
	end
	if #ar == 2 then
		return mid(ar[1],ar[2])
	end
	if #ar == 3 then
		return mid(mid(ar[1],ar[2]),ar[3])
	end
end

function lua_math.clamp(value, min, max)
	return math.max(math.min(value, max), min)
end

-- Dijkstra算法（迪杰斯特拉）典型的最短路径路由算法
-- beg: 出发点 (in)
-- adjmap: 邻接矩阵 (in)
-- dist: 出发点到各点的最短路径长度(out)
-- path : 路径上到达该点的前一个点
function lua_math.dijkstra(beg, adjmap)	
	local dist = {}
	local path = {}
	local flag = {}

	for id, _ in pairs(adjmap) do
		dist[id] = -1
		path[id] = -1
		flag[id] = 0
	end

	dist[beg] = 0
	while true do
		local v = -1
		for id, _ in pairs(adjmap) do
			if flag[id] == 0 and dist[id] >= 0 then -- 寻找未被处理过且
				if  v < 0 or dist[id] < dist[v] then -- 距离最小的点
					v = id
				end
			end
		end

		if v < 0 then
			return path, dist  -- 所有联通的点都被处理过
		end

		flag[v] = 1
		local adjDataV = adjmap[v]
		if not adjDataV then
			skynet.error("lua_math.dijkstra invalid data")
			return path, dist
		end

		for id, len in pairs(adjDataV) do
			if dist[id] < 0 or dist[v] + adjDataV[id] < dist[id] then -- 不满足三角不等式
				dist[id] = dist[v] + len	
				path[id] = v			
			end
		end
	end

	return path, dist
end

-- 计算从起点到终点的路径点，
-- beg 起点 (in)
-- ed 终点 (in)
-- 原始路径数据,为dijkstra的返回值path (in)
-- 是否检查循环数据, 默认不检查（in）
-- 途径路径点(包括终点, 不包括起点) (out)
function lua_math.calcPaths(beg, ed, paths, check)
	if check then
		for k, v in pairs(paths) do
			if paths[v] == k then
				skynet.error("input data has cricle point")
				return
			end
		end
	end

	local rts = {ed}
	local v = ed
	while v ~= beg do
		if paths[v] == nil then
			return
		end

		if paths[v] ~= beg then
			table.insert(rts, 1, paths[v])
		end

		v = paths[v]
	end 

	return rts
end

function lua_math.lerp(a, b, t)
	return a + (b - a) * t
end
return lua_math
