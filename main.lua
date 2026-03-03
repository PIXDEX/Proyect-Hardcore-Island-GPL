-- ==========================================
-- TERRARIA DOWNGRADED - VERSIÓN DEFINITIVA PERSISTENTE
-- ==========================================

local mapa = {}
local estado = "menu" 
local tile = 64
local p = { x = 3200, y = 3200, v = 300, vida = 100, max_vida = 100, madera = 20 }
local img = {}
local enemigos = {}
local slot_sel = 1
local timer_enemigo = 0
local atacando = 0 
local inv_abierto = false

-- SISTEMA DE INVENTARIO Y CRAFTEO
local inventario = { [5]=0, [6]=0, [7]=0, [8]=0 } -- Cantidad de objetos fabricados
local crafteo_grid = {0,0,0, 0,0,0, 0,0,0}
local resultado_id = 0
local recetas = {
    ["000030000"] = 5, -- Madera al centro = Fogata
    ["333303333"] = 8, -- Madera anillo = Cofre
    ["333000000"] = 6, -- Madera arriba = Muro
    ["030030030"] = 7, -- Madera columna = Puerta
}

local hotbar_items = {
    { nombre = "Muro", id = 6 },
    { nombre = "Puerta", id = 7 },
    { nombre = "Cofre", id = 8 },
    { nombre = "Fogata", id = 5 }
}

-- ==========================================
-- PERSISTENCIA (GUARDADO Y CARGA)
-- ==========================================
function guardar_partida()
    local data = ""
    -- Guardar Stats del Jugador
    data = data .. "P:" .. p.x .. "," .. p.y .. "," .. p.vida .. "," .. p.madera .. "\n"
    -- Guardar Inventario
    data = data .. "I:" .. inventario[5] .. "," .. inventario[6] .. "," .. inventario[7] .. "," .. inventario[8] .. "\n"
    -- Guardar Mapa (Solo guardamos lo que no es tierra/id 1 para ahorrar espacio)
    for f = 1, 100 do
        for c = 1, 100 do
            if mapa[f][c] ~= 1 then
                data = data .. "M:" .. f .. "," .. c .. "," .. mapa[f][c] .. "\n"
            end
        end
    end
    love.filesystem.write("savegame.txt", data)
    print("¡Partida Guardada!")
end

function cargar_partida()
    if not love.filesystem.getInfo("savegame.txt") then return false end
    
    -- Resetear mapa a tierra antes de cargar
    for f=1,100 do mapa[f] = {}; for c=1,100 do mapa[f][c] = 1 end end

    for line in love.filesystem.lines("savegame.txt") do
        local type = line:sub(1,1)
        local content = line:sub(3)
        local parts = {}
        for v in content:gmatch("([^,]+)") do table.insert(parts, tonumber(v)) end

        if type == "P" then
            p.x, p.y, p.vida, p.madera = parts[1], parts[2], parts[3], parts[4]
        elseif type == "I" then
            inventario[5], inventario[6], inventario[7], inventario[8] = parts[1], parts[2], parts[3], parts[4]
        elseif type == "M" then
            if mapa[parts[1]] then mapa[parts[1]][parts[2]] = parts[3] end
        end
    end
    return true
end

-- ==========================================
-- LÓGICA DE JUEGO
-- ==========================================
function generar_nuevo_mapa()
    for f = 1, 100 do
        mapa[f] = {}
        for c = 1, 100 do
            if f==1 or f==100 or c==1 or c==100 then mapa[f][c] = 2 
            else mapa[f][c] = (love.math.random() < 0.1) and 3 or 1 end
        end
    end
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    fuente_juego = love.graphics.newFont(18)
    fuente_titulo = love.graphics.newFont(50)
    
    pcall(function()
        img[1] = love.graphics.newImage("assets/tierra.png")
        img[2] = love.graphics.newImage("assets/muro.png")
        img[3] = love.graphics.newImage("assets/madera.png")
        img[4] = love.graphics.newImage("assets/personaje.png")
        img[5] = love.graphics.newImage("assets/fuego.png")
    end)
    
    if not cargar_partida() then generar_nuevo_mapa() end
end

function es_solido(nx, ny)
    local c, f = math.floor((nx+16)/tile)+1, math.floor((ny+16)/tile)+1
    if mapa[f] and mapa[f][c] then
        local id = mapa[f][c]
        return (id == 2 or id == 6 or id == 8)
    end
    return false
end

function love.update(dt)
    if estado ~= "jugando" or inv_abierto then return end

    -- Movimiento
    local dx, dy = 0, 0
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then dy = -1 end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then dy = 1 end
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then dx = -1 end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then dx = 1 end

    if dx ~= 0 or dy ~= 0 then
        local mag = math.sqrt(dx*dx + dy*dy)
        dx, dy = (dx/mag)*p.v*dt, (dy/mag)*p.v*dt
        if not es_solido(p.x + dx, p.y) then p.x = p.x + dx end
        if not es_solido(p.x, p.y + dy) then p.y = p.y + dy end
    end

    -- Fogata (Curación)
    local pc, pf = math.floor((p.x+32)/tile)+1, math.floor((p.y+32)/tile)+1
    if mapa[pf] and mapa[pf][pc] == 5 then p.vida = math.min(p.max_vida, p.vida + 15*dt) end

    -- IA Enemigos
    timer_enemigo = timer_enemigo + dt
    if timer_enemigo > 4 then 
        local e = { x = p.x + love.math.random(-600, 600), y = p.y + love.math.random(-600, 600), v = 150 }
        table.insert(enemigos, e)
        timer_enemigo = 0 
    end
    for i = #enemigos, 1, -1 do
        local e = enemigos[i]
        if e.x < p.x then e.x = e.x + e.v*dt else e.x = e.x - e.v*dt end
        if e.y < p.y then e.y = e.y + e.v*dt else e.y = e.y - e.v*dt end
        if math.sqrt((e.x-p.x)^2 + (e.y-p.y)^2) < 30 then p.vida = p.vida - 20*dt end
    end

    if p.vida <= 0 then estado = "menu"; p.vida = 100 end
    if atacando > 0 then atacando = atacando - dt end
end

function love.draw()
    if estado == "menu" then
        love.graphics.clear(0.1, 0.1, 0.1)
        love.graphics.setFont(fuente_titulo)
        love.graphics.printf("HARDCORE ISLAND", 0, 200, 800, "center")
        love.graphics.setFont(fuente_juego)
        love.graphics.printf("Presiona ENTER para sobrevivir", 0, 350, 800, "center")

    elseif estado == "jugando" or estado == "pausa" then
        local cam_x, cam_y = math.floor(-p.x + 400), math.floor(-p.y + 300)
        love.graphics.push()
        love.graphics.translate(cam_x, cam_y)

        -- Mapa Optimizado (Solo dibujamos lo cercano)
        local start_c = math.max(1, math.floor(p.x/tile) - 10)
        local end_c = math.min(100, start_c + 22)
        local start_f = math.max(1, math.floor(p.y/tile) - 8)
        local end_f = math.min(100, start_f + 18)

        for f = start_f, end_f do
            for c = start_c, end_c do
                local x, y = (c-1)*tile, (f-1)*tile
                local id = mapa[f][c]
                if img[id] then love.graphics.draw(img[id], x, y, 0, 2, 2)
                elseif id == 6 then love.graphics.setColor(0.5,0.5,0.5) love.graphics.rectangle("fill", x, y, 64, 64)
                elseif id == 8 then love.graphics.setColor(0.4,0.2,0.1) love.graphics.rectangle("fill", x+8, y+16, 48, 32)
                end
                love.graphics.setColor(1,1,1)
            end
        end

        -- Ghost Preview
        if not inv_abierto and estado == "jugando" then
            local mx, my = love.mouse.getPosition()
            local gx, gy = math.floor((mx - cam_x)/tile)*tile, math.floor((my - cam_y)/tile)*tile
            love.graphics.setColor(1,1,1,0.3)
            love.graphics.rectangle("fill", gx, gy, 64, 64)
        end

        if atacando > 0 then love.graphics.setColor(1,1,1,0.4) love.graphics.circle("fill", p.x+32, p.y+32, 100) end
        
        love.graphics.setColor(1,1,1)
        if img[4] then love.graphics.draw(img[4], p.x, p.y, 0, 2, 2) end
        
        love.graphics.setColor(1,0,0)
        for _, e in ipairs(enemigos) do love.graphics.rectangle("fill", e.x, e.y, 30, 30) end
        love.graphics.pop()

        -- UI
        love.graphics.setColor(0,0,0,0.8); love.graphics.rectangle("fill", 10, 10, 250, 40)
        love.graphics.setColor(1,0,0); love.graphics.rectangle("fill", 15, 15, (p.vida/p.max_vida)*220, 30)
        love.graphics.setColor(1,1,1); love.graphics.print("HP: "..math.floor(p.vida).." | Madera: "..p.madera, 20, 20)

        -- Hotbar
        for i, it in ipairs(hotbar_items) do
            local x = 240 + (i-1)*85
            love.graphics.setColor(0,0,0,0.8)
            if i == slot_sel then love.graphics.setColor(0.3, 0.3, 1) end
            love.graphics.rectangle("fill", x, 520, 75, 75)
            love.graphics.setColor(1,1,1); love.graphics.rectangle("line", x, 520, 75, 75)
            love.graphics.print(it.nombre, x+5, 525, 0, 0.7)
            love.graphics.setColor(1,1,0); love.graphics.print("x"..inventario[it.id], x+45, 570)
        end

        -- Mesa Crafteo
        if inv_abierto then
            love.graphics.setColor(0,0,0,0.9); love.graphics.rectangle("fill", 200, 50, 400, 450, 10, 10)
            love.graphics.setColor(1,1,1); love.graphics.printf("MESA DE CRAFTEO (E)", 200, 70, 400, "center")
            for i=1,9 do
                local r, c = math.floor((i-1)/3), (i-1)%3
                local sx, sy = 300 + c*70, 120 + r*70
                love.graphics.rectangle("line", sx, sy, 64, 64)
                if crafteo_grid[i] == 3 then love.graphics.draw(img[3], sx, sy, 0, 2, 2) end
            end
            if resultado_id > 0 then
                love.graphics.print("CLICK RESULTADO:", 345, 335)
                love.graphics.rectangle("line", 365, 360, 64, 64)
                if img[resultado_id] then love.graphics.draw(img[resultado_id], 365, 360, 0, 2, 2) end
            end
        end

        if estado == "pausa" then
            love.graphics.setColor(0,0,0,0.8); love.graphics.rectangle("fill", 0, 0, 800, 600)
            love.graphics.setColor(1,1,1); love.graphics.setFont(fuente_titulo)
            love.graphics.printf("PAUSA", 0, 150, 800, "center")
            love.graphics.setFont(fuente_juego)
            love.graphics.printf("P: Volver | G: Guardar | M: Salir", 0, 300, 800, "center")
        end
    end
end

function love.keypressed(key)
    if key == "return" and estado == "menu" then estado = "jugando" end
    if key == "p" then estado = (estado == "jugando") and "pausa" or "jugando" end
    if key == "e" and estado == "jugando" then inv_abierto = not inv_abierto end
    if key == "g" and estado == "pausa" then guardar_partida() end
    if key == "m" and estado == "pausa" then estado = "menu" end
    if tonumber(key) and tonumber(key) <= 4 then slot_sel = tonumber(key) end
    if key == "space" and estado == "jugando" then
        atacando = 0.2
        for i=#enemigos,1,-1 do
            if math.sqrt((enemigos[i].x-p.x)^2 + (enemigos[i].y-p.y)^2) < 110 then table.remove(enemigos, i) end
        end
    end
end

function love.mousepressed(x, y, button)
    if inv_abierto then
        for i=1,9 do
            local r, c = math.floor((i-1)/3), (i-1)%3
            local sx, sy = 300 + c*70, 120 + r*70
            if x > sx and x < sx+64 and y > sy and y < sy+64 then
                if crafteo_grid[i] == 0 and p.madera > 0 then crafteo_grid[i] = 3; p.madera = p.madera-1
                elseif crafteo_grid[i] == 3 then crafteo_grid[i] = 0; p.madera = p.madera+1 end
                local s = ""; for j=1,9 do s = s .. crafteo_grid[j] end; resultado_id = recetas[s] or 0
            end
        end
        if resultado_id > 0 and x > 365 and x < 429 and y > 360 and y < 424 then
            inventario[resultado_id] = inventario[resultado_id] + 1
            for i=1,9 do crafteo_grid[i] = 0 end; resultado_id = 0
        end
        return
    end
    if estado ~= "jugando" then return end
    local cx, cy = p.x - 400, p.y - 300
    local col, fil = math.floor((x+cx)/tile)+1, math.floor((y+cy)/tile)+1
    if not mapa[fil] or not mapa[fil][col] then return end
    if button == 1 then
        local id = hotbar_items[slot_sel].id
        if inventario[id] > 0 and mapa[fil][col] == 1 then
            mapa[fil][col] = id; inventario[id] = inventario[id] - 1
        end
    elseif button == 2 and mapa[fil][col] == 3 then
        mapa[fil][col] = 1; p.madera = p.madera + 2
    end
end