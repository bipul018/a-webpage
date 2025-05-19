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

export fn init(w: i32, h: i32) ?*Instance {
    return Instance.init(w, h) catch return null;
}

export fn deinit(pinst: ?*Instance) void {
    if (pinst) |inst| {
        inst.deinit();
    }
}
export fn get_tmp_str(pinst: ?*Instance, size: usize) ?[*]u8 {
    if (pinst) |inst| {
        return inst.get_tmp_str(size);
    } else {
        return null;
    }
}

export fn touch_event(pinst: ?*Instance, evt_str: ?[*:0]const u8, id: u32, px: i32, py: i32) bool {
    if (pinst) |inst| {
        if (@hasDecl(@TypeOf(inst.cxt), "touch_event"))
            return inst.cxt.touch_event(Common.from_c_str(evt_str), id, px, py);
    }
    return false;
}

export fn key_event(pinst: ?*Instance, evt_str: ?[*:0]const u8) void {
    if (pinst) |inst| {
        if (@hasDecl(@TypeOf(inst.cxt), "key_event"))
            inst.cxt.key_event(Common.from_c_str(evt_str));
    }
}

export fn resize_event(pinst: ?*Instance, neww2: u32, newh2: u32) void {
    if (pinst) |inst| {
        inst.resize_event(neww2, newh2);
    }
}

export fn loop(pinst: ?*Instance) void {
    if (pinst) |inst| {
        inst.loop();
    }
}

const Pos = struct {
    x: i32,
    y: i32,
};

const nw = 17;
const nh = 17;
var glob: *Instance = undefined;
const action_frame_count = 50; // The number of frames a single action runs
const Lane = enum {
    middle,
    left,
    right,
};
const ObstacleKind = enum { overpass, underpass, nopass };
const Obstacle = struct {
    kind: ObstacleKind,
    lane: Lane,
    after: u32,
};
const Context = struct {
    inst: *Instance = undefined,
    wait: u32 = 0,
    score: i32 = 0,
    obstacles: std.ArrayList(Obstacle) = undefined,
    lane: Lane = .middle, // These represent the three possible places the character can be in
    action: enum {
        none,
        rolling,
        go_right,
        go_left,
        jumping,
    } = .none, // One of the four possible actions that a player can take at a time, including 'no action'
    action_tl: u32 = 0,
    event: RunnerEvents = .{},

    pub fn init(inst: *Instance) !@This() {
        var self = @This(){};
        self.inst = inst;
        const gpa_allocr = inst.gpa.allocator();
        self.wait = 0;
        self.obstacles = std.ArrayList(Pos).init(gpa_allocr);
        errdefer self.obstacles.deinit();

        glob = inst;
        return self;
    }
    pub fn deinit(self: *@This()) void {
        self.obstacles.deinit();
    }
    pub fn key_event(self: *@This(), key_name: []const u8) void {
        self.event.key_event(key_name);
    }
    pub fn touch_event(self: *@This(), evt_name: []const u8, id: u32, px: i32, py: i32) bool {
        return self.event.touch_event(evt_name, id, px, py);
    }
    fn generate_obstacle(self: *@This(), max_late: u32) !void {
        // Always generate obstacle after the last occuring obstacle
        // The list will have obstacles in incoming order
        const min_time = blk: {
            if (self.obstacles.getLastOrNull()) |o| {
                break :blk o.after;
            } else {
                break :blk 5;
            }
        };
        const new_time = self.inst.prng.random().uintAtMost(u32, max_late) + min_time;
        const new_lane = self.inst.prng.random().enumValue(Lane);
        const obs_type = self.inst.prng.random().enumValue(ObstacleKind);
        try self.obstacles.append(.{ .kind = obs_type, .lane = new_lane, .after = new_time });
    }
    pub fn loop(self: *@This()) void {
        if (self.wait > 0) {
            self.wait -= 1;
            return;
        }
        //Set update rate
        self.wait = 23;
        //Update

        // Initiate the action 
        const total_action_time = 20;
        if ((self.action == .none) and (self.action_tl == 0)){
            if (self.event.down) { self.action = .rolling; }
            if (self.event.up) { self.action = .jumping; }
            if (self.event.right) { self.action = .go_right; }
            if (self.event.left) {self.action = .go_left; }
            if (self.action != .none){
                self.action_tl = total_action_time;
            }
        }
        self.event.reset_events();

        // Logic that controls the transition of action (no collision detection yet)
        if(self.action_tl > 0){
            self.action_tl -= 1;
        } else {
            self.action_tl = 0;
            self.action = .none;
        }
            
        var did_it_collide = false;
        // Write the logic that moves around the player
        if(self.action_tl == total_action_time){
            if(self.action == .go_right){
                switch(self.lane){
                    .left => {self.lane = .middle;},
                    .middle => {self.lane = .right;},
                    .right => {did_it_collide = true; self.action = .none;},
                }
            }
            if(self.action == .go_left){
                switch(self.lane){
                    .right => {self.lane = .middle;}
                    .middle => {self.lane = .left;},
                    .left => {did_it_collide = true; self.action = .none},
                }
            }
        }

        //Perform collision detection

        // Collison happens if some obstacle is imminent, and the player is there in the same lane and is not skipping
        if ((self.obstacles.items.len > 0) and (self.obstacles.items[0].after == 0)){
            const obst = self.obstacles.items[0];
            if((obst.lane == self.lane) and 
               ((obst.kind == .nopass) or 
                ((obst.kind == .underpass) and (self.action != .rolling)) or
                ((obst.kind == .overpass) and (self.action != .jumping)))){
                // Collision has happened
                did_it_collide = true;
            } else {
                self.score += 1;
            }
            // Now remove that obstacle from the list
            _=self.obstacles.orderedRemove(0);
        }
        if(did_it_collide){ self.score -= 1; } 
        // Now decrement the 'after' of each obstacle by 1
        for(&self.obstacles.items)|*obs|{
            obs.after -= 1;
        }

        // Spawn the obstacles

        //Draw
        clear_rect(0, 0, self.inst.w, self.inst.h);

        for (self.obstacles.items) |b| {
            // Need to do some kind of perspective projection (even if only 1 dimension)
            //draw_box(self, .{ .x = b.x, .y = b.y }, false);
        }
        // Draw the player here
        //draw_box(self, self.food, true);

        set_font(ZigStr.init("bold 30px serif"));

        stroke_text(ZigStr.init("Welcome"), @divFloor(self.inst.w, 2) - 60, @divFloor(self.inst.h, 2));
        stroke_text(ZigStr.init("To"), @divFloor(self.inst.w, 2) - 20, @divFloor(self.inst.h, 2) + 40);
        stroke_text(ZigStr.init("The Running Game"), @divFloor(self.inst.w, 2) - 125, @divFloor(self.inst.h, 2) + 80);
    }
};

fn draw_box(cxt: *Context, pos0: Pos, is_food: bool) void {
    const cell = Pos{
        .x = @max(1, @divFloor(cxt.inst.w, nw)),
        .y = @max(1, @divFloor(cxt.inst.h, nh)),
    };
    const pad = 5;
    const clear = Pos{ .x = @max(cell.x - 2 * pad, 0), .y = @max(cell.y - 2 * pad, 0) };
    const stroke = Pos{ .x = @max(clear.x - 2 * pad, 0), .y = @max(clear.y - 2 * pad, 0) };

    const pos = Pos{
        .x = @divFloor(pos0.x * cxt.inst.w, nw),
        .y = @divFloor(pos0.y * cxt.inst.h, nh),
    };

    if (is_food) {
        fill_rect(pos.x + pad, pos.y + pad, @max(1, clear.x), @max(1, clear.y));
    } else {
        fill_rect(pos.x, pos.y, cell.x, cell.y);
        clear_rect(pos.x + pad, pos.y + pad, clear.x, clear.y);
        stroke_rect(pos.x + 2 * pad, pos.y + 2 * pad, stroke.x, stroke.y);
    }
}

const RunnerEvents = struct {
    down: bool = false,
    right: bool = false,
    up: bool = false,
    left: bool = false,

    touch_pos: Pos = .{ .x = 0, .y = 0 },
    last_touch: ?u32 = null,

    pub fn reset_events(self: *@This()) void {
        self.down = false;
        self.right = false;
        self.left = false;
        self.up = false;
    }

    pub fn key_event(self: *@This(), key_name: []const u8) void {
        if (std.mem.eql(u8, key_name, "ArrowDown")) {
            self.down = true;
        }
        if (std.mem.eql(u8, key_name, "ArrowRight")) {
            self.right = true;
        }
        if (std.mem.eql(u8, key_name, "ArrowUp")) {
            self.up = true;
        }
        if (std.mem.eql(u8, key_name, "ArrowLeft")) {
            self.left = true;
        }
        glob.flush_log();
    }

    pub fn touch_event(self: *@This(), evt_name: []const u8, id: u32, px: i32, py: i32) bool {
        if (std.mem.eql(u8, evt_name, "enter")) {
            //if(null == self.last_touch){
            self.last_touch = id;
            self.touch_pos = Pos{ .x = px, .y = py };
            //}
            glob.log_buff.writer().print("Enter event at {} {}\n", .{ px, py }) catch {};
        }
        if (std.mem.eql(u8, evt_name, "leave")) {
            glob.log_buff.writer().print("Leave event del {} {} \n", .{ px - self.touch_pos.x, py - self.touch_pos.y }) catch {};
            if ((null != self.last_touch) and (id == self.last_touch.?)) {
                const dp = Pos{ .x = @intCast(@abs(px - self.touch_pos.x)), .y = @intCast(@abs(py - self.touch_pos.y)) };
                const touchr = 50;
                if ((dp.x >= dp.y) and (dp.x > touchr)) {
                    self.key_event(if (px > self.touch_pos.x) "ArrowRight" else "ArrowLeft");
                }
                if ((dp.y >= dp.x) and (dp.y > touchr)) {
                    self.key_event(if (py > self.touch_pos.y) "ArrowDown" else "ArrowUp");
                }
                self.last_touch = null;
            }
        }
        glob.flush_log();
        return false;
    }
};
