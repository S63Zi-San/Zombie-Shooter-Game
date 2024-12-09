local Movement = {}

function Movement:new()
    local movement = {
        speed = 180,
        dashSpeed = 500,
        isDashing = false,
        dashDuration = 0.2,
        dashTimer = 0,
        dashCooldown = 0.5,
        dashCooldownTimer = 0,
        trail = {},
        maxTrailPoints = 5,
        trailUpdateTime = 0.02,
        trailTimer = 0
    }
    self.__index = self
    return setmetatable(movement, self)
end

function Movement:loadAnimations(sprites)
    -- سيتم استخدامها لاحقاً عند إضافة الرسوم المتحركة
end

function Movement:updateTrail(dt, player)
    self.trailTimer = self.trailTimer + dt
    if self.trailTimer >= self.trailUpdateTime then
        self.trailTimer = 0
        
        -- إضافة نقطة جديدة للأثر
        table.insert(self.trail, {
            x = player.x,
            y = player.y,
            alpha = 1.0
        })
        
        -- إزالة النقاط القديمة
        if #self.trail > self.maxTrailPoints then
            table.remove(self.trail, 1)
        end
        
        -- تحديث شفافية النقاط
        for i, point in ipairs(self.trail) do
            point.alpha = point.alpha * 0.8
        end
    end
end

function Movement:update(dt, player)
    -- تحديث مؤقت تبريد الاندفاع
    if self.dashCooldownTimer > 0 then
        self.dashCooldownTimer = self.dashCooldownTimer - dt
    end

    -- تحقق من إمكانية الاندفاع
    if love.keyboard.isDown('lshift') and not self.isDashing and self.dashCooldownTimer <= 0 then
        self.isDashing = true
        self.dashTimer = self.dashDuration
        self.dashCooldownTimer = self.dashCooldown
        self.trail = {}
    end

    -- تحديث الاندفاع
    if self.isDashing then
        -- تحديث الأثر
        self:updateTrail(dt, player)
        
        -- تحديث مؤقت الاندفاع
        self.dashTimer = self.dashTimer - dt
        if self.dashTimer <= 0 then
            self.isDashing = false
            self.trail = {}
        end
        
        return self.dashSpeed
    end

    -- الحركة الأساسية
    local moveX, moveY = 0, 0
    if love.keyboard.isDown('w') then
        moveY = -1
    end
    if love.keyboard.isDown('s') then
        moveY = 1
    end
    if love.keyboard.isDown('a') then
        moveX = -1
        self.lastDirection = -1
    end
    if love.keyboard.isDown('d') then
        moveX = 1
        self.lastDirection = 1
    end

    -- تطبيع الحركة القطرية
    if moveX ~= 0 and moveY ~= 0 then
        local length = math.sqrt(moveX^2 + moveY^2)
        moveX = moveX / length
        moveY = moveY / length
    end

    -- تطبيق السرعة المناسبة
    player.x = player.x + moveX * self.speed * dt
    player.y = player.y + moveY * self.speed * dt

    return self.speed
end

function Movement:getCurrentFrame()
    return 1
end

function Movement:getDirection()
    return self.lastDirection
end

return Movement

