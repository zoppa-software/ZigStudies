const std = @import("std");
const lib = @import("BPlus_lib");
const zoppa = @import("zoppa_helper/bplus_tree.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var bplus_tree = try zoppa.BPlusTree(i32, compare_fn).init(allocator);
    defer bplus_tree.deinit();

    const datas: [20]i32 = [_]i32{ 16, 15, 13, 6, 5, 10, 19, 11, 7, 9, 8, 14, 18, 17, 20, 4, 12, 1, 2, 3 };
    for (datas) |data| {
        try bplus_tree.add(data);
    }

    std.debug.print("count: {d}\n", .{bplus_tree.count});
    var iter = bplus_tree.iterate();
    for (1..21) |i| {
        std.debug.print("{d}: {d}\n", .{ i, iter.next().? });
    }
}

/// テスト用の比較関数
fn compare_fn(comptime _: type, lhs: i32, rhs: i32) i32 {
    if (lhs < rhs) {
        return -1;
    } else if (lhs > rhs) {
        return 1;
    } else {
        return 0;
    }
}

test {
    _ = @import("zoppa_helper/store.zig");
    _ = @import("zoppa_helper/binary_search.zig");
    _ = @import("zoppa_helper/bplus_tree.zig");
}
