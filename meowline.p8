pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- variables del jugador
player = {
    x = 0,
    y = 0,
    dx = 0,
    dy = 0,
    w = 8,
    h = 8,
    grounded = false
}

-- gravedad y velocidad
gravity = 0.3
jump_power = -5
move_speed = 2

-- plataformas
platforms = {
--    {x = 0, y = 96, w = 1020, h = 8}, -- plataforma larga
--    {x = 64, y = 64, w = 8, h = 8}    -- bloque en x=64, y=64
}

-- funciれはn para dibujar
function _draw()
    cls()

    map(0, 0, 0, 0, 128, 128)
    -- centrar la cれくmara en el jugador
    local cam_x = mid(0, player.x - 64, 1024 - 128) -- ajustar lれとmites del mapa
    local cam_y = mid(0, player.y - 64, 256 - 128)
    camera(cam_x, cam_y)

    -- dibujar jugador
    rectfill(player.x, player.y, player.x + player.w, player.y + player.h, 7)

    -- dibujar plataformas
    for p in all(platforms) do
        rectfill(p.x, p.y, p.x + p.w, p.y + p.h, 6)
    end
end

-- funciれはn para actualizar
function _update()
    -- movimiento horizontal
    if btn(0) then -- izquierda
        player.dx = -move_speed
    elseif btn(1) then -- derecha
        player.dx = move_speed
    else
        player.dx = 0
    end

    -- salto
    if btnp(4) and player.grounded then
        player.dy = jump_power
        player.grounded = false
    end

    -- aplicar gravedad
    player.dy += gravity

    -- actualizar posiciれはn
    player.x += player.dx
    player.y += player.dy

    -- colisiれはn con plataformas
    player.grounded = false
    for p in all(platforms) do
        if player.x + player.w > p.x and player.x < p.x + p.w and
           player.y + player.h > p.y and player.y + player.h <= p.y + p.h then
            player.y = p.y - player.h
            player.dy = 0
            player.grounded = true
        end
    end

    -- evitar salir de los lれとmites del mapa
    if player.x < 0 then player.x = 0 end
    if player.x + player.w > 1024 then player.x = 1024 - player.w end
    if player.y > 2000 then player.y = 256 end
end
__gfx__
00000000333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000555333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
