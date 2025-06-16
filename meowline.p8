pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- variables

-- Activar modo debugging (se ven las hitboxes)
debugging = false;

player = {
    x = 64,
    y = 80,
    dx = 0,
    dy = 0,
    w = 12,
    h = 16,
    grounded = false,
    der = true,
    anim_frame = 0,
    anim_timer = 0,
    anim_speed = 8,
    walking = false,
    lives = 7
}

-- Estados del juego
game_state = "menu" -- Estados: "menu", "playing", "game_over", "victory"

-- Coordenadas de las zonas
menu_zone = {x = 1, y = 448}
game_over_zone = {x = 192, y = 448} 
game_start_zone = {x = 64, y = 80}
victory_zone = {x = 320, y = 448}

-- Enemigos roombas
roombas = {}
roomba_move_speed = 1
roomba_spawn_sprite = 32
initial_roomba_positions = {}

-- Variables de las ratas
rats = {}
rat_move_speed = 0.5
rat_spawn_sprites = {34, 35, 36}
initial_rat_positions = {}

-- Variables de los murcielagos
bats = {}
bat_speed = 1
bat_spawn_sprite = 39
initial_bat_positions = {}
bat_return_distance = 80  -- 10 bloques * 8 pixeles = 80 pixeles

-- Variables de movimiento
gravity = 0.3
jump_power = -5
move_speed = 2

-- Sistema de maullido
meow_active = false
meow_timer = 0
meow_duration = 30  -- Duracion del maullido en frames
meow_radius = 64    -- Radio de 8 bloques (8 * 8 = 64 pixeles)

-- Indice del sprite solido (suelo)
platform_sprites = { 64, 71 } -- Bloques de plataforma (solo solidos desde arriba)
solid_sprites = { 66, 72 } -- Bloques totalmente solidos (desde todos los lados)
damage_sprites = { 67, 69, 70 } -- Bloques que danan al jugador

-- Sistema de animacion de bloques
animated_blocks = {}

-- Bloque de agua (sprites 69 y 70)
block_timer = 0
block_animation_speed = 20

-- Sistema de checkpoints
checkpoints = {}
current_checkpoint = nil
checkpoint_sprite = 96

checkpoint_animation = {
    active = false,
    x = 0,
    y = 0,
    frame = 0,
    timer = 0,
    speed = 15
}

-- Sistema de paquetes y victoria
doors = {}
door_sprite = 100  -- Sprite de puerta (parte inferior)
door_top_sprite = 84  -- Sprite de puerta (parte superior)
delivered_sprite = 101  -- Sprite cuando se entrega el paquete
score = 0  -- Paquetes entregados
target_score = 0  -- Total de puertas en el mapa

-->8
-- Funciones de colisiones

-- Funcion para verificar si un sprite es una plataforma
function is_platform_sprite(sprite_id)
    for platform in all(platform_sprites) do
        if sprite_id == platform then
            return true
        end
    end
    return false
end

-- Funcion para verificar si un sprite es un bloque solido
function is_solid_sprite(sprite_id)
    for solid in all(solid_sprites) do
        if sprite_id == solid then
            return true
        end
    end
    return false
end

-- Funcion para verificar si un sprite es un bloque que dana al jugador
function is_damage_sprite(sprite_id)
    for damage in all(damage_sprites) do
        if sprite_id == damage then
            return true
        end
    end
    return false
end

-- Funcion para detectar bloques solidos
function check_solid_collision(x, y, w, h)
    x = flr(x)
    y = flr(y)
    
    local start_cx = flr(x / 8)
    local end_cx = flr((x + w - 1) / 8)
    local start_cy = flr(y / 8)
    local end_cy = flr((y + h - 1) / 8)

    for cx = start_cx, end_cx do
        for cy = start_cy, end_cy do
            local sprite_id = mget(cx, cy)
            if is_solid_sprite(sprite_id) then
                return true, cx * 8, cy * 8  -- Devolver posicion del bloque
            end
        end
    end

    return false
end

-- Funcion para detectar bloques daninos
function check_damage_collision(x, y, w, h)
    x = flr(x)
    y = flr(y)
    
    local start_cx = flr(x / 8)
    local end_cx = flr((x + w - 1) / 8)
    local start_cy = flr(y / 8)
    local end_cy = flr((y + h - 1) / 8)

    for cx = start_cx, end_cx do
        for cy = start_cy, end_cy do
            local sprite_id = mget(cx, cy)
            if is_damage_sprite(sprite_id) then
                return true
            end
        end
    end

    return false
end

-- Funcion para detectar plataformas
function check_platform_collision(x, y, w, h)
    x = flr(x)
    y = flr(y)
    
    local start_cx = flr(x / 8)
    local end_cx = flr((x + w - 1) / 8)
    local start_cy = flr(y / 8)
    local end_cy = flr((y + h - 1) / 8)

    for cx = start_cx, end_cx do
        for cy = start_cy, end_cy do
            local sprite_id = mget(cx, cy)
            if is_platform_sprite(sprite_id) then -- Cambio aqui
                return true, cy * 8
            end
        end
    end

    return false
end

function check_ground_collision(x, y, w, h)
    -- Verificar plataformas
    local platform_collided, platform_y = check_platform_collision(x, y, w, h)
    if platform_collided then
        return true, platform_y
    end
    
    -- Verificar bloques solidos
    local solid_collided, _, solid_y = check_solid_collision(x, y, w, h)
    if solid_collided then
        return true, solid_y
    end
    
    return false
end

function check_player_on_roomba()
    for roomba in all(roombas) do
        if player.y + player.h >= roomba.y and player.y + player.h <= roomba.y + 4 and -- Permitir un rango de 4 pixeles
           player.x + player.w > roomba.x and player.x < roomba.x + roomba.w and
           player.dy >= 0 then
            return true, roomba
        end
    end
    
    return false
end

function check_player_over_checkpoint()
    for checkpoint in all(checkpoints) do
        if player.x + player.w > checkpoint.x and 
           player.x < checkpoint.x + checkpoint.w and
           player.y + player.h > checkpoint.y and 
           player.y < checkpoint.y + checkpoint.h then
            return checkpoint
        end
    end
    return nil
end

function check_player_over_door()
    for door in all(doors) do
        if not door.delivered and
           player.x + player.w > door.x and 
           player.x < door.x + door.w and
           player.y + player.h > door.y and 
           player.y < door.y + door.h then
            return door
        end
    end
    return nil
end

function check_player_roomba_side_collision()
    for roomba in all(roombas) do
        if player.x + player.w > roomba.x and player.x < roomba.x + roomba.w and
           player.y + player.h > roomba.y and player.y < roomba.y + roomba.h then

            local on_roomba, _ = check_player_on_roomba()
            if not on_roomba then
                return true
            end
        end
    end

    return false
end

function check_player_rat_collision()
    for rat in all(rats) do
        if player.x + player.w > rat.x and player.x < rat.x + rat.w and
           player.y + player.h > rat.y and player.y < rat.y + rat.h then
            return true
        end
    end
    return false
end

function check_player_bat_collision()
    for bat in all(bats) do
        if player.x + player.w > bat.x and player.x < bat.x + bat.w and
           player.y + player.h > bat.y and player.y < bat.y + bat.h then
            return true
        end
    end
    return false
end

-- Funcion que detecta cualquier sprite donde las roombas se pueden parar
function check_roomba_ground_collision(x, y, w, h)
    x = flr(x)
    y = flr(y)
    
    local start_cx = flr(x / 8)
    local end_cx = flr((x + w - 1) / 8)
    local start_cy = flr(y / 8)
    local end_cy = flr((y + h - 1) / 8)

    for cx = start_cx, end_cx do
        for cy = start_cy, end_cy do
            local sprite_id = mget(cx, cy)
            -- Las roombas pueden pararse en plataformas, bloques solidos Y bloques daninos
            if is_platform_sprite(sprite_id) or is_solid_sprite(sprite_id) or is_damage_sprite(sprite_id) then
                return true, cy * 8
            end
        end
    end

    return false
end

function check_rat_ground_collision(x, y, w, h)
    x = flr(x)
    y = flr(y)
    
    local start_cx = flr(x / 8)
    local end_cx = flr((x + w - 1) / 8)
    local start_cy = flr(y / 8)
    local end_cy = flr((y + h - 1) / 8)

    for cx = start_cx, end_cx do
        for cy = start_cy, end_cy do
            local sprite_id = mget(cx, cy)
            -- Las ratas pueden pararse en plataformas y bloques solidos
            -- Pero no en bloques daninos
            if is_platform_sprite(sprite_id) or is_solid_sprite(sprite_id) then
                return true, cy * 8
            end
        end
    end

    return false
end

function game_over()
    game_state = "game_over"
    player.x = game_over_zone.x
    player.y = game_over_zone.y
    player.dx = 0
    player.dy = 0
    player.grounded = true
    player.is_walking = false
    checkpoint_animation.active = false
end

function manage_damage()
    player.lives -= 1
    
    if player.lives <= 0 then
        game_over()
    else
        -- Reiniciar en checkpoint si hay uno activo, sino en posicion normal
        if current_checkpoint then
            player.x = current_checkpoint.x
            player.y = current_checkpoint.y - player.h
        else
            player.x = game_start_zone.x
            player.y = game_start_zone.y
        end
        player.dx = 0
        player.dy = 0
        player.grounded = false
    end
end

function victory()
    -- Ir a la pantalla de victoria
    game_state = "victory"
    player.x = victory_zone.x
    player.y = victory_zone.y
    player.dx = 0
    player.dy = 0
    player.grounded = true
    player.is_walking = false
    checkpoint_animation.active = false
end

function deliver_package(door)
    door.delivered = true
    score += 1
    
    -- Cambiar sprite en el mapa (parte inferior)
    local map_x = door.x / 8
    local map_y = (door.y + 8) / 8  -- Parte inferior de la puerta
    mset(map_x, map_y, delivered_sprite)  -- Cambiar sprite 100 a 101
    
    -- Verificar victoria
    if score >= target_score then
        victory()
    end
end

-->8
-- Funciones para inicializacion del juego

-- Funcion de inicializacion de todos los enemigos, entidades y objetos del mapa
function _init()
    spawn_enemies_from_map()
    spawn_checkpoints_from_map()
    spawn_doors_from_map()
    find_animated_blocks()
end

-- Funcion para escanear el mapa y crear enemigos (por ahora solo roombas)
function spawn_enemies_from_map()
    -- Limpiar arrays existentes
    roombas = {} 
    rats = {}

    -- Si es la primera vez, escanear el mapa y guardar posiciones
    if #initial_roomba_positions == 0 then
        for mx = 0, 127 do
            for my = 0, 31 do
                if mget(mx, my) == roomba_spawn_sprite then
                    add(initial_roomba_positions, {x = mx * 8, y = my * 8})
                    mset(mx, my, 0) -- Eliminar del mapa solo la primera vez
                end
            end
        end
    end

    if #initial_rat_positions == 0 then
        for mx = 0, 127 do
            for my = 0, 31 do
                local sprite_id = mget(mx, my)
                -- Verificar si es alguna de las 3 variantes de rata
                for i, rat_sprite in ipairs(rat_spawn_sprites) do
                    if sprite_id == rat_sprite then
                        add(initial_rat_positions, {
                            x = mx * 8, 
                            y = my * 8, 
                            variant = i  -- Guardar que variante es (1, 2, o 3)
                        })
                        mset(mx, my, 0) -- Eliminar del mapa
                        break
                    end
                end
            end
        end
    end

    if #initial_bat_positions == 0 then
        for mx = 0, 126 do
            for my = 0, 31 do
                if mget(mx, my) == bat_spawn_sprite then
                    add(initial_bat_positions, {x = mx * 8, y = my * 8})
                    mset(mx, my, 0)
                    mset(mx + 1, my, 0)
                end
            end
        end
    end

    -- Crear enemigos desde las posiciones guardadas
    for pos in all(initial_roomba_positions) do
        local new_roomba = {
            x = pos.x,
            y = pos.y,
            dx = roomba_move_speed,
            w = 16,
            h = 8,
            grounded = false,
            anim_frame = 0,
            anim_timer = 0,
            anim_speed = 5
        }
        add(roombas, new_roomba)
    end

    for pos in all(initial_rat_positions) do
        local new_rat = {
            x = pos.x,
            y = pos.y,
            dx = rat_move_speed,
            w = 8,
            h = 8,
            grounded = false,
            scared = false, -- Si esta asustada por el maullido
            variant = pos.variant, -- Que variante de color es
            anim_frame = 0,
            anim_timer = 0,
            anim_speed = 10
        }
        add(rats, new_rat)
    end

    for pos in all(initial_bat_positions) do
        local new_bat = {
            x = pos.x,
            y = pos.y,
            spawn_x = pos.x,  -- Posicion inicial para volver
            spawn_y = pos.y,  -- Posicion inicial para volver
            dx = 0,
            dy = 0,
            w = 16,
            h = 8,
            state = "idle", -- Estados: "idle", "attacking", "returning"
            anim_frame = 0,
            anim_timer = 0,
            anim_speed = 15
        }
        add(bats, new_bat)
    end
end

function spawn_checkpoints_from_map()
    checkpoints = {} -- limpiar array existente
    
    -- Escanear todo el mapa buscando checkpoints
    for mx = 0, 126 do -- 126 porque el checkpoint es de 2 sprites de ancho
        for my = 0, 31 do
            if mget(mx, my) == checkpoint_sprite then
                -- Crear nuevo checkpoint en esta posicion
                local new_checkpoint = {
                    x = mx * 8,
                    y = my * 8,
                    w = 16,
                    h = 8,
                    activated = false
                }
                add(checkpoints, new_checkpoint)
            end
        end
    end
end

function spawn_doors_from_map()
    doors = {} -- limpiar array existente
    target_score = 0  -- resetear contador
    
    -- Escanear todo el mapa buscando puertas
    for mx = 0, 126 do
        for my = 0, 31 do
            if mget(mx, my) == door_sprite or mget(mx, my) == delivered_sprite then
                local new_door = {
                    x = mx * 8,
                    y = (my - 1) * 8,
                    w = 8,
                    h = 16,
                    delivered = false
                }
                add(doors, new_door)

                target_score += 1  -- Contar total de puertas
            end
        end
    end
end

function find_animated_blocks()
    animated_blocks = {} -- limpiar array existente
    
    -- Escanear todo el mapa buscando bloques de agua (sprite 69)
    for mx = 0, 127 do
        for my = 0, 31 do
            if mget(mx, my) == 69 then
                add(animated_blocks, {x = mx, y = my, original_sprite = 69})
            end
        end
    end
end

-->8
-- Funciones de dibujo

function _draw()
    cls()

    map(0, 0, 0, 0, 128, 128)

    -- Dibujar checkpoints y puertas antes de la camara, ya que sino estos dan la ilusion de moverse
    draw_checkpoints()
    draw_doors()
    draw_roombas()
    draw_rats()
    draw_bats()

    local cam_x = mid(0, player.x - 64, 1024 - 128)
    local cam_y = player.y - 64
    camera(cam_x, cam_y)

    if game_state == "playing" then
        local sprite_id
        if meow_active then
            sprite_id = 12 -- Sprite del maullido
        elseif not player.grounded then
            if player.dy < 0 then
                sprite_id = 8  -- Sprite para cuando esta subiendo
            else
                sprite_id = 10 -- Sprite para cuando esta cayendo
            end
        elseif player.is_walking then
            -- En el suelo y caminando: usar animacion de caminar
            local walk_sprites = {2, 4, 6}
            sprite_id = walk_sprites[player.anim_frame + 1]
        else
            -- En el suelo y parado: sprite idle
            sprite_id = 0
        end

        spr(sprite_id, player.x - 2, player.y, 2, 2, player.der)

        if meow_active then
            -- Determinar que sprite usar basado en el timer del maullido
            local front_sprite_id
            if flr(meow_timer / 8) % 2 == 0 then -- Cambiar cada 8 frames
                front_sprite_id = 14 -- Sprite 13 (2 de alto, 1 de largo: 13, 29)
            else
                front_sprite_id = 15 -- Sprite 14 (2 de alto, 1 de largo: 14, 30)
            end
            
            -- Posicionar el sprite enfrente del gato segun su direccion
            local front_x
            if player.der then -- Mirando a la derecha
                front_x = player.x + player.w + 2
            else -- Mirando a la izquierda
                front_x = player.x - 10 
            end
            
            spr(front_sprite_id, front_x, player.y, 1, 2, player.der)  -- 1 de ancho, 2 de alto
        end
    end
    
    if debugging then
        -- Dibuja el area de colision de todas las roombas
        for roomba in all(roombas) do
            rect(roomba.x, roomba.y, roomba.x + roomba.w, roomba.y + roomba.h, 8)
        end

        -- Dibuja el area de colision del jugador
        rect(player.x, player.y, player.x + player.w, player.y + player.h, 9)
    end

    if game_state == "playing" then
        -- Mostrar vidas durante el juego
        for i = 1, player.lives do
            spr(98, cam_x + 2 + (i - 1) * 10, cam_y + 2, 1, 1)
        end

        -- Mostrar puntuacion durante el juego
        print("packages: " .. score .. "/" .. target_score, cam_x + 2, cam_y + 12, 7)


        -- Mostrar indicaciones de interaccion con la tecla "X"
        local door_below = check_player_over_door()
        local checkpoint_below = check_player_over_checkpoint()
        
        if door_below then
            print("press x to deliver", cam_x + 30, cam_y + 115, 7)
        elseif checkpoint_below and not checkpoint_below.activated then
            print("press x to save", cam_x + 30, cam_y + 115, 7)
        end

    elseif game_state == "menu" then
        -- Texto del menu
        print("press z to start", cam_x + 32, cam_y + 100, 7)
    elseif game_state == "game_over" then
        -- Texto de game over
        print("press x for menu", cam_x + 32, cam_y + 110, 8)
    elseif game_state == "victory" then
        -- Textos de victoria
        print("congratulations on delivering", cam_x + 5, cam_y + 40, 7)
        print("all packages!", cam_x + 35, cam_y + 50, 7)
        print("zoo york and its inhabitants", cam_x + 8, cam_y + 70, 7)
        print("thank you for your contribution!", cam_x + 2, cam_y + 80, 7)
        print("press x to return to menu", cam_x + 15, cam_y + 110, 8)
    end
end

-- Funcion para dibujar a las roombas
function draw_roombas()
    for roomba in all(roombas) do
        local sprite_id
        if roomba.anim_frame == 0 then
            sprite_id = 32  -- Sprites 32-33
        else
            sprite_id = 48  -- Sprites 48-49
        end
        
        spr(sprite_id, roomba.x, roomba.y, 2, 1)
    end
end

function draw_rats()
    for rat in all(rats) do
        local sprite_id
        
        -- Determinar el sprite basado en la variante y frame de animaciれはn
        if rat.anim_frame == 0 then
            -- Frame 1: sprites 34, 35, 36
            sprite_id = rat_spawn_sprites[rat.variant]
        else
            -- Frame 2: sprites 50, 51, 52
            sprite_id = rat_spawn_sprites[rat.variant] + 16 -- 34+16=50, 35+16=51, 36+16=52
        end
        
        -- Determinar si el sprite debe estar espejado
        local flip_x = rat.dx > 0  -- Si se mueve hacia la derecha, espejar
        
        spr(sprite_id, rat.x, rat.y, 1, 1, flip_x)
    end
end

function draw_bats()
    for bat in all(bats) do
        local sprite_id
        
        if bat.state == "idle" then
            -- Comportamiento 1: sprite estatico 39-40
            sprite_id = 39
        else
            -- Comportamiento 2 y 3: alternar entre 37-38 y 53-54
            if bat.anim_frame == 0 then
                sprite_id = 37  -- Sprites 37-38
            else
                sprite_id = 53  -- Sprites 53-54
            end
        end
        
        local flip_x = bat.dx < 0
        
        spr(sprite_id, bat.x, bat.y, 2, 1, flip_x)
    end
end

-- Funcion para dibujar los checkpoints y su animacion
function draw_checkpoints()
    -- Dibujar todos los checkpoints normales
    for checkpoint in all(checkpoints) do
        spr(96, checkpoint.x, checkpoint.y, 2, 1)
    end
    
    -- Dibujar animacion si esta activa
    if checkpoint_animation.active then
        local anim_sprites = {80, 82}
        local current_sprite = anim_sprites[checkpoint_animation.frame + 1]
        spr(current_sprite, checkpoint_animation.x, checkpoint_animation.y, 2, 1)
    end
end

-- Funcion para dibujar las puertas
function draw_doors()
    for door in all(doors) do
        if not door.delivered then
            -- Dibujar puerta no entregada (sprites 84 arriba, 100 abajo)
            spr(84, door.x, door.y, 1, 1)
            spr(100, door.x, door.y + 8, 1, 1)
        else
            -- Dibujar puerta entregada (sprites 84 arriba, 101 abajo)
            spr(84, door.x, door.y, 1, 1)
            spr(101, door.x, door.y + 8, 1, 1)
        end
    end
end

-->8
-- Funciones de actualizacion

function _update()
    if game_state == "menu" then
        update_menu()
    elseif game_state == "playing" then
        update_playing()
    elseif game_state == "game_over" then
        update_game_over()
    elseif game_state == "victory" then
        update_victory()
    end
end

-- Funcion para actualizar el juego
function update_playing()

    if not meow_active then
        -- Movimiento del jugador
        if btn(0) then -- izquierda
            player.dx = -move_speed
            player.der = false
            player.is_walking = true
        elseif btn(1) then -- derecha
            player.dx = move_speed
            player.der = true
            player.is_walking = true
        else
            player.dx = 0
            player.is_walking = false
            player.anim_frame = 0
        end
    else
        -- Si el maullido esta activo, no se puede mover
        player.dx = 0
        player.is_walking = false
        player.anim_frame = 0
    end

    if player.is_walking then
        player.anim_timer += 1
        if player.anim_timer >= player.anim_speed then
            player.anim_timer = 0
            player.anim_frame = (player.anim_frame + 1) % 3
        end
    end
    
    if btnp(2) and player.grounded then -- Tecla direccional arriba
        -- Activar maullido
        meow_active = true
        meow_timer = 0
        
        -- Asustar a todas las ratas en el radio
        for rat in all(rats) do
            local distance = sqrt((rat.x + rat.w/2 - player.x - player.w/2)^2 + 
                                (rat.y + rat.h/2 - player.y - player.h/2)^2)
            
            if distance <= meow_radius then
                rat.scared = true
                -- Cambiar direccion para alejarse del jugador
                if rat.x + rat.w/2 < player.x + player.w/2 then
                    rat.dx = -abs(rat.dx)  -- Ir hacia la izquierda
                else
                    rat.dx = abs(rat.dx)   -- Ir hacia la derecha
                end
            end
        end

        for bat in all(bats) do
            if bat.state == "idle" then
                local distance = sqrt((bat.x + bat.w/2 - player.x - player.w/2)^2 + 
                                    (bat.y + bat.h/2 - player.y - player.h/2)^2)
                
                if distance <= meow_radius then
                    bat.state = "attacking"
                end
            end
        end
    end

    -- Actualizar timer del maullido
    if meow_active then
        meow_timer += 1
        if meow_timer >= meow_duration then
            meow_active = false
            meow_timer = 0
        end
    end

    -- Salto
    if btnp(4) and player.grounded and not meow_active then
        player.dy = jump_power
        player.grounded = false
    end

    -- Revisar interacciones del mapa
    if btnp(5) then -- X button
        local checkpoint_below = check_player_over_checkpoint()
        if checkpoint_below and not checkpoint_below.activated then
            -- Activar el checkpoint (ganar vida y guardar posicion)
            checkpoint_below.activated = true
            current_checkpoint = checkpoint_below
            player.lives += 1  -- Ganar 1 vida extra
            
            -- Activar animacion sobre el checkpoint
            checkpoint_animation.active = true
            checkpoint_animation.x = checkpoint_below.x
            checkpoint_animation.y = checkpoint_below.y - 8  -- 8 poxeles arriba del checkpoint
            checkpoint_animation.frame = 0
            checkpoint_animation.timer = 0
        end

        local door_below = check_player_over_door()
        if door_below then
            deliver_package(door_below)
        end
    end

    -- Actualizar animacion del checkpoint si esta activa
    if checkpoint_animation.active then
        checkpoint_animation.timer += 1
        if checkpoint_animation.timer >= checkpoint_animation.speed then
            checkpoint_animation.timer = 0
            checkpoint_animation.frame = (checkpoint_animation.frame + 1) % 2  -- Alterna entre 0 y 1
        end
    end

    -- Aplicar gravedad
    player.dy += gravity

    local new_x = player.x + player.dx
    if check_solid_collision(new_x, player.y, player.w, player.h) then
        player.dx = 0
    else
        player.x = new_x
    end

    -- Verificar si esta sobre roomba
    local on_roomba, current_roomba = check_player_on_roomba()
    if on_roomba then
        player.grounded = true
        player.y = current_roomba.y - player.h
        player.dy = 0
        
        local potential_new_x = player.x + current_roomba.dx
        
        local horizontal_collision = check_solid_collision(potential_new_x, player.y, player.w, player.h)
        
        -- El jugador puede moverse con la roomba sin problemas, no hay bloques solidos delante
        if not horizontal_collision then
            player.x += current_roomba.dx
        
        -- El jugador tiene un bloque solido delante, no puede atravesarlo, pero puede saltar
        elseif horizontal_collision then
                player.grounded = true
        end
    else
        local new_y = player.y + player.dy
        if check_solid_collision(player.x, new_y, player.w, player.h) then
            if player.dy > 0 then
                player.grounded = true
                player.dy = 0
                -- Ajustar posicion para estar justo encima del bloque
                local _, _, block_y = check_solid_collision(player.x, new_y, player.w, player.h)
                player.y = block_y - player.h
            else  -- Subiendo (golpeo el techo)
                player.dy = 0
                local _, _, block_y = check_solid_collision(player.x, new_y, player.w, player.h)
                player.y = block_y + 8  -- Posicionar debajo del bloque
            end
        else
            player.y = new_y  -- Aplicar movimiento vertical

            -- Verificar colision con el suelo (plataformas y solidos)
            player.grounded = false
            local collided, ground_y = check_ground_collision(player.x, player.y + player.h, player.w, 1)
            if collided and player.dy >= 0 then
                player.y = ground_y - player.h
                player.dy = 0
                player.grounded = true
            end
        end
    end

    -- Verificar colision con bloques que danan al jugador
    if check_damage_collision(player.x, player.y, player.w, player.h) then
        manage_damage()
    end

    -- Verificar colision lateral con roomba
    if check_player_roomba_side_collision() then
        manage_damage()
    end

    -- Verificar colision con ratas
    if check_player_rat_collision() then
        manage_damage()
    end

    -- Verificar colision con murcielagos
    if check_player_bat_collision() then
        manage_damage()
    end

    -- Limites del mapa
    if player.x < 0 then player.x = 0 end
    if player.x + player.w > 1024 then player.x = 1024 - player.w end
    if player.y > 256 then player.y = 256 end

    -- Actualizar todos los enemigos
    update_roombas()
    update_rats()
    update_bats()
    update_animated_blocks()
end

-- Funcion para actualizar las roombas
function update_roombas()
    for roomba in all(roombas) do
        -- Manejo de la animacion
        roomba.anim_timer += 1
        if roomba.anim_timer >= roomba.anim_speed then
            roomba.anim_timer = 0
            roomba.anim_frame = (roomba.anim_frame + 1) % 2  -- Alterna entre 0 y 1
        end

        -- Verificar colision horizontal con bloques solidos
        local new_x = roomba.x + roomba.dx
        if check_solid_collision(new_x, roomba.y, roomba.w, roomba.h) then
            roomba.dx = -roomba.dx  -- Cambiar direccion
        else
            roomba.x = new_x  -- Aplicar movimiento
        end

        roomba.grounded = false

        -- Verificar colision con el suelo
        local collided, ground_y = check_roomba_ground_collision(roomba.x, roomba.y + roomba.h, roomba.w, 1)
        if collided then
            roomba.y = ground_y - roomba.h
            roomba.grounded = true
        else
            -- Aplicar gravedad si no esta en el suelo
            roomba.y += gravity
        end

        -- Verificar colision frontal
        local front_x = roomba.x + (roomba.dx > 0 and roomba.w or -1)
        local front_y = roomba.y + roomba.h - 1
        local front_collided = check_roomba_ground_collision(front_x, front_y, 1, 1) or 
                             check_solid_collision(front_x, front_y, 1, 1)

        -- Verificar si hay suelo delante
        local below_front_x = roomba.x + (roomba.dx > 0 and roomba.w or -1)
        local below_front_y = roomba.y + roomba.h + 1
        local below_front_collided = check_roomba_ground_collision(below_front_x, below_front_y, 1, 1)

        -- Cambiar de direccion si hay obstaculo o no hay suelo
        if front_collided or not below_front_collided then
            roomba.dx = -roomba.dx
        end
    end
end

function update_rats()
    for rat in all(rats) do
        -- Manejo de la animacion
        rat.anim_timer += 1
        if rat.anim_timer >= rat.anim_speed then
            rat.anim_timer = 0
            rat.anim_frame = (rat.anim_frame + 1) % 2
        end

        -- Verificar colision horizontal con bloques solidos
        local new_x = rat.x + rat.dx
        if check_solid_collision(new_x, rat.y, rat.w, rat.h) then
            rat.dx = -rat.dx  -- Cambiar direccion si choca con pared
        else
            rat.x = new_x  -- Aplicar movimiento
        end

        rat.grounded = false

        -- Verificar colision con el suelo
        local collided, ground_y = check_rat_ground_collision(rat.x, rat.y + rat.h, rat.w, 1)
        if collided then
            rat.y = ground_y - rat.h
            rat.grounded = true
        else
            -- Aplicar gravedad si no esta en el suelo
            rat.y += gravity
        end

        -- Verificar si pisa bloque danino (solo si no esta asustada)
        if rat.scared and check_damage_collision(rat.x, rat.y + rat.h - 1, rat.w, 1) then
            -- La rata muere al pisar bloque danino
            del(rats, rat)
        else
            -- Verificar colision frontal y suelo delante
            local front_x = rat.x + (rat.dx > 0 and rat.w or -1)
            local front_y = rat.y + rat.h - 1
            local front_collided = check_rat_ground_collision(front_x, front_y, 1, 1) or 
                                 check_solid_collision(front_x, front_y, 1, 1)

            local below_front_x = rat.x + (rat.dx > 0 and rat.w or -1)
            local below_front_y = rat.y + rat.h + 1
            local below_front_collided = check_rat_ground_collision(below_front_x, below_front_y, 1, 1)

            -- Cambiar de direccion si hay obstaculo o no hay suelo (solo si no esta asustada)
            if not rat.scared and (front_collided or not below_front_collided) then
                rat.dx = -rat.dx
            end
        end
    end
end

function update_bats()
    for bat in all(bats) do
        -- Manejo de la animacion
        bat.anim_timer += 1
        if bat.anim_timer >= bat.anim_speed then
            bat.anim_timer = 0
            bat.anim_frame = (bat.anim_frame + 1) % 2
        end

        if bat.state == "idle" then
            -- Comportamiento 1: Quieto, solo flotando
            bat.dx = 0
            bat.dy = 0
            
        elseif bat.state == "attacking" then
            -- Comportamiento 2: Perseguir al jugador
            
            -- Calcular direccion hacia el jugador
            local target_x = player.x + player.w/2
            local target_y = player.y + player.h/2
            local bat_center_x = bat.x + bat.w/2
            local bat_center_y = bat.y + bat.h/2
            
            local distance_to_player = sqrt((target_x - bat_center_x)^2 + (target_y - bat_center_y)^2)
            local distance_to_spawn = sqrt((bat.spawn_x - bat.x)^2 + (bat.spawn_y - bat.y)^2)
            
            -- Si esta muy lejos del spawn, volver
            if distance_to_spawn > bat_return_distance then
                bat.state = "returning"
            else
                -- Moverse hacia el jugador
                if distance_to_player > 0 then
                    bat.dx = ((target_x - bat_center_x) / distance_to_player) * bat_speed
                    bat.dy = ((target_y - bat_center_y) / distance_to_player) * bat_speed
                end
            end
            
        elseif bat.state == "returning" then
            -- Comportamiento 3: Volver al spawn
            -- Volver al spawn
            local bat_center_x = bat.x + bat.w/2
            local bat_center_y = bat.y + bat.h/2
            local distance_to_spawn = sqrt((bat.spawn_x - bat_center_x)^2 + (bat.spawn_y - bat_center_y)^2)
            
            if distance_to_spawn < 8 then -- Cerca del spawn
                bat.state = "idle"
                bat.x = bat.spawn_x
                bat.y = bat.spawn_y
                bat.dx = 0
                bat.dy = 0
            else
                -- Moverse hacia el spawn
                bat.dx = ((bat.spawn_x - bat_center_x) / distance_to_spawn) * bat_speed
                bat.dy = ((bat.spawn_y - bat_center_y) / distance_to_spawn) * bat_speed
            end
        end

        -- Aplicar movimiento con verificacion de colision con bloques solidos
        local new_x = bat.x + bat.dx
        local new_y = bat.y + bat.dy
        
        -- Verificar colision horizontal
        if not check_solid_collision(new_x, bat.y, bat.w, bat.h) then
            bat.x = new_x
        else
            bat.dx = 0 -- Detener movimiento horizontal si hay colision
        end
        
        -- Verificar colision vertical
        if not check_solid_collision(bat.x, new_y, bat.w, bat.h) then
            bat.y = new_y
        else
            bat.dy = 0 -- Detener movimiento vertical si hay colision
        end
    end
end

function update_animated_blocks()

    -- Bloque de agua
    block_timer += 1
    
    if block_timer >= block_animation_speed then
        block_timer = 0
        
        -- Alternar entre sprites 69 y 70 para todos los bloques de agua
        for block in all(animated_blocks) do
            local current_sprite = mget(block.x, block.y)
            if current_sprite == 69 then
                mset(block.x, block.y, 70)  -- Cambiar a frame 2
            elseif current_sprite == 70 then
                mset(block.x, block.y, 69)  -- Cambiar a frame 1
            end
        end
    end
end

-- Funcion para actualizar el estado de menu
function update_menu()
    -- Posicionar jugador en la zona del menu
    player.x = menu_zone.x
    player.y = menu_zone.y
    player.dx = 0
    player.dy = 0
    player.grounded = true
    player.is_walking = false
    
    -- Solo responder al boton de salto para empezar
    if btnp(4) then -- Z button
        game_state = "playing"
        player.x = game_start_zone.x
        player.y = game_start_zone.y
        player.lives = 7
        current_checkpoint = nil
        score = 0
        checkpoint_animation.active = false
        block_timer = 0
        _init()
    end
end

-- Funcion para actualizar el estado de game over
function update_game_over()
    -- Mantener al jugador en la zona de game over
    player.x = game_over_zone.x
    player.y = game_over_zone.y
    player.dx = 0
    player.dy = 0
    player.grounded = true
    player.is_walking = false
    
    if btnp(5) then -- X - volver al menu
        game_state = "menu"
    end
end

-- Funcion para actualizar el estado de victoria
function update_victory()
    -- Mantener al jugador en la zona de victoria
    player.x = victory_zone.x
    player.y = victory_zone.y
    player.dx = 0
    player.dy = 0
    player.grounded = true
    player.is_walking = false
    
    -- Solo responder al boton X para volver al menu
    if btnp(5) then
        game_state = "menu"
    end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000001100000000ddd
0000000000000000000000000000000000000000000000000000000000000000000677760000000000000000000000000000000000000000001100010000ddd0
000000000000000000000000000000000000000000000000000000000000000700063737600000000000000000000000000000000000000000100111000dd000
000000000000000000000000000000700000000000000070006000000000007000067676000000070000000000000007000000000000000001101100000d00dd
00060060000000000060000000000007006000000000070067776600000000600650555700000060000000000000000700060060000000000100100100dd0dd0
00677760000000006777660000000006677766000000060063737000000000600655666650000600000006060000006000677760000000000101101100d00d00
00637370000000076373700000000060637370000000006067676000000000600066766665500600000677760000006000637370000000070101001000d0d00d
00676760000000066767600000000060676760000000006005557500000000600006666666660600000637370000006000676760000000060101001000d0d00d
00055560000000600555750000000060055575000000006006777755766666000000666666666500000676760055566000055560000000600101001000d0d00d
00067766777700600677775576666600067777500007760007776666666666000000005566666550000055575566660000055566777700600101101100d00d00
00077766666670600777666666666600077766655677660006766666666666000000000055666050000066666666666000077766666670600100100100dd0dd0
000676666667750006766666666666000676666666666600066666655666666000000000006666000000666666666660000676666667750001101100000d00dd
000666666677670006666665566666600666666556666600055600000000506000000000000006600000666666556560000666666677670000100111000dd000
0005566007766500055660000000506000566000000056655060000000050660000000000000006000005666550005600005566007766500001100010000ddd0
00050060057650000500600000005060000560000000006550600000000506000000000000000000000056000000050000050060057650000001100000000ddd
00050060566000000500600000005060000060000000006000000000000000000000000000000000000056000000000000050060566000000000000000000000
00000007700000000000006000000006000000601110000000000111000000011000000000000000000000000000000000000000000000000000000000000000
0000007447000000000000600000006000000060cc111010010111cc000000111100000000000000000000000000000000000000000000000000000000000000
0066664884666600000ff006000ff060000ff006c1cc11a11a11cc1c000001111110000000000000000000000000000000000000000000000000000000000000
0666666666666660005ff006007ff006006ff006c1c1c111111c1c10001cc174471cc10000000000000000000000000000000000000000000000000000000000
76666666666666670505555607077776060666660001c174471c10000011c111111c110000000000000000000000000000000000000000000000000000000000
0666666666666660e5555555e7777777e66666660000014444100000000111111111100000000000000000000000000000000000000000000000000000000000
0066c16666c166000055555000777770006666600000001551000000000011611611000000000000000000000000000000000000000000000000000000000000
00001100001100000015015000670670006706700000000110000000000000100100000000000000000000000000000000000000000000000000000000000000
00000007700000000000000600000060000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000078870000000000006000000060000000601110001001000111000000000000000000000000000000000000000000000000000000000000000000000000
0066668448666600000ff060000ff006000ff0601cc1118118111cc1000000000000000000000000000000000000000000000000000000000000000000000000
0666666666666660005ff006007ff006006ff0061c1cc111111cc1c1000000000000000000000000000000000000000000000000000000000000000000000000
7666666666666667050555560707777606066666001c11744711c100000000000000000000000000000000000000000000000000000000000000000000000000
0666666666666660e5555555e7777777e66666660000014444100000000000000000000000000000000000000000000000000000000000000000000000000000
00661166661166000055555000777770006666600000001551000000000000000000000000000000000000000000000000000000000000000000000000000000
00001c00001c00000051051000760760007607600000000110000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddd111111116666666606000060555555550000000000000000666666661111111100000000000000000000000000000000000000000000000000000000
dd1dd1dd155511156611116666600666533355530333003330003300563665635335353500000000000000000000000000000000000000000000000000000000
d11d11d1111111116161161666600666555555553333333333333333666666665535553300000000000000000000000000000000000000000000000000000000
11111111511155516116611666666666355533353333333333333333355533355555555300000000000000000000000000000000000000000000000000000000
11111111111111116116611611111111555555553333333333333333555555555355335500000000000000000000000000000000000000000000000000000000
11111111155511156161161611111111533355533333333333333333533355535335535500000000000000000000000000000000000000000000000000000000
11111111111111116611116611111111555555553333333333333333555555555555535300000000000000000000000000000000000000000000000000000000
11111111511155516666666611111111355533353333333333333333355533353355555300000000000000000000000000000000000000000000000000000000
00000000000000000808000000000000444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08080000000000000080000000000000446666440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800000000070000000000000007000466cc6640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000006000000000080800600046cccc640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0600600000000600060060008006000046cccc640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67776008080006006777600000060000466cc6640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
63737000800006006373700000060000446666440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67676000000060006767600000006000444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ffffffffffffff00000000000777700444444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000
0ffffffffffffff0000000000777777044444aa444444aa400000000000000000000000000000000000000000000000000000000000000000000000000000000
0fdff88ff88ffdf0088008807677767744444aa444444aa400000000000000000000000000000000000000000000000000000000000000000000000000000000
f0dff888888ffd0f0838838077676777444444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000
f0dfff8888fffd0f0088880077c7c777444444444fffff3400000000000000000000000000000000000000000000000000000000000000000000000000000000
f0fffff88fffff0f0008800007777770444444444ffff3f400000000000000000000000000000000000000000000000000000000000000000000000000000000
00ffffffffffff000000000007676770444444444f3f3ff400000000000000000000000000000000000000000000000000000000000000000000000000000000
00ffffffffffff000000000000767600444444444ff3fff400000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000077000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070700000000000000700000000000077700007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00707070000000000000707000000000070700007070000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700070770770700070700077077700070777707000007777070707000000000000000000000000000000000000000000000000000000000000000000000000
00700777777707707077070707077700070777777077077777077777000000000000000000000000000000000000000000000000000000000000000000000000
00700707007007707077070707070000777770070707070770770070000000000000000000000000000000000000000000000000000000000000000000000000
07000777770770070707077000777700777077770707770777700770000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14141414141414141414141414141414242424242424242424242424242424241414141414141414141414141414141400000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000071727370000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000047576700000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000717273700000000000014240000000007172737000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000475767000000000014240000000000004757670000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000051500000000000014240000000000003600000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000061600000000000014240000000000000616000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000242400000000000014240000000000002424000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14141414141414141414141414141414242424242424242424242424242424241414141414141414141414141414141400000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000200042000000000000000000000000000000600000000000000000000000004242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4342424242000000000000000000000000000000424200000000000000000000004242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000040404040400000000000000000004242000000000000000000000000004242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000041414141410000404040400000420000000000000000000000006000004242000064000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000041414141410000414141410000000000000000000064000000424242424242424242424200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000041414141410000414141410000000000000000004242420000424242424242424242424200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0020000041414141410000414141410000000000000000000000000000424242424242424242420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040400000404040404040404040404043434343434343424242424242424242420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444444444444444444444444444444444427444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444444444444444444444444444444444444444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4747474747474747474747444444444444444444444444444444444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444444444444444444444444444444444444444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444442223244444444444444444444444444444444444444747474444444444444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4848484848484848484545484848484848484848484848484545454848484848484848484848480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
