local Shooting = {}

function Shooting:new()
    local shooting = {
        bullets = {},
        currentAmmo = 30,
        maxAmmo = 30,
        reloadTime = 2,
        reloadTimer = 0,
        isReloading = false,
        shootTimer = 0,
        shootDelay = 0.2,
        bulletSpeed = 500,
        bulletScale = 0.3,
        damage = 50,
        -- إضافة متغيرات الرسوم المتحركة للإطلاق
        shootingFrames = {}, -- سيتم تعبئتها بإطارات الإطلاق
        currentShootFrame = 1,
        shootAnimationTimer = 0,
        shootFrameDelay = 0.05, -- سرعة تحريك إطارات الإطلاق
        isShootingAnimation = false
    }
    self.__index = self
    return setmetatable(shooting, self)
end

function Shooting:loadAnimations(sprites)
    -- تحميل إطارات الإطلاق من ملف الصور
    self.shootingFrames = sprites.shootFrames -- يجب أن تكون مصفوفة من الإطارات
end

function Shooting:update(dt, player, camera)
    -- تحديث مؤقت إطلاق النار
    if self.shootTimer > 0 then
        self.shootTimer = self.shootTimer - dt
    end

    -- تحديث الرسوم المتحركة للإطلاق
    if self.isShootingAnimation then
        self.shootAnimationTimer = self.shootAnimationTimer + dt
        if self.shootAnimationTimer >= self.shootFrameDelay then
            self.shootAnimationTimer = 0
            self.currentShootFrame = self.currentShootFrame + 1
            if self.currentShootFrame > #self.shootingFrames then
                self.currentShootFrame = 1
                self.isShootingAnimation = false
            end
        end
    end

    -- تحديث عملية إعادة التحميل
    if self.isReloading then
        self.reloadTimer = self.reloadTimer - dt
        if self.reloadTimer <= 0 then
            self.currentAmmo = self.maxAmmo
            self.isReloading = false
        end
    end

    -- إطلاق النار
    if love.mouse.isDown(1) and self.shootTimer <= 0 and not self.isReloading and self.currentAmmo > 0 then
        -- بدء الرسوم المتحركة للإطلاق
        self.isShootingAnimation = true
        self.currentShootFrame = 1

        -- حساب زاوية الطلقة
        local mouseX = love.mouse.getX() + camera.x
        local mouseY = love.mouse.getY() + camera.y
        local angle = math.atan2(mouseY - player.y, mouseX - player.x)

        -- إنشاء طلقة جديدة
        local startX = player.x + math.cos(angle) * 20
        local startY = player.y + math.sin(angle) * 20
        
        local bullet = {
            x = startX,
            y = startY,
            direction = angle,
            speed = self.bulletSpeed
        }
        table.insert(self.bullets, bullet)
        
        -- تحديث العداد
        self.currentAmmo = self.currentAmmo - 1
        self.shootTimer = self.shootDelay
    end

    -- بدء إعادة التحميل
    if love.keyboard.isDown('r') and not self.isReloading and self.currentAmmo < self.maxAmmo then
        self.isReloading = true
        self.reloadTimer = self.reloadTime
    end

    -- تحديث الطلقات
    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i]
        b.x = b.x + math.cos(b.direction) * b.speed * dt
        b.y = b.y + math.sin(b.direction) * b.speed * dt

        -- إزالة الطلقات البعيدة
        if distanceBetween(b.x, b.y, player.x, player.y) > 1000 then
            table.remove(self.bullets, i)
        end
    end
end

function Shooting:getCurrentShootFrame()
    return self.shootingFrames[self.currentShootFrame]
end

function Shooting:isAnimating()
    return self.isShootingAnimation
end

function Shooting:draw(bulletSprite)
    -- رسم الطلقات
    for _, b in ipairs(self.bullets) do
        love.graphics.draw(
            bulletSprite,
            b.x,
            b.y,
            b.direction,
            self.bulletScale,
            self.bulletScale,
            bulletSprite:getWidth()/2,
            bulletSprite:getHeight()/2
        )
    end
end

function distanceBetween(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

return Shooting
