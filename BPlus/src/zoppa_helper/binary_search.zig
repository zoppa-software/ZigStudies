const std = @import("std");
const testing = std.testing;

/// 以上の要素のバイナリサーチを行う
pub fn binary_search_ge(comptime T: type, arr: []const T, target: T, compare: fn (lhs: T, rhs: T) i32) isize {
    if (arr.len == 0) return 1;
    var left: isize = 0;
    var right: isize = @intCast(arr.len);

    while (left < right) {
        const mid = left + @divFloor(right - left, 2);

        // 比較関数を使用して、ターゲットと中間値を比較
        const cmp = compare(arr[@intCast(mid)], target);
        if (cmp >= 0) {
            right = mid;
        } else {
            left = mid + 1;
        }
    }
    return left;
}

/// より以下の要素のバイナリサーチを行う
pub fn binary_search_lt(comptime T: type, arr: []const T, target: T, compare: fn (lhs: T, rhs: T) i32) isize {
    const res = binary_search_ge(T, arr, target, compare);
    return res - 1;
}

/// 以下の要素のバイナリサーチを行う
pub fn binary_search_le(comptime T: type, arr: []const T, target: T, compare: fn (lhs: T, rhs: T) i32) isize {
    if (arr.len == 0) return -1;
    var left: isize = -1;
    var right: isize = @intCast(arr.len - 1);

    while (left < right) {
        const mid = left + @divFloor(right - left + 1, 2);

        // 比較関数を使用して、ターゲットと中間値を比較
        const cmp = compare(arr[@intCast(mid)], target);
        if (cmp <= 0) {
            left = mid;
        } else {
            right = mid - 1;
        }
    }
    return right;
}

/// より上の要素のバイナリサーチを行う
pub fn binary_search_gt(comptime T: type, arr: []const T, target: T, compare: fn (lhs: T, rhs: T) i32) isize {
    const res = binary_search_le(T, arr, target, compare);
    return res + 1;
}

/// テスト用の比較関数
fn compare_fn(lhs: u32, rhs: u32) i32 {
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
    const index1 = binary_search_ge(u32, arr[0..], 1, compare_fn);
    try std.testing.expectEqual(index1, 0);
    const index2 = binary_search_ge(u32, arr[0..], 2, compare_fn);
    try std.testing.expectEqual(index2, 3);
    const index3 = binary_search_ge(u32, arr[0..], 3, compare_fn);
    try std.testing.expectEqual(index3, 4);
    const index4 = binary_search_ge(u32, arr[0..], 4, compare_fn);
    try std.testing.expectEqual(index4, 6);
    const index5 = binary_search_ge(u32, arr[0..], 5, compare_fn);
    try std.testing.expectEqual(index5, 9);
    const index6 = binary_search_ge(u32, arr[0..], 6, compare_fn);
    try std.testing.expectEqual(index6, 12);
    const index7 = binary_search_ge(u32, arr[0..], 7, compare_fn);
    try std.testing.expectEqual(index7, 16);

    const arr2 = [_]u32{ 3, 3, 4, 6, 8 };
    const index20 = binary_search_ge(u32, arr2[0..], 0, compare_fn);
    try std.testing.expectEqual(index20, 0);
    const index21 = binary_search_ge(u32, arr2[0..], 1, compare_fn);
    try std.testing.expectEqual(index21, 0);
    const index22 = binary_search_ge(u32, arr2[0..], 2, compare_fn);
    try std.testing.expectEqual(index22, 0);
    const index23 = binary_search_ge(u32, arr2[0..], 3, compare_fn);
    try std.testing.expectEqual(index23, 0);
    const index24 = binary_search_ge(u32, arr2[0..], 4, compare_fn);
    try std.testing.expectEqual(index24, 2);
    const index25 = binary_search_ge(u32, arr2[0..], 5, compare_fn);
    try std.testing.expectEqual(index25, 3);
    const index26 = binary_search_ge(u32, arr2[0..], 6, compare_fn);
    try std.testing.expectEqual(index26, 3);
    const index27 = binary_search_ge(u32, arr2[0..], 7, compare_fn);
    try std.testing.expectEqual(index27, 4);
    const index28 = binary_search_ge(u32, arr2[0..], 8, compare_fn);
    try std.testing.expectEqual(index28, 4);
    const index29 = binary_search_ge(u32, arr2[0..], 9, compare_fn);
    try std.testing.expectEqual(index29, 5);
    const index30 = binary_search_ge(u32, arr2[0..], 10, compare_fn);
    try std.testing.expectEqual(index30, 5);
}

// binary_search_ltのテスト
test "binary_search_lt test" {
    const arr2 = [_]u32{ 3, 3, 4, 6, 8 };
    const index20 = binary_search_lt(u32, arr2[0..], 0, compare_fn);
    try std.testing.expectEqual(index20, -1);
    const index21 = binary_search_lt(u32, arr2[0..], 1, compare_fn);
    try std.testing.expectEqual(index21, -1);
    const index22 = binary_search_lt(u32, arr2[0..], 2, compare_fn);
    try std.testing.expectEqual(index22, -1);
    const index23 = binary_search_lt(u32, arr2[0..], 3, compare_fn);
    try std.testing.expectEqual(index23, -1);
    const index24 = binary_search_lt(u32, arr2[0..], 4, compare_fn);
    try std.testing.expectEqual(index24, 1);
    const index25 = binary_search_lt(u32, arr2[0..], 5, compare_fn);
    try std.testing.expectEqual(index25, 2);
    const index26 = binary_search_lt(u32, arr2[0..], 6, compare_fn);
    try std.testing.expectEqual(index26, 2);
    const index27 = binary_search_lt(u32, arr2[0..], 7, compare_fn);
    try std.testing.expectEqual(index27, 3);
    const index28 = binary_search_lt(u32, arr2[0..], 8, compare_fn);
    try std.testing.expectEqual(index28, 3);
    const index29 = binary_search_lt(u32, arr2[0..], 9, compare_fn);
    try std.testing.expectEqual(index29, 4);
    const index30 = binary_search_lt(u32, arr2[0..], 10, compare_fn);
    try std.testing.expectEqual(index30, 4);
}

// binary_search_leのテスト
test "binary_search_le test" {
    const arr = [_]u32{ 1, 1, 1, 2, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7 };
    const index1 = binary_search_le(u32, arr[0..], 1, compare_fn);
    try std.testing.expectEqual(index1, 2);
    const index2 = binary_search_le(u32, arr[0..], 2, compare_fn);
    try std.testing.expectEqual(index2, 3);
    const index3 = binary_search_le(u32, arr[0..], 3, compare_fn);
    try std.testing.expectEqual(index3, 5);
    const index4 = binary_search_le(u32, arr[0..], 4, compare_fn);
    try std.testing.expectEqual(index4, 8);
    const index5 = binary_search_le(u32, arr[0..], 5, compare_fn);
    try std.testing.expectEqual(index5, 11);
    const index6 = binary_search_le(u32, arr[0..], 6, compare_fn);
    try std.testing.expectEqual(index6, 15);
    const index7 = binary_search_le(u32, arr[0..], 7, compare_fn);
    try std.testing.expectEqual(index7, 19);

    const arr2 = [_]u32{ 3, 3, 4, 6, 8 };
    const index20 = binary_search_le(u32, arr2[0..], 0, compare_fn);
    try std.testing.expectEqual(index20, -1);
    const index21 = binary_search_le(u32, arr2[0..], 1, compare_fn);
    try std.testing.expectEqual(index21, -1);
    const index22 = binary_search_le(u32, arr2[0..], 2, compare_fn);
    try std.testing.expectEqual(index22, -1);
    const index23 = binary_search_le(u32, arr2[0..], 3, compare_fn);
    try std.testing.expectEqual(index23, 1);
    const index24 = binary_search_le(u32, arr2[0..], 4, compare_fn);
    try std.testing.expectEqual(index24, 2);
    const index25 = binary_search_le(u32, arr2[0..], 5, compare_fn);
    try std.testing.expectEqual(index25, 2);
    const index26 = binary_search_le(u32, arr2[0..], 6, compare_fn);
    try std.testing.expectEqual(index26, 3);
    const index27 = binary_search_le(u32, arr2[0..], 7, compare_fn);
    try std.testing.expectEqual(index27, 3);
    const index28 = binary_search_le(u32, arr2[0..], 8, compare_fn);
    try std.testing.expectEqual(index28, 4);
    const index29 = binary_search_le(u32, arr2[0..], 9, compare_fn);
    try std.testing.expectEqual(index29, 4);
    const index30 = binary_search_le(u32, arr2[0..], 10, compare_fn);
    try std.testing.expectEqual(index30, 4);
}

// binary_search_gtのテスト
test "binary_search_gt test" {
    const arr2 = [_]u32{ 3, 3, 4, 6, 8 };
    const index20 = binary_search_gt(u32, arr2[0..], 0, compare_fn);
    try std.testing.expectEqual(index20, 0);
    const index21 = binary_search_gt(u32, arr2[0..], 1, compare_fn);
    try std.testing.expectEqual(index21, 0);
    const index22 = binary_search_gt(u32, arr2[0..], 2, compare_fn);
    try std.testing.expectEqual(index22, 0);
    const index23 = binary_search_gt(u32, arr2[0..], 3, compare_fn);
    try std.testing.expectEqual(index23, 2);
    const index24 = binary_search_gt(u32, arr2[0..], 4, compare_fn);
    try std.testing.expectEqual(index24, 3);
    const index25 = binary_search_gt(u32, arr2[0..], 5, compare_fn);
    try std.testing.expectEqual(index25, 3);
    const index26 = binary_search_gt(u32, arr2[0..], 6, compare_fn);
    try std.testing.expectEqual(index26, 4);
    const index27 = binary_search_gt(u32, arr2[0..], 7, compare_fn);
    try std.testing.expectEqual(index27, 4);
    const index28 = binary_search_gt(u32, arr2[0..], 8, compare_fn);
    try std.testing.expectEqual(index28, 5);
    const index29 = binary_search_gt(u32, arr2[0..], 9, compare_fn);
    try std.testing.expectEqual(index29, 5);
    const index30 = binary_search_gt(u32, arr2[0..], 10, compare_fn);
    try std.testing.expectEqual(index30, 5);
}
