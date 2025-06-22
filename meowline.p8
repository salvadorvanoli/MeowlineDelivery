pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- variables cambieeesss

-- Activar modo debugging (se ven las hitboxes)
debugging = false

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
game_state = "cinematic" -- Estados: "cinematic", "menu", "playing", "game_over", "victory"

-- Sistema de fondos
background_map = {}
default_background_roofs = 65 -- Sprite de fondo por defecto para techos populares
default_background_sewers = 128 -- Sprite de fondo por defecto para alcantarillas
current_music_side = "left" -- "left" o "right"

-- Coordenadas de las zonas
cinematic_zone = { x = 384, y = 384 } -- Posicion en la cinematica (48*8, 48*8)
menu_zone = { x = 1, y = 448 }
game_over_zone = { x = 192, y = 448 }
game_start_zone = { x = 18, y = 200 }
victory_zone = { x = 320, y = 448 }

-- Variables para la cinematica
cinematic_timer = 0
cinematic_duration = 180 -- 3 segundos a 60 FPS
cinematic_page = 1 -- Pagina actual de la cinematica
cinematic_max_pages = 4 -- Total de paginas

-- Enemigos roombas
roombas = {}
roomba_move_speed = 1
roomba_spawn_sprite = 32
initial_roomba_positions = {}
roomba_hum_playing = false

-- Variables de las ratas
rats = {}
rat_move_speed = 0.5
rat_spawn_sprites = { 34, 35, 36 }
initial_rat_positions = {}

-- Variables de los murcielagos
bats = {}
bat_speed = 1
bat_spawn_sprite = 39
initial_bat_positions = {}
bat_return_distance = 48 -- 10 bloques * 8 pixeles = 80 pixeles
bat_sound_playing = false
bat_sound_channel = 3

-- Variables de movimiento
gravity = 0.3
jump_power = -5
move_speed = 2

-- Sistema de maullido
meow_active = false
meow_timer = 0
meow_duration = 30 -- Duracion del maullido en frames
meow_radius = 64 -- Radio de 8 bloques (8 * 8 = 64 pixeles)

-- Indice del sprite solido (suelo)
platform_sprites = { 64, 71, 94 } -- Bloques de plataforma (solo solidos desde arriba)
solid_sprites = { 43, 44, 66, 71, 72, 73, 74, 75, 76, 77, 78, 95, 102 } -- Bloques totalmente solidos (desde todos los lados)
damage_sprites = { 47, 63, 67, 69, 70, 109 } -- Bloques que danan al jugador

-- Sistema de animacion de bloques
animated_blocks = {}

-- Sistema de carteles
signs = {}
texts = {
        "presiona z para saltar",
        "presiona arriba para maullar, asusta ratas, cuidado con murcielagos!",
        "evita los alambres de espinas!",
        "manten presionado abajo para bajar plataformas",
        "tu objetivo es entregar paquetes, la cantidad actual se muestra arriba",
        "aventurate por las calles de zoo york y entrega todos los paquetes, suerte!",
        "esquiva las amenazas de la ciudad",
        "no siempre se necesita saltar! courier es mas largo de lo que parece"
        }

-- Sistema de botones
buttons = {}
button_range = 256 -- Radio de busqueda en pixeles
button_inactive_sprite = 85
button_active_sprite = 86
door_closed_sprite = 102
door_open_sprite = 103

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

-- Animaciれはn de muerte
death_animation = {
    active = false,
    x = 0,
    y = 0,
    dy = -1, -- Velocidad de subida
    timer = 0,
    duration = 30 -- 1 segundo
}

-- Sistema de paquetes y victoria
doors = {}
door_sprite = 100 -- Sprite de puerta (parte inferior)
door_top_sprite = 84 -- Sprite de puerta (parte superior)
delivered_sprite = 101 -- Sprite cuando se entrega el paquete
score = 0 -- Paquetes entregados
target_score = 0 -- Total de puertas en el mapa

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
                return true, cx * 8, cy * 8 -- Devolver posicion del bloque
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
            if is_platform_sprite(sprite_id) then
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
        if player.y + player.h >= roomba.y and player.y + player.h <= roomba.y + 4
                -- Permitir un rango de 4 pixeles
                and player.x + player.w > roomba.x and player.x < roomba.x + roomba.w
                and player.dy >= 0 then
            return true, roomba
        end
    end

    return false
end

function check_player_over_checkpoint()
    for checkpoint in all(checkpoints) do
        if player.x + player.w > checkpoint.x
                and player.x < checkpoint.x + checkpoint.w
                and player.y + player.h > checkpoint.y
                and player.y < checkpoint.y + checkpoint.h then
            return checkpoint
        end
    end
    return nil
end

function check_player_over_door()
    for door in all(doors) do
        if not door.delivered
                and player.x + player.w > door.x
                and player.x < door.x + door.w
                and player.y + player.h > door.y
                and player.y < door.y + door.h then
            return door
        end
    end
    return nil
end

function check_player_over_button()
    for button in all(buttons) do
        if not button.activated and
           player.x + player.w > button.x and
           player.x < button.x + button.w and
           player.y + player.h > button.y and
           player.y < button.y + button.h then
            return button
        end
    end
    return nil
end

function check_player_over_sign()
    for sign in all(signs) do
        if player.x + player.w > sign.x and
           player.x < sign.x + sign.w and
           player.y + player.h > sign.y and
           player.y < sign.y + sign.h then
            return sign
        end
    end
    return nil
end

function activate_button(button)
    -- Marcar botれはn como activado
    button.activated = true
    mset(button.map_x, button.map_y, button_active_sprite)
    sfx(23)

    -- Buscar la puerta mas cercana
    local closest_door = nil
    local closest_distance = 9999
    local door_count = 0
    
    -- Buscar todas las puertas cerradas en el mapa
    for mx = 0, 127 do
        for my = 0, 30 do
            if mget(mx, my) == door_closed_sprite then
                door_count = door_count + 1
                local door_x = mx * 8
                local door_y = my * 8
                
                -- Distancia Manhattan (sqrt da overflow debido a los valores usados en las operaciones)
                local dx = abs(door_x - button.x)
                local dy = abs(door_y - button.y)
                local distance = dx + dy
                
                if distance <= button_range and distance < closest_distance then
                    closest_distance = distance
                    closest_door = {x = mx, y = my}
                end
            end
        end
    end
    
    if closest_door then
        local found_x = closest_door.x
        local found_y = closest_door.y
        
        local sprite_above = mget(found_x, found_y - 1)
        
        if sprite_above == door_closed_sprite then
            mset(found_x, found_y, 103)
            mset(found_x, found_y - 1, 104)
            sfx(24)
        else
            local sprite_below = mget(found_x, found_y + 1)
            
            if sprite_below == door_closed_sprite then
                mset(found_x, found_y, 104)
                mset(found_x, found_y + 1, 103)
                sfx(24)
            end
        end
        
        return true
    else
        return false
    end
end

function check_player_roomba_side_collision()
    for roomba in all(roombas) do
        if player.x + player.w > roomba.x and player.x < roomba.x + roomba.w
                and player.y + player.h > roomba.y and player.y < roomba.y + roomba.h then
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
        if player.x + player.w > rat.x and player.x < rat.x + rat.w
                and player.y + player.h > rat.y and player.y < rat.y + rat.h then
            return true
        end
    end
    return false
end

function check_player_bat_collision()
    for bat in all(bats) do
        if player.x + player.w > bat.x and player.x < bat.x + bat.w
                and player.y + player.h > bat.y and player.y < bat.y + bat.h then
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
            -- Las roombas pueden pararse en plataformas, bloques solidos y bloques daninos
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
    music(39)
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
    sfx(11)

    if player.lives <= 0 then
        game_over()
    else
        -- Activar animacion de muerte
        death_animation.active = true
        death_animation.x = player.x + player.w / 2 - 4  -- Centrar sprite 99 (8x8)
        death_animation.y = player.y + player.h / 2 - 4  -- Centrar verticalmente
        death_animation.timer = 0
        
        -- Detener movimiento del jugador durante la animacion
        player.dx = 0
        player.dy = 0
        player.is_walking = false
    end
end

function victory()
    music(42)
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
    sfx(5)
    door.delivered = true
    score += 1

    -- Cambiar sprite en el mapa (parte inferior)
    local map_x = door.x / 8
    local map_y = (door.y + 8) / 8
    -- Parte inferior de la puerta
    mset(map_x, map_y, delivered_sprite)
    -- Cambiar sprite 100 a 101

    -- Verificar victoria
    if score >= target_score then
        victory()
    end
end

-->8
-- Funciones para inicializacion del juego

-- Funcion de inicializacion de todos los enemigos, entidades y objetos del mapa
function _init()
    initialize_background_map()
    apply_skybox()
    spawn_enemies_from_map()
    spawn_checkpoints_from_map()
    spawn_doors_from_map()
    reset_buttons_and_doors()
    spawn_buttons_from_map()
    spawn_signs_from_map()
    find_animated_blocks()
    player.walk_sound_timer = 0
end

-- Funcion para escanear el mapa y crear enemigos
function spawn_enemies_from_map()
    -- Limpiar arrays existentes
    roombas = {}
    rats = {}
    bats = {}

    -- Si es la primera vez, escanear el mapa y guardar posiciones
    if #initial_roomba_positions == 0 then
        for mx = 0, 127 do
            for my = 0, 31 do
                if mget(mx, my) == roomba_spawn_sprite then
                    add(initial_roomba_positions, { x = mx * 8, y = my * 8 })
                    mset(mx, my, background_map[mx][my])
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
                        add(
                            initial_rat_positions, {
                                x = mx * 8,
                                y = my * 8,
                                variant = i -- Guardar que variante es (1, 2, o 3)
                            }
                        )
                        mset(mx, my, background_map[mx][my])
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
                    add(initial_bat_positions, { x = mx * 8, y = my * 8 })
                    mset(mx, my, background_map[mx][my])
                    mset(mx + 1, my, background_map[mx + 1][my])
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
            spawn_x = pos.x, -- Posicion inicial para volver
            spawn_y = pos.y, -- Posicion inicial para volver
            dx = 0,
            dy = 0,
            w = 16,
            h = 8,
            state = "idle", -- Estados: "idle", "attacking", "returning"
            anim_frame = 0,
            anim_timer = 0,
            anim_speed = 15,
            attack_timer = 0,
            return_timer = 0
        }
        add(bats, new_bat)
    end
end

function spawn_checkpoints_from_map()
    checkpoints = {}
    -- Limpiar array existente

    -- Escanear todo el mapa buscando checkpoints
    for mx = 0, 126 do
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
    doors = {}
    -- Limpiar array existente
    target_score = 0
    -- Resetear contador

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

                target_score += 1 -- Contar total de puertas
            end
        end
    end
end

function spawn_buttons_from_map()
    buttons = {} --Limpiar array existente
    
    for mx = 0, 127 do
        for my = 0, 30 do
            if mget(mx, my) == button_inactive_sprite then
                local new_button = {
                    x = mx * 8,
                    y = my * 8,
                    map_x = mx,
                    map_y = my,
                    w = 8,
                    h = 8,
                    activated = false
                }
                add(buttons, new_button)
            end
        end
    end
end

function reset_buttons_and_doors()
    -- Resetear todos los botones activados (sprite 86) a inactivos (sprite 85)
    for mx = 0, 127 do
        for my = 0, 30 do
            if mget(mx, my) == button_active_sprite then
                mset(mx, my, button_inactive_sprite)
            end
        end
    end
    
    -- Resetear todas las puertas abiertas (sprites 103 y 104) a cerradas (sprite 102)
    for mx = 0, 127 do
        for my = 0, 30 do
            local sprite_id = mget(mx, my)
            if sprite_id == 103 or sprite_id == 104 then
                mset(mx, my, door_closed_sprite)
            end
        end
    end
    
    -- Resetear el estado de los botones en el array
    for button in all(buttons) do
        button.activated = false
    end
end

function spawn_signs_from_map()
    signs = {} -- Limpiar array existente
    
    for mx = 0, 127 do
        for my = 0, 30 do
            local sprite_id = mget(mx, my)
            -- Verificar si es alguno de los sprites de cartel (87-92)
            if sprite_id >= 55 and sprite_id <= 62 then
                local new_sign = {
                    x = mx * 8,
                    y = my * 8,
                    w = 8,
                    h = 8,
                    text_id = sprite_id - 54 -- sprite 55 = texto 1, 56 = texto 2, etc.
                }
                add(signs, new_sign)
            end
        end
    end
end

function find_animated_blocks()
    animated_blocks = {}
    -- Limpiar array existente

    -- Escanear todo el mapa buscando bloques de agua (sprite 69)
    for mx = 0, 127 do
        for my = 0, 31 do
            if mget(mx, my) == 69 then
                add(animated_blocks, { x = mx, y = my, original_sprite = 69 })
            end
        end
    end
end

function initialize_background_map()
    -- Inicializar todo con fondo vacio
    for x = 0, 127 do
        background_map[x] = {}
        for y = 0, 31 do
            background_map[x][y] = 0 -- Sprite vacio por defecto
        end
    end
    
    -- Establecer fondos personalizados para poner en los espacios dejados por entidades
    -- Zona 1: Techos Populares
    set_background_area(0, 0, 64, 31, default_background_roofs)

    -- Zona 2: Alcantarillas
    set_background_area(65, 0, 127, 31, default_background_sewers)
end

function apply_skybox()
    -- Zona 1: Techos Populares
    local skybox_sprites = {128, 134, 148, 149, 150, 166, 182, 189, 190}
    
    for x = 0, 64 do
        for y = 0, 31 do
            -- Solo asignar sprite aleatorio si no hay sprite en el mapa (sprite 0)
            if mget(x, y) == 0 then
                local random_sprite = skybox_sprites[flr(rnd(#skybox_sprites)) + 1]
                mset(x, y, random_sprite)
            end
        end
    end

    -- Zona 2: Alcantarillas
    for x = 64, 127 do
        for y = 0, 31 do
            -- Solo asignar sprite aleatorio si no hay sprite en el mapa (sprite 0)
            if mget(x, y) == 0 then
                local random_sprite = skybox_sprites[flr(rnd(#skybox_sprites)) + 1]
                mset(x, y, random_sprite)
            end
        end
    end
end

function set_background_area(start_x, start_y, end_x, end_y, sprite_id)
    for x = start_x, end_x do
        for y = start_y, end_y do
            if x >= 0 and x <= 127 and y >= 0 and y <= 31 then
                background_map[x][y] = sprite_id
            end
        end
    end
end

-->8
-- Funciones de dibujo

function _draw()
    cls()

    if game_state == "cinematic" then
        if cinematic_page <= 2 then
            -- Primeras dos paginas: zona (48,48) a (63,63)
            map(48, 48, 0, 0, 16, 16)
        else
            -- Ultimas dos paginas: zona (64,48) a (79,63)
            map(64, 48, 0, 0, 16, 16)
        end

        -- Centrar la camara en la cinematica
        camera(0, 0)

        -- Mostrar texto segun la pagina actual
        if cinematic_page == 1 then
            print_centered("en una ciudad abandonada,", 90, 6)
            print_centered("los humanos se han", 100, 6)
            print_centered("esfumado...", 110, 6)
            
        elseif cinematic_page == 2 then
            print_centered("solo quedan las mascotas", 90, 6)
            print_centered("luchando por sobrevivir", 100, 6)
            print_centered("en las calles vacias.", 110, 6)
            
        elseif cinematic_page == 3 then
            print_centered("courier cat, un gato", 90, 6)
            print_centered("callejero rapido y astuto,", 100, 6)
            print_centered("acepta la mision...", 110, 6)
            
        elseif cinematic_page == 4 then
            print_centered("recorrer las calles", 90, 6)
            print_centered("peligrosas llevando", 100, 6)
            print_centered("esperanza entre todos.", 110, 6)
        end
        
        -- Instrucciones en la parte mas inferior
        print_centered("x: continuar  z: saltar", 120, 8)
        
        -- Indicador de pagina en la esquina superior
        local page_text = cinematic_page .. "/" .. cinematic_max_pages
        print(page_text, 2, 2, 5)  -- Esquina superior izquierda
        
    else
        -- Dibujar el mapa normal para otros estados

        if game_state == "playing" then
            map(0, 0, 0, 0, 128, 31)  -- Solo hasta fila 30 durante el juego
        else
            map(0, 0, 0, 0, 128, 128) -- Mapa completo en menus
        end

        -- Dibujar entidades antes que la camara, ya que sino dan la ilusion de moverse erraticamente
        draw_checkpoints()
        draw_doors()
        draw_roombas()
        draw_rats()
        draw_bats()

        local cam_x = mid(0, player.x - 64, 1024 - 128)
        local cam_y

        -- Aplicar limites de camara solo durante el juego
        if game_state == "playing" then
            cam_y = mid(0, player.y - 64, (30 * 8) - 128)  -- Limitado a 30 bloques durante el juego
        else
            cam_y = player.y - 64  -- Sin limite en menれむs/cinematicas
        end

        camera(cam_x, cam_y)

        if game_state == "playing" then
            local sprite_id
            if meow_active then
                sprite_id = 12 -- Sprite del maullido
            elseif not player.grounded then
                if player.dy < 0 then
                    sprite_id = 8 -- Sprite para cuando esta subiendo
                else
                    sprite_id = 10 -- Sprite para cuando esta cayendo
                end
            elseif player.is_walking then
                -- En el suelo y caminando: usar animacion de caminar
                local walk_sprites = { 2, 4, 6 }
                sprite_id = walk_sprites[player.anim_frame + 1]
            else
                -- En el suelo y parado: sprite idle
                sprite_id = 0
            end

            if not death_animation.active then
                spr(sprite_id, player.x - 2, player.y, 2, 2, player.der)
            end

            if meow_active then
                -- Determinar que sprite usar basado en el timer del maullido
                local front_sprite_id
                if flr(meow_timer / 8) % 2 == 0 then
                    -- Cambiar cada 8 frames
                    front_sprite_id = 14 -- Sprite 13 (2 de alto, 1 de largo: 13, 29)
                else
                    front_sprite_id = 15 -- Sprite 14 (2 de alto, 1 de largo: 14, 30)
                end

                -- Posicionar el sprite enfrente del gato segun su direccion
                local front_x
                if player.der then
                    -- Mirando a la derecha
                    front_x = player.x + player.w + 2
                else
                    -- Mirando a la izquierda
                    front_x = player.x - 10
                end

                spr(front_sprite_id, front_x, player.y, 1, 2, player.der) -- 1 de ancho, 2 de alto
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
            print_multiline_centered_outline("packages: " .. score .. "/" .. target_score, cam_x - 35, cam_y + 12, 7, 0, 120)

            -- Mostrar indicaciones de interaccion con la tecla "X"
            local door_below = check_player_over_door()
            local checkpoint_below = check_player_over_checkpoint()
            local button_below = check_player_over_button()
            local sign_below = check_player_over_sign()

            if door_below then
                print_multiline_centered_outline("presiona x para entregar el paquete", cam_x, cam_y + 100, 7, 0, 120)
            elseif checkpoint_below and not checkpoint_below.activated then
                print_multiline_centered_outline("presiona x para guardar", cam_x, cam_y + 100, 7, 0, 120)
            elseif button_below then
                print_multiline_centered_outline("presiona x para activar", cam_x, cam_y + 100, 7, 0, 120)
            elseif sign_below then
                -- Mostrar el texto del cartel
                local text = texts[sign_below.text_id]
                if text then
                    local num_lines = print_multiline_centered_outline(text, cam_x, cam_y + 100, 10, 0, 120)
                end
            end
        elseif game_state == "menu" then
            -- Texto del menu
            print("press z to start", cam_x + 32, cam_y + 100, 7)
        elseif game_state == "game_over" then
            -- Texto de game over
            print("press x for menu", cam_x + 32, cam_y + 110, 8)
        elseif game_state == "victory" then
            -- Mostrar texto segun la pagina de victoria (centrado horizontalmente)
            if victory_page == 1 then
                print_centered_cam("felicidades!", cam_x, cam_y + 90, 7)
                print_centered_cam("has entregado todos", cam_x, cam_y + 100, 6)
                print_centered_cam("los paquetes.", cam_x, cam_y + 110, 6)
                
            elseif victory_page == 2 then
                print_centered_cam("michi miedin y los", cam_x, cam_y + 90, 6)
                print_centered_cam("habitantes de zoo york", cam_x, cam_y + 100, 6)
                print_centered_cam("agradecen tu contribucion!", cam_x, cam_y + 110, 6)
                
            elseif victory_page == 3 then
                print_centered_cam("gracias por jugar!", cam_x, cam_y + 100, 7)
            end
            
            -- Instrucciones centradas
            print_centered_cam("x: continuar  z: menu", cam_x, cam_y + 120, 8)

         end
    end

    if death_animation.active then
        spr(99, death_animation.x, death_animation.y, 1, 1)
    end
end

-- Funcion para dibujar a las roombas
function draw_roombas()
    for roomba in all(roombas) do
        local sprite_id
        if roomba.anim_frame == 0 then
            sprite_id = 32 -- Sprites 32-33
        else
            sprite_id = 48 -- Sprites 48-49
        end

        spr(sprite_id, roomba.x, roomba.y, 2, 1)
    end
end

function draw_rats()
    for rat in all(rats) do
        local sprite_id

        -- Determinar el sprite basado en la variante y frame de animacion
        if rat.anim_frame == 0 then
            -- Frame 1: sprites 34, 35, 36
            sprite_id = rat_spawn_sprites[rat.variant]
        else
            -- Frame 2: sprites 50, 51, 52
            sprite_id = rat_spawn_sprites[rat.variant] + 16 -- 34+16=50, 35+16=51, 36+16=52
        end

        -- Determinar si el sprite debe estar espejado
        local flip_x = rat.dx > 0 -- Si se mueve hacia la derecha, espejar

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
                sprite_id = 37 -- Sprites 37-38
            else
                sprite_id = 53 -- Sprites 53-54
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
        local anim_sprites = { 80, 82 }
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
    if game_state == "cinematic" then
        update_cinematic()
    elseif game_state == "menu" then
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
    -- Coordenada x de la puerta divisoria
    local door_x = 53 * 8

    -- Determinar de quれた lado estれく el jugador
    local side = player.x < door_x and "left" or "right"

    -- Cambiar mれむsica solo si cambia de lado
    if side != current_music_side then
        if side == "left" then
            music(13)
        else
            music(25) -- Cambia por el pattern que quieras para la derecha
        end
        current_music_side = side
    end

    if not gameplay_music_playing then
        music(13)
        gameplay_music_playing = true
    end

    if death_animation.active then
        death_animation.timer += 1
        death_animation.y += death_animation.dy  -- Mover hacia arriba
        
        -- Si la animacion termino (despues de 1 segundo)
        if death_animation.timer >= death_animation.duration then
            death_animation.active = false
            
            -- Se teleporta al checkpoint
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
        
        -- Durante la animacion, no procesar controles del jugador
        return
    end

    if not meow_active then
        -- Movimiento del jugador
        if btn(0) then
            -- izquierda
            player.dx = -move_speed
            player.der = false
            player.is_walking = true
        elseif btn(1) then
            -- derecha
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

           -- Reproducir solo en frames especれとficos y si esta en el suelo
            if player.grounded and player.anim_frame % 2 == 0 then
                sfx(9)  -- Canal 0
            end
        end
    end

    if btnp(2) and player.grounded then
        -- Tecla direccional arriba
        -- Activar maullido
        meow_active = true
        meow_timer = 0

        -- Asustar a todas las ratas en el radio
        for rat in all(rats) do
            local distance = sqrt((rat.x + rat.w / 2 - player.x - player.w / 2) ^ 2
                    + (rat.y + rat.h / 2 - player.y - player.h / 2) ^ 2)

            if distance <= meow_radius then
                rat.scared = true
                -- Cambiar direccion para alejarse del jugador
                if rat.x + rat.w / 2 < player.x + player.w / 2 then
                    rat.dx = -abs(rat.dx) -- Ir hacia la izquierda
                else
                    rat.dx = abs(rat.dx) -- Ir hacia la derecha
                end
            end
        end

        for bat in all(bats) do
            if bat.state == "idle" then
                local distance = sqrt((bat.x + bat.w / 2 - player.x - player.w / 2) ^ 2
                        + (bat.y + bat.h / 2 - player.y - player.h / 2) ^ 2)

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
        sfx(12)
    end

    -- Revisar interacciones del mapa
    if btnp(5) then
        
        -- Verificar si el jugador esta sobre un checkpoint
        local checkpoint_below = check_player_over_checkpoint()
        if checkpoint_below and not checkpoint_below.activated then
            -- Activar el checkpoint (ganar vida y guardar posicion)
            checkpoint_below.activated = true
            current_checkpoint = checkpoint_below
            player.lives += 1 -- Ganar 1 vida extra

            sfx(4)

            -- Activar animacion sobre el checkpoint
            checkpoint_animation.active = true
            checkpoint_animation.x = checkpoint_below.x
            checkpoint_animation.y = checkpoint_below.y - 8
            checkpoint_animation.frame = 0
            checkpoint_animation.timer = 0
        end

        -- Verificar si el jugador esta sobre una puerta
        local door_below = check_player_over_door()
        if door_below then
            deliver_package(door_below)
        end

        -- Verificar si el jugador esta sobre un boton
        local button_below = check_player_over_button()
        if button_below then
            activate_button(button_below)
        end
    end

    -- Actualizar animacion del checkpoint si esta activa
    if checkpoint_animation.active then
        checkpoint_animation.timer += 1
        if checkpoint_animation.timer >= checkpoint_animation.speed then
            checkpoint_animation.timer = 0
            checkpoint_animation.frame = (checkpoint_animation.frame + 1) % 2 -- Alterna entre 0 y 1
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
            else
                -- Subiendo (golpeo el techo)
                player.dy = 0
                local _, _, block_y = check_solid_collision(player.x, new_y, player.w, player.h)
                player.y = block_y + 8 -- Posicionar debajo del bloque
            end
        else
            player.y = new_y -- Aplicar movimiento verticals

            -- Verificar colision con el suelo (plataformas y solidos)
            player.grounded = false

            -- Solo verificar colision con plataformas si NO se esta presionando abajo
            local check_platforms = not btn(3)

            if btn(3) then sfx(40) end
            
            local collided, ground_y
            if check_platforms then
                collided, ground_y = check_ground_collision(player.x, player.y + player.h, player.w, 1)
            else
                -- Si se presiona abajo, solo verificar bloques solidos, no plataformas
                local solid_collided, _, solid_y = check_solid_collision(player.x, player.y + player.h, player.w, 1)
                collided = solid_collided
                ground_y = solid_y
            end

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
    if player.y > (30 * 8) then player.y = (30 * 8) end

    -- Actualizar todos los enemigos
    update_roombas()
    update_rats()
    update_bats()
    update_animated_blocks()

    local roomba_near = false
for roomba in all(roombas) do
    local px = player.x + player.w/2
    local py = player.y + player.h/2
    local rx = roomba.x + roomba.w/2
    local ry = roomba.y + roomba.h/2
    local dist = sqrt((px - rx)^2 + (py - ry)^2)
    if dist < 16 then
        roomba_near = true
        break
    end
end

if roomba_near then
    if not roomba_hum_playing then
        sfx(6, 2)
        roomba_hum_playing = true
    end
else
    if roomba_hum_playing then
        sfx(-1, 2)
        roomba_hum_playing = false
    end
end
end

-- Funcion para actualizar las roombas
function update_roombas()
    for roomba in all(roombas) do
        -- Manejo de la animacion
        roomba.anim_timer += 1
        if roomba.anim_timer >= roomba.anim_speed then
            roomba.anim_timer = 0
            roomba.anim_frame = (roomba.anim_frame + 1) % 2 -- Alterna entre 0 y 1
        end

        -- Verificar colision horizontal con bloques solidos
        local new_x = roomba.x + roomba.dx
        if check_solid_collision(new_x, roomba.y, roomba.w, roomba.h) then
            roomba.dx = -roomba.dx -- Cambiar direccion
        else
            roomba.x = new_x -- Aplicar movimiento
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
        local front_collided = check_roomba_ground_collision(front_x, front_y, 1, 1)
                or check_solid_collision(front_x, front_y, 1, 1)

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
            rat.dx = -rat.dx -- Cambiar direccion si choca con pared
        else
            rat.x = new_x -- Aplicar movimiento
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
            local front_collided = check_rat_ground_collision(front_x, front_y, 1, 1)
                    or check_solid_collision(front_x, front_y, 1, 1)

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
    local any_bat_attacking = false
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
            bat.attack_timer = 0  -- Reset timer cuando esta idle
            bat.return_timer = 0  -- Reset timer cuando esta idle
            
        elseif bat.state == "attacking" then
            any_bat_attacking = true
            -- Comportamiento 2: Perseguir al jugador
            bat.attack_timer += 1  -- Incrementar timer de ataque
            
            -- Si lleva mas de 3 segundos atacando (180 frames), forzar retorno
            if bat.attack_timer > 180 then
                bat.state = "returning"
                bat.attack_timer = 0
                bat.return_timer = 0
            else
                -- Calcular direccion hacia el jugador
                local target_x = player.x + player.w / 2
                local target_y = player.y + player.h / 2
                local bat_center_x = bat.x + bat.w / 2
                local bat_center_y = bat.y + bat.h / 2

                local distance_to_player = sqrt((target_x - bat_center_x) ^ 2 + (target_y - bat_center_y) ^ 2)
                local distance_to_spawn = sqrt((bat.spawn_x - bat_center_x) ^ 2 + (bat.spawn_y - bat_center_y) ^ 2)

                -- Si esta muy lejos del spawn, volver
                if distance_to_spawn > bat_return_distance then
                    bat.state = "returning"
                    bat.attack_timer = 0
                    bat.return_timer = 0
                else
                    -- Moverse hacia el jugador
                    if distance_to_player > 0 then
                        bat.dx = ((target_x - bat_center_x) / distance_to_player) * bat_speed
                        bat.dy = ((target_y - bat_center_y) / distance_to_player) * bat_speed
                    end
                end
            end
            
        elseif bat.state == "returning" then
            -- Comportamiento 3: Volver al spawn
            bat.return_timer += 1  -- Incrementar timer de retorno
            
            -- Si lleva mas de 2 segundos volviendo (120 frames), teleport
            if bat.return_timer > 120 then
                -- Teleport directo al spawn
                bat.x = bat.spawn_x
                bat.y = bat.spawn_y
                bat.dx = 0
                bat.dy = 0
                bat.state = "idle"
                bat.return_timer = 0
            else
                -- Intentar volver normalmente
                local bat_center_x = bat.x + bat.w / 2
                local bat_center_y = bat.y + bat.h / 2
                local distance_to_spawn = sqrt((bat.spawn_x - bat_center_x) ^ 2 + (bat.spawn_y - bat_center_y) ^ 2)

                if distance_to_spawn < 8 then
                    -- Cerca del spawn - volver a idle
                    bat.state = "idle"
                    bat.x = bat.spawn_x
                    bat.y = bat.spawn_y
                    bat.dx = 0
                    bat.dy = 0
                    bat.return_timer = 0
                else
                    -- Moverse hacia el spawn
                    bat.dx = ((bat.spawn_x - bat_center_x) / distance_to_spawn) * bat_speed
                    bat.dy = ((bat.spawn_y - bat_center_y) / distance_to_spawn) * bat_speed
                end
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
    -- Manejar el sonido del murciれたlago (fuera del bucle)
    if any_bat_attacking and not bat_sound_playing then
        sfx(31, bat_sound_channel)
        bat_sound_playing = true
    elseif not any_bat_attacking and bat_sound_playing then
        sfx(-1, bat_sound_channel)
        bat_sound_playing = false
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
                mset(block.x, block.y, 70) -- Cambiar a frame 2
            elseif current_sprite == 70 then
                mset(block.x, block.y, 69) -- Cambiar a frame 1
            end
        end
    end
end

-- Funcion para actualizar el estado de cinematica
function update_cinematic()

    if not cinematic_music_playing then
        music(0)
        cinematic_music_playing = true
    end

    -- Posicionar jugador en la zona de cinematica (opcional, si quieres mostrar al gato)
    player.x = cinematic_zone.x
    player.y = cinematic_zone.y
    player.dx = 0
    player.dy = 0
    player.grounded = true
    player.is_walking = false

    -- Incrementar timer
    cinematic_timer += 1

  -- Avanzar pagina con X
    if btnp(5) then -- X button
        sfx(2)
        cinematic_page += 1
        if cinematic_page > cinematic_max_pages then
            music(-1)
            game_state = "menu"
            cinematic_timer = 0
            cinematic_page = 1 -- Reset para la proxima vez
        end
    end
    
    -- Saltar cinematica completamente con Z
    if btnp(4) then -- Z button
        sfx(3)
        music(-1)

        game_state = "menu"
        cinematic_timer = 0
        cinematic_page = 1 -- Reset para la proxima vez
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
    if btnp(4) then
        -- Z button
        sfx(3)
        music(13)
        game_state = "playing"
        player.x = game_start_zone.x
        player.y = game_start_zone.y
        player.lives = 7
        current_checkpoint = nil
        score = 0
        checkpoint_animation.active = false
        block_timer = 0
        roomba_hum_playing = false -- RESETEAR SONIDO
        sfx(-1, 2)
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

    if btnp(5) then
        -- X - volver al menu
        sfx(2)
        music(-1)
        game_state = "menu"
        cinematic_timer = 0 -- Reset cinematic timer
    end
end

-- Variables para la victoria
victory_page = 1
victory_max_pages = 3

-- Funcion para actualizar el estado de victoria
function update_victory()
    -- Mantener al jugador en la zona de victoria
    player.x = victory_zone.x
    player.y = victory_zone.y
    player.dx = 0
    player.dy = 0
    player.grounded = true
    player.is_walking = false

    -- Avanzar pagina con X
    if btnp(5) then -- X button
        sfx(2)
        victory_page += 1
        if victory_page > victory_max_pages then
            music(-1)
            game_state = "menu"
            victory_page = 1 -- Reset para la proxima vez
        end
    end
    
    -- Saltar a menu con Z
    if btnp(4) then -- Z button
        sfx(1)
        music(-1)
        game_state = "menu"
        victory_page = 1 -- Reset para la proxima vez
    end
end

-->8
-- Funciones de manejo de texto

function split_text_into_words(text)
    local words = {}
    local current_word = ""
    
    for i = 1, #text do
        local char = sub(text, i, i)
        if char == " " then
            if #current_word > 0 then
                add(words, current_word)
                current_word = ""
            end
        else
            current_word = current_word .. char
        end
    end
    
    -- Agregar la ultima palabra si existe
    if #current_word > 0 then
        add(words, current_word)
    end
    
    return words
end

function wrap_text(text, max_width)
    local words = split_text_into_words(text)
    local lines = {}
    local current_line = ""
    
    for word in all(words) do
        local test_line = current_line
        if #current_line > 0 then
            test_line = current_line .. " " .. word
        else
            test_line = word
        end
        
        -- Si la linea de prueba cabe en el ancho, agregarla
        if #test_line * 4 <= max_width then  -- 4 pixeles por caracter en PICO-8
            current_line = test_line
        else
            -- Si no cabe, guardar la linea actual y empezar nueva
            if #current_line > 0 then
                add(lines, current_line)
            end
            current_line = word
        end
    end
    
    -- Agregar la ultima linea si tiene contenido
    if #current_line > 0 then
        add(lines, current_line)
    end
    
    return lines
end

function print_multiline(text, x, y, color, max_width)
    local lines = wrap_text(text, max_width)
    local line_height = 8 -- Altura entre lineas en PICO-8
    
    for i = 1, #lines do
        local line = lines[i]
        print(line, x, y + (i - 1) * line_height, color)
    end
    
    return #lines -- Devolver numero de lineas para calcular altura total
end

function print_multiline_centered(text, cam_x, y, color, max_width)
    local lines = wrap_text(text, max_width)
    local line_height = 8
    
    for i = 1, #lines do
        local line = lines[i]
        local line_x = cam_x + (128 - #line * 4) / 2  -- Centrar cada linea
        print(line, line_x, y + (i - 1) * line_height, color)
    end
    
    return #lines -- Devolver numero de lineas
end

function print_with_outline(text, x, y, text_color, outline_color)
    -- Dibujar el borde (8 direcciones alrededor del texto)
    print(text, x - 1, y - 1, outline_color)  -- Arriba-izquierda
    print(text, x, y - 1, outline_color)      -- Arriba
    print(text, x + 1, y - 1, outline_color)  -- Arriba-derecha
    print(text, x - 1, y, outline_color)      -- Izquierda
    print(text, x + 1, y, outline_color)      -- Derecha
    print(text, x - 1, y + 1, outline_color)  -- Abajo-izquierda
    print(text, x, y + 1, outline_color)      -- Abajo
    print(text, x + 1, y + 1, outline_color)  -- Abajo-derecha
    
    -- Dibujar el texto principal encima
    print(text, x, y, text_color)
end

function print_multiline_centered_outline(text, cam_x, y, text_color, outline_color, max_width)
    local lines = wrap_text(text, max_width)
    local line_height = 8
    
    for i = 1, #lines do
        local line = lines[i]
        local line_x = cam_x + (128 - #line * 4) / 2  -- Centrar cada linea
        print_with_outline(line, line_x, y + (i - 1) * line_height, text_color, outline_color)
    end
    
    return #lines
end

-- Funcion para imprimir texto centrado horizontalmente
function print_centered(text, y, color)
    local x = (128 - #text * 4) / 2
    print(text, x, y, color)
end

-- Funcion para imprimir texto centrado horizontalmente con camara
function print_centered_cam(text, cam_x, y, color)
    local x = cam_x + (128 - #text * 4) / 2
    print(text, x, y, color)
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
00000007700000000000006000000006000000601110000000000111000000011000000033330000333330006666666666666666000000006666666600000000
0000007447000000000000600000006000000060cc111010010111cc000000111100000033333000333333003636636336366060333000000606636300000333
0066664884666600000ff006000ff060000ff006c1cc11a11a11cc1c000001111110000033333000333333336666666666666666333300006666666600003333
0666666666666660005ff006007ff006006ff006c1c1c111111c1c10001cc174471cc10033333000333333333333333333330000333300000003333300003333
76666666666666670505555607077776060666660001c174471c10000011c111111c110033333000333333333333333333333000333330000003333300033333
0666666666666660e5555555e7777777e66666660000014444100000000111111111100033330000333333333333333333330000333300000000333300003333
0066c16666c166000055555000777770006666600000001551000000000011611611000033333000333333333333333333333000333330000003333300033333
00001100001100000015015000670670006706700000000110000000000000100100000033333000333333333333333333333000333330000003333300033333
00000007700000000000000600000060000000060000000000000000111111111111111111111111111111111111111111111111111111111111111100033333
000000788700000000000060000000600000006011100010010001111ffffff11ffffff11ffffff11ffffff11ffffff11ffffff11ffffff11ffffff100333333
0066668448666600000ff060000ff006000ff0601cc1118118111cc11f66f6f11f66f6f11f66f6f11f66f6f11f66f6f11f66f6f11f66f6f11f66f6f133333333
0666666666666660005ff006007ff006006ff0061c1cc111111cc1c11ffffff11ffffff11ffffff11ffffff11ffffff11ffffff11ffffff11ffffff133333333
7666666666666667050555560707777606066666001c11744711c1001f6666f11f6666f11f6666f11f6666f11f6666f11f6666f11f6666f11f6666f133333333
0666666666666660e5555555e7777777e666666600000144441000001ffffff11ffffff11ffffff11ffffff11ffffff11ffffff11ffffff11ffffff133333333
006611666611660000555550007777700066666000000015510000001f6f66f11f6f66f11f6f66f11f6f66f11f6f66f11f6f66f11f6f66f11f6f66f133333333
00001c00001c00000051051000760760007607600000000110000000111111111111111111111111111111111111111111111111111111111111111133333333
66666666111111116666666660600060555555550000000000000000411111111111111411111111444444444444444441111111111111144444444411111111
16166161155511156611116606060606533355530333003330003300411111111111111411111111411111111111111441111111111111141111111111111111
66666666111111116161161600606060555555553333333333333333411111111111111411111111411111111111111441111111111111141111111111111111
51115551511155516116611600060600355533353333333333333333411111111111111411111111411111111111111441111111111111141111111111111111
11111111111111116116611600606060555555553333333333333333411111111111111411111111411111111111111441111111111111141111111111111111
15551115155511156161161606060606533355533333333333333333411111111111111411111111411111111111111441111111111111141111111111111111
11111111111111116611116660600060555555553333333333333333411111111111111411111111411111111111111441111111111111141111111111111111
51115551511155516666666606000006355533353333333333333333444444444444444444444444411111111111111441111111111111141111111111111111
00000000000000000808000000000000444444441188881111888811000000000000000000000000000000000000000000000000000000006666666688848884
08080000000000000080000000000000446666441888888118888881000000000000000000000000000000000000000000000000000000000606606044444444
00800000000070000000000000007000466cc6648844448888bbbb88000000000000000000000000000000000000000000000000000000006666666648884888
0000000000006000000000080800600046cccc648844448888bbbb88000000000000000000000000000000000000000000000000000000000000000044444444
0600600000000600060060008006000046cccc648844448888bbbb88000000000000000000000000000000000000000000000000000000000000000088848884
67776008080006006777600000060000466cc6648844448888bbbb88000000000000000000000000000000000000000000000000000000000000000044444444
63737000800006006373700000060000446666441888888118888881000000000000000000000000000000000000000000000000000000000000000048884888
67676000000060006767600000006000444444441188881111888811000000000000000000000000000000000000000000000000000000000000000044444444
0ffffffffffffff000000000007777004444444444444444d166661dd111111dd186681d1111144444111111011111104aaaaaa4616111610000333344444444
0ffffffffffffff0000000000777777044444aa444444aa4d166661dd111111dd111111d15551fffff45111511111111a4aaaa4a161616160003333314444444
0fdff88ff88ffdf0088008807677767744444aa444444aa4d186681dd111111dd111111d444444ffff41111111aaaa11aa4aa4aa116161610003333311444444
f0dff888888ffd0f08388380776767774444444444444444d168861dd111111dd111111dffffff4fff4155511aaaaaa1aaa44aaa111616110003333311144444
f0dfff8888fffd0f0088880077c7c777444444444fffff34d168861dd111111dd111111dff66ff4fff4111111aaaaaa1aaa44aaa116161610003333311114444
f0fffff88fffff0f0008800007777770444444444ffff3f4d186681dd111111dd111111dfff66f44444441151aa44aa1aa4aa4aa161616160000333311111444
00ffffffffffff000000000007676770444444444f3f3ff4d166661dd111111dd111111dfff66f4ffffff4110aa44aa0a4aaaa4a616111610003333315551144
00ffffffffffff000000000000767600444444444ff3fff4d166661dd186681dd111111dffff6f4ff66ff451000440004aaaaaa4161111160003333311111114
000000000000000000000000000000000770000070000000000000001111111111111111ffffff4fff66f4110004400000000004444444444000000044444444
000707000000000000007000000000000777000070000000000000001118811111188111ffffff4ffffff4150004400000000044444444444400000044444441
007070700000000000007070000000000707000070700000000000001118811111888811ff666f44444444410004400000000444444444444440000044444411
007000707707707000707000770777000707777070000077770707071118811118188181fff66f4ffffffff40004400000004444444444444444000044444111
007007777777077070770707070777000707777770770777770777771818818111188111ffffff4f66ff6ff40004400000044444444444444444400044441111
007007070070077070770707070700007777700707070707707700701188881111188111ffffff4ffffffff40004400000444444444444444444440044411111
070007777707700707070770007777007770777707077707777007701118811111188111ff666f4fff66fff40004400004444444441111444444444044115551
000000000000000000000000000000000000000000000000000000001111111111111111ffffff4ffffffff40004400044444444411551144444444441111111
00000000000000000000000000000000000fff00f000000000000000000000000000011111111111111111111110000000000000000000000000000000000000
0020000000000000000000002000000000000ff0000000100000000000020000000011011100000000000001111000000000000000000000008808e000000000
00000000000100000000000000000000000000ff0002000000000020000000000000111111011111111111011010000000000000000000000888888e00000000
00000000000000000100000000000f00000000ff000f0000f0000000000000001000111111011111111111011111000000000000000000000888888800000000
00000000000000000100000000000000000000ff01f0f20000000000100000000000001111011100000111011101100000005000005000000888888800000000
000000f0000000001110000100000000f0000fff000f000000000000110000000000011111011000000011011101100000005500055500000088888000000000
000000000000000111100000000000000ffffff00001000200001000110000000000111011010000000001011111000000005555555500000008e80000000000
0000000000020001111100000000000000ffff000000000000000000110000100000111111010000000001011101100000005ffff55500000000800000000000
0000000000000001010100000000000000000000000000000000000001000010000001111101000000000101111110000000f5555f5500000000000000000000
0010000000000001010100000000100000000000000000000000000001010011000011111101000000000101111110000000fc55cfff00000000000000000000
0000000000000001111100010000000000001000000000000000000011110111001111111101100000001101111111000000f5555fff00000000000000000000
00000000011100011111001110000000000000000000010000000000011111111111101111011100000111011111111000000fffffff00000000000000000000
0000000001010001010100101000111000000000000000000000000001110111111111111101111111111101111110100000000ffff000000000000000000000
00111000010100111111001010001100200000000000000000000000111101110110111101011111111111011111101004444444ffff00000000000000000000
111110001111001111111111100111000000000000000000000000001101111011100110010111111111110111111111048484555fff00000000000000000000
110010111111111111011111101111000000010000000000000000001111111111100010000111111111110111111111044844555fff00000000000000000000
11001011111101111111111010111111000000000000000000000000111111111110000000011111110001011111001004444444ffff00500000000000000000
110010100011111011111111111101010000000000000000000000001ddd11111110000003011111110001011111101000000ffffffff0550000000000000000
110010101011111111111111111111110000000000000000000000000dddddd11dd0000003001111111001011111111100000ffffffff0550000000000000000
111110101911111111101111101101010000000000000000000000000ddddddddddd000000001111111111011111111100000ffffffff5550000000000000000
1111101011111101110011111111010100000000006006000000000011111dd444444000000111111111110111111101000000fffffff5500000000000000000
111100101111110011000111111101110000000000677760000000000dddddd5555550000101111111111101111111110000005f00ff00000000000000000000
11011d10101111000000011111111111070000000073736000000000dd0dddd55555500001011111111111011111111100000055005550000000000000000000
11011110dd01110003003011d1111111060000000067676000000000d00dddd55555500001011111111111011111111100000055000550000000000000000000
01011110dd01440000000011d1111111006000000065550000000000d00ddddd0000000001011111111111011111111000000000000000000000000000000000
000111000d0155500000011dd11111110060077776677600000000000d00ddd00000000001011111111111011111111000000000000000000000000000000000
000110000d0055500000111dd11111110060766666677700000000000dd000000000000001000000000000001111110000000000000000000000000000000000
1000000000d0000000011111111111110005776666667600000000000dddddd00000d0dd01111111111111111111110000000000000000000000000000000000
0000000000dd00000001ddddd1111110000767766666660000000000001ddd00dd0dd0d100100000000000001111111000000000000000000000000000000000
0111111dddd00d0dd00dddddddd1110000056677006655000000000001111d0ddd00d00100100000000000011111111000000000000000000000000000000000
0000111dddd0dd00dd00ddd1111100000000567500600500000000000ddddd00dd00111111111111000011111111110000000000000000000000000000000000
00000000011111111111111111000000000000665060050000000000000111111111111111111110011111111000000000000000000000000000000000000000
14141414141414141414141414141414242424242424242424242424242424240000495900000000000049000049004900005900000000590000580000000068
00490000000000000000000000000049000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240059000000590000680000004900000000005900580717273700000059000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240059496859071727370058005900490059000000000068475767005900005900
00005900680049005800590000680059000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000047576700000000000000005900590000005800000068005900
00000000000000000000004859000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000717273700000000000014240000000007172737000000000000246800590000000049000000004800590068004900006859182838480000000049
000000490059788898a8b80059006800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000475767000000000014240000000000004757670000000000240000000058000000000068000059000000000000000009192939590068000000
005900000000798999a9b90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1400000000000000000000000000001424000000000000000000000000000024005900000000e80059005900590000000000590068000a1a2a3a000000005900
0000000059007a8a9aaaba5900005900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
140000000000000515000000000000142400000000000036000000000000002400005900495900c8d8005900450059005900000000000b1b2b3b000000000000
0000000000007b8b9babbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1400000000000006160000000000001424000000000000061600000000000024004900004a5a00c9d90000004600000000000049000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1400000000000024240000000000001424000000000000242400000000000024005900004b5b00cada0004040404000049000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000404040404040404040404005900000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14000000000000000000000000000014240000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14141414141414141414141414141414242424242424242424242424242424240000000000000000000000000000000000000000000000000000000000000000
__map__
424242424242424242424242424242424242424f4f774f4f4f4d00000000000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4343434343434343434343434343434343435f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
4241414141414141414141414141414141414249494949494f4d00000000000000000000000000000000000000000000000000858400000000000000000000005f5f5f444444444444000043435f5f5f0000000043434300434343430000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
4241414141414141414141413b413c4155416600000000004c4d000000000000000000000000000000000000008c8d00000000000000000000000000000000005f5f5f444444444444000000435f5f5f4444440000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
4241414141414141414141414141414141416600000000004c4d000000000000000000000000000000000000009c9d0000000000004a4b0000000000000000005f5f5f446c44004444000000005f5f5f4444440000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
424141414142424242424242424242424242425e5e5e5e5e4c4d00000000000000000000007c7d7d7d7d7d7d7d7d7d7d7d7e0000004c4d0000000000000000005f5f5f444444644444000000005f5f5f4400440000000000000000000000003e00005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
4241414141414141414141414141414141414200000000004748000000000000000000007c7f41414141414141414141416f7e00004c4d0000000000000000005f5f5f5f5f5f5f5f5f00550000435f5f4464440000000000000000000000007b00005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
4241414141414141414141414141414141414200000000000000000000000000000000000041416c6c6c4100416c6c6c41410000004c4d0000000000000000005f5f5f5f5f5f5f5f5f007b0000435f5f5e5e5e00005e00005e00005e00005e5f00005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
42404041414141414141414141414141414142000000000000000000000000000000000000414141414141644141414141410000004c4d0000000000000000005f5f5f5f5f5f5f5f5f5e5e0000435f5f0000000000000000000000000000005f00005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f
42414141414141414141414141414141414142000000000060000000000000000000000000004141404040404040404141000000004c4d000000000000000000000000000000000000000000005f5f5f4545454545454545454545454545455f00005f5f00000000000000000000000000000000000000000000270044444444
424141414141414141414141414141414141424e4e4e4e4e4e4e4b00000000000000000000000041414141414141410000005500004c4d000000000000000000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f000000000000000000000000000000000000000000000000446c6c6c
42414141404040414141414141414141414142494949494949494800000000000000000000000000414141414141410043007b00004c4d00000000000000000000006000000000000000005e5e5f000000000000002700000000000000005f5f5e5e5f5f000000000000000000000000000000000000000000000000446c6c6c
424141414141414141414141414141414141424f4f4f4f4f000000000000000000000000000000006d4141414141405e5e5e5e00004c4d00000000000000002e2b2b2b2b2b2b2b2d78000000005f000000000000000000000000000000005f5f00005f5f00000000000000000000000000000000000000000000770044444444
42414141414141414141414141413d414141424f004f6c4f0000000000000000000000000000005e404041414141410000000000004c4d00000000000000006e5f5f5f5f5f5f5f297b000000005f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000007b0044440044
424141414141414141414141414141414141424f644f4f4f00000000000000000000000000000000414141414141410000000000004c4d00000000005e5e5e2e5f5f5f5f5f5f5f2c5e00000000660038000000000000000000000000000000000000000000005f5f22222324222324225f5f24222324222324245f5f44446444
424a4e4b4141412041414141414a4e4b4141425e5e5e5e5e00000000006b00000000000000000000414141414141410000000000004c4d00000000000000006e5f5f5f5f5f5f5f29000000000066007b005f2422232423220000000000005f5f5e5e5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5e5e5f5f
424c4f4d4040404040404040404c4f4d404042000000000000000000007b00000000000000000000414141414141410000000000004c4d00000000000000006e5f5f5f4444445f5f0000005e5e5f5f5f5f5f5f5f5f5f5f5f45455f5f5f5f5f5f00005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f
424c4f4d4141414141414141414c4f4d414142000000000000000000007b000000000000000000004141414141416d0000000000004c4d00000000000000006e5f5f5f444444664444000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f
424749484141414141414141414c4f4d7878420000000000005e5e5e4a4b00000000000000000000414141414140405e00000000004c4d00000000000000006e5f5f5f445544664444000000005f444444444444444444440000000000005f5f00005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f
424141414141414141414141414c4f4d4141420000000000000000004c4d00000000000000000000414141414141410000000000004c4d5e5e5e5e000000006e5f5f5f5e5e5e5f2c5e006b00005f444444444444444444440000000000005f5f5e5e5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5e5e5f5f
424141414141414141414141414c4f4d4040420000000000000000004c4d00000000390000000000414141414141410000000000004c4d00000000000000006e5f5f5f0000005f2900007b00005f44444444446c6c6c444400006b000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f
424141414141414141414141414c4f4d4141420000000000000000004c4d000000007b0000000000414141414141410000000000004c4d00000000000000006e5f5f5f0000005f2900007b00006644554400446c6c6c444400007b000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f
42414141414141414141413a414c4f4d7878420000000000000000004c4d0000004a4b434343435e404041414141410000000000004c4d00000000000000006e5f5f5f5e5e5e5f2a45455f0000664444446444444444444400007b000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f
424141414141414141414141414c4f4d4141420000000000000000004c4d0000004c4d4343434300414141414141410000000000004c4d00000000000000436e5f5f5f0000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5e5e5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5e5e5f5f
42414141414141414a4e4b4040474948404042434300000000007c7d7d7d7d7e004c4d4343434300414141414141410000000000004c4d0000000000005e5e2e5f5f5f0000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f7d7d7e00004343434343434343434343434300000000000000005f5f
42696a41414137414c4f4d41414141414141424343000000007c7f414141416f7e4c4d4e4e4e4b00414141414141410000000000004c4d00000000000000006e5f5f5f5e5e5e5f5f00000000270000000027000000000000000000000000000000005f5f41416f7e000043434343434343434343430000005500000000005f5f
42797a41414141414c4f4d4141414141414142434300006b0000414141414141004c4d4949494800414141414141410000000000004c4d5e5e5e00000000006e5f5f5f7d7e005f5f00000000000000000000000000000000000000000000000000005f5f416c416f7e0000004343434343434300000000007b00000000005f5f
424e4e4e4e4e4e4e4f4f4f4e4e4e4e4e4e4e42434300007b0000416c414141405e4c4d414141410041414040404141000000000000474800000000000000006e5f5f5f416f7e5f5f00000000000000000000000000000000000000006b00000000005f5f41414141000000000000000000000000000000005f5f5f5f5f5f5f5f
424f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f42434300007b0000414141004141004c4d410041410041414141414141000000007800660000000078000000006e5f5f5f00416f7e0000000000000000000000000000000000000000007b00000000005f5f4100414100000000000000000000000000000000665f5f5f5f5f5f5f
424f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f42434300007b0000412041642041004c4d416441410041412041414141000000007b0066000000007b000000006e5f5f5f6441416f7e00000000000000000000002223000000000000007b00000000005f5f41644141000000000000000000000000000000006620005f5f5f5f5f
424f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f424e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4b454545453f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4545455f5f5f5f5f4545455f5f5f5f5f5f5f5f5f5f5f5f5f5f5f454545454545454545454545454545455f5f5f5f5f5f5f5f
4949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949494949
__sfx__
11100c0018775187251c7751c7251f7751f72524775247251f7751f7251c7751c72518700187001c7001c7001f7001f70024700247001f7001f7001c7001c70018700187001c7001c7001f7001f7002470024700
11100c0018775187251d7751d7252077520725247752472520775207251d7751d72518700187001c7001c7001f7001f70024700247001f7001f7001c7001c70018700187001c7001c7001f7001f7002470024700
010200002153526535005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
010300003053534535044050440610406044050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01070000247342b73432734267342d73434734287342f734367342a73431734387343973039731397323973500700007000070000700007000070000700007000070000700007000070000700007000070000700
01060000247742476124751247412b7742b7413277432761327513274232735000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011300000073000730007300073000730007300073000730007300073000730007300073000730007300073000730007300073000730007300073000730007300073000730007300073000730007300073000730
11100c0018775187251c7751c7251f7751f72524775247251f7751f7251c7751c72518700187001c7001c7001f7001f70024700247001f7001f7001c7001c70018700187001c7001c7001f7001f7002470024700
01c000001883018830189301893018830188301893018930188301883018930189301883018830189301893014830148300f8300f83011930119300c9300c93013930139300e9300e9300e8300e8300e93013830
010100000c13515003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
69c000001c5241f524205241d5241f5241f52524524245251c5241f524205241d5241f5241f525245242652427524245242b5242b5252e514295242c5242c5251c504185241a52422524215241e5241f5241f525
011000001c1431c1331c1231c1131b1031a1030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200000471005721067310c74110751077510070000700007001970000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
331c00001151011510115101351011510115101551015510155101551015510155151151011510115101351011510115100e5100e510115101151013510135101551015510155101351010510105100c5100c510
311c0000020150e015110150e015150150e0151801218015150121501510012100150a0150e01515010180101701013010150121501511012110151001210015020150e015110150e015150150e0151501518015
330e000010510105101051010510115101151011510115100e5100e5100e5100e5100e5100e5100e5100e510155101551015510155101a5101a5121a5121a5121a5121a5121a5121a5121a5121a5121a5101a515
310e000017011170121701217012170121701200000000001101011010110151100011010110100e0100e01015010150100c0100c0100e0100e0100e0100e0120e0120e0120e0120e0120e0100e0100e0100e015
310e000017011170121701217012170121701200000000001101011010110151100011010110100e0100e01015010150100c0100c0100e0100e0100e0100e010110100e01015010110101a010150101d01015010
c11c00002d3122d3122d3122b31029310293122831228312293122931228312283102b3102b3122b3122931028310293102631026312283122831229312293102d3112d3122d3122b31029310293102831028310
c10e00002631226312263122631024310243122431224315243102431024310243102431024315243102431028310283102931029310263102631026310263102631026310263102631026310263102631026315
011800001901017015170001901017015170001a010190151901017015170001901017015170001a010190151c0101a015000001c01019015000001e0101c0151c0101a015000001c010190151e0001c0001a005
011800000e0100e015000000e0100e015000000e0100e0150e0100e015000000e0100e015000000e0100e01510010100150000010010100150000010010100151001010015000000000000000000000000000000
d51800000231506315021150231506315021150231506315023150631502115023150631502115023150631504315073150421504315073150421504315073150431507315042150421504115042150431504415
010200002406025051270412f0002b0512c0512d0412e0312f0212f0052f00032000030000000037000370002f0002f0002f0002f000000003300004000000000000000000000000000000000000000000000000
0102000002215006200341500630052150063008415006300b215006400d415006401022500640124250065011225006400f425006400d2150064009415006300621500630054150063003215006300341500620
5d1e000000315003150031500315013150030500315003150031500315013150030500315003150031500315013150030500315003150031500315013150030500315003150031500315013150c3150c3150c315
011e0000180121801218012180121f0121f0121f0121f0121e0121e0121e0121e0121e0121e0121e0121e012180121801218012180121b0121b0121b0121b0121a0121a0121a0121a0121a0121a0121a0121a012
5d1e000000315003150031500315013152141500315003150031500315013152141500315003150031500315013152141500315003150031500315013152141500315003150031500315013150c3150c3150c315
011e00000c31300412004120c3131a31307412074120c3131a3131a313064120c3131a3130641206412064120c313264152141500412034120c31321415034121a3131a313024121a31321415024120241202412
011e000000315003150031500315013151841500315003150031500315013151e41500315003150031500315013151841500315003150031500315013150131500315003150031500315013150c3150c3150c315
011e00000c313184151e4150c3131a3130c3131e4150c3131a3131a313184150c3131a3131a3131a3131e4150c3131e4151e4150c3131a3130c313013150c3131a3131a3131e4151a313184151a3131e41518415
1302011617344292451750417344292451950417344292451c5041734429245000001734429245000001734429245000000000000000000000000000000000000000000000000000000000000000000000000000
012200000c0130000000000000000c0130000000000000000c0130000000000000000c0130000000000000000c0130c01300000000000c0130000000000000000c0130000000000000000c013000000000000000
1302010117354292551750417354292551950417354292551c5041735429255000001735429255000001735429255000000000000000000000000000000000000000000000000000000000000000000000000000
912000001774017730157401573013740137301574012730127301273012720127201272012710127101271017740177301574015730137401373015740127301273012730127201272013740137301574015730
01200000137301372013710137001073010720107100e7300e7200e710107001070010700107001070010700137301372013710137001073010720107100e7300e7200e710000000000000000000000000000000
c92000001753215532175320000015532000001353212532000000000015532000001353200000125320000017532155321753200000155320000013532125320000010532000001253200000135321553200000
912000001774017730157401573013740137301574012730127301273012720127201272012710127101271017740177301574015730137401373015740137301373013730137201372017740177301574015730
01200000137321372213712000001073210722107120e7320e7220e71215721157211372113721127211273113732137221371213702107321072210712177321772217712000000000000000000000000000000
c92000001753215532175320000015532000001353212532000000000015532000001353200000125320000017532155321753200000155320000012532135320000015532135321553217532135001553200000
110100000c11515003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
911200001915519115201552011525155251152015520115191551911520155201152515525115201552011519155191151d1551d115201552011525155251152415500000000000000029450294522a4502a452
011200001910525315201052c3152510525315201052c3151910525315201052c3152510525315201052c31519105253151d10529315201052c315251052531524105000002a605000002a6352a6152a6352a635
911200002c4502c4312c4302c4302c4322c4322c4322c4322c4322c4322c4322c43229450294522a4502a4522c4502c4312c4302c4302c4322c4322c4322c4322c4322c4322c4322c43229450294522a4502a452
01120000201552810525155291052915526105291552510525315251151d115251152a6352a6152a6352a635201552810525155291052915526105291552510525315251151d115251152a6352a6152a6352a635
491200002c4502c4312c4302c4302c4322c4322e4502e4312e4302e4302e4322e4322c4502c4312c4322c4322a4502a4312a4302a4302a4322a4322a4322a4322a4322a4322a4322a43227450274312945029431
01120000201551a10526155211052915520105201551a10526155211052915500000221550000026155000001b1551e1051e15500000221550000027155000002a6152a6252a6052a6352a6052a6352a6452a605
491200002a4502a4312a4302a4302a4322a4322a4322a4322a4322a4322a4322a432274502745029450294502a4502a4312a4302a4302a4322a4322a4322a4322a4322a4322a4322a43227450274502945029450
011200001b1551b4001e1550000022155000002215500000271152a115221152a115271152a11522115000001b1551b4001e1550000022155000002215500000271152a115221152a115271152a1152211500000
491200002a4502a4312a4302a4302a4322a4322c4502c4312c4302c4302c4322c4322a4502a4502a4522a4522a4502a4312945029431274502743129450294312943229432294322943229432294322943229432
011200001b155000001e1550000022155000001b155000001e155000002415500000211551c400241550000020155000000000000000000000000025155000000000000000191550000020155000002515500000
49120000294502943129432294322745027431274322743226450264312743027432284302843229430294322a4502a4312945029431274502743129450294312943229432264502643127450274312743227432
01120000221550000020400000002115500000000000000020155000001b155000001c155000001d15500000221550000020155000001e15500000201550000000000000001d155000001e155000000000000000
491200002743227432274322743227432274322743227432294502943129432294322a4502a4312a4322a4322a4502a4312a4322a4322a4322a4322a4322a4322d4322d4322d4322d4322a4502a4312a4322a432
011200001b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b145271551b14527155
491200002a4502a43129450294312745027431294502943129432294322645026431274502743127432274322743227432274322743227432274322743227432274001f4001f4501f45020450204502245022450
01120000221550000020155000001e15500000201550000000000000001d155000001f1550000000000000001b145271551b145271551b145271551b145271551b145271551b145271551b145271551b14527155
49120000234502343122450224312045020431224502243122432224321f4501f4312045020431204322043220432204322043220432204322043220432204320000000000000000000029450294522a4502a452
011200001b1551b115000000000000000000001915519115000000000000000000001815518115000000000014145181551414518155141451815514145181551415500000000000000000000000000000000000
__music__
00 080a4344
01 1f424344
00 21424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 0d0e4344
00 0f104344
00 0d0e4344
00 0f114344
00 120e4344
02 13104344
01 14154344
00 14154344
00 14151644
00 41424344
00 41424344
00 41424344
01 19424344
00 19424344
00 191a4344
00 191a4344
00 1b1c4344
00 1b1c4344
00 1d1e4344
00 1d1e4344
00 1a1e4344
00 1a1e4344
00 1f1a4344
00 1f1a4344
02 1f4c4344
01 20424344
01 22234344
00 22232444
02 25262744
00 292a4344
01 2b2c4344
00 2d2e4344
00 2f304344
00 31324344
00 33344344
00 35364344
00 37384344
02 393a4344

