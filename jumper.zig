const std = @import("std");
const math = std.math;
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

var glob: *Instance = undefined;

pub fn log(comptime format:[] const u8,
           args: anytype) void{
    glob.log_buff.writer().print(format, args) catch {};
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
const Context = struct{
    inst: *Instance = undefined,

    event:JumperEvents=.{},

    bpos:Vec2 = Vec2{.x = 100, .y = 400},
    bvel:f32 = 0.0,
    const brad = 15;
    pub fn init(inst: *Instance) !@This(){
        var self=@This(){};
        self.inst = inst;
        const gpa_allocr = inst.gpa.allocator();
        _=gpa_allocr;
        glob = inst;
        self.bpos.y = @floatFromInt(inst.h);
        self.bpos.y /= 2;
        self.bpos.x = brad;
        self.bpos.x *= 3;
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
        const max_vel = 8;
        const grav = 0.32;


        //log("Last touch val = {d}\n", .{tch});
        if(self.event.touch_dur)|tch|{
            if(self.event.touch_id)|_|{
                if(tch > 2){
                    //self.bvel.y -= math.pow(f32, 50, -tch);
                    //self.bpos.y -= 50;
                    self.bvel = -10;
                    self.event.touch_dur = null;
                }
                else{
                    self.event.touch_dur.? += 1;
                }
            }
            else{
                // if(tch > 0)
                //     self.bpos.y -= 50.0 * tch/50.0;
                self.event.touch_dur = null;
            }
        }
        
        self.bpos = add(self.bpos, Vec2{.x = 0, .y = self.bvel});
        self.bvel = @min(grav + self.bvel, max_vel);
        if(self.bpos.y < Context.brad){
            self.bpos.y = Context.brad;
            self.bvel = 0;
        }
        
        
        if(self.bpos.y > @as(f32, @floatFromInt(self.inst.h - Context.brad))){
            self.bpos.y = @floatFromInt(self.inst.h - Context.brad);
        }
        glob.flush_log();
        
        //Draw
        JS.clear_rect(0, 0, self.inst.w, self.inst.h);

        JS.set_fill_style(ZigStr.init("#00ff00"));
        JS.fill_circle(@intFromFloat(self.bpos.x),
                       @intFromFloat(self.bpos.y),
                       Context.brad);
        JS.set_fill_style(ZigStr.init("#000000"));
        
        JS.set_font(ZigStr.init("bold 30px serif"));
        
        JS.stroke_text(ZigStr.init("This is"), @divFloor(self.inst.w, 2) - 60, @divFloor(self.inst.h, 2));
        JS.stroke_text(ZigStr.init("The"), @divFloor(self.inst.w, 2)-20, @divFloor(self.inst.h, 2) + 40);
        JS.stroke_text(ZigStr.init("Jumping Game"), @divFloor(self.inst.w, 2)-125, @divFloor(self.inst.h, 2) + 80);

    }
};


const Pos = struct{ x: i32, y:i32 };
const JumperEvents = struct{
    //tracks how long key down has been happening
    touch_id: ?u32 = null,
    touch_dur: ?f32 = null,

    pub fn reset_events(self: *@This()) void{
        _=self;
    }

    pub fn key_event(self: *@This(), key_name: [] const u8) void{
        //Need to add type, else not going to be useful in this game
        _=self; _=key_name;
    }

    pub fn touch_event(self: *@This(), evt_name: [] const u8,
                       id: u32, px: i32, py: i32) bool{
        _=px; _=py;
        //Cares about first touch to first untouch
        if(std.mem.eql(u8, evt_name, "enter")){
            //if id is null but dur isn't, then this event is not yet processed
            if((self.touch_id == null) and (self.touch_dur != null))
                return false;
            self.touch_id = id;
            self.touch_dur = 0;
        }
        else if(std.mem.eql(u8, evt_name, "leave")){
            if(self.touch_id == id)
                self.touch_id = null;
        }
        glob.flush_log();
        return false;
    }
};

