const std = @import("std");

extern fn set_font(std: ZigStr) void;
extern fn fill_text(str: ZigStr, posx: i32, posy: i32) void;
extern fn stroke_text(str: ZigStr, posx: i32, posy: i32) void;
extern fn fill_rect(x: i32, y: i32, wid: i32, hei: i32) void;
extern fn stroke_rect(x: i32, y: i32, wid: i32, hei: i32) void;
extern fn clear_rect(x: i32, y: i32, wid: i32, hei: i32) void;

const Common = @import("common.zig");
const Instance = Common.Instance(Context);
const ZigStr = Common.ZigStr;

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
            return inst.cxt.touch_event(Common.from_c_str(evt_str),
                                        id, px, py);
    }
    return false;
}

export fn key_event(pinst: ?*Instance, evt_str: ?[*:0] const u8) void{
    if(pinst)|inst|{
        if(@hasDecl(@TypeOf(inst.cxt), "key_event"))
            inst.cxt.key_event(Common.from_c_str(evt_str));
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
};

//Aspect ratio, width to height of a cell
const as_rt : f32 = 16.0/9.0;

//Number of cells along width and height
const cols = 20;
const rows = 30;

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
        return self;
    }
    pub fn deinit(self: *@This()) void{
        _=self;
    }
    pub fn key_event(self: *@This(), key_name:[] const u8) void{
        self.event.key_event(key_name);
    }
    // pub fn touch_event(self: *@This(), evt_name:[] const u8,
    //                    id: u32, px: i32, py: i32) bool{
    //     return self.event.touch_event(evt_name, id,
    //                                   px, py);
    // }
    pub fn loop(self: *@This()) void{
        //Update
        const move_speed = 0.5;
        if(self.event.left){
            self.breaker_pos.x = @max(1, self.breaker_pos.x - move_speed);
        }
        if(self.event.right){
            self.breaker_pos.x = @min(cols-1, self.breaker_pos.x + move_speed);
        }
        self.event.reset_events();
        
        //Draw
        clear_rect(0, 0, self.inst.w, self.inst.h);

        for(self.bricks, 0..)|row, i|{
            for(row, 0..)|cell, j|{

                if(cell){
                    
                    // self.log_buff.writer().print("Hello\n", .{}) catch {};
                    // self.flush_log();
                    var dim = self.calc_cell_size();
                    dim.x *= 0.9;
                    dim.y *= 0.9;
                    const pos = Vec2{
                        .x = @floatFromInt(j),
                        .y = @floatFromInt(i),
                    };
                    const cpos = self.to_canvas_coord(pos);
                    fill_rect(@intFromFloat(cpos.x), @intFromFloat(cpos.y),
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
            fill_rect(@intFromFloat(cpos.x), @intFromFloat(cpos.y),
                      @intFromFloat(dim.x), @intFromFloat(dim.y));
        }
        
        
        set_font(ZigStr.init("bold 30px serif"));
        
        stroke_text(ZigStr.init("This is"), @divFloor(self.inst.w, 2) - 60, @divFloor(self.inst.h, 2));
        stroke_text(ZigStr.init("An Amazing"), @divFloor(self.inst.w, 2)-20, @divFloor(self.inst.h, 2) + 40);
        stroke_text(ZigStr.init("Brick Game"), @divFloor(self.inst.w, 2)-125, @divFloor(self.inst.h, 2) + 80);

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
        if(std.mem.eql(u8, evt_name, "touchstart")){
            if(null == self.last_touch){
                self.last_touch = id;
                self.touch_pos = Pos{.x=px,.y=py};
            }
        }
        if(std.mem.eql(u8, evt_name, "touchend")){
            if((null != self.last_touch) and (id == self.last_touch.?)){
                const dp = Pos{.x = @intCast(@abs(px - self.touch_pos.x)),
                               .y = @intCast(@abs(py - self.touch_pos.y))};
                const touchr = 50;
                if((dp.x >= dp.y) and (dp.x > touchr)){
                    self.key_event(if(px > self.touch_pos.x) "ArrowRight" else "ArrowLeft");
                }
                if((dp.y >= dp.x) and (dp.y > touchr)){
                    self.key_event(if(py > self.touch_pos.y) "ArrowDown" else "ArrowUp");
                }
            }
            self.last_touch = null;
        }
        return false;
    }
};

