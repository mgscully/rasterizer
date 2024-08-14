module main
import os
import math
import gfx

const (
    size       = Size2i{  512, 512 }
    center     = Point2i{ 256, 256 }
    radius     = 192
    radcols    = [ RadiusColor{ 64, gfx.red }, RadiusColor{ 128, gfx.green }, RadiusColor{ 192, gfx.blue } ]
    num_points = 36
    num_sides  = 15
)

struct RadiusColor {
    radius int
    color Color
}
struct ColoredLineSegment {
    lineseg LineSegment2i
    color   Color
}

// convenience type aliases
type Image         = gfx.Image
type Point2        = gfx.Point2
type Point2i       = gfx.Point2i
type Size2i        = gfx.Size2i
type LineSegment2i = gfx.LineSegment2i
type Color         = gfx.Color

type Rasterizer = fn (mut Image)


//////////////////////////////////////////////////////////////////////////////////////////////////
// Simple rasterizer functions

// Rasterize a _simple_ line segment, which must: have coincident endpoints, be horizontal, or be vertical
fn (mut image Image) raster_simple_line_segment(p0 Point2i, p1 Point2i, color Color) {
    assert p0.x == p1.x || p0.y == p1.y

    /*
        set pixel colors in image along horizontal or vertical line between p0 and p1
    */
    
    if p0.y == p1.y {
        // horizontal line segment
        y := p0.y
        x_min := math.min(p0.x, p1.x)
        x_max := math.max(p0.x, p1.x)
        for x in x_min .. (x_max+1) {
            image.set_xy(x, y, color)
        }
    } 
    else {
        // vertical line segment
        x := p0.x
        y_min := math.min(p0.y, p1.y)
        y_max := math.max(p0.y, p1.y)
        for y in y_min .. (y_max+1) {
            image.set_xy(x, y, color)
        }
    }
}

// Rasterizes a rectangle into image
fn (mut image Image) raster_rectangle(center Point2i, size Size2i, color Color) {
    top_left     := Point2i{ center.x - size.width, center.y - size.height }
    bottom_left  := Point2i{ center.x - size.width, center.y + size.height }
    bottom_right := Point2i{ center.x + size.width, center.y + size.height }
    top_right    := Point2i{ center.x + size.width, center.y - size.height }

    // NOTE: can replace raster_simple_line_segment with raster_line_segment once implemented
    image.raster_simple_line_segment(top_left,     bottom_left,  color)  // left side
    image.raster_simple_line_segment(bottom_left,  bottom_right, color)  // bottom side
    image.raster_simple_line_segment(bottom_right, top_right,    color)  // right side
    image.raster_simple_line_segment(top_right,    top_left,     color)  // top side
}


//////////////////////////////////////////////////////////////////////////////////////////////////
// More interesting rasterizer functions

// Rasterizes an arbitrary line segment (general form of raster_simple_line_segment)
fn (mut image Image) raster_line_segment(p0 Point2i, p1 Point2i, color Color)  {
    mut x1 := p0.x
    mut y1 := p0.y
    mut x2 := p1.x
    mut y2 := p1.y

    mut dx := x2 - x1
    mut dy := y2 - y1

    mut switch := math.abs(dy) > math.abs(dx)

    if switch {
        x1, y1 = y1, x1
        x2 , y2 = y2, x2 
        dx = x2 - x1 
        dy = y2 - y1
    }

    if x1 > x2  {
        x1, x2 = x2, x1
        y1, y2 = y2, y1 
    }

    dx = x2 - x1 
    dy = y2 - y1 
    
    mut yi := 1
    if dy < 0 {
        yi = -1 
        dy *= -1
    }

    mut d:= (2*dy) -dx
    mut y_curr := y1
    //array of points 
    mut points := []Point2i{}
    for x_curr in x1 .. x2 {

        if switch {
            image.set_xy(y_curr, x_curr, color)
            //add to array 
            points << Point2i {y_curr, x_curr}
        }
        else {
            image.set_xy(x_curr, y_curr, color)
            points << Point2i {x_curr, y_curr}
        }

        if d > 0 {
            y_curr += yi
            d += (2*(dy-dx))
        }
        else {
            d += 2*dy
        }
    }
    
}

// Rasterizes a list of line segments
fn (mut image Image) raster_line_segments(collinesegs []ColoredLineSegment) {
    for collineseg in collinesegs {
        image.raster_line_segment(
            collineseg.lineseg.p0,
            collineseg.lineseg.p1,
            collineseg.color,
        )
    }
}

// Rasterizes a simple star (asterisk) shape
fn (mut image Image) raster_star(center Point2i, radius int, num_points int, color Color) {
    cx, cy := center.x, center.y
    for i in 0 .. num_points {
        radians := math.radians(f64(i) * 360.0 / f64(num_points))
        point := Point2i{ int(math.cos(radians) * radius + cx), int(math.sin(radians) * radius + cy) }
        image.raster_line_segment(center, point, color)
    }
}

// Rasterizes a simple, fixed, closed polygon (rotated square)
fn (mut image Image) raster_fixed_polygon(center Point2i, radius int, color Color) {
    cx, cy := center.x, center.y
    cr, sr := int(0.5403023059 * f64(radius)), int(0.8414709848 * f64(radius))
    points := [
        Point2i{ cx + cr, cy + sr },
        Point2i{ cx - sr, cy + cr },
        Point2i{ cx - cr, cy - sr },
        Point2i{ cx + sr, cy - cr },
    ]
    image.raster_line_segment(points[0], points[1], color)
    image.raster_line_segment(points[1], points[2], color)
    image.raster_line_segment(points[2], points[3], color)
    image.raster_line_segment(points[3], points[0], color)
}

// Rasterize the perimeter of a regular closed polygon
fn (mut image Image) raster_regular_polygon(center Point2i, radius int, num_sides int, color Color) {
    step := f64(math.pi * 2) / f64(num_sides)
    
    mut corners := [] Point2i{cap: num_sides}

    //determine the corner points
    for i in 0 .. num_sides {
        mut angle := f64(i) * step
        //determine x and y values for current corner
        mut x := center.x + int(radius * math.cos(angle))
        mut y := center.y + int(radius * math.sin(angle))
        corners << Point2i{x, y}
    }

    for i in 0.. num_sides {
        mut p_0 := corners[i]
        //using modulus to loop backa around at end
        mut p_1 := corners[(i + 1) % num_sides]
        image.raster_line_segment(p_0, p_1, color)
    }

}

// Rasterize the perimeter of a circle into a list of points
fn (mut image Image) raster_circle(center Point2i, radius int, color Color) {
 
    mut x := radius 
    mut y := 0
    x_0 := center.x
    y_0 := center.y
    mut dx := 1 
    mut dy := 1 
    mut err := dx - 2 * radius 

    for (x >= y) {
        image.set_xy(x_0 + x, y_0 + y, color) //first octant
        image.set_xy(x_0 + y, y_0 + x, color) //second octant 
        image.set_xy(x_0 - y, y_0 + x, color) //third octant 
        image.set_xy(x_0 - x, y_0 + y, color) //fourth octant
        image.set_xy(x_0 - x, y_0 - y, color) //fifth octant
        image.set_xy(x_0 - y, y_0 -x, color) //sixth octant
        image.set_xy(x_0 + y, y_0 - x, color) //seventh octant 
        image.set_xy(x_0 + x, y_0 - y, color) //eighth octant

        if err <= 0 {
            y++
            err += dy
            dy += 2
        }
        if err > 0 {
            x --
            dx += 2
            err += -2 * radius + dx
        }
    }

}

// Generate a simple, fixed, closed polygon (rotated square)
fn generate_fixed_polygon(center Point2i, radius int, color Color) []ColoredLineSegment {
    mut collinesegs := []ColoredLineSegment{}

    cx, cy := center.x, center.y
    cr, sr := int(0.5403023059 * f64(radius)), int(0.8414709848 * f64(radius))
    points := [
        Point2i{ cx + cr, cy + sr },
        Point2i{ cx - sr, cy + cr },
        Point2i{ cx - cr, cy - sr },
        Point2i{ cx + sr, cy - cr },
    ]
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[0], points[1] }
        color: color
    }
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[1], points[2] }
        color: color
    }
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[2], points[3] }
        color: color
    }
    collinesegs << ColoredLineSegment{
        lineseg: LineSegment2i{ points[3], points[0] }
        color: color
    }

    return collinesegs
}

fn generate_fractal_tree(start Point2, length f64, direction f64, length_factor f64, spread f64, spread_factor f64, count int, max_count int) []ColoredLineSegment {
    mut collinesegs := []ColoredLineSegment{}
    mut vector := Point2{math.cos(direction)*length, math.sin(direction)*length}
    end := Point2{start.x + vector.x, start.y + vector.y}
    line_seg := LineSegment2i {start.as_point2i(), end.as_point2i()}
    color_line_seg := ColoredLineSegment{line_seg, gfx.green}

    collinesegs << color_line_seg

    if count > 0 {
        start_param := end
        length_param := length * length_factor
        direction_param1 := direction + spread 
        direction_param2 := direction - spread 
        length_factor_param := length_factor
        spread_param := spread * spread_factor
        spread_factor_param := spread_factor
        count_param := count - 1 
        collinesegs << generate_fractal_tree(start_param, length_param, direction_param1, length_factor_param, spread_param, spread_factor_param, count_param, max_count)
        collinesegs << generate_fractal_tree(start_param, length_param, direction_param2, length_factor_param, spread_param, spread_factor_param, count_param, max_count)
    }
    return collinesegs
}

//function to rasterize a flat-bottomed triangle 
//assumes that vertex_2 and vertex_3 are connected by a horizontal edge
fn (mut image Image)raster_flat_bottom_triangle (vertex_1 Point2i, vertex_2 Point2i, vertex_3 Point2i, color Color) {

    //calculate inverted slopes to get x values from y values
    invslope1 := f64(vertex_1.x - vertex_2.x) / f64(vertex_1.y - vertex_2.y)
    invslope2 := f64(vertex_1.x - vertex_3.x) / f64(vertex_1.y - vertex_3.y)

    mut curr_x1 := f64(vertex_1.x)
    mut curr_x2 := f64(vertex_1.x)

    //work down from vertex 1
    for scanline := vertex_1.y; scanline <= vertex_2.y; scanline++ {
        point_1 := Point2i{int(curr_x1), scanline}
        point_2 := Point2i{int(curr_x2), scanline}
        image.raster_simple_line_segment(point_1, point_2, color)
        curr_x1 += invslope1
        curr_x2 += invslope2
    }
    
}

//function to rasterize a flat-topped triangle 
//assumes that vertex_2 and vertex_3 are connected by a horizontal edge
fn (mut image Image)raster_flat_top_triangle (vertex_1 Point2i, vertex_2 Point2i, vertex_3 Point2i, color Color) {
    
    //calculate inverted slopes to get x values from y values
    invslope1 := f64(vertex_2.x - vertex_1.x) / f64(vertex_2.y - vertex_1.y)
    invslope2 := f64(vertex_3.x - vertex_1.x) / f64(vertex_3.y - vertex_1.y)

    mut curr_x1 := f64(vertex_2.x)
    mut curr_x2 := f64(vertex_3.x)

    //work down from vertex 1
    for scanline in vertex_2.y .. vertex_1.y {
        point_1 := Point2i{int(curr_x1), scanline}
        point_2 := Point2i{int(curr_x2), scanline}
        image.raster_simple_line_segment(point_1, point_2, color)
        curr_x1 += invslope1
        curr_x2 += invslope2
    }
    
}


// rasterization of a filled triangle
fn (mut image Image) raster_triangle(vertex_1 Point2i, vertex_2 Point2i, vertex_3 Point2i, color Color) {
    // create an array of vertices and sort by y value so you can determine
    //which is the middle vertex whose y value should be used to find the boundary point
    mut vertices := [vertex_1, vertex_2, vertex_3]
    vertices.sort(a.y < b.y)

    //assign v1..3 based on increasing y values
    v1 := vertices[0]
    v2 := vertices[1]
    v3 := vertices[2]

    //if the two highest y values are the same, the triangle has a flat bottom
    if v2.y == v3.y {
        image.raster_flat_bottom_triangle(v1, v2, v3, color)
    } 
    //if the two lowest y values are the same, its a flat topped triangle 
    else if v1.y == v2.y {
        image.raster_flat_top_triangle(v3, v1, v2, color)
    } 

    //if the triangle has no horizontal line, divide into two triangles
    else {
        //calculate x boundary
        x_boundary := int(f64(v1.x) + (f64(v2.y - v1.y) / f64(v3.y - v1.y)) * f64(v3.x - v1.x))
        boundary_point := Point2i{x_boundary,v2.y}
        
        image.raster_flat_bottom_triangle(v1, v2, boundary_point, color)
    
        image.raster_flat_top_triangle(v3, v2, boundary_point, color)
    }
}

//helper function for my creative artifact
fn (mut image Image) raster_filled_semi_circle(center Point2i, radius int, color Color) {

    //approach: raster similarly to the outline of a circle but instead of coloring in points
    //color in horizontal lines
    mut x := radius 
    mut y := 0
    x_0 := center.x
    y_0 := center.y
    mut dx := 1 
    mut dy := 1 
    mut err := dx - 2 * radius 

    for (x >= y) {
        mut point_1 := Point2i{x_0 - x, y_0 - y}
        mut point_2 := Point2i{x_0 + x, y_0 - y}
        image.raster_line_segment(point_1, point_2, color)
        
        mut point_3 := Point2i{x_0 - y, y_0 - x}
        mut point_4 := Point2i{x_0 + y, y_0 - x}
        image.raster_line_segment(point_3, point_4, color)
        
        if err <= 0 {
        y++
        err += dy
        dy += 2
        }
        if err > 0 {
            x --
            dx += 2
            err += -2 * radius + dx
        }
    }
    
}
//creative artifact: rasterize heart
fn (mut image Image) raster_filled_heart(width int, height int, color Color) {

    //approach: rasterize two filled in semi circles and a triangle 
    //heart will always be placed at the center of the screen 
    circle_r := int(width/4)

    if height - circle_r < int(size.height/2) && width < size.width { 


        triangle_v1 := Point2i{center.x - 2 * circle_r, center.y}
        triangle_v2 := Point2i{center.x + 2 * circle_r, center.y}
        triangle_v3 := Point2i{int((triangle_v1.x + triangle_v2.x)/2), center.y + height - circle_r}
        semi1_center := Point2i{center.x-circle_r, center.y}
        semi2_center := Point2i{center.x+circle_r, center.y}

        image.raster_filled_semi_circle(semi1_center, circle_r, color)
        image.raster_filled_semi_circle(semi2_center, circle_r, color)

        image.raster_triangle(triangle_v1, triangle_v2, triangle_v3, color)

    }

    else {
        eprintln('Error: size out of bounds')
    }


}

//extra credit, creating a beating heart gif

//////////////////////////////////////////////////////////////////////////////////////////////////
// General render function

// creates an image, calls each of the passed rasterizer functions, then returns final image
fn render_image(rasterizers []Rasterizer) Image {
    mut image := gfx.Image.new(size)
    for rasterizer in rasterizers {
        rasterizer(mut image)
    }
    return image
}

//////////////////////////////////////////////////////////////////////////////////////////////////

fn main() {
    // Make sure images folder exists, because this is where all
    // generated images will be saved
    if !os.exists('output') {
        os.mkdir('output') or { panic(err) }
    }

    println('Rendering rectangle...')
    render_image([
        fn (mut image Image) { image.raster_rectangle(center, Size2i{ radius, radius }, gfx.white) },
    ]).save_png('output/P01_00_rectangle.png')

    println('Rendering star...')
    render_image([
        fn (mut image Image) { image.raster_star(center, radius, num_points, gfx.yellow) },
    ]).save_png('output/P01_01_star.png')

    println('Rendering fixed polygon...')
    render_image([
        fn (mut image Image) { image.raster_fixed_polygon(center, radius, gfx.cyan) },
    ]).save_png('output/P01_02_fixed_polygon.png')

    println('Rendering regular polygon...')
    render_image([
        fn (mut image Image) { image.raster_regular_polygon(center, radius, num_sides, gfx.red) },
    ]).save_png('output/P01_03_regular_polygon.png')

    println('Rendering circle...')
    render_image([
        fn (mut image Image) { image.raster_circle(center, radius, gfx.green) },
    ]).save_png('output/P01_04_circle.png')

    println('Rendering circles...')
    render_image(
        radcols.map(fn (radcol RadiusColor) Rasterizer {
            return fn [radcol] (mut image Image) { image.raster_circle(center, radcol.radius, radcol.color) }
        })
    ).save_png('output/P01_05_circles.png')

    println('Rendering fixed polygon using generator...')
    shape_fixed_polygon := generate_fixed_polygon(center, radius, gfx.magenta)
    render_image([
        fn [shape_fixed_polygon] (mut image Image) { image.raster_line_segments(shape_fixed_polygon) },
    ]).save_png('output/P01_06_fixed_polygon.png')

    println('Rendering fractal tree using generator...')
    shape_fractal_tree := generate_fractal_tree(
        Point2{ 256, 500 },  // start
        100,                 // length
        math.radians(270),   // direction
        0.75,                // length_factor
        math.radians(30),    // spread
        0.85,                // spread_factor
        10,                  // count
        10,                  // max_count
    )
    render_image([
        fn [shape_fractal_tree] (mut image Image) { image.raster_line_segments(shape_fractal_tree) },
    ]).save_png('output/P01_07_fractal_tree.png')

    //raster triangle 
    vertex_1 := Point2i{150, 150}
    vertex_2 := Point2i{270, 152}
    vertex_3 := Point2i{450, 400}
    println('Rendering filled triangle...')
    render_image([
        fn [vertex_1, vertex_2, vertex_3] (mut image Image) { image.raster_triangle(vertex_1, vertex_2, vertex_3, gfx.yellow) },
    ]).save_png('output/P01_01_triangle.png')

    //raster filled heart 
    width := 200 
    height := 200 
    println('Rendering filled heart...')
    render_image([
        fn [width, height] (mut image Image) { image.raster_filled_heart(width, height, gfx.red) },
    ]).save_png('output/P01_01_filled_heart.png')

    println('Generating images for beating heart gif')

    for i in 0 .. 9 {

        factor := 50 * (i % 3)

        mut w := 200 + factor 
        mut h := 200 + factor 

        mut name := 'output/gif_input/heart_' + i.str() + '.png'

        render_image([
        fn [w, h] (mut image Image) { image.raster_filled_heart(w, h, gfx.red) },
    ]).save_png(name)

    }
    println('Beating heart gif created  and saved to output:)')

    println('Done!')
}