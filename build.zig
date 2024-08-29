const std = @import("std");


fn setup_wasm_build(b: *std.Build, exe: *std.Build.Step.Compile) void{
    _=b;
    // <https://github.com/ziglang/zig/issues/8633>
    //exe.global_base = 6560;
    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.import_memory = true;
    //exe.stack_size = std.wasm.page_size;

    exe.initial_memory = std.wasm.page_size * 20;
    //exe.max_memory = std.wasm.page_size * max_number_of_pages;

}

pub fn build(b: *std.Build) void {

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    
    const snake = b.addExecutable(.{
        .name = "snake",
        .root_source_file = b.path("snake.zig"),
        //.root_source_file = .{. path ="base.zig"},
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    setup_wasm_build(b, snake);


    const brick = b.addExecutable(.{
        .name = "brick",
        .root_source_file = b.path("brick.zig"),
        //.root_source_file = .{. path="brick.zig"},
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    setup_wasm_build(b, brick);
    
    const jumper = b.addExecutable(.{
        .name = "jumper",
        .root_source_file = b.path("jumper.zig"),
        //.root_source_file = .{. path="jumper.zig"},
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    setup_wasm_build(b, jumper);

    const vsrust = b.addExecutable(.{
        .name = "vsrust",
        .root_source_file = b.path("vsrust.zig"),
        .target=wasm_target,
        .optimize = .ReleaseSmall,
    });
    setup_wasm_build(b, vsrust);

    b.installArtifact(vsrust);
    b.installArtifact(snake);
    b.installArtifact(brick);
    b.installArtifact(jumper);
}
