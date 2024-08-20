const std = @import("std");

pub const std_options = .{
    .logFn = my_log_fn,
};
pub fn my_log_fn(
comptime level: std.log.Level,            
comptime scope: @TypeOf(.EnumLiteral),    
comptime format: []const u8,              
    args: anytype,
) void {
    _=level;
    _=scope;
    _=format;
    _=args;
}

//const c = @cImport({@cInclude("jsfunc.h");});
const ZigStr = extern struct{
    ptr: [*] const u8,
    len: usize,
    fn init(str: [] const u8) ZigStr{
        return .{
            .ptr = str.ptr,
            .len = str.len
        };
    }
};
extern fn crypto_secure_random(max_val: u64) u64;
extern fn log_str(str: ZigStr) void;
extern fn resize_canvas(width: u32, height: u32) void;
extern fn set_font(std: ZigStr) void;
extern fn fill_text(str: ZigStr, posx: i32, posy: i32) void;
extern fn stroke_text(str: ZigStr, posx: i32, posy: i32) void;
extern fn fill_rect(x: i32, y: i32, wid: i32, hei: i32) void;
extern fn stroke_rect(x: i32, y: i32, wid: i32, hei: i32) void;
extern fn clear_rect(x: i32, y: i32, wid: i32, hei: i32) void;

const Vec2 = struct{
    x: f32,
    y: f32,
};

//Aspect ratio, width to height of a cell
const as_rt : f32 = 16.0/9.0;

//Number of cells along width and height
const cols = 20;
const rows = 30;

const Context = struct{

    gpa: std.heap.GeneralPurposeAllocator(.{}),
    tmp_str:std.ArrayList(u8) = undefined,
    key_press: Keys = undefined,
    prng: std.rand.DefaultPrng = undefined,

    //Any event update rate
    wait:u32 = 0,
    
    //Canvas width and height
    w:i32 = 0,
    h:i32 = 0,

    //2D array of allowed bricks from top
    bricks:[rows/2][cols] bool = blk:{
        var tmp:[rows/2][cols] bool = undefined;
        for(&tmp)|*row|{
            for(row)|*cell|{
                cell.* = true;
                //tmp[i][j] = true;
            }
        }
        tmp[rows/4][cols/2] = false;
        break :blk tmp;
    },
    
    //Info of breaker
    breaker_len:f32 = 2.0,
    //Center along x, but top of y
    breaker_pos:Vec2 = Vec2{.x = cols/2.0, .y = rows - 2},

    //Info of ball
    ball_rad:f32 = 0.4,
    ball_cen:Vec2 = Vec2{.x = cols/2.0, .y = rows - 3 - 0.4},
    ball_vel:Vec2 = Vec2{.x = 0, .y = -0.1},

    log_buff:std.ArrayList(u8) = undefined,
    
    fn flush_log(self: *Context) void{
        log_str(ZigStr.init(self.log_buff.items));
        self.log_buff.clearAndFree();
    }
    
    fn calc_used_dim(self: * const Context) Vec2{
        //Calculate ratio of total width to total height needed,
        const ac_as_rt = (as_rt * cols) / rows;

        //First assume we use full height, but adjusted width
        var dim = Vec2{.x = @as(f32, @floatFromInt(self.h)) * ac_as_rt,
                       .y = @floatFromInt(self.h)};
        //If assumption is wrong, use full width
        if(dim.x > @as(f32, @floatFromInt(self.w))){
            dim.x = @floatFromInt(self.w);
            dim.y = @as(f32, @floatFromInt(self.w)) / ac_as_rt;
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
    
    //Drawing function of a cell todo add color

    // dir:union(enum){
    //     rl:enum{l,r},
    //     ud:enum{u,d},
    // } = .{.rl=.r},

    
};

fn initerr(w:i32, h:i32) !*Context{
    var og_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const og_gpa_allocr = og_gpa.allocator();
    errdefer _= og_gpa.deinit();

    const cxt = try og_gpa_allocr.create(Context);
    errdefer og_gpa_allocr.destroy(cxt);
    cxt.* = Context{.gpa = og_gpa};

    const gpa_allocr = cxt.gpa.allocator();

    cxt.log_buff = std.ArrayList(u8).init(gpa_allocr);
    errdefer cxt.log_buff.deinit();
    
    cxt.w = w;
    cxt.h = h;
    cxt.tmp_str = std.ArrayList(u8).init(gpa_allocr);
    errdefer cxt.tmp_str.deinit();
    cxt.wait = 0;
    //cxt.dir = .{.rl = .r};

    cxt.prng = std.rand.DefaultPrng.init(crypto_secure_random((1<<63)-1));

    //cxt.log_buff.writer().print("Hello\n", .{}) catch {};
    
    return cxt;
}

export fn init(w:i32, h:i32) ?*Context{
    return initerr(w,h) catch null;
}


export fn deinit(pcxt: ?*Context) void{
    if(pcxt)|cxt|{
        var gpa = cxt.gpa;
        const gpa_allocr = gpa.allocator();
        defer _=gpa.deinit();
        defer gpa_allocr.destroy(cxt);

        cxt.log_buff.deinit();
        cxt.tmp_str.deinit();
    }
}


export fn get_tmp_str(pcxt: ?*Context, size: usize) ?[*]u8{
    if(pcxt)|cxt|{
        cxt.tmp_str.resize(size+1) catch return null;
        return cxt.tmp_str.items.ptr;
    }
    return null;
}

const Keys = struct{
    down: bool = false,
    right: bool = false,
    up: bool = false,
    left: bool = false,
};

export fn key_event(pcxt: ?*Context, cstr: ?[*:0] const u8) void{
    if(pcxt)|cxt|{
        if(cstr)|spanstr|{
            const str = std.mem.span(spanstr);
            if(std.mem.eql(u8, str, "ArrowDown")){
                cxt.key_press.down = true;
            }
            if(std.mem.eql(u8, str, "ArrowRight")){
                cxt.key_press.right = true;
            }
            if(std.mem.eql(u8, str, "ArrowUp")){
                cxt.key_press.up = true;
            }
            if(std.mem.eql(u8, str, "ArrowLeft")){
                cxt.key_press.left = true;
            }
        }
    }
}



export fn resize_event(pcxt: ?*Context, neww2: u32, newh2: u32) void{
    const newh = @divFloor(newh2 * 9, 10); //Leave off 10% from bottom
    const neww = @divFloor(neww2 * 95,100); //Leave off some on the right side
    if(pcxt)|cxt|{
        //Always make a square board
        //Try to make space for text at bottom
        const dim = @min(newh, neww);
        cxt.w = @intCast(dim);
        cxt.h = @intCast(dim);
        resize_canvas(@intCast(cxt.w), @intCast(cxt.h));
    }
}

export fn loop(pcxt: ?*Context) void{
    if(pcxt)|cxt|{
        if(cxt.wait > 0){
            cxt.wait -=1;
            return;
        }
        //Set update rate
        cxt.wait = 1;
        //Update

        const move_speed = 0.5;
        if(cxt.key_press.left){
            cxt.breaker_pos.x = @max(1, cxt.breaker_pos.x - move_speed);
        }
        if(cxt.key_press.right){
            cxt.breaker_pos.x = @min(cols-1, cxt.breaker_pos.x + move_speed);
        }
        cxt.key_press = .{};
        
        //Draw
        clear_rect(0, 0, cxt.w, cxt.h);

        for(cxt.bricks, 0..)|row, i|{
            for(row, 0..)|cell, j|{

                if(cell){
                    
                    // cxt.log_buff.writer().print("Hello\n", .{}) catch {};
                    // cxt.flush_log();
                    var dim = cxt.calc_cell_size();
                    dim.x *= 0.9;
                    dim.y *= 0.9;
                    const pos = Vec2{
                        .x = @floatFromInt(j),
                        .y = @floatFromInt(i),
                    };
                    const cpos = cxt.to_canvas_coord(pos);
                    fill_rect(@intFromFloat(cpos.x), @intFromFloat(cpos.y),
                              @intFromFloat(dim.x), @intFromFloat(dim.y));
                }

            }
            
        }

        {
            const pos = Vec2{
                .x = cxt.breaker_pos.x - cxt.breaker_len/2,
                .y = cxt.breaker_pos.y,
            };
            var dim = cxt.calc_cell_size();
            dim.x *= cxt.breaker_len;

            const cpos = cxt.to_canvas_coord(pos);
            fill_rect(@intFromFloat(cpos.x), @intFromFloat(cpos.y),
                      @intFromFloat(dim.x), @intFromFloat(dim.y));
        }
        
        
        set_font(ZigStr.init("bold 30px serif"));
        
        stroke_text(ZigStr.init("Welcome"), @divFloor(cxt.w, 2) - 60, @divFloor(cxt.h, 2));
        stroke_text(ZigStr.init("To"), @divFloor(cxt.w, 2)-20, @divFloor(cxt.h, 2) + 40);
        stroke_text(ZigStr.init("Da Brick Game"), @divFloor(cxt.w, 2)-125, @divFloor(cxt.h, 2) + 80);

    }
}
