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

const Pos = struct{
    x: i32,
    y: i32,
};

const Context = struct{
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    tmp_str:std.ArrayList(u8),
    key_press: Keys,
    prng: std.rand.DefaultPrng,
    
    w:i32 = 0,
    h:i32 = 0,

    wait:u32 = 0,
    snake:std.ArrayList(Pos),
    food:Pos,
    dir:union(enum){
        rl:enum{l,r},
        ud:enum{u,d},
    } = .{.rl=.r},

    log_buff:std.ArrayList(u8),
    inline fn logger(self: *Context) std.io.AnyWriter{
        return self.log_buff.writer().any();
    }
    inline fn flush_log(self: *Context) void{
        if(self.log_buff.items.len > 0){
            log_str(ZigStr.init(self.log_buff.items));
        }
        self.log_buff.clearAndFree();
    }
};

const nw = 17;
const nh = 17;

fn initerr(w:i32, h:i32) !*Context{
    var og_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const og_gpa_allocr = og_gpa.allocator();
    errdefer _= og_gpa.deinit();

    const cxt = try og_gpa_allocr.create(Context);
    errdefer og_gpa_allocr.destroy(cxt);
    cxt.gpa = og_gpa;
    const gpa_allocr = cxt.gpa.allocator();
    
    cxt.log_buff = std.ArrayList(u8).init(gpa_allocr);
    errdefer cxt.log_buff.deinit();
    
    cxt.w = w;
    cxt.h = h;
    cxt.tmp_str = std.ArrayList(u8).init(gpa_allocr);
    errdefer cxt.tmp_str.deinit();
    cxt.wait = 0;
    cxt.snake = std.ArrayList(Pos).init(gpa_allocr);
    errdefer cxt.snake.deinit();
    
    try cxt.snake.append(.{.x = 0,.y = 0});
    cxt.dir = .{.rl = .r};

    cxt.prng = std.rand.DefaultPrng.init(crypto_secure_random((1<<63)-1));
    
    cxt.food.x = @intCast(cxt.prng.random().uintAtMost(u32, nw-1));
    cxt.food.y = @intCast(cxt.prng.random().uintAtMost(u32, nh-1));
    
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
        cxt.snake.deinit();
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

var last_touch: ?u32 = null;
var touch_pos = Pos{.x=0,.y=0};
export fn touch_event(pcxt: ?*Context, evt_str: ?[*:0] u8, id: u32, px: i32, py: i32) bool{
    // _=pcxt;
    // _=evt_str;
    // _=id;
    // _=px;
    // _=py;
    // return false;
    
    if(evt_str == null) return false;
    if(pcxt)|cxt|{
        const evt = std.mem.span(evt_str.?);
        if(std.mem.eql(u8, evt, "touchstart")){
            cxt.logger().print("Touching started : {}", .{id}) catch {};
            if(null == last_touch){
                last_touch = id;
                touch_pos = Pos{.x=px,.y=py};
            }
        }
        if(std.mem.eql(u8, evt, "touchend")){
            cxt.logger().print("Touching ended : {}", .{id}) catch {};
            if((null != last_touch) and (id == last_touch.?)){
                const dp = Pos{.x = @intCast(@abs(px - touch_pos.x)),
                               .y = @intCast(@abs(py - touch_pos.y))};
                const touchr = 50;
                if((dp.x >= dp.y) and (dp.x > touchr)){
                    cxt.logger().print("\nTouching right or left", .{}) catch {};
                    key_event(cxt, if(px > touch_pos.x) "ArrowRight" else "ArrowLeft");
                }
                if((dp.y >= dp.x) and (dp.y > touchr)){
                    cxt.logger().print("\nToucing up or down", .{}) catch {};
                    key_event(cxt, if(py > touch_pos.y) "ArrowDown" else "ArrowUp");
                }
            }
            last_touch = null;
        }
        cxt.flush_log();
    }
    return false;
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
        cxt.wait = 23;
        //Update

        if(cxt.dir == .rl){
            if(cxt.key_press.down){
                cxt.dir = .{.ud = .d};
            }
            if(cxt.key_press.up){
                cxt.dir = .{.ud = .u};
            }
        }
        else if(cxt.dir == .ud){
            if(cxt.key_press.left){
                cxt.dir = .{.rl = .l};
            }
            if(cxt.key_press.right){
                cxt.dir = .{.rl = .r};
            }
        }
        cxt.key_press = .{};
        {
            var nhead = cxt.snake.items[0];
            switch(cxt.dir){
                .rl => nhead.x += switch(cxt.dir.rl){
                    .r => 1, .l => -1
                },
                .ud => nhead.y += switch(cxt.dir.ud){
                    .u => -1, .d => 1
                }
            }
            nhead.x = @mod(nhead.x, nw);
            nhead.y = @mod(nhead.y, nh);

            const was_food = (nhead.x == cxt.food.x) and
                (nhead.y == cxt.food.y);
            
            //Move the snake
            for(cxt.snake.items)|*b|{
                std.mem.swap(Pos, b, &nhead);
            }
            if(was_food){
                cxt.snake.append(nhead) catch {};
                cxt.log_buff.writer().print("Food generated\n", .{}) catch {};
                cxt.flush_log();
                cxt.food.x = @intCast(cxt.prng.random().uintAtMost(u32, nw-1));
                cxt.food.y = @intCast(cxt.prng.random().uintAtMost(u32, nh-1));
            }

            //cxt.snake.items[0] = nhead;
        }

        //Draw
        clear_rect(0, 0, cxt.w, cxt.h);
        
        for(cxt.snake.items)|b|{
            draw_box(cxt, .{.x = b.x, .y = b.y}, false);
        }
        draw_box(cxt, cxt.food, true);

        set_font(ZigStr.init("bold 30px serif"));
        
        stroke_text(ZigStr.init("Welcome"), @divFloor(cxt.w, 2) - 60, @divFloor(cxt.h, 2));
        stroke_text(ZigStr.init("To"), @divFloor(cxt.w, 2)-20, @divFloor(cxt.h, 2) + 40);
        stroke_text(ZigStr.init("Da Snake Game"), @divFloor(cxt.w, 2)-125, @divFloor(cxt.h, 2) + 80);

    }

}

fn draw_box(cxt: *Context, pos0: Pos, is_food:bool) void{
    const cell = Pos{
        .x = @max(1, @divFloor(cxt.w , nw)),
        .y = @max(1, @divFloor(cxt.h , nh)),
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
        .x = @divFloor(pos0.x * cxt.w, nw),
        .y = @divFloor(pos0.y * cxt.h, nh),
    };

    
    if(is_food){
        fill_rect(pos.x + pad, pos.y + pad, @max(1,clear.x), @max(1,clear.y));
        // fill_rect(@divFloor(cw,4)+px, @divFloor(ch,4)+py,
        //           @divFloor(cw,2), @divFloor(ch,2));
    }
    else{
        
        fill_rect(pos.x, pos.y, cell.x, cell.y);
        clear_rect(pos.x + pad, pos.y + pad, clear.x, clear.y);
        stroke_rect(pos.x + 2*pad, pos.y + 2*pad, stroke.x, stroke.y);
    }
}
