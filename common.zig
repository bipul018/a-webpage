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
pub const ZigStr = extern struct{
    ptr: [*] const u8,
    len: usize,
    pub fn init(str: [] const u8) ZigStr{
        return .{
            .ptr = str.ptr,
            .len = str.len
        };
    }
};

//Converts c string to zig string, and returns empty string if null
pub fn from_c_str(cstr: ?[*:0] const u8) [] const u8{
    if(cstr)|sstr|{ return std.mem.span(sstr); }
    return "";
}

pub extern fn crypto_secure_random(max_val: u64) u64;
pub extern fn log_str(str: ZigStr) void;
pub extern fn resize_canvas(width: u32, height: u32) void;
pub extern fn set_font(fnt: ZigStr) void;
pub extern fn set_fill_style(fstl: ZigStr) void;
pub extern fn fill_text(str: ZigStr, posx: i32, posy: i32) void;
pub extern fn stroke_text(str: ZigStr, posx: i32, posy: i32) void;
pub extern fn fill_rect(x: i32, y: i32, wid: i32, hei: i32) void;
pub extern fn fill_circle(x: i32, y: i32, r: i32) void;
pub extern fn stroke_rect(x: i32, y: i32, wid: i32, hei: i32) void;
pub extern fn clear_rect(x: i32, y: i32, wid: i32, hei: i32) void;

pub fn Instance(T: anytype) type{
    return struct{
        gpa: std.heap.GeneralPurposeAllocator(.{}),
        tmp_str:std.ArrayList(u8),
        prng: std.rand.DefaultPrng,
        log_buff:std.ArrayList(u8),
        w:i32 = 0,
        h:i32 = 0,
        cxt: T,
        pub inline fn logger(self: *@This()) std.io.AnyWriter{
            return self.log_buff.writer().any();
        }
        pub inline fn flush_log(self: *@This()) void{
            if(self.log_buff.items.len > 0){
                log_str(ZigStr.init(self.log_buff.items));
            }
            self.log_buff.clearAndFree();
        }
        pub fn init(w:i32, h:i32) !*@This(){
            var og_gpa = std.heap.GeneralPurposeAllocator(.{}){};
            const og_gpa_allocr = og_gpa.allocator();
            errdefer _= og_gpa.deinit();

            const inst = try og_gpa_allocr.create(@This());
            errdefer og_gpa_allocr.destroy(inst);
            inst.gpa = og_gpa;
            const gpa_allocr = inst.gpa.allocator();
            
            inst.log_buff = std.ArrayList(u8).init(gpa_allocr);
            errdefer inst.log_buff.deinit();
            
            inst.tmp_str = std.ArrayList(u8).init(gpa_allocr);
            errdefer inst.tmp_str.deinit();
            
            inst.prng = std.rand.DefaultPrng.init(crypto_secure_random((1<<63)-1));
            
            inst.w = w;
            inst.h = h;
            
            inst.cxt = try T.init(inst);

            return inst;
        }
        pub fn deinit(self: *@This()) void{
            var gpa = self.gpa;
            const gpa_allocr = gpa.allocator();
            defer _=gpa.deinit();
            defer gpa_allocr.destroy(self);

            self.log_buff.deinit();
            self.tmp_str.deinit();
            self.cxt.deinit();
        }
        pub fn get_tmp_str(self: *@This(), size: usize) ?[*]u8{
            self.tmp_str.resize(size+1) catch return null;
            return self.tmp_str.items.ptr;
        }
        pub fn tmp_print(self: *@This(), comptime format: [] const u8,
                         args: anytype) ?[] const u8{
            self.tmp_str.resize(0) catch return null;
            _=self.tmp_str.writer().print(format, args) catch return null;
            return self.tmp_str.items;
        }
        pub fn resize_event(self: *@This(), neww2: u32, newh2: u32) void{
            const newh = @divFloor(newh2 * 9, 10); //Leave off 10% from bottom
            const neww = @divFloor(neww2 * 95,100); //Leave off some on the right side
            //Always make a square board
            //Try to make space for text at bottom
            const dim = @min(newh, neww);
            self.w = @intCast(dim);
            self.h = @intCast(dim);
            resize_canvas(@intCast(self.w), @intCast(self.h));
        }
        pub fn loop(self: *@This()) void{
            self.cxt.loop();
        }
    };
}
