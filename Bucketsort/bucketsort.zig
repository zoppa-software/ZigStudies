const std = @import("std");

pub fn BucketSort(
    comptime T: type,
    comptime getIndexMax: fn () u32,
    comptime convertIndex: fn (T) u32,
) type {
    return struct {
        const Self = @This();

        pub fn sort(
            allocator: std.mem.Allocator,
            list: []const T,
        ) ![]T {
            const indexMax = getIndexMax();
            const result = try allocator.alloc(T, list.len);

            const counter = try allocator.alloc(u32, indexMax + 1);
            defer allocator.free(counter);
            for (counter) |*item| {
                item.* = 0;
            }

            for (list) |item| {
                counter[convertIndex(item)] += 1;
            }

            const stepCounter = try allocator.alloc(u32, indexMax + 1);
            defer allocator.free(stepCounter);
            for (stepCounter) |*item| {
                item.* = 0;
            }

            var i: u32 = 1;
            while (i <= indexMax) : (i += 1) {
                counter[i] += counter[i - 1];
                stepCounter[i] = counter[i];
            }

            for (list) |item| {
                const index = convertIndex(item) - 1;
                result[stepCounter[index]] = item;
                stepCounter[index] += 1;
            }

            return result;
        }
    };
}
