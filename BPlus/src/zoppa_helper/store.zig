const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// 指定した型のオブジェクトを保持する。
pub fn Store(comptime T: type, comptime size: comptime_int) type {
    return struct {
        /// 自身の型
        const Self = @This();

        // 削除済みリスト
        deleted: []*T,

        // 削除済み数
        deleted_count: usize,

        // データの格納先
        instances: [][*]T,

        // アロケータ
        allocator: Allocator,

        /// ストアを初期化します。
        pub fn init(alloc: Allocator) !Self {
            var res = Self{
                .deleted_count = 0,
                .deleted = try alloc.alloc(*T, size),
                .instances = try alloc.alloc([*]T, 0),
                .allocator = alloc,
            };

            // エラーが発生した場合は、初期化を行わない
            res.createCache() catch |err| {
                return err;
            };

            return res;
        }

        /// ストアを破棄します。
        pub fn deinit(self: *Self) void {
            self.deleted_count = 0;
            self.allocator.free(self.deleted);
            for (self.instances) |item| {
                self.allocator.free(item[0..size]);
            }
            self.allocator.free(self.instances);
        }

        /// ストアをクリアします。
        pub fn clear(self: *Self) !void {
            self.deinit();
            self.deleted = try self.alloc.alloc(*T, size);
            self.instances = try self.alloc.alloc([*]T, 0);
            self.createCache() catch |err| {
                return err;
            };
        }

        /// キャッシュを作成します。
        fn createCache(self: *Self) !void {
            // 実体を保持する領域を確保する
            var new_instances = try self.allocator.alloc([*]T, self.instances.len + 1);
            @memcpy(new_instances[0..self.instances.len], self.instances);

            const tmp = try self.allocator.alloc(T, size);
            new_instances[new_instances.len - 1] = tmp.ptr;
            self.allocator.free(self.instances);
            self.instances = new_instances;

            // サイズを変更する
            self.deleted_count = size;
            for (tmp, 0..) |*item, i| {
                self.deleted[i] = item;
            }
        }

        /// ストアからオブジェクトを取得します。
        pub fn get(self: *Self) !*T {
            // 削除済みリストが空の場合は、キャッシュを作成する
            if (self.deleted_count <= 0) {
                self.createCache() catch |err| {
                    return err;
                };
            }

            // 削除済みリストから取得する
            const item = self.deleted[self.deleted_count - 1];
            self.deleted_count -= 1;
            return item;
        }

        /// ストアにオブジェクトを返却します。
        pub fn put(self: *Self, item: *T) !void {
            if (self.deleted_count >= self.deleted.len) {
                // 削除済みリストが満杯の場合は、リストを拡張する
                const want = (self.instances.len * size - self.deleted.len) / 2;
                const new_deleted = try self.allocator.alloc(*T, self.deleted.len + if (want > size) want else size);
                @memcpy(new_deleted[0..self.deleted.len], self.deleted);
                self.allocator.free(self.deleted);
                self.deleted = new_deleted;
            }
            self.deleted[self.deleted_count] = item;
            self.deleted_count += 1;
        }
    };
}

// ストアを初期化をテストします。
test "Store init" {
    const allocator = std.testing.allocator;
    var store = try Store(i32, 10).init(allocator);
    defer store.deinit();

    // ストアの初期化が成功したことを確認する
    try testing.expect(store.deleted_count == 10);
}

// ストアからオブジェクトを取得するテスト
test "Store get" {
    const allocator = std.testing.allocator;
    var store = try Store(i32, 2).init(allocator);
    defer store.deinit();

    // ストアからオブジェクトを取得する
    // ストアからオブジェクトを取得した後の状態を確認する
    _ = try store.get();
    try testing.expect(store.deleted_count == 1);

    _ = try store.get();
    try testing.expect(store.deleted_count == 0);

    _ = try store.get();
    try testing.expect(store.deleted_count == 1);
}

// ストアにオブジェクトを返却するテスト
test "Store put" {
    const allocator = std.testing.allocator;
    var store = try Store(i32, 2).init(allocator);
    defer store.deinit();

    // ストアにオブジェクトを返却する
    const item1 = try store.get();
    const item2 = try store.get();
    const item3 = try store.get();
    const item4 = try store.get();
    const item5 = try store.get();
    const item6 = try store.get();
    const item7 = try store.get();
    const item8 = try store.get();
    const item9 = try store.get();
    _ = try store.get();

    try store.put(item1);
    try store.put(item2);
    try store.put(item3);
    try store.put(item4);
    try store.put(item5);
    try store.put(item6);
    try store.put(item7);
    try store.put(item8);
    try store.put(item9);

    // ストアにオブジェクトを返却した後の状態を確認する
    try testing.expect(store.deleted_count == 9);
}
