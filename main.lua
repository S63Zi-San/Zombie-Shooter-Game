function love.load()
    math.randomseed(os.time())
    love.window.setMode(800, 600)
    
    -- تهيئة الكاميرا
    camera = {
        x = 0,
        y = 0,
        speed = 200,
        smoothness = 0.1
    }
    
    -- تحميل الصور
    sprites = {
        background = love.graphics.newImage('sprites/background.png'),
        bullet = love.graphics.newImage('sprites/bullet.png'),
        zombie = love.graphics.newImage('sprites/zombie.png'),
        boss = love.graphics.newImage('sprites/boss.png'),
        -- صور اللاعب
        player = {
            idle = love.graphics.newImage('sprites/player_Stand.png.png'),
            walk = {
                love.graphics.newImage('sprites/player_walk1.png.png'),
                love.graphics.newImage('sprites/player_walk2.png.png'),
                love.graphics.newImage('sprites/player_walk3.png.png')
            },
            shoot = {
                love.graphics.newImage('sprites/player_shoot1.png.png'),
                love.graphics.newImage('sprites/player_shoot2.png.png')
            }
        }
    }

    -- حدود الخريطة تعتمد على حجم الخلفية
    mapWidth = sprites.background:getWidth()
    mapHeight = sprites.background:getHeight()

    -- إضافة نظام الجزيئات
    particles = love.graphics.newParticleSystem(sprites.bullet, 32)
    particles:setParticleLifetime(0.5, 1)
    particles:setEmissionRate(20)
    particles:setSizeVariation(1)
    particles:setLinearAcceleration(-50, -50, 50, 50)
    particles:setColors(1, 1, 0, 1, 1, 0, 0, 0)

    -- تهيئة المتغيرات العامة
    bullets = {}
    zombies = {}
    boss = nil
    
    -- تهيئة اللاعب
    package.path = package.path .. ";.\\?.lua"
    local Player = require('player')
    player = Player:new(sprites, camera, mapWidth, mapHeight)
    player.x = mapWidth / 2
    player.y = mapHeight / 2

    -- تهيئة حالة اللعبة
    gameState = 1
    currentRound = 1
    killCount = 0
    requiredKills = 15  -- عدد القتلى المطلوبة
    score = 0
    lives = 3
    zombieSpawnTimer = 0
    maxTime = 2
    timer = maxTime
    transitionTimer = 3
    myFont = love.graphics.newFont(30)
    bigFont = love.graphics.newFont(60)
    bossMaxHealth = 2000  -- صحة البوس
    bossSpawnTimer = 1.5  -- وقت ظهور الزومبي في مرحلة البوس
    gameWon = false
    missedShots = 0
    totalPlayTime = 0
    gameStartTime = 0
    highScore = 0
end

function love.update(dt)
    particles:update(dt)
    
    -- تحديث موقع الكاميرا في جميع حالات اللعب النشطة
    if gameState == 2 or gameState == 3 or gameState == 4 then
        local targetX = player.x - love.graphics.getWidth() / 2
        local targetY = player.y - love.graphics.getHeight() / 2
        
        camera.x = camera.x + (targetX - camera.x) * camera.smoothness
        camera.y = camera.y + (targetY - camera.y) * camera.smoothness
    end
    
    if gameState == 2 then
        -- تحديث الوقت الكلي للعب
        if gameStartTime > 0 then
            totalPlayTime = love.timer.getTime() - gameStartTime
        end
        
        -- تحقق من انتهاء اللعبة بعد 5 راوندات
        if currentRound > 5 then
            gameState = 6  -- انتهاء اللعبة بالفوز
            return
        end
        
        -- تحديث موقع الكاميرا بنعومة
        if gameState == 2 or gameState == 4 then
            local targetX = player.x - love.graphics.getWidth() / 2
            local targetY = player.y - love.graphics.getHeight() / 2
            
            camera.x = camera.x + (targetX - camera.x) * camera.smoothness
            camera.y = camera.y + (targetY - camera.y) * camera.smoothness
        end
        
        player:update(dt)

        -- تحديث الزومبي
        for i = #zombies, 1, -1 do
            local z = zombies[i]
            if z then
                z.x = z.x + math.cos(enemyAngle(z)) * z.speed * dt
                z.y = z.y + math.sin(enemyAngle(z)) * z.speed * dt

                if distanceBetween(z.x, z.y, player.x, player.y) < 30 then
                    lives = lives - 1
                    table.remove(zombies, i)
                    if lives <= 0 then
                        gameState = 5
                        if score > highScore then
                            highScore = score
                        end
                        return
                    end
                end
            end
        end

        -- تحديث الطلقات
        for i = #bullets, 1, -1 do
            local b = bullets[i]
            -- تحريك الطلقة
            b.x = b.x + math.cos(b.direction) * b.speed * dt
            b.y = b.y + math.sin(b.direction) * b.speed * dt
            
            -- تحقق من إصابة الزومبي أو البوس
            local hitSomething = false
            
            -- تحقق من إصابة الزومبي
            for j = #zombies, 1, -1 do
                local z = zombies[j]
                if z and distanceBetween(b.x, b.y, z.x, z.y) < 20 then
                    table.remove(zombies, j)
                    table.remove(bullets, i)
                    killCount = killCount + 1
                    score = score + 10  -- 10 نقاط لكل قتل
                    hitSomething = true
                    break
                end
            end
            
            -- تحقق من إصابة البوس (فقط في مرحلة البوس)
            if not hitSomething and boss and gameState == 4 and distanceBetween(b.x, b.y, boss.x, boss.y) < boss.size then
                table.remove(bullets, i)
                boss.health = boss.health - 50
                -- إضافة تأثير بصري عند إصابة البوس
                for j = 1, 6 do
                    local angle = (j * math.pi * 2) / 6
                    local particleX = boss.x + math.cos(angle) * 30
                    local particleY = boss.y + math.sin(angle) * 30
                    particles:setPosition(particleX, particleY)
                    particles:emit(5)
                end
                hitSomething = true
                if boss.health <= 0 then
                    -- إضافة تأثير انفجار كبير عند موت البوس
                    for j = 1, 16 do
                        local angle = (j * math.pi * 2) / 16
                        local particleX = boss.x + math.cos(angle) * 50
                        local particleY = boss.y + math.sin(angle) * 50
                        particles:setPosition(particleX, particleY)
                        particles:emit(15)
                    end
                    boss = nil
                    gameWon = true
                    if score > highScore then
                        highScore = score
                    end
                    gameState = 6  -- حالة جديدة لشاشة الفوز
                    score = score + 2000  -- مكافأة إضافية لقتل البوس
                end
            end
            
            -- إذا خرجت الطلقة من الشاشة أو لم تصب شيئاً
            if not hitSomething and distanceBetween(b.x, b.y, player.x, player.y) > 1000 then
                table.remove(bullets, i)
                missedShots = missedShots + 1
                score = score - 30  -- خصم 30 نقطة لكل طلقة ضائعة
            end
        end
        
        -- إطلاق النار
        if love.mouse.isDown(1) and player.shootTimer <= 0 then
            -- حساب موقع بداية الطلقة
            local angle = playerMouseAngle()
            local startX = player.x + math.cos(angle) * 20
            local startY = player.y + math.sin(angle) * 20
            
            -- إنشاء طلقة جديدة
            local bullet = {
                x = startX,
                y = startY,
                direction = angle,
                speed = 500
            }
            table.insert(bullets, bullet)
            player.shootTimer = player.shootDelay
        end

        -- تحديث مؤقت إطلاق النار
        if player.shootTimer > 0 then
            player.shootTimer = player.shootTimer - dt
        end

        -- تحقق من قتل الزومبي بالداش
        if player.isDashing then
            particles:setPosition(player.x, player.y)
            particles:emit(10)
            
            -- إنشاء دائرة قتل كبيرة حول اللاعب
            local dashKillRadius = 100  -- نصف قطر منطقة القتل
            for i = #zombies, 1, -1 do
                local z = zombies[i]
                if z and distanceBetween(z.x, z.y, player.x, player.y) < dashKillRadius then
                    -- إضافة تأثير للقتل
                    for j = 1, 8 do
                        local angle = (j * math.pi * 2) / 8
                        local particleX = z.x + math.cos(angle) * 20
                        local particleY = z.y + math.sin(angle) * 20
                        particles:setPosition(particleX, particleY)
                        particles:emit(5)
                    end
                    
                    table.remove(zombies, i)
                    killCount = killCount + 1
                    score = score + 10
                end
            end

            -- التحقق من إصابة البوس بالداش
            if boss and gameState == 4 then
                if distanceBetween(boss.x, boss.y, player.x, player.y) < boss.size + player.dashKillRadius then
                    boss.health = boss.health - 200  -- زيادة الضرر على البوس
                    -- إضافة تأثير للضرر
                    for j = 1, 12 do
                        local angle = (j * math.pi * 2) / 12
                        local particleX = boss.x + math.cos(angle) * 30
                        local particleY = boss.y + math.sin(angle) * 30
                        particles:setPosition(particleX, particleY)
                        particles:emit(8)
                    end
                    
                    if boss.health <= 0 then
                        boss = nil
                        gameWon = true
                        if score > highScore then
                            highScore = score
                        end
                        gameState = 6  -- حالة جديدة لشاشة الفوز
                        score = score + 1000
                    end
                end
            end
        end

        -- تحقق من اكتمال الجولة
        if killCount >= requiredKills then
            currentRound = currentRound + 1
            killCount = 0
            
            if currentRound == 5 then
                -- الانتقال إلى مرحلة البوس
                gameState = 3
                transitionTimer = 3
                requiredKills = 1
            elseif currentRound < 5 then
                -- الانتقال إلى الراوند التالي
                gameState = 3
                transitionTimer = 3
                requiredKills = requiredKills + 5
            end
        end

        -- إنشاء زومبي جديد
        zombieSpawnTimer = zombieSpawnTimer - dt
        if zombieSpawnTimer <= 0 then
            spawnZombie()
            zombieSpawnTimer = maxTime
        end
    elseif gameState == 3 then
        transitionTimer = transitionTimer - dt
        if transitionTimer <= 0 then
            if currentRound == 5 then
                gameState = 4
                spawnBoss()
            else
                gameState = 2
            end
            resetGame()
        end

    elseif gameState == 4 then
        -- تحديث البوس
        if boss then
            player:update(dt)

            -- حركة البوس
            local angle = enemyAngle(boss)
            local speed = boss.speed
            
            -- زيادة السرعة في وضع الغضب
            if boss.health <= boss.rageModeThreshold then
                boss.rageMode = true
                speed = speed * 1.5
                boss.attackCooldown = 0.75  -- هجمات أسرع في وضع الغضب
            end
            
            boss.x = boss.x + math.cos(angle) * speed * dt
            boss.y = boss.y + math.sin(angle) * speed * dt
            
            -- هجوم خاص عندما يكون البوس في وضع الغضب
            if boss.rageMode then
                boss.specialAttackTimer = boss.specialAttackTimer - dt
                if boss.specialAttackTimer <= 0 then
                    -- إطلاق موجة من الزومبي
                    for i = 1, 8 do
                        local angle = (i * math.pi * 2) / 8
                        local zombie = {
                            x = boss.x + math.cos(angle) * 50,
                            y = boss.y + math.sin(angle) * 50,
                            speed = 200
                        }
                        table.insert(zombies, zombie)
                    end
                    boss.specialAttackTimer = boss.specialAttackCooldown
                end
            end

            -- تحقق من اصطدام البوس باللاعب
            if distanceBetween(boss.x, boss.y, player.x, player.y) < boss.size then
                lives = 0  -- الموت مباشرة عند لمس البوس
                gameState = 5
                return
            end

            -- تحديث الطلقات
            for i = #bullets, 1, -1 do
                local b = bullets[i]
                b.x = b.x + math.cos(b.direction) * b.speed * dt
                b.y = b.y + math.sin(b.direction) * b.speed * dt
                
                -- تحقق من إصابة البوس
                if distanceBetween(b.x, b.y, boss.x, boss.y) < boss.size then
                    table.remove(bullets, i)
                    boss.health = boss.health - 50
                    if boss.health <= 0 then
                        boss = nil
                        gameWon = true
                        if score > highScore then
                            highScore = score
                        end
                        gameState = 6  -- حالة جديدة لشاشة الفوز
                        score = score + 1000
                    end
                end
                
                -- إزالة الطلقات خارج الشاشة
                if b.x < 0 or b.x > 5000 or
                   b.y < 0 or b.y > 5000 then
                    table.remove(bullets, i)
                end
            end

            -- تحقق من إصابة البوس بالداش
            if player.dashing and distanceBetween(player.x, player.y, boss.x, boss.y) < boss.size + player.dashKillRadius then
                boss.health = boss.health - 200
                if boss.health <= 0 then
                    boss = nil
                    gameWon = true
                    if score > highScore then
                        highScore = score
                    end
                    gameState = 6  -- حالة جديدة لشاشة الفوز
                    score = score + 1000
                end
            end

            -- تحديث جنود البوس
            for i = #zombies, 1, -1 do
                local z = zombies[i]
                if z then  -- تحقق من وجود الزومبي
                    -- حركة الجنود
                    local angle = enemyAngle(z)
                    z.x = z.x + math.cos(angle) * z.speed * dt
                    z.y = z.y + math.sin(angle) * z.speed * dt

                    -- تحقق من إصابة اللاعب
                    if distanceBetween(z.x, z.y, player.x, player.y) < 30 then
                        lives = lives - 1
                        table.remove(zombies, i)
                        if lives <= 0 then
                            gameState = 5
                        else
                            resetGame()
                        end
                    end

                    -- تحقق من إصابة الجنود بالطلقات
                    for j = #bullets, 1, -1 do
                        local b = bullets[j]
                        if b and distanceBetween(b.x, b.y, z.x, z.y) < 20 then
                            table.remove(zombies, i)
                            table.remove(bullets, j)
                            score = score + 20
                            break
                        end
                    end

                    -- تحقق من إصابة الجنود بالداش
                    if player.dashing and distanceBetween(player.x, player.y, z.x, z.y) < player.dashKillRadius then
                        table.remove(zombies, i)
                        score = score + 30
                    end
                end
            end

            -- إطلاق النار
            if love.mouse.isDown(1) and player.shootTimer <= 0 then
                local angle = playerMouseAngle()
                local startX = player.x + math.cos(angle) * 20
                local startY = player.y + math.sin(angle) * 20
                
                local bullet = {
                    x = startX,
                    y = startY,
                    direction = angle,
                    speed = 500
                }
                table.insert(bullets, bullet)
                player.shootTimer = player.shootDelay
            end

            -- تحديث مؤقت إطلاق النار
            if player.shootTimer > 0 then
                player.shootTimer = player.shootTimer - dt
            end

            -- توليد جنود جدد
            bossSpawnTimer = bossSpawnTimer - dt
            if #zombies < 5 and bossSpawnTimer <= 0 then
                spawnZombie()
                bossSpawnTimer = 2  -- كل ثانيتين
            end
        end
    end
end

function love.draw()
    if gameState == 1 then
        drawMainMenu()
    elseif gameState == 2 then
        -- حفظ حالة الرسم الحالية
        love.graphics.push()
        
        -- تطبيق تحويلات الكاميرا
        love.graphics.translate(-camera.x, -camera.y)
        
        -- رسم الخلفية بشكل متكرر حول اللاعب بدون حدود
        local bgWidth = sprites.background:getWidth()
        local bgHeight = sprites.background:getHeight()
        local startX = math.floor((camera.x - bgWidth) / bgWidth) * bgWidth
        local startY = math.floor((camera.y - bgHeight) / bgHeight) * bgHeight
        local endX = startX + love.graphics.getWidth() + bgWidth * 2
        local endY = startY + love.graphics.getHeight() + bgHeight * 2
        
        for x = startX, endX, bgWidth do
            for y = startY, endY, bgHeight do
                love.graphics.draw(sprites.background, x, y)
            end
        end
        
        -- رسم حدود الخريطة
        love.graphics.setLineWidth(4)  -- سمك الخط
        -- الحدود الخارجية
        love.graphics.setColor(0.8, 0, 0, 0.8)  -- أحمر غامق
        love.graphics.rectangle("line", 0, 0, mapWidth, mapHeight)
        
        -- الهامش الداخلي
        love.graphics.setColor(1, 0, 0, 0.3)  -- أحمر شفاف
        local margin = 20
        love.graphics.rectangle("line", margin, margin, mapWidth - margin * 2, mapHeight - margin * 2)
        
        -- إعادة لون الرسم للأبيض
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)  -- إعادة سمك الخط للافتراضي

        -- رسم اللاعب
        player:draw()
        
        -- رسم الزومبي
        for _, z in ipairs(zombies) do
            if z then
                love.graphics.draw(sprites.zombie, z.x, z.y, enemyAngle(z), 1, 1, sprites.zombie:getWidth()/2, sprites.zombie:getHeight()/2)
            end
        end
        
        -- رسم الطلقات
        for _, b in ipairs(bullets) do
            love.graphics.draw(sprites.bullet, b.x, b.y, b.direction, 0.3, 0.3, sprites.bullet:getWidth()/2, sprites.bullet:getHeight()/2)
        end
        
        -- استعادة حالة الرسم
        love.graphics.pop()
        
        -- رسم واجهة المستخدم
        drawUI()
    elseif gameState == 3 then
        love.graphics.setFont(bigFont)
        love.graphics.printf("Round " .. currentRound .. " Complete!", 0, 100, love.graphics.getWidth(), "center")
        love.graphics.setFont(myFont)
        love.graphics.printf("Prepare for the next round...", 0, 300, love.graphics.getWidth(), "center")
    elseif gameState == 4 then
        -- حفظ حالة الرسم الحالية
        love.graphics.push()
        
        -- تطبيق تحويلات الكاميرا
        love.graphics.translate(-camera.x, -camera.y)
        
        -- رسم الخلفية بشكل متكرر حول اللاعب بدون حدود
        local bgWidth = sprites.background:getWidth()
        local bgHeight = sprites.background:getHeight()
        local startX = math.floor((camera.x - bgWidth) / bgWidth) * bgWidth
        local startY = math.floor((camera.y - bgHeight) / bgHeight) * bgHeight
        local endX = startX + love.graphics.getWidth() + bgWidth * 2
        local endY = startY + love.graphics.getHeight() + bgHeight * 2
        
        for x = startX, endX, bgWidth do
            for y = startY, endY, bgHeight do
                love.graphics.draw(sprites.background, x, y)
            end
        end
        
        -- رسم حدود الخريطة
        love.graphics.setLineWidth(4)  -- سمك الخط
        -- الحدود الخارجية
        love.graphics.setColor(0.8, 0, 0, 0.8)  -- أحمر غامق
        love.graphics.rectangle("line", 0, 0, mapWidth, mapHeight)
        
        -- الهامش الداخلي
        love.graphics.setColor(1, 0, 0, 0.3)  -- أحمر شفاف
        local margin = 20
        love.graphics.rectangle("line", margin, margin, mapWidth - margin * 2, mapHeight - margin * 2)
        
        -- إعادة لون الرسم للأبيض
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)  -- إعادة سمك الخط للافتراضي

        -- رسم اللاعب
        player:draw()
        
        -- رسم البوس
        if boss then
            love.graphics.setColor(1, 0, 0)
            love.graphics.draw(sprites.boss, boss.x, boss.y, 0, 2, 2, sprites.boss:getWidth()/2, sprites.boss:getHeight()/2)
            
            -- رسم شريط الصحة للبوس (ثابت على الشاشة)
            love.graphics.push()
            love.graphics.origin()  -- إعادة تعيين التحويلات للرسم على الشاشة مباشرة
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", 50, 50, (boss.health / bossMaxHealth) * 700, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", 50, 50, 700, 20)
            love.graphics.pop()
        end

        -- رسم الطلقات والزومبي
        for _, b in ipairs(bullets) do
            love.graphics.draw(sprites.bullet, b.x, b.y, b.direction, 0.3, 0.3, sprites.bullet:getWidth()/2, sprites.bullet:getHeight()/2)
        end

        for _, z in ipairs(zombies) do
            if z then
                love.graphics.draw(sprites.zombie, z.x, z.y, enemyAngle(z), 1, 1, sprites.zombie:getWidth()/2, sprites.zombie:getHeight()/2)
            end
        end

        -- استعادة حالة الرسم
        love.graphics.pop()
        
        -- رسم واجهة المستخدم
        drawUI()
        
    elseif gameState == 5 then
        love.graphics.setFont(bigFont)
        love.graphics.printf("Game Over!", 0, 200, love.graphics.getWidth(), "center")
        love.graphics.setFont(myFont)
        love.graphics.printf("Final Score: " .. score, 0, 300, love.graphics.getWidth(), "center")
        love.graphics.printf("Press Enter to Restart", 0, 400, love.graphics.getWidth(), "center")
    elseif gameState == 6 then  
        love.graphics.setFont(bigFont)
        if currentRound == 5 then
            love.graphics.printf("CONGRATULATIONS!\nYOU DEFEATED THE FINAL BOSS!", 0, 100, love.graphics.getWidth(), "center")
        else
            love.graphics.printf("YOU WIN!", 0, 100, love.graphics.getWidth(), "center")
        end
        
        love.graphics.setFont(myFont)
        -- عرض الوقت المستغرق في اللعب
        local minutes = math.floor(totalPlayTime / 60)
        local seconds = math.floor(totalPlayTime % 60)
        
        love.graphics.printf("Final Statistics:", 0, 200, love.graphics.getWidth(), "center")
        love.graphics.printf("Time: " .. string.format("%02d:%02d", minutes, seconds), 0, 250, love.graphics.getWidth(), "center")
        love.graphics.printf("Missed Shots: " .. missedShots, 0, 300, love.graphics.getWidth(), "center")
        love.graphics.printf("Final Score: " .. score, 0, 350, love.graphics.getWidth(), "center")
        love.graphics.printf("High Score: " .. highScore, 0, 400, love.graphics.getWidth(), "center")
        love.graphics.printf("Press Enter to Play Again", 0, 500, love.graphics.getWidth(), "center")
    end
end

function drawUI()
    love.graphics.setFont(myFont)
    love.graphics.printf("Score: " .. score, 10, 10, love.graphics.getWidth(), "left")
    love.graphics.printf("Lives: " .. lives, 10, 40, love.graphics.getWidth(), "left")
    
    -- Show round info and special message for final boss
    if currentRound == 5 then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.printf("FINAL BOSS ROUND!", 0, 10, love.graphics.getWidth(), "center")
        if boss then
            love.graphics.printf("Boss Health: " .. boss.health, 0, 40, love.graphics.getWidth(), "center")
        end
    else
        love.graphics.printf("Round: " .. currentRound .. " - Kills: " .. killCount .. "/" .. requiredKills, 0, 10, love.graphics.getWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function drawMainMenu()
    -- رسم القائمة الرئيسية
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- رسم موجات متحركة في الخلفية
    for i = 0, 10 do
        love.graphics.setColor(0.3, 0.3, 0.5, 0.5)
        love.graphics.circle("line", love.graphics.getWidth()/2, 
                           love.graphics.getHeight()/2, 
                           i * 50 + love.timer.getTime() * 50 % 100)
    end
    
    -- رسم عنوان اللعبة مع تأثير الظل
    love.graphics.setFont(bigFont)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf("Zombie Shooter", 3, 103, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.printf("Zombie Shooter", 0, 100, love.graphics.getWidth(), "center")
    
    -- رسم نص البدء
    love.graphics.setFont(myFont)
    love.graphics.setColor(1, 1, 1, 0.7 + math.sin(love.timer.getTime() * 3) * 0.3)
    love.graphics.printf("Press Enter to Start", 0, 300, love.graphics.getWidth(), "center")
    
    -- إعادة تعيين اللون إلى الافتراضي
    love.graphics.setColor(1, 1, 1, 1)
end

function playerMouseAngle()
    local mouseX = love.mouse.getX() + camera.x
    local mouseY = love.mouse.getY() + camera.y
    return math.atan2(mouseY - player.y, mouseX - player.x)
end

function spawnZombie()
    -- اختيار موقع عشوائي على حدود الخريطة
    local side = love.math.random(1, 4)
    local x, y
    
    if side == 1 then  -- أعلى
        x = love.math.random(0, mapWidth)
        y = -50
    elseif side == 2 then  -- يمين
        x = mapWidth + 50
        y = love.math.random(0, mapHeight)
    elseif side == 3 then  -- أسفل
        x = love.math.random(0, mapWidth)
        y = mapHeight + 50
    else  -- يسار
        x = -50
        y = love.math.random(0, mapHeight)
    end

    -- إنشاء الزومبي
    local zombie = {
        x = x,
        y = y,
        speed = 100,
        sprite = sprites.zombie,
        rotation = 0,
        scale = 0.5,
        health = 100
    }
    table.insert(zombies, zombie)
end

function love.keypressed(key)
    if key == "return" then
        if gameState == 1 then
            gameState = 2
            gameStartTime = love.timer.getTime()
            resetGame()
        elseif gameState == 5 or gameState == 6 then
            -- إعادة تهيئة كل شيء من البداية
            gameState = 1
            currentRound = 1
            killCount = 0
            requiredKills = 15
            score = 0
            lives = 3
            totalPlayTime = 0
            gameStartTime = 0
            resetGame()
        end
    end
end

function resetGame()
    zombies = {}
    bullets = {}
    
    -- تحديث موقع الكاميرا فوراً عند إعادة التشغيل
    camera.x = player.x - love.graphics.getWidth() / 2
    camera.y = player.y - love.graphics.getHeight() / 2
    
    -- تعيين موقع اللاعب في المنتصف
    player.x = mapWidth / 2
    player.y = mapHeight / 2
    
    missedShots = 0
    gameWon = false
end

function enemyAngle(enemy)
    if enemy then
        return math.atan2(player.y - enemy.y, player.x - enemy.x)
    end
    return 0
end

function distanceBetween(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function getZombieSpeed()
    -- زيادة السرعة تدريجياً مع كل راوند
    if currentRound == 1 then
        return 100  -- سرعة أساسية
    elseif currentRound == 2 then
        return 150  -- سرعة متوسطة
    elseif currentRound == 3 then
        return 200  -- سرعة عالية
    elseif currentRound == 4 then
        return 250  -- سرعة عالية جداً
    else
        return 300  -- سرعة قصوى
    end
end

function getZombieHealth()
    -- زيادة الصحة تدريجياً مع كل راوند
    if currentRound == 1 then
        return 3  -- صحة أساسية
    elseif currentRound == 2 then
        return 5  -- صحة متوسطة
    elseif currentRound == 3 then
        return 8  -- صحة عالية
    elseif currentRound == 4 then
        return 12  -- صحة عالية جداً
    else
        return 15  -- صحة قصوى للراوند الأخير
    end
end

function spawnBoss()
    boss = {
        x = love.graphics.getWidth() / 2,
        y = -100,
        speed = 150,
        size = 60,
        health = bossMaxHealth,
        attackTimer = 0,
        attackCooldown = 1.5,
        specialAttackTimer = 0,
        specialAttackCooldown = 5,
        rageMode = false,
        rageModeThreshold = bossMaxHealth * 0.3  -- يدخل في وضع الغضب عند 30% من الصحة
    }
end