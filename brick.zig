const std = @import("std");

// extern fn set_font(std: ZigStr) void;
// extern fn fill_text(str: ZigStr, posx: i32, posy: i32) void;
// extern fn stroke_text(str: ZigStr, posx: i32, posy: i32) void;
// extern fn fill_rect(x: i32, y: i32, wid: i32, hei: i32) void;
// extern fn stroke_rect(x: i32, y: i32, wid: i32, hei: i32) void;
// extern fn clear_rect(x: i32, y: i32, wid: i32, hei: i32) void;

const JS = @import("common.zig");
const Instance = JS.Instance(Context);
const ZigStr = JS.ZigStr;

export fn init(w:i32, h:i32) ?*Instance{
    return Instance.init(w, h) catch return null;
}

export fn deinit(pinst: ?*Instance) void{
    if(pinst)|inst|{ inst.deinit(); }
}
export fn get_tmp_str(pinst: ?*Instance, size: usize) ?[*] u8{
    if(pinst)|inst|{ return inst.get_tmp_str(size); }
    else { return null; }
}

export fn touch_event(pinst: ?*Instance, evt_str: ?[*:0] const u8, id: u32, px: i32, py: i32) bool{
    if(pinst)|inst|{
        if(@hasDecl(@TypeOf(inst.cxt), "touch_event"))
            return inst.cxt.touch_event(JS.from_c_str(evt_str),
                                        id, px, py);
    }
    return false;
}

export fn key_event(pinst: ?*Instance, evt_str: ?[*:0] const u8) void{
    if(pinst)|inst|{
        if(@hasDecl(@TypeOf(inst.cxt), "key_event"))
            inst.cxt.key_event(JS.from_c_str(evt_str));
    }
}

export fn resize_event(pinst: ?*Instance, neww2: u32, newh2: u32) void{
    if(pinst)|inst|{ inst.resize_event(neww2, newh2); }
}

export fn loop(pinst: ?*Instance) void{
    if(pinst)|inst|{ inst.loop(); }
}

const Vec2 = struct{
    x: f32,
    y: f32,

    pub fn rotate(self: @This(), degs: f32) @This(){
        const s = std.math.sin(std.math.degreesToRadians(degs));
        const c = std.math.cos(std.math.degreesToRadians(degs));
        return @This(){
            .x = self.x * c - self.y * s,
            .y = self.x * s + self.y * c
        };
    }
    pub fn sx_(self: @This()) @This(){
        return @This(){.x = self.x, .y = 0};
    }
    pub fn s_y(self: @This()) @This(){
        return @This(){.x = 0, .y = self.y};
    }
    pub fn syx(self: @This()) @This(){
        return @This(){.x = self.x, .y = self.y};
    }
    pub fn scale(self: @This(), fac: f32) @This(){
        return @This(){.x = self.x * fac, .y = self.y * fac};
    }
};

pub fn add(a: Vec2, b: Vec2) Vec2{
    return Vec2{.x = a.x + b.x,
                .y = a.y + b.y};
}
pub fn dot(a: Vec2, b: Vec2) f32{
    return a.x * b.x + a.y * b.y;
}
//Aspect ratio, width to height of a cell
const as_rt : f32 = 16.0/9.0;

//Number of cells along width and height
const cols = 18;
const rows = 20;
var glob: *Instance = undefined;

pub fn log(comptime format:[] const u8,
           args: anytype) void{
    glob.log_buff.writer().print(format, args) catch {};
}

const Context = struct{
    inst: *Instance = undefined,
    //Any event update rate
    //wait:u32 = 0,
    
    event:BoardEvents=.{},
    
    //2D array of allowed bricks from top
    bricks:[rows/2][cols] bool = blk:{
        var tmp:[rows/2][cols] bool = undefined;
        for(&tmp)|*row|{
            for(row)|*cell|{
                cell.* = true;
                //tmp[i][j] = true;
            }
        }
        // for(0..4)|i|{
        //     for(0..rows/2)|j|{
        //         tmp[j][i] = false;
        //     }
        // }
        tmp[rows/4][cols/2] = false;
        break :blk tmp;
    },
    
    //Info of breaker
    breaker_len:f32 = 3.0,
    //Center along x, but top of y
    breaker_pos:Vec2 = Vec2{.x = cols/2.0, .y = rows - 2},

    //Info of ball
    ball_rad:f32 = 0.4, // Fraction of radius expressed in terms of width
    ball_cen:Vec2 = Vec2{.x = cols/2.0, .y = rows - 4 - 0.4},
    ball_vel:Vec2 = Vec2{.x = -0.0, .y = 0.3},
    //ball_cen:Vec2 = Vec2{.x = 0, .y = 3 - 0.1},
    //ball_vel:Vec2 = Vec2{.x = -0.1, .y = -0.0},

    fn calc_used_dim(self: * const Context) Vec2{
        //Calculate ratio of total width to total height needed,
        const ac_as_rt = (as_rt * cols) / rows;

        //First assume we use full height, but adjusted width
        var dim = Vec2{.x = @as(f32, @floatFromInt(self.inst.h)) * ac_as_rt,
                       .y = @floatFromInt(self.inst.h)};
        //If assumption is wrong, use full width
        if(dim.x > @as(f32, @floatFromInt(self.inst.w))){
            dim.x = @floatFromInt(self.inst.w);
            dim.y = @as(f32, @floatFromInt(self.inst.w)) / ac_as_rt;
        }
        return dim;
    }
    
    fn calc_cell_size(self: * const Context) Vec2{
        const used_dim = self.calc_used_dim();
        const cell_size = Vec2{.x = used_dim.x / cols,
                               .y = used_dim.y / rows};
        return cell_size;
    }

    fn to_canvas_coord(self: * const Context, pos: Vec2) Vec2{
        const cell_size = self.calc_cell_size();
        const pt = Vec2{.x = pos.x * cell_size.x,
                        .y = pos.y * cell_size.y};
        return pt;
    }
    fn from_canvas_coord(self: * const Context, pos: Vec2) Vec2{
        const cell_size = self.calc_cell_size();
        const pt = Vec2{.x = pos.x / cell_size.x,
                        .y = pos.y / cell_size.y};
        return pt;
    }

    pub fn init(inst: *Instance) !@This(){
        var self=@This(){};
        self.inst = inst;
        const gpa_allocr = inst.gpa.allocator();
        _=gpa_allocr;
        glob = inst;
        return self;
    }
    pub fn deinit(self: *@This()) void{
        _=self;
    }
    pub fn key_event(self: *@This(), key_name:[] const u8) void{
        self.event.key_event(key_name);
    }
    pub fn touch_event(self: *@This(), evt_name:[] const u8,
                       id: u32, px: i32, py: i32) bool{
        return self.event.touch_event(evt_name, id,
                                      px, py);
    }
    pub fn loop(self: *@This()) void{
        //Update
        const move_speed = 0.5;
        if(self.event.last_touch == null){
            if(self.event.left){
                self.breaker_pos.x = @max(1, self.breaker_pos.x - move_speed);
            }
            if(self.event.right){
                self.breaker_pos.x = @min(cols-1, self.breaker_pos.x + move_speed);
            }
        }
        else{
            self.breaker_pos.x = self.from_canvas_coord(
                Vec2{
                    .x = @floatFromInt(self.event.touch_pos.x),
                    .y = @floatFromInt(self.event.touch_pos.y),
            }).x;
            self.breaker_pos.x = @max(1, self.breaker_pos.x);
            self.breaker_pos.x = @min(cols-1, self.breaker_pos.x);
        }
        self.event.reset_events();

        self.ball_cen.x += self.ball_vel.x;
        self.ball_cen.y += self.ball_vel.y;

        const bth = struct{
            pcxt: * Context,
            fn init(cxt: *Context) @This(){
                return @This(){.pcxt = cxt};
            }
            fn log(selfme: @This()) void{
                glob.log_buff.writer().print("Ball at {d} {d} \n",
                                                  .{selfme.pcxt.ball_cen.x,
                                                    selfme.pcxt.ball_cen.y}) catch {};
                glob.flush_log();
            }
            fn reflect(val: f32, boundary: f32, dir: enum{less,more}) ?f32{
                if(((dir == .less) and (val > boundary)) or
                       ((dir == .more) and (val < boundary))){
                        return 2*boundary-val;
                }
                return null;
            }
            fn between(val: f32, pad: f32, low: f32, high: f32) bool{
                if(low > high)
                    return between(val, pad, high, low);
                return ((val-pad) <= high) and
                    ((val+pad) >= low);
            }
        }.init(self);
        const ref = @TypeOf(bth).reflect;
        const betn = @TypeOf(bth).between;

        //Reflect with boundaries
        if(ref(self.ball_cen.x, self.ball_rad, .more))|nx|{
            self.ball_cen.x = nx;
            self.ball_vel.x = -self.ball_vel.x;
        }
        if(ref(self.ball_cen.x, cols-self.ball_rad, .less))|nx|{
            self.ball_cen.x = nx;
            self.ball_vel.x = -self.ball_vel.x;
        }
        
        if(ref(self.ball_cen.y, self.ball_rad * rows/cols, .more))|ny|{
            self.ball_cen.y = ny;
            self.ball_vel.y = -self.ball_vel.y;
        }
        if(ref(self.ball_cen.y, rows-self.ball_rad*rows/cols, .less))|ny|{
            self.ball_cen.y = ny;
            self.ball_vel.y = -self.ball_vel.y;
        }

        //Reflect with board
        if(ref(self.ball_cen.y, self.breaker_pos.y-self.ball_rad*rows/cols, .less))|my|{
            if((self.ball_cen.x >= (self.breaker_pos.x - self.breaker_len/2 - self.ball_rad)) and (self.ball_cen.x <= (self.breaker_pos.x + self.breaker_len/2 + self.ball_rad))){
                //_=my;
                self.ball_cen.y = my;
                //self.ball_vel.y = -self.ball_vel.y;
                //Distort the velocity direction according to % of breaker point
                const frac = 45 * (self.ball_cen.x - self.breaker_pos.x)/(self.breaker_len*0.5);
                const ref_norm = (Vec2{.x = 0, .y = -1.0}).rotate(frac);
                const ref_perp = (Vec2{.x = 1, .y = 0}).rotate(frac);

                self.ball_vel = add(ref_norm.scale(-dot(ref_norm, self.ball_vel)),
                                    ref_perp.scale(dot(ref_perp, self.ball_vel)));

                // self.ball_vel = add(self.ball_vel.sx_(),
                //                     self.ball_vel.s_y().rotate(frac));
            }
        }

        //Collide with the bricks
        {
            var coll_x = false;
            var coll_y = false;
            var coll_count:f32 = 0;
            for(self.bricks, 0..)|row, i|{
                for(row, 0..)|cell, j|{
                    if(!cell) continue;
                    const pos = Vec2{
                        .x = @floatFromInt(j),
                        .y = @floatFromInt(i),
                    };
                    const brad = Vec2{
                        .x = self.ball_rad,
                        .y = self.ball_rad * rows/cols
                    };
                    //Not considering radius and position readjustment
                    const xcoll = betn(pos.x-brad.x,0, self.ball_cen.x,
                                       self.ball_cen.x - self.ball_vel.x) or
                        betn(pos.x+brad.x+1,0, self.ball_cen.x,
                             self.ball_cen.x - self.ball_vel.x);
                    const ycoll = betn(pos.y-brad.y,0, self.ball_cen.y,
                                       self.ball_cen.y - self.ball_vel.y) or
                        betn(pos.y+brad.y+1,0, self.ball_cen.y,
                             self.ball_cen.y - self.ball_vel.y);
                    const is_in =
                        betn(self.ball_cen.y, 0, pos.y-brad.y, pos.y+1+brad.y) and
                        betn(self.ball_cen.x,0, pos.x-brad.x, pos.x+1+brad.x);
                    if((xcoll or ycoll) and is_in){
                        self.bricks[i][j] = false;
                        coll_x = coll_x or xcoll; coll_y = coll_y or ycoll;
                        coll_count += 1.0;
                    }
                    if(is_in and !xcoll and !ycoll){
                        log("Ball is inside a brick but it did so withouht crossing any boundaries !!!!!\n", .{});
                    }

                }
            }
            if(coll_x){
                self.ball_vel.x *= -1;
            }
            if(coll_y){
                self.ball_vel.y *= -1;
            }
            self.ball_vel = add(self.ball_vel, Vec2{.x = coll_count * 0.005,
                                                    .y = coll_count * 0.005});
        }
        glob.flush_log();
        
        //Draw
        JS.clear_rect(0, 0, self.inst.w, self.inst.h);

        {
            const bp = self.to_canvas_coord(self.ball_cen);
            JS.set_fill_style(ZigStr.init("#00ff00"));
            JS.fill_circle(@intFromFloat(bp.x),
                           @intFromFloat(bp.y),
                           @intFromFloat(self.ball_rad * self.calc_cell_size().x));
            
            JS.set_fill_style(ZigStr.init("#000000"));
        }
                
        
        for(self.bricks, 0..)|row, i|{
            for(row, 0..)|cell, j|{

                if(cell){
                    
                    // self.log_buff.writer().print("Hello\n", .{}) catch {};
                    // self.flush_log();
                    var dim = self.calc_cell_size();
                    dim.x *= 0.9;
                    dim.y *= 0.9;
                    var pos = Vec2{
                        .x = @floatFromInt(j),
                        .y = @floatFromInt(i),
                    };
                    pos.x += 0.05; pos.y += 0.05;
                    const cpos = self.to_canvas_coord(pos);
                    JS.fill_rect(@intFromFloat(cpos.x), @intFromFloat(cpos.y),
                              @intFromFloat(dim.x), @intFromFloat(dim.y));
                }

            }
            
        }

        {
            const pos = Vec2{
                .x = self.breaker_pos.x - self.breaker_len/2,
                .y = self.breaker_pos.y,
            };
            var dim = self.calc_cell_size();
            dim.x *= self.breaker_len;

            const cpos = self.to_canvas_coord(pos);
            JS.fill_rect(@intFromFloat(cpos.x), @intFromFloat(cpos.y),
                      @intFromFloat(dim.x), @intFromFloat(dim.y));
        }
        
        
        JS.set_font(ZigStr.init("bold 30px serif"));
        
        JS.stroke_text(ZigStr.init("This is"), @divFloor(self.inst.w, 2) - 60, @divFloor(self.inst.h, 2));
        JS.stroke_text(ZigStr.init("An Amazing"), @divFloor(self.inst.w, 2)-20, @divFloor(self.inst.h, 2) + 40);
        JS.stroke_text(ZigStr.init("Brick Game"), @divFloor(self.inst.w, 2)-125, @divFloor(self.inst.h, 2) + 80);

    }
};


const Pos = struct{ x: i32, y:i32 };
const BoardEvents = struct{
    //down: bool = false,
    right: bool = false,
    //up: bool = false,
    left: bool = false,

    touch_pos:Pos = .{.x=0,.y=0},
    last_touch: ?u32 = null,

    pub fn reset_events(self: *@This()) void{
        //self.down = false; self.up = false;
        self.left = false; self.right = false;
    }

    pub fn key_event(self: *@This(), key_name: [] const u8) void{
        
        if(std.mem.eql(u8, key_name, "ArrowRight")){
            self.right = true;
        }
        if(std.mem.eql(u8, key_name, "ArrowLeft")){
            self.left = true;
        }
        // if(std.mem.eql(u8, key_name, "ArrowUp")){
        //     self.up = true;
        // }
        // if(std.mem.eql(u8, key_name, "ArrowDown")){
        //     self.down = true;
        // }
    }

    pub fn touch_event(self: *@This(), evt_name: [] const u8,
                       id: u32, px: i32, py: i32) bool{
        _=evt_name;
        self.last_touch = id;
        self.touch_pos = Pos{.x=px,.y=py};
        glob.flush_log();
        return false;
    }
};

