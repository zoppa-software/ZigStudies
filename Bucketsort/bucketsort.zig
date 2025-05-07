const std = @import("std");

/// Bucket Sort
/// これは比較に基づかないソートアルゴリズムです。
/// リストの要素を複数のバケットに分配することで動作します。
pub fn BucketSort(
    /// ソート対象のリストの型
    comptime T: type,
    /// ソート対象のバケットのインデックス最大値を取得する関数
    comptime getIndexMax: fn () u32,
    /// ソート対象要素のバケットインデックスを取得する関数
    comptime convertIndex: fn (T) u32,
) type {
    return struct {
        /// ソート結果
        result: ?[]T = null,

        /// インスタンスの参照
        const Self = @This();

        /// インスタンスを初期化します
        pub fn init() Self {
            return Self{ .result = null };
        }

        /// ソートを実行します
        pub fn sort(
            self: *Self,
            allocator: std.mem.Allocator,
            list: []const T,
        ) ![]T {
            // 引数の検証
            if (list.len == 0) {
                return try allocator.alloc(T, 0);
            }

            // 戻り値のリストを作成します
            var tmp = try allocator.alloc(T, list.len);
            const indexMax = getIndexMax();

            // バケットのインデックスごとのカウンタを作成します
            const counter = try allocator.alloc(u32, indexMax + 1);
            defer allocator.free(counter);
            for (counter) |*item| {
                item.* = 0;
            }

            // バケットのインデックスごとをカウントします
            for (list) |item| {
                counter[convertIndex(item)] += 1;
            }

            // バケットのインデックスごとのカウンタを累積します
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

            // 累積したカウンタを使って、ソートされたリストを作成します
            for (list) |item| {
                const index = convertIndex(item) - 1;
                tmp[stepCounter[index]] = item;
                stepCounter[index] += 1;
            }
            self.result = tmp;
            return tmp;
        }

        /// ソート結果を解放します
        /// これは、sort()メソッドを呼び出した後に呼び出す必要があります。
        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            if (self.result) |result| {
                allocator.free(result);
            }
        }
    };
}
