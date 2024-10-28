const std = @import("std");
extern fn set_font(std: ZigStr) void;
extern fn fill_text(str: ZigStr, posx: i32, posy: i32) void;
extern fn stroke_text(str: ZigStr, posx: i32, posy: i32) void;
extern fn fill_rect(x: i32, y: i32, wid: i32, hei: i32) void;
extern fn stroke_rect(x: i32, y: i32, wid: i32, hei: i32) void;
extern fn clear_rect(x: i32, y: i32, wid: i32, hei: i32) void;

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

const Vec2 = @Vector(2, f32);
const Pos = @Vector(2, i32);
const UPos = @Vector(2, usize);

pub fn pos_to_vec2(pos: anytype) Vec2{
    return Vec2{
        @floatFromInt(pos[0]),
        @floatFromInt(pos[1]),
    };
}

pub fn vec2_to_pos(vec2: Vec2) Pos{
    return Pos{
        @intFromFloat(vec2[0]),
        @intFromFloat(vec2[1])
    };
}

pub fn pos_to_upos(pos: Pos) UPos{
    return UPos{
        @intCast(pos[0]),
        @intCast(pos[1])
    };
}

const nw = 17;
const nh = 17;
var glob: *Instance = undefined;
const Context = struct{
    const types = [_][] const u8{
        "#000000", // This is the blank type
        //"#FF5733", "#33FF57", "#3357FF", "#FF33A1", "#FFD733", "#7A33FF"
        "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff"
    };
    const gcnt = 8;
    const box_size = 10.0;

    inst: *Instance=undefined,

    grid:[gcnt][gcnt]usize = undefined,
    score:i32 = 0,
    event:CrushEvents=.{},
    pub fn init(inst: *Instance) !@This(){
        var self=@This(){};
        self.inst = inst;
        const gpa_allocr = inst.gpa.allocator();
        _=gpa_allocr;
        //self.wait = 0;
        //self.crush = std.ArrayList(Pos).init(gpa_allocr);
        //errdefer self.crush.deinit();
        glob = inst;
        
        self.clear_grid();
        while(true){
            _=self.make_all_fall();
            const c = self.clear_3s();
            if(c == 0) break;
        }
        self.inst.log_buff.clearRetainingCapacity();
        return self;   
    }
    pub fn deinit(self: *@This()) void{
        _=self;
    }
    pub fn key_event(self: *@This(), key_name:[] const u8) void{
        //_=key_name;_=self;
        self.event.key_event(key_name);
    }
    pub fn touch_event(self: *@This(), evt_name:[] const u8,
                       id: u32, px: i32, py: i32) bool{
        //_=self;_=evt_name;_=id;_=px;_=py;
        return self.event.touch_event(evt_name, id,
                                      px, py);
        //return false;
    }
    pub fn clear_grid(self: *@This()) void{
        for(0..gcnt)|x|{
            for(0..gcnt)|y|{
                //self.grid[i][j] = @intCast(self.inst.prng.random().uintAtMost(u32, types.len-1));
                self.grid[x][y] = 0;
            }
        }
    }

    //An internal function to create the falling filling mechanism for a single box
    fn make_a_fall(self: *@This(), pos: Pos) bool{
        //Check how many from here on up is empty,
        // If empty then non empty, then move down that much
        // Then recursively call to fill randomly
        // But do this later
        const p = pos_to_upos(pos);

        //Lower of empty
        var min :i32 = pos[1];
        //Upper of empty
        var max :i32 = pos[1];


        //Now while not empty, move up min
        while((min >= 0) and (self.grid[p[0]][@intCast(min)] != 0)){
            min -= 1;
        }
        //Case when there is no empty upto top
        if(min < 0) return false;

        //Now since current(min) is empty, we move up max from min till empty
        max =  min;
        while((max >= 0) and (self.grid[p[0]][@intCast(max)] == 0)){
            max -= 1;
        }
        //glob.log_buff.writer().print("max found : max = {} min = {} pos = {}\n", .{max, min, pos}) catch {};
        if(max < 0){
            //Fill with random stuff and return true
            for(0..@intCast(min+1))|y|{
                self.grid[p[0]][y] = @intCast(self.inst.prng.random().uintAtMost(u32, types.len-2)+1);
            }
            //glob.log_buff.writer().print("max <0 : max = {} min = {} pos = {}\n", .{max, min, pos}) catch {};            
        }
        else{
            // Move down stuff and try again
            // min-max amount to move down
            // new min will be at least the difference on to this min

            const diff:i32 = min-max;
            //first move is max goes to min
            for(0..@intCast(max+1))|_|{
                self.grid[p[0]][@intCast(min)] = self.grid[p[0]][@intCast(min-diff)];
                min -= 1;
            }
            for(0..@intCast(diff))|y|{
                self.grid[p[0]][y] = 0;
            }
            //glob.log_buff.writer().print("max >=0 : max = {} min = {} pos = {}\n", .{max, min, pos}) catch {};            
            _=self.make_a_fall(Pos{pos[0], max});

        }
        return true;
    }
    pub fn make_all_fall(self: *@This()) bool{
        var falled = false;
        for(0..gcnt)|x|{
            falled = self.make_a_fall(Pos{@intCast(x), gcnt-1}) or falled;
        }
        return falled;
    }
    fn is_all_same(self:*const @This(), poses:[]const UPos) bool{
        if(poses.len < 2) return false;
        var is_same = self.grid[poses[0][0]][poses[0][1]] != 0;
        for(1..poses.len)|i|{
            is_same = is_same and
                (self.grid[poses[0][0]][poses[0][1]] ==
                     self.grid[poses[i][0]][poses[i][1]]);
        }
        return is_same;
    }
    
    // Function that checks if a horizontal 3s is formed, and clears it
    // Then checks if vertical 3s is formed (for now)
    pub fn clear_3s(self: *@This()) u32{

        // Use mark and sweep style algorithm
        var marks:[gcnt][gcnt]bool = undefined;
        for(0..gcnt)|x|{
            for(0..gcnt)|y|{
                marks[x][y] = false;
            }
        }
        glob.log_buff.writer().print("{any}\n", .{self.grid}) catch {};
        // Mark cells to clear, any direction >= 3 will be cleared
        
        // Go for each height, check each row

        for(0..gcnt)|y|{
            for(0..gcnt-2)|x|{

                if((self.grid[x][y] != 0) and
                       (self.grid[x][y] == self.grid[x+1][y]) and
                       (self.grid[x][y] == self.grid[x+2][y])){
                    // if(self.is_all_same(&[_]UPos{
                        // .{x,y}, .{x+1,y}, .{x+2,y}
                    // })){
                    marks[x+0][y] = true;
                    marks[x+1][y] = true;
                    marks[x+2][y] = true;
                }
            }
        }
        // Go for each width, check each row
        for(0..gcnt)|x|{
            for(0..gcnt-2)|y|{
                if((self.grid[x][y] != 0) and
                       (self.grid[x][y] == self.grid[x][y+1]) and
                       (self.grid[x][y] == self.grid[x][y+2])){
                    // if(self.is_all_same(&[_]UPos{
                        // .{x,y}, .{x,y+1}, .{x,y+2}
                    // })){
                    marks[x][y+0] = true;
                    marks[x][y+1] = true;
                    marks[x][y+2] = true;
                }
            }
        }

        

        // Sweep up the cleared ones
        var cnt:u32 = 0;
        for(0..gcnt)|x|{
            for(0..gcnt)|y|{
                if(marks[x][y]){
                    self.grid[x][y] = 0;
                    cnt += 1;
                }
            }
        }
        
        glob.log_buff.writer().print("Clearing {} 3s\n", .{cnt}) catch {};
        glob.log_buff.writer().print("{any}\n", .{self.grid}) catch {};
        return cnt;

    }
    
    //Function to help swap using pos
    pub fn swap(self:*@This(), pinx1:Pos, pinx2:Pos) void{
        const inx1 = pos_to_upos(pinx1);
        const inx2 = pos_to_upos(pinx2);
        const tmp: usize = self.grid[inx1[0]][inx1[1]];
        self.grid[inx1[0]][inx1[1]] = self.grid[inx2[0]][inx2[1]];
        self.grid[inx2[0]][inx2[1]] = tmp;
    }
    
    // Function to convert from grid space to screen space
    pub fn convf(self: *@This(), l: f32) f32{
        const dm:f32 = @floatFromInt(@min(self.inst.w, self.inst.h));
        // The magic constant is min grid length visible
        return dm * l / 100.0; 
    }
    pub fn convi(self: *@This(), l: i32) i32{
        return @intFromFloat(self.convf(@floatFromInt(l)));
    }
    pub fn convv(self: *@This(), v: Vec2) Vec2{
        return Vec2{
            self.convf(v[0]),
            self.convf(v[1]),
        };
    }
    pub fn revef(self: *@This(), l: f32) f32{
        return l/self.convf(1.0);
    }
    pub fn revei(self: *@This(), l: i32) i32{
        return @intFromFloat(self.revef(@floatFromInt(l)));
    }
    pub fn revev(self: *@This(), v: Vec2) Vec2{
        return Vec2{
            self.revef(v[0]),
            self.revef(v[1]),
        };
    }
    pub fn loop(self: *@This()) void{
        
        var highlight_cell:?Pos = null;
        //Detect events
        {

            // Select if cell is highlighted
            const mpos_inx = self.revev(pos_to_vec2(self.event.hover_pos)) /
                @as(Vec2, @splat(box_size));
            if (@reduce(.And, mpos_inx >= Vec2{0.0,0.0}) and
                    @reduce(.And, mpos_inx < @as(Vec2, @splat(@floatFromInt(gcnt)))))
                highlight_cell = vec2_to_pos(mpos_inx);

            if(highlight_cell)|hc|{
                //For now do the opposite swap
                if(self.event.right and (hc[0] > 0)){
                    //Go left
                    self.swap(hc, Pos{hc[0]-1, hc[1]});
                }
                else if(self.event.left and (hc[0] < (gcnt-1))){
                    //Go right
                    self.swap(hc, Pos{hc[0]+1, hc[1]});
                }
                else if(self.event.up and (hc[1] < (gcnt-1))){
                    //Go down
                    self.swap(hc, Pos{hc[0], hc[1]+1});
                }
                else if(self.event.down and (hc[1] > 0)){
                    //Go up
                    self.swap(hc, Pos{hc[0], hc[1]-1});
                }
                if(self.event.space){
                    self.grid[@intCast(hc[0])][@intCast(hc[1])] = 0;
                }
            }
        }


        // Update logic
        {
            if(self.event.cbutton){
                //while(self.clear_3s() > 0){
                _=self.clear_3s();
            //}
            }
            if(self.event.pbutton){
                //while(self.clear_3s() > 0){
                    _=self.make_all_fall();
            //}
            }
            //while(self.make_all_fall()){ 
            while(true){
                const c = self.clear_3s();
                self.score += @intCast(c);
                if(c > 3) self.score += 2;
                if(c > 4) self.score += 2;
                if(!self.make_all_fall() and (c == 0)) break;
            }
        }

        self.event.reset_events();
        clear_rect(0, 0, self.inst.w, self.inst.h);
        //Drawing portion
        {

            
            
            for(0..gcnt)|x|{
                for(0..gcnt)|y|{
                    const pad_per = 0.1;
                    const pad = pad_per * box_size;
                    const rad = 0.5*box_size - pad;

                    const basepos = @as(Vec2, @splat(box_size)) * pos_to_vec2(UPos{x,y});
                    //Check if hovering on the box for now
                    const gbase = self.convv(basepos);
                    if(highlight_cell)|c|{
                        if(@reduce(.And, c == Pos{@intCast(x), @intCast(y)})){
                            JS.set_fill_style(ZigStr.init("#5555aa"));
                            JS.fill_rect(@intFromFloat(gbase[0]),
                                         @intFromFloat(gbase[1]),
                                         @intFromFloat(self.convf(box_size)),
                                         @intFromFloat(self.convf(box_size)));
                        }
                    }
                    if (@reduce(.And, pos_to_vec2(self.event.hover_pos) >= gbase) and
                            @reduce(.And, pos_to_vec2(self.event.hover_pos) <= (gbase+@as(Vec2, @splat(self.convf(box_size)))))){

                    }
                    const gpos = basepos + @as(Vec2, @splat(pad+rad));
                    const bpos = vec2_to_pos(self.convv(gpos));
                    JS.set_fill_style(ZigStr.init(types[self.grid[x][y]]));

                    JS.fill_circle(bpos[0], bpos[1], @intFromFloat(self.convf(rad)));
                }
            }
        }
        
        set_font(ZigStr.init("bold 30px serif"));
        // stroke_text(ZigStr.init("Welcome"), @divFloor(self.inst.w, 2) - 60, @divFloor(self.inst.h, 2));
        // stroke_text(ZigStr.init("To"), @divFloor(self.inst.w, 2)-20, @divFloor(self.inst.h, 2) + 40);
        stroke_text(ZigStr.init("Match N Crush"), @divFloor(self.inst.w, 2)-125, @divFloor(self.inst.h, 2) + 200);
        if(self.inst.tmp_print("Score = {}", .{self.score}))|str|{
        stroke_text(ZigStr.init(str), 125, @divFloor(self.inst.h, 2) + 300);            
        }


        glob.flush_log();
    }


};


    
const CrushEvents = struct{
    down: bool = false,
    right: bool = false,
    up: bool = false,
    left: bool = false,

    space: bool = false,
    pbutton: bool = false,
    cbutton: bool = false,

    touch_pos:Pos=.{0,0},
    last_touch: ?u32 = null,

    //Latest hover id
    hover_id: ?u32 = null,
    hover_pos: Pos = .{0,0},


    pub fn reset_events(self: *@This()) void{
        self.down = false; self.right = false;
        self.left = false; self.up = false;
        self.space = false; self.pbutton = false; self.cbutton = false;
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
        if(std.mem.eql(u8, key_name, "Space")){
            self.space = true;
        }
        if(std.mem.eql(u8, key_name, "KeyP")){
            self.pbutton = true;
        }
        if(std.mem.eql(u8, key_name, "KeyC")){
            self.cbutton = true;
        }
        glob.flush_log();
    }

    pub fn touch_event(self: *@This(), evt_name: [] const u8,
                       id: u32, px: i32, py: i32) bool{
        //if(std.mem.eql(u8, evt_name, "enter")){
        if(std.mem.eql(u8, evt_name, "enter")){
            //if(null == self.last_touch){
                self.last_touch = id;
                self.touch_pos = Pos{px,py};
            //}
            //glob.log_buff.writer().print("Enter event at {} {}\n", .{px, py}) catch {};
        }
        if(!std.mem.eql(u8, evt_name, "leave")){
            //if(null == self.last_touch){
            self.hover_id = id;
            self.hover_pos = Pos{px,py};
            //}
            //glob.log_buff.writer().print("Enter event at {} {}\n", .{px, py}) catch {};
        }
        if(std.mem.eql(u8, evt_name, "leave")){
            //glob.log_buff.writer().print("Leave event del {} {} \n", .{
                //px - self.touch_pos[0], py - self.touch_pos[1]}) catch {};
            if((null != self.last_touch) and (id == self.last_touch.?)){
                const dp = Pos{@intCast(@abs(px - self.touch_pos[0])),
                               @intCast(@abs(py - self.touch_pos[1]))};
                const touchr = 50;
                if((dp[0] >= dp[1]) and (dp[0] > touchr)){
                    self.key_event(if(px > self.touch_pos[0]) "ArrowRight" else "ArrowLeft");
                }
                if((dp[1] >= dp[0]) and (dp[1] > touchr)){
                    self.key_event(if(py > self.touch_pos[1]) "ArrowDown" else "ArrowUp");
                }
                self.last_touch = null;
            }
            if((null != self.hover_id) and (id == self.hover_id.?)){
                self.hover_id = null;
            }
        }
        glob.flush_log();
        return false;
    }
};
