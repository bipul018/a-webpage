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
extern fn fill_text(str: ?[*] const u8, len: i32, posx: i32, posy: i32) void;
extern fn fill_rect(x: i32, y: i32, wid: i32, hei: i32) void;


export fn init(posx:i32, posy:i32) i32{
    const str = "Hello";
    const str2 = "World";
    fill_text(str.ptr, str.len, @divFloor(posx, 2), @divFloor(posy, 2));
    fill_text(str2.ptr, str2.len, @divFloor(posx, 2), @divFloor(posy, 2) + 30);
    fill_rect(0,0, 100, 60);
    return 6969;
}
