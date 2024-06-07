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
extern fn crypto_secure_random(max_val: u32) u32;
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
};

const nw = 15;
const nh = 15;

fn initerr(w:i32, h:i32) !*Context{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocr = gpa.allocator();
    errdefer _= gpa.deinit();

    const cxt = try gpa_allocr.create(Context);
    errdefer gpa_allocr.destroy(cxt);
    cxt.gpa = gpa;
    cxt.w = w;
    cxt.h = h;
    cxt.tmp_str = std.ArrayList(u8).init(gpa_allocr);
    errdefer cxt.tmp_str.deinit();
    cxt.wait = 0;
    cxt.snake = std.ArrayList(Pos).init(gpa_allocr);
    errdefer cxt.snake.deinit();
    // try cxt.snake.append(.{.x = 2,.y = 0});
    // try cxt.snake.append(.{.x = 1,.y = 0});
    try cxt.snake.append(.{.x = 0,.y = 0});
    cxt.dir = .{.rl = .r};

    cxt.prng = std.rand.DefaultPrng.init(crypto_secure_random((1<<32)-1));
    cxt.food = .{.x = 3, .y = 3};

    return cxt;
}

export fn init(w:i32, h:i32) ?*Context{
    return initerr(w,h) catch null;
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
        cxt.wait = 20;
        //Update

        if(cxt.dir == .rl){
            if(cxt.key_press.down){
                cxt.dir = .{.ud = .d};
            }
            if(cxt.key_press.up){
                cxt.dir = .{.ud = .u};
            }
        }
        if(cxt.dir == .ud){
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
        stroke_text(ZigStr.init("The Snake Game"), @divFloor(cxt.w, 2)-125, @divFloor(cxt.h, 2) + 80);

    }

}

fn draw_box(cxt: *Context, pos: Pos, is_food:bool) void{
    const cw = @divFloor(cxt.w , nw);
    const ch = @divFloor(cxt.h , nh);
    
    const px = pos.x * cw;
    const py = pos.y * ch;
    if(is_food){
        fill_rect(@divFloor(cw,4)+px, @divFloor(ch,4)+py,
                  @divFloor(cw,2), @divFloor(ch,2));
    }
    else{
        
        fill_rect(px, py, cw, ch);
        clear_rect(@divFloor(cw,5)+px, @divFloor(ch,5)+py,
                   3*@divFloor(cw,5), 3*@divFloor(ch,5));
        stroke_rect(@divFloor(cw,4)+px, @divFloor(ch,4)+py,
                    @divFloor(cw,2), @divFloor(ch,2));
    }
}
