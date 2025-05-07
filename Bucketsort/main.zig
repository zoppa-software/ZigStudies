const std = @import("std");
const expect = std.testing.expect;
const allocator = std.heap.page_allocator;
const bsort = @import("bucketsort.zig");

pub fn main() !void {
    // 要素をソートする配列
    const list = [_]u8{ 8, 17, 11, 1, 15, 15, 18, 9, 3, 16, 18, 19, 7, 15, 3, 1 };
    std.debug.print("開始 = {any}\n", .{list});

    // バケットソートを実行
    var sorter = bsort.BucketSort(u8, indexMax, indexConverter).init();
    const answer = try sorter.sort(allocator, &list);
    defer sorter.deinit(allocator);

    // ソート後の配列を表示
    std.debug.print("終了 = {any}\n", .{answer});
}

fn indexMax() u32 {
    return 19;
}

fn indexConverter(item: u8) u32 {
    return item;
}

test "0要素のリスト" {
    const list = [_]u8{};

    var sorter = bsort.BucketSort(u8, indexMax, indexConverter).init();
    const answer = try sorter.sort(allocator, &list);
    defer sorter.deinit(allocator);

    try expect(@TypeOf(answer) == []u8);
    try expect(answer.len == 0);
}

test "5要素のリスト" {
    const list = [_]u8{ 3, 5, 1, 2, 4 };

    var sorter = bsort.BucketSort(u8, indexMax, indexConverter).init();
    const answer = try sorter.sort(allocator, &list);
    defer sorter.deinit(allocator);

    try expect(@TypeOf(answer) == []u8);
    try expect(std.mem.eql(u8, answer, &[_]u8{ 1, 2, 3, 4, 5 }));
}
