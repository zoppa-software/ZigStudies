const std = @import("std");
const testing = std.testing;

/// 以上の要素のバイナリサーチを行う
pub fn binary_search_ge(comptime T: type, arr: []const T, target: T, compare: fn (@TypeOf(T), lhs: T, rhs: T) i32) !i64 {
    var left: i64 = 0;
    var right: i64 = @intCast(arr.len - 1);

    while (left < right) {
        const mid = left + @divFloor(right - left, 2);

        // 比較関数を使用して、ターゲットと中間値を比較
        const cmp = compare(@TypeOf(T), arr[@intCast(mid)], target);
        if (cmp == 0) {
            right = mid;
        } else if (cmp < 0) {
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }

    if (compare(@TypeOf(T), arr[@intCast(left)], target) > 0) {
        return left - 1;
    }
    return left;
}

/// 以下の要素のバイナリサーチを行う
pub fn binary_search_le(comptime T: type, arr: []const T, target: T, compare: fn (@TypeOf(T), lhs: T, rhs: T) i32) !i64 {
    var left: i64 = 0;
    var right: i64 = @intCast(arr.len - 1);

    while (left < right) {
        const mid = left + @divFloor(right - left + 1, 2);

        // 比較関数を使用して、ターゲットと中間値を比較
        const cmp = compare(@TypeOf(T), arr[@intCast(mid)], target);
        if (cmp == 0) {
            left = mid;
        } else if (cmp < 0) {
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }

    if (compare(@TypeOf(T), arr[@intCast(right)], target) < 0) {
        return right + 1;
    }
    return right;
}

/// テスト用の比較関数
fn compare_fn(comptime T: type, lhs: T, rhs: T) i32 {
    if (lhs < rhs) {
        return -1;
    } else if (lhs > rhs) {
        return 1;
    } else {
        return 0;
    }
}

// binary_search_geのテスト
test "binary_search_ge test" {
    const arr = [_]u32{ 1, 1, 1, 2, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7 };
    const index1 = try binary_search_ge(u32, arr[0..], 1, compare_fn);
    try std.testing.expectEqual(index1, 0);
    const index2 = try binary_search_ge(u32, arr[0..], 2, compare_fn);
    try std.testing.expectEqual(index2, 3);
    const index3 = try binary_search_ge(u32, arr[0..], 3, compare_fn);
    try std.testing.expectEqual(index3, 4);
    const index4 = try binary_search_ge(u32, arr[0..], 4, compare_fn);
    try std.testing.expectEqual(index4, 6);
    const index5 = try binary_search_ge(u32, arr[0..], 5, compare_fn);
    try std.testing.expectEqual(index5, 9);
    const index6 = try binary_search_ge(u32, arr[0..], 6, compare_fn);
    try std.testing.expectEqual(index6, 12);
    const index7 = try binary_search_ge(u32, arr[0..], 7, compare_fn);
    try std.testing.expectEqual(index7, 16);

    const arr2 = [_]u32{ 3, 3, 4, 6, 8 };
    const index20 = try binary_search_ge(u32, arr2[0..], 0, compare_fn);
    try std.testing.expectEqual(index20, -1);
    const index21 = try binary_search_ge(u32, arr2[0..], 1, compare_fn);
    try std.testing.expectEqual(index21, -1);
    const index22 = try binary_search_ge(u32, arr2[0..], 2, compare_fn);
    try std.testing.expectEqual(index22, -1);
    const index23 = try binary_search_ge(u32, arr2[0..], 3, compare_fn);
    try std.testing.expectEqual(index23, 0);
    const index24 = try binary_search_ge(u32, arr2[0..], 4, compare_fn);
    try std.testing.expectEqual(index24, 2);
    const index25 = try binary_search_ge(u32, arr2[0..], 5, compare_fn);
    try std.testing.expectEqual(index25, 2);
    const index26 = try binary_search_ge(u32, arr2[0..], 6, compare_fn);
    try std.testing.expectEqual(index26, 3);
    const index27 = try binary_search_ge(u32, arr2[0..], 7, compare_fn);
    try std.testing.expectEqual(index27, 3);
    const index28 = try binary_search_ge(u32, arr2[0..], 8, compare_fn);
    try std.testing.expectEqual(index28, 4);
    const index29 = try binary_search_ge(u32, arr2[0..], 9, compare_fn);
    try std.testing.expectEqual(index29, 4);
    const index30 = try binary_search_ge(u32, arr2[0..], 10, compare_fn);
    try std.testing.expectEqual(index30, 4);
}

// binary_search_leのテスト
test "binary_search_le test" {
    const arr = [_]u32{ 1, 1, 1, 2, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7 };
    const index1 = try binary_search_le(u32, arr[0..], 1, compare_fn);
    try std.testing.expectEqual(index1, 2);
    const index2 = try binary_search_le(u32, arr[0..], 2, compare_fn);
    try std.testing.expectEqual(index2, 3);
    const index3 = try binary_search_le(u32, arr[0..], 3, compare_fn);
    try std.testing.expectEqual(index3, 5);
    const index4 = try binary_search_le(u32, arr[0..], 4, compare_fn);
    try std.testing.expectEqual(index4, 8);
    const index5 = try binary_search_le(u32, arr[0..], 5, compare_fn);
    try std.testing.expectEqual(index5, 11);
    const index6 = try binary_search_le(u32, arr[0..], 6, compare_fn);
    try std.testing.expectEqual(index6, 15);
    const index7 = try binary_search_le(u32, arr[0..], 7, compare_fn);
    try std.testing.expectEqual(index7, 19);

    const arr2 = [_]u32{ 3, 3, 4, 6, 8 };
    const index20 = try binary_search_le(u32, arr2[0..], 0, compare_fn);
    try std.testing.expectEqual(index20, 0);
    const index21 = try binary_search_le(u32, arr2[0..], 1, compare_fn);
    try std.testing.expectEqual(index21, 0);
    const index22 = try binary_search_le(u32, arr2[0..], 2, compare_fn);
    try std.testing.expectEqual(index22, 0);
    const index23 = try binary_search_le(u32, arr2[0..], 3, compare_fn);
    try std.testing.expectEqual(index23, 1);
    const index24 = try binary_search_le(u32, arr2[0..], 4, compare_fn);
    try std.testing.expectEqual(index24, 2);
    const index25 = try binary_search_le(u32, arr2[0..], 5, compare_fn);
    try std.testing.expectEqual(index25, 3);
    const index26 = try binary_search_le(u32, arr2[0..], 6, compare_fn);
    try std.testing.expectEqual(index26, 3);
    const index27 = try binary_search_le(u32, arr2[0..], 7, compare_fn);
    try std.testing.expectEqual(index27, 4);
    const index28 = try binary_search_le(u32, arr2[0..], 8, compare_fn);
    try std.testing.expectEqual(index28, 4);
    const index29 = try binary_search_le(u32, arr2[0..], 9, compare_fn);
    try std.testing.expectEqual(index29, 5);
    const index30 = try binary_search_le(u32, arr2[0..], 10, compare_fn);
    try std.testing.expectEqual(index30, 5);
}
