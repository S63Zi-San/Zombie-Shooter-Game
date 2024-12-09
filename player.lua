local Movement = require('movement')

local Player = {}

function Player:new(sprites, camera, mapWidth, mapHeight)
    local player = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 2,
        speed = 180,
        sprites = sprites.player,  -- مجموعة الصور
        radius = 20,
        scale = 0.9,
        camera = camera,
        -- حدود الخريطة
        mapWidth = mapWidth or 2000,
        mapHeight = mapHeight or 2000,
        -- نظام الذخيرة
        currentAmmo = 30,
        maxAmmo = 30,
        reloadTime = 2,
        reloadTimer = 0,
        isReloading = false,
        shootTimer = 0,
        shootDelay = 0.2,
        -- نظام الحركة
        movement = Movement:new(),
        -- نظام الرسوم المتحركة
        rotation = 0,
        isMoving = false,
        isShooting = false,
        currentState = "idle",
        animTimer = 0,
        animFrame = 1,
        -- إضافة متغير التصحيح
        debug = true
    }
    
    self.__index = self
    return setmetatable(player, self)
end

function Player:updateAnimation(dt)
    self.animTimer = self.animTimer + dt

    if self.isShooting then
        -- تحديث إطار إطلاق النار
        if self.animTimer >= 0.1 then  -- سرعة حركة إطلاق النار
            self.animFrame = self.animFrame % #self.sprites.shoot + 1
            self.animTimer = 0
        end
        self.currentState = "shoot"
    elseif self.isMoving then
        -- تحديث إطار المشي
        if self.animTimer >= 0.2 then  -- سرعة حركة المشي
            self.animFrame = self.animFrame % #self.sprites.walk + 1
            self.animTimer = 0
        end
        self.currentState = "walk"
    else
        -- العودة لوضع الوقوف
        self.currentState = "idle"
        self.animFrame = 1
        self.animTimer = 0
    end
end

function Player:getCurrentSprite()
    if self.currentState == "shoot" and self.sprites.shoot then
        return self.sprites.shoot[self.animFrame] or self.sprites.idle
    elseif self.currentState == "walk" and self.sprites.walk then
        return self.sprites.walk[self.animFrame] or self.sprites.idle
    else
        return self.sprites.idle
    end
end

function Player:update(dt)
    -- تحديث نظام الحركة
    local moveX, moveY = 0, 0
    self.isMoving = false
    
    if love.keyboard.isDown('w') then
        moveY = -1
        self.isMoving = true
    end
    if love.keyboard.isDown('s') then
        moveY = 1
        self.isMoving = true
    end
    if love.keyboard.isDown('a') then
        moveX = -1
        self.isMoving = true
    end
    if love.keyboard.isDown('d') then
        moveX = 1
        self.isMoving = true
    end

    -- تحديث حالة إطلاق النار
    self.isShooting = love.mouse.isDown(1)

    -- تطبيع الحركة القطرية
    if moveX ~= 0 and moveY ~= 0 then
        local length = math.sqrt(moveX^2 + moveY^2)
        moveX = moveX / length
        moveY = moveY / length
    end

    -- حساب الموقع الجديد
    local newX = self.x + moveX * self.speed * dt
    local newY = self.y + moveY * self.speed * dt

    -- حجم اللاعب (نصف العرض والارتفاع)
    local playerWidth = 25
    local playerHeight = 25

    -- تحديث الموقع فقط إذا كان ضمن حدود الخلفية
    if newX >= playerWidth and newX <= self.mapWidth - playerWidth then
        self.x = newX
    end
    if newY >= playerHeight and newY <= self.mapHeight - playerHeight then
        self.y = newY
    end

    -- تحديث زاوية الدوران باتجاه الماوس
    local mouseX, mouseY = love.mouse.getPosition()
    local worldMouseX = mouseX + self.camera.x
    local worldMouseY = mouseY + self.camera.y
    self.rotation = math.atan2(worldMouseY - self.y, worldMouseX - self.x)

    -- تحديث الرسوم المتحركة
    self:updateAnimation(dt)

    -- تحديث مؤقت إطلاق النار
    if self.shootTimer > 0 then
        self.shootTimer = self.shootTimer - dt
    end

    -- تحديث مؤقت إعادة التحميل
    if self.isReloading then
        self.reloadTimer = self.reloadTimer - dt
        if self.reloadTimer <= 0 then
            self.currentAmmo = self.maxAmmo
            self.isReloading = false
        end
    end
end

function Player:draw()
    love.graphics.setColor(1, 1, 1, 1)
    
    -- الحصول على الصورة الحالية
    local currentSprite = self:getCurrentSprite()
    
    -- التأكد من وجود الصورة قبل الرسم
    if currentSprite then
        -- رسم اللاعب
        love.graphics.draw(
            currentSprite,
            self.x,
            self.y,
            self.rotation,
            self.scale,
            self.scale,
            currentSprite:getWidth() / 2,
            currentSprite:getHeight() / 2
        )
        
        -- رسم معلومات التصحيح إذا كان مفعلاً
        if self.debug then
            love.graphics.print(string.format(
                "X: %d, Y: %d\nState: %s\nFrame: %d",
                math.floor(self.x),
                math.floor(self.y),
                self.currentState,
                self.animFrame
            ), 10, 10)
        end
    end
end

return Player
