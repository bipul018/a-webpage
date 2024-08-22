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

extern fn crypto_secure_random(max_val: u64) u64;
extern fn log_str(str: ZigStr) void;
extern fn resize_canvas(width: u32, height: u32) void;
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
        return inst.cxt.touch_event(Common.from_c_str(evt_str),
                                    id, px, py);
    }
    return false;
}

export fn key_event(pinst: ?*Instance, evt_str: ?[*:0] const u8) void{
    if(pinst)|inst|{
        inst.cxt.key_event(Common.from_c_str(evt_str));
    }
}

export fn resize_event(pinst: ?*Instance, neww2: u32, newh2: u32) void{
    if(pinst)|inst|{ inst.resize_event(neww2, newh2); }
}

export fn loop(pinst: ?*Instance) void{
    if(pinst)|inst|{ inst.loop(); }
}

const Pos = struct{
    x: i32,
    y: i32,
};

const nw = 17;
const nh = 17;



const Context = struct{
    inst: *Instance=undefined,
    wait:u32=0,
    snake:std.ArrayList(Pos)=undefined,
    food:Pos=undefined,
    dir:union(enum){
        rl:enum{l,r},
        ud:enum{u,d},
    } = .{.rl=.r},
    event:SnakeEvents=.{},
    pub fn init(inst: *Instance) !@This(){
        var self=@This(){};
        self.inst = inst;
        const gpa_allocr = inst.gpa.allocator();
        self.wait = 0;
        self.snake = std.ArrayList(Pos).init(gpa_allocr);
        errdefer self.snake.deinit();
        
        try self.snake.append(.{.x = 0,.y = 0});
        self.dir = .{.rl = .r};
        self.food.x = @intCast(inst.prng.random().
                                   uintAtMost(u32, nw-1));
        self.food.y = @intCast(inst.prng.random().
                                   uintAtMost(u32, nh-1));
        return self;   
    }
    pub fn deinit(self: *@This()) void{
        self.snake.deinit();
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

        if(self.wait > 0){
            self.wait -=1;
            return;
        }
        //Set update rate
        self.wait = 23;
        //Update

        if(self.dir == .rl){
            if(self.event.down){
                self.dir = .{.ud = .d};
            }
            if(self.event.up){
                self.dir = .{.ud = .u};
            }
        }
        else if(self.dir == .ud){
            if(self.event.left){
                self.dir = .{.rl = .l};
            }
            if(self.event.right){
                self.dir = .{.rl = .r};
            }
        }
        self.event.reset_events();

        {
            var nhead = self.snake.items[0];
            switch(self.dir){
                .rl => nhead.x += switch(self.dir.rl){
                    .r => 1, .l => -1
                },
                .ud => nhead.y += switch(self.dir.ud){
                    .u => -1, .d => 1
                }
            }
            nhead.x = @mod(nhead.x, nw);
            nhead.y = @mod(nhead.y, nh);

            const was_food = (nhead.x == self.food.x) and
                (nhead.y == self.food.y);
            
            //Move the snake
            for(self.snake.items)|*b|{
                std.mem.swap(Pos, b, &nhead);
            }
            if(was_food){
                self.snake.append(nhead) catch {};
                self.inst.log_buff.writer().print("Food generated\n", .{}) catch {};
                self.inst.flush_log();
                self.food.x = @intCast(self.inst.prng.random().uintAtMost(u32, nw-1));
                self.food.y = @intCast(self.inst.prng.random().uintAtMost(u32, nh-1));
            }

            //self.snake.items[0] = nhead;
        }

        //Draw
        clear_rect(0, 0, self.inst.w, self.inst.h);
        
        for(self.snake.items)|b|{
            draw_box(self, .{.x = b.x, .y = b.y}, false);
        }
        draw_box(self, self.food, true);

        set_font(ZigStr.init("bold 30px serif"));
        
        stroke_text(ZigStr.init("Welcome"), @divFloor(self.inst.w, 2) - 60, @divFloor(self.inst.h, 2));
        stroke_text(ZigStr.init("To"), @divFloor(self.inst.w, 2)-20, @divFloor(self.inst.h, 2) + 40);
        stroke_text(ZigStr.init("The Snake Game"), @divFloor(self.inst.w, 2)-125, @divFloor(self.inst.h, 2) + 80);

    }


};

fn draw_box(cxt: *Context, pos0: Pos, is_food:bool) void{
    const cell = Pos{
        .x = @max(1, @divFloor(cxt.inst.w , nw)),
        .y = @max(1, @divFloor(cxt.inst.h , nh)),
    };
    const pad = 5;
    const clear = Pos{
        .x = @max(cell.x - 2 * pad, 0),
        .y = @max(cell.y - 2 * pad, 0)
    };
    const stroke = Pos{
        .x = @max(clear.x - 2 * pad, 0),
        .y = @max(clear.y - 2 * pad, 0)
    };

    const pos = Pos{
        .x = @divFloor(pos0.x * cxt.inst.w, nw),
        .y = @divFloor(pos0.y * cxt.inst.h, nh),
    };

    if(is_food){
        fill_rect(pos.x + pad, pos.y + pad, @max(1,clear.x), @max(1,clear.y));
    }
    else{
        fill_rect(pos.x, pos.y, cell.x, cell.y);
        clear_rect(pos.x + pad, pos.y + pad, clear.x, clear.y);
        stroke_rect(pos.x + 2*pad, pos.y + 2*pad, stroke.x, stroke.y);

    }
}
    

    
const SnakeEvents = struct{
    down: bool = false,
    right: bool = false,
    up: bool = false,
    left: bool = false,

    touch_pos:Pos = .{.x=0,.y=0},
    last_touch: ?u32 = null,

    pub fn reset_events(self: *@This()) void{
        self.down = false; self.right = false;
        self.left = false; self.up = false;
    }

    pub fn key_event(self: *@This(), key_name: [] const u8) void{
        if(std.mem.eql(u8, key_name, "ArrowDown")){
            self.down = true;
        }
        if(std.mem.eql(u8, key_name, "ArrowRight")){
            self.right = true;
        }
        if(std.mem.eql(u8, key_name, "ArrowUp")){
            self.up = true;
        }
        if(std.mem.eql(u8, key_name, "ArrowLeft")){
            self.left = true;
        }
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
