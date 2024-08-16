package main

import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:thread"
import rl "vendor:raylib"

screen_width :: 1280
screen_height :: 960

circle_radius :: 5
circle_color :: rl.LIME

minimum_distance: f32 : 15.0
min_distance_squared :: minimum_distance * minimum_distance
epsilon :: 0.0001
num_placement_tries :: 1000

cell_size : i32
n_cells_width : i32
n_cells_height : i32
total_cells : i32

Vector2 :: struct {
    x, y: i32,
}

circle_positions: [dynamic]Vector2

main :: proc() {
    rl.InitWindow(screen_width, screen_height, "Breaker")
    defer rl.CloseWindow()

    cell_size = i32(math.floor(minimum_distance / math.SQRT_TWO))
    n_cells_width = screen_width / cell_size + 1
    n_cells_height = screen_height / cell_size + 1
    total_cells = n_cells_width * n_cells_height

    drawing_thread := thread.create_and_start(generate_circle_positions)
    defer thread.destroy(drawing_thread)

    for !rl.WindowShouldClose() {

        rl.BeginDrawing()

        rl.ClearBackground(rl.DARKBROWN)

        for position in circle_positions {
            rl.DrawCircle(position.x, position.y, circle_radius, circle_color)
        }

        if !thread.is_done(drawing_thread) {
            rl.DrawText("Placing points", 20, 20, 20, rl.LIGHTGRAY)
        }

        rl.EndDrawing()
    }
}

generate_circle_positions :: proc() {
    initial_circle_position := Vector2 {
        rand.int31_max(screen_width),
        rand.int31_max(screen_height),
    }

    // NOTE: all of these points get initialized to (0, 0)
    // We're just going to say that a point can't exist at (0, 0),
    // and treat it as a null value.
    grid: [dynamic]Vector2
    resize(&grid, total_cells)
    insert_point(&grid, initial_circle_position)

    append(&circle_positions, initial_circle_position)

    unprocessed_circles: queue.Queue(Vector2)
    queue.init(&unprocessed_circles)
    queue.push_back(&unprocessed_circles, initial_circle_position)

    current_point: Vector2

    for queue.len(unprocessed_circles) > 0 {
        current_point = queue.pop_front(&unprocessed_circles)

        for i in 0 ..< num_placement_tries {
            new_point := pick_new_point(current_point)

            if is_valid_point(new_point, grid) {
                append(&circle_positions, new_point)
                insert_point(&grid, new_point)
                queue.push_back(&unprocessed_circles, new_point)
            }
        }
    }

}

insert_point :: proc(grid: ^[dynamic]Vector2, point: Vector2) {
    x_index := point.x / cell_size
    y_index := point.y / cell_size

    grid^[x_index * n_cells_height+ y_index] = point
}

pick_new_point :: proc(point: Vector2) -> Vector2 {
    theta := rand.float32() * math.TAU
    radius := minimum_distance + epsilon

    return Vector2 {
        i32(f32(point.x) + radius * math.cos(theta)),
        i32(f32(point.y) + radius * math.sin(theta)),
    }
}

is_valid_point :: proc(point: Vector2, grid: [dynamic]Vector2) -> bool {
    // Return false if the point isn't even on the screen
    if point.x < 0 ||
       point.x >= screen_width ||
       point.y < 0 ||
       point.y >= screen_height {
        return false
    }

    x_index := point.x / cell_size
    y_index := point.y / cell_size

    // Get a list of all nearby cells
    x_min := max(x_index - 1, 0)
    x_max := min(x_index + 1, n_cells_width - 1)
    y_min := max(y_index - 1, 0)
    y_max := min(y_index + 1, n_cells_height - 1)

    for x in x_min ..= x_max {
        for y in y_min ..= y_max {
            grid_point := grid[x * n_cells_height+ y]

            if grid_point.x == 0 && grid_point.y == 0 {
                continue
            }

            x_diff := point.x - grid_point.x
            y_diff := point.y - grid_point.y
            distance_squared := f32(x_diff * x_diff + y_diff * y_diff)

            if distance_squared < min_distance_squared {
                return false
            }
        }
    }

    return true
}
