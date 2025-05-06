const std = @import("std");
const expect = std.testing.expect;
const allocator = std.heap.page_allocator;
const bsort = @import("bucketsort.zig");

pub fn main() !void {
    // 要素をソートする配列
    const list = [_]u8{ 8, 17, 11, 1, 15, 15, 18, 9, 3, 16, 18, 19, 7, 15, 3, 1 };
    std.debug.print("開始 = {any}\n", .{list});

    // バケットソートを実行
    const answer = try bsort.BucketSort(u8, indexMax, indexConverter).sort(allocator, &list);
    defer allocator.free(answer);

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
    const answer = try bsort.BucketSort(u8, indexMax, indexConverter).sort(allocator, &list);
    defer allocator.free(answer);
    try expect(@TypeOf(answer) == []u8);
    try expect(answer.len == 0);
}

test "5要素のリスト" {
    const list = [_]u8{ 3, 5, 1, 2, 4 };
    const answer = try bsort.BucketSort(u8, indexMax, indexConverter).sort(allocator, &list);
    defer allocator.free(answer);
    try expect(@TypeOf(answer) == []u8);
    try expect(answer.len == 5);
    try expect(answer[0] == 1);
    try expect(answer[1] == 2);
    try expect(answer[2] == 3);
    try expect(answer[3] == 4);
    try expect(answer[4] == 5);
}
