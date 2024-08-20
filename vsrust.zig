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



const PRIMES = [_]i32{2, 3, 5, 7, 11, 13, 17, 19, 23};

export fn nth_prime(n: usize) i32 {
    return PRIMES[n];
}
