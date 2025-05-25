const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const store = @import("store.zig");
const bsearch = @import("binary_search.zig");
const expect = std.testing.expect;

/// B+木コレクション
/// B+木のコレクションを実装します。
/// データベースやファイルシステムなどの大規模なデータセットを効率的に管理するために使用されるデータ構造です。
/// B木の変種であり、すべての値がリーフノードに格納されることを除いて、B木と同じ特性を持っています。
/// データの挿入、削除、検索を効率的に行うことができるため、大規模なデータセットを扱うアプリケーションに適しています。
pub fn BPlusTree(comptime T: type, compare: fn (lhs: T, rhs: T) i32) type {
    // ブロックサイズ
    const block_size: comptime_int = 8;

    // バケットサイズ
    const bucket_size: comptime_int = block_size * 2 + 1;

    return struct {
        /// コレクションの対象の型
        const Self = @This();

        // 葉の要素
        const BLeaf = struct {
            count: usize,
            prev: ?*BLeaf,
            next: ?*BLeaf,
            value: [bucket_size]T,

            /// 葉要素を初期化します。
            pub fn init(self: *@This()) void {
                self.count = 0;
                self.prev = null;
                self.next = null;
            }
        };

        // 枝の要素
        const BBranch = struct {
            count: usize,
            value: [bucket_size]BParts,
            head_leaf: *BLeaf,

            /// 枝要素を初期化します。
            pub fn init(self: *@This(), left_value: BParts, right_value: BParts) void {
                self.count = 2;
                self.value[0] = left_value;
                self.value[1] = right_value;
                self.traverseLeaf();
            }

            /// 先頭の葉要素を取得します。
            pub fn traverseLeaf(self: *@This()) void {
                var ptr: BParts = self.value[0];
                while (true) {
                    switch (ptr) {
                        .leaf => break,
                        .branch => |brh| {
                            ptr = brh.value[0];
                        },
                        .value => unreachable,
                    }
                }
                self.head_leaf = ptr.leaf;
            }
        };

        // 枝と葉の要素の共通部分
        const BParts = union(enum) {
            leaf: *BLeaf,
            branch: *BBranch,
            value: *const T,
        };

        // イテレータ
        const Iterator = struct {
            tree: *Self,
            leaf: ?*BLeaf,
            index: usize,

            /// 次の要素を取得します。
            pub fn next(self: *Iterator) ?T {
                while (self.leaf) |leaf| {
                    if (self.index < leaf.count) {
                        const value = leaf.value[self.index];
                        self.index += 1;
                        return value;
                    } else {
                        self.leaf = leaf.next;
                        self.index = 0;
                    }
                }
                return null;
            }
        };

        /// 要素の数
        count: usize,

        /// ルートノード
        root_branch: ?*BBranch = null,

        /// 開始葉要素
        start_leaf: *BLeaf,

        /// 葉要素が変更されたかどうかを示すフラグ
        leaf_changed: bool,

        /// 枝要素ストア
        leaf_store: store.Store(BLeaf, 32),

        /// 葉要素ストア
        branch_store: store.Store(BBranch, 16),

        // アロケータ
        allocator: Allocator,

        /// B+木コレクションを初期化します。
        pub fn init(alloc: Allocator) !Self {
            var leaf_store = try store.Store(BLeaf, 32).init(alloc);
            var res = Self{
                .count = 0,
                .root_branch = null,
                .start_leaf = try leaf_store.get(),
                .leaf_changed = false,
                .leaf_store = leaf_store,
                .branch_store = try store.Store(BBranch, 16).init(alloc),
                .allocator = alloc,
            };
            res.start_leaf.init();
            return res;
        }

        /// B+木コレクションを構築します。
        pub fn initAndRegister(alloc: Allocator, source_collection: *[]T) !Self {
            var leaf_store = try store.Store(BLeaf, 32).init(alloc);
            var res = Self{
                .count = 0,
                .root_branch = null,
                .start_leaf = try leaf_store.get(),
                .leaf_changed = false,
                .leaf_store = leaf_store,
                .branch_store = try store.Store(BBranch, 16).init(alloc),
                .allocator = alloc,
            };

            // 元のコレクションの要素をB+木に登録する
            res.start_leaf.init();
            for (source_collection.*) |value| {
                try res.add(value);
            }
            return res;
        }

        /// B+木コレクションを破棄します。
        pub fn deinit(self: *Self) void {
            // ストアを破棄する
            self.leaf_store.deinit();
            self.branch_store.deinit();
        }

        /// B+木コレクションをクリアします。
        pub fn clear(self: *Self) !void {
            // ストアをクリアする
            try self.leaf_store.clear();
            try self.branch_store.clear();

            // ルートノードと開始葉要素を初期化する
            self.count = 0;
            self.root_branch = null;
            self.start_leaf = try self.leaf_store.get();
            self.start_leaf.init();
        }

        /// 先頭要素で比較します。
        fn compare_parts(lhs: BParts, rhs: BParts) i32 {
            const left_value = switch (lhs) {
                .leaf => |lf| lf.value[0],
                .branch => |rt| rt.head_leaf.value[0],
                .value => |v| v.*,
            };
            const right_value = switch (rhs) {
                .leaf => |lf| lf.value[0],
                .branch => |rt| rt.head_leaf.value[0],
                .value => |v| v.*,
            };
            return compare(left_value, right_value);
        }

        /// B+木コレクションに要素を追加します。
        pub fn add(self: *Self, value: T) !void {
            self.leaf_changed = false;

            if (self.root_branch) |root_bh| {
                // ルートノードが空でない場合、ルートノードに追加する
                const next_branch = try self.add_branch(root_bh, value);
                if (next_branch) |next_bh| {
                    const new_branch = try self.branch_store.get();
                    new_branch.init(.{ .branch = root_bh }, next_bh);
                    self.root_branch = new_branch;
                }
            } else {
                // ルートノードが空の場合、葉のみを追加する
                const next_leaf = try self.add_leaf(self.start_leaf, value);
                if (next_leaf) |next_lf| {
                    const new_branch = try self.branch_store.get();
                    new_branch.init(.{ .leaf = self.start_leaf }, next_lf);
                    self.root_branch = new_branch;
                }
            }
        }

        /// 葉要素に値を追加します。
        fn add_leaf(self: *Self, leaf: *BLeaf, value: T) !?BParts {
            if (leaf.count == 0) {
                leaf.value[0] = value;
                leaf.count += 1;
                self.count += 1;
                self.leaf_changed = true;
                return null;
            } else {
                // バイナリサーチを使用して、値を挿入する位置を見つける
                const insert = bsearch.binary_search_gt(T, leaf.value[0..leaf.count], value, compare);
                const index: usize = if (insert < 0) 0 else @intCast(insert);

                if (leaf.count < bucket_size) {
                    // 挿入位置に値を挿入する
                    var i: usize = leaf.count;
                    while (i > index) : (i -= 1) {
                        leaf.value[i] = leaf.value[i - 1];
                    }
                    leaf.value[index] = value;

                    leaf.count += 1;
                    self.count += 1;
                    self.leaf_changed = true;
                    return null;
                } else {
                    //　葉要素が満杯の場合、分割する
                    const new_leaf = try self.split_leaf(leaf, value, index);
                    self.count += 1;
                    self.leaf_changed = true;
                    return .{ .leaf = new_leaf };
                }
            }
        }

        /// 枝要素に値を追加します。
        fn add_branch(self: *Self, branch: *BBranch, value: T) !?BParts {
            // バイナリサーチを使用して、値を挿入する位置を見つける
            const insert = bsearch.binary_search_le(BParts, branch.value[0..branch.count], .{ .value = &value }, compare_parts);
            const index: usize = if (insert < 0) 0 else @intCast(insert);

            // 挿入位置に値を挿入する
            const tmp_parts: ?BParts = switch (branch.value[index]) {
                // 葉要素に値を追加する
                .leaf => |lf| try self.add_leaf(lf, value),
                // 枝要素に値を追加する
                .branch => |bh| try self.add_branch(bh, value),
                // 値を追加しない
                .value => unreachable,
            };

            if (tmp_parts) |new_part| {
                // 新しい要素を追加する
                if (branch.count < bucket_size) {
                    // 挿入位置に値を挿入する
                    if (branch.count > index + 1) {
                        var i: usize = branch.count;
                        while (i > index + 1) : (i -= 1) {
                            branch.value[i] = branch.value[i - 1];
                        }
                    }

                    branch.value[index + 1] = new_part;
                    branch.count += 1;
                    return null;
                } else {
                    return .{ .branch = try split_branch(self, branch, new_part, index + 1) };
                }
            } else {
                // 新しい要素を追加しない
                return null;
            }
        }

        /// 葉要素を分割します。
        fn split_leaf(self: *Self, leaf: *BLeaf, value: T, index: usize) !*BLeaf {
            // 新しい枝要素を生成して直前の枝要素と合体して値を追加
            var new_leaf = try self.leaf_store.get();
            new_leaf.init();
            split_parts(BLeaf, T, new_leaf, leaf, index, value);

            // 前後のリンクを設定する
            new_leaf.next = leaf.next;
            new_leaf.prev = leaf;
            if (leaf.next != null) {
                leaf.next.?.prev = new_leaf;
            }
            leaf.next = new_leaf;

            // 新しく生成した葉要素を返す
            return new_leaf;
        }

        /// 枝要素を分割します。
        fn split_branch(self: *Self, branch: *BBranch, new_part: BParts, index: usize) !*BBranch {
            // 新しい枝要素を生成して直前の枝要素と合体して値を追加
            var new_branch = try self.branch_store.get();
            split_parts(BBranch, BParts, new_branch, branch, index, new_part);

            // 検索キー参照変更
            new_branch.traverseLeaf();

            // 新しく生成した枝要素を返す
            return new_branch;
        }

        /// 値を追加して要素を分割します。
        fn split_parts(comptime ST: type, comptime VT: type, new_parts: *ST, prev_parts: *ST, index: usize, value: VT) void {
            if (index < block_size + 1) {
                // 後半部をコピー
                new_parts.count = block_size + 1;
                for (block_size..bucket_size, 0..) |i, j| {
                    new_parts.value[j] = prev_parts.value[i];
                }

                // 前半部に値を挿入する
                prev_parts.count = block_size + 1;
                var i: usize = block_size;
                while (i > index) : (i -= 1) {
                    prev_parts.value[i] = prev_parts.value[i - 1];
                }
                prev_parts.value[index] = value;
            } else {
                // 後半部に値を挿入する
                const split_index: usize = index - (block_size + 1);
                new_parts.count = block_size + 1;
                if (split_index > 0) {
                    for ((block_size + 1)..index, 0..) |i, j| {
                        new_parts.value[j] = prev_parts.value[i];
                    }
                }
                for (index..bucket_size, (split_index + 1)..) |i, j| {
                    new_parts.value[j] = prev_parts.value[i];
                }
                new_parts.value[split_index] = value;

                // 前半部分は変更なし
                prev_parts.count = block_size + 1;
            }
        }

        /// B+木コレクションから要素を削除します
        pub fn remove(self: *Self, value: T) !bool {
            if (self.root_branch) |root_brh| {
                // ルートノードが空でない場合、枝要素から削除する
                _ = try self.remove_branch(root_brh, value);

                // バランス後にルートが不要ならば削除
                if (root_brh.count <= 1) {
                    switch (root_brh.value[0]) {
                        .leaf => |lf| {
                            self.start_leaf = lf;
                            self.root_branch = null;
                        },
                        .branch => |brh| {
                            self.root_branch = brh;
                        },
                        .value => unreachable,
                    }
                }
                return self.leaf_changed;
            } else {
                // ルートノードが空の場合、葉要素から削除する
                return self.remove_leaf(self.start_leaf, value);
            }
        }

        /// B+木コレクションの葉から要素を削除します（内部用）
        fn remove_leaf(self: *Self, leaf: *BLeaf, value: T) !bool {
            // バイナリサーチを使用して、値を削除する位置を見つける
            const find = bsearch.binary_search_le(T, leaf.value[0..leaf.count], value, compare);
            const index: usize = if (find < 0) 0 else @intCast(find);

            if (index < leaf.count and leaf.value[index] == value) {
                // 値が見つかった場合、削除する
                for (index..leaf.count - 1, index + 1..) |i, j| {
                    leaf.value[i] = leaf.value[j];
                }
                leaf.count -= 1;
                self.count -= 1;
                self.leaf_changed = true;
                return true;
            } else {
                // 値が見つからなかった場合、falseを返す
                return false;
            }
        }

        /// B+木コレクションの枝から要素を削除します（内部用）
        fn remove_branch(self: *Self, branch: *BBranch, value: T) !bool {
            // バイナリサーチを使用して、値を削除する位置を見つける
            var i = bsearch.binary_search_le(BParts, branch.value[0..branch.count], .{ .value = &value }, compare_parts);
            while (i >= 0) : (i -= 1) {
                // 参照位置を取得する
                const index: usize = @intCast(i);

                // 葉、枝要素から値を削除する
                const removed = switch (branch.value[@intCast(index)]) {
                    .leaf => |lf| try self.remove_leaf(lf, value),
                    .branch => |brh| try self.remove_branch(brh, value),
                    .value => unreachable,
                };

                // 削除された場合、枝要素をマージする
                if (removed) {
                    return switch (branch.value[0]) {
                        .leaf => self.balance_leaf(branch, index),
                        .branch => self.balance_branch(branch, index),
                        .value => unreachable,
                    };
                }
            }
            return false;
        }

        /// 葉要素をバランスします。
        fn balance_leaf(self: *Self, branch: *BBranch, index: usize) !bool {
            if (branch.value[index].leaf.count <= block_size) {
                if (index > 0 and branch.value[index - 1].leaf.count > block_size + 1) {
                    division_leaf(branch.value[index - 1].leaf, branch.value[index].leaf);
                    return false;
                } else if (index < branch.count - 1 and branch.value[index + 1].leaf.count > block_size + 1) {
                    division_leaf(branch.value[index].leaf, branch.value[index + 1].leaf);
                    return false;
                } else if (index > 0) {
                    return blk: {
                        bypass_leaf(branch.value[index - 1].leaf, branch.value[index].leaf);
                        const rem = branch.value[index].leaf;
                        const res = merge_parts(BLeaf, branch, index - 1, branch.value[index - 1].leaf, branch.value[index].leaf);
                        try self.leaf_store.put(rem);
                        break :blk res;
                    };
                } else if (index < branch.count - 1) {
                    return blk: {
                        bypass_leaf(branch.value[index].leaf, branch.value[index + 1].leaf);
                        const rem = branch.value[index + 1].leaf;
                        const res = merge_parts(BLeaf, branch, index, branch.value[index].leaf, branch.value[index + 1].leaf);
                        try self.leaf_store.put(rem);
                        break :blk res;
                    };
                }
            }
            return false;
        }

        /// 枝要素をバランスします。
        fn balance_branch(self: *Self, branch: *BBranch, index: usize) !bool {
            if (branch.value[index].branch.count <= block_size) {
                if (index > 0 and branch.value[index - 1].branch.count > block_size + 1) {
                    division_branch(branch.value[index - 1].branch, branch.value[index].branch);
                    return false;
                } else if (index < branch.count - 1 and branch.value[index + 1].branch.count > block_size + 1) {
                    division_branch(branch.value[index].branch, branch.value[index + 1].branch);
                    return false;
                } else if (index > 0) {
                    return blk: {
                        const rem = branch.value[index].branch;
                        const res = merge_parts(BBranch, branch, index - 1, branch.value[index - 1].branch, branch.value[index].branch);
                        try self.branch_store.put(rem);
                        break :blk res;
                    };
                } else if (index < branch.count - 1) {
                    return blk: {
                        const rem = branch.value[index + 1].branch;
                        const res = merge_parts(BBranch, branch, index, branch.value[index].branch, branch.value[index + 1].branch);
                        try self.branch_store.put(rem);
                        break :blk res;
                    };
                }
            }
            return false;
        }

        /// 葉要素を二分割します。
        fn division_leaf(left: *BLeaf, right: *BLeaf) void {
            var merged = Concat(BLeaf, T).init(left, right);
            merged.division(left, right);
        }

        /// 枝要素を二分割します。
        fn division_branch(left: *BBranch, right: *BBranch) void {
            // 枝を結合し、分割
            var merged = Concat(BBranch, BParts).init(left, right);
            merged.division(left, right);

            // 検索キー参照変更
            right.traverseLeaf();
        }

        /// 要素を結合します。
        /// 要素を結合するためのユーティリティ関数です。
        fn Concat(comptime CT: type, comptime RT: type) type {
            return struct {
                const ConSelf = @This();
                left_value: *CT,
                right_value: *CT,
                total_count: usize,

                // 二つの葉要素を結合します。
                pub fn init(left_value: *CT, right_value: *CT) ConSelf {
                    return ConSelf{
                        .left_value = left_value,
                        .right_value = right_value,
                        .total_count = left_value.count + right_value.count,
                    };
                }

                // 要素を取得します。
                pub fn get(lself: *ConSelf, index: usize) RT {
                    return if (index < lself.left_value.count)
                        lself.left_value.value[index]
                    else
                        lself.right_value.value[index - lself.left_value.count];
                }

                // 分割します。
                pub fn division(self: *ConSelf, left: *CT, right: *CT) void {
                    // 左側の要素を更新
                    const new_left_count = self.total_count / 2;
                    for (0..new_left_count, 0..) |i, j| {
                        left.value[j] = self.get(i);
                    }

                    // 右側の要素を更新
                    for (new_left_count..self.total_count, 0..) |i, j| {
                        right.value[j] = self.get(i);
                    }

                    left.count = new_left_count;
                    right.count = self.total_count - new_left_count;
                }
            };
        }

        /// 葉要素の右側をショートカットします。
        fn bypass_leaf(left: *BLeaf, right: *BLeaf) void {
            left.next = right.next;
            if (right.next) |next| {
                next.prev = left;
            }
        }

        /// 要素を結合します。
        fn merge_parts(comptime NT: type, node_branch: *BBranch, index: usize, left: *NT, right: *NT) bool {
            // 前の葉に集約
            for (0..right.count, left.count..) |i, j| {
                left.value[j] = right.value[i];
            }
            left.count += right.count;

            // 要素を前詰め
            for (index + 2..node_branch.count, index + 1..) |i, j| {
                node_branch.value[j] = node_branch.value[i];
            }
            node_branch.count -= 1;
            return (node_branch.count <= block_size);
        }

        /// イテレータを使用して、B+木コレクションの要素を反復処理します。
        /// イテレータは、B+木コレクションの要素を順番に処理するための構造体です。
        pub fn iterate(self: *Self) Iterator {
            return Iterator{
                .tree = self,
                .leaf = self.start_leaf,
                .index = 0,
            };
        }
    };
}

/// テスト用の比較関数
fn compare_fn(lhs: i32, rhs: i32) i32 {
    if (lhs < rhs) {
        return -1;
    } else if (lhs > rhs) {
        return 1;
    } else {
        return 0;
    }
}

fn shuffle_array(alloc: Allocator, prng: *std.Random.DefaultPrng, start: usize, end: usize) ![]i32 {
    var arr = try alloc.alloc(i32, end - start + 1);
    for (start..end + 1, 0..) |i, j| {
        arr[j] = @intCast(i);
    }

    for (0..arr.len - 1) |i| {
        const j = prng.random().int(u32) % (arr.len - i);
        const tmp = arr[arr.len - 1 - i];
        arr[arr.len - 1 - i] = arr[j];
        arr[j] = tmp;
    }
    return arr;
}

// ツリーを初期化、追加をテストします。
test "BPlusTree add test" {
    const allocator = std.testing.allocator;
    var bplus_tree = try BPlusTree(i32, compare_fn).init(allocator);
    defer bplus_tree.deinit();

    try bplus_tree.add(6);
    try bplus_tree.add(4);
    try bplus_tree.add(10);
    try bplus_tree.add(1);
    try bplus_tree.add(7);
    try bplus_tree.add(8);
    try bplus_tree.add(2);
    try bplus_tree.add(5);
    try bplus_tree.add(3);

    var iter = bplus_tree.iterate();
    try expect(iter.next().? == 1);
    try expect(iter.next().? == 2);
    try expect(iter.next().? == 3);
    try expect(iter.next().? == 4);
    try expect(iter.next().? == 5);
    try expect(iter.next().? == 6);
    try expect(iter.next().? == 7);
    try expect(iter.next().? == 8);
    try expect(iter.next().? == 10);
    try expect(iter.next() == null);
}

// ツリーからの削除をテストします。
test "BPlusTree remove test" {
    const allocator = std.testing.allocator;
    var bplus_tree = try BPlusTree(i32, compare_fn).init(allocator);
    defer bplus_tree.deinit();

    const datas = [_]i32{ 7, 2, 1, 10, 5, 8, 3, 9, 4, 6 };
    for (datas) |data| {
        try bplus_tree.add(data);
    }

    _ = try bplus_tree.remove(5);
    _ = try bplus_tree.remove(1);
    _ = try bplus_tree.remove(2);
    _ = try bplus_tree.remove(3);
    _ = try bplus_tree.remove(4);

    var iter = bplus_tree.iterate();
    try expect(iter.next().? == 6);
    try expect(iter.next().? == 7);
    try expect(iter.next().? == 8);
    try expect(iter.next().? == 9);
    try expect(iter.next().? == 10);
    try expect(iter.next() == null);
}

test "BPlusTree add and remove test 100" {
    var prng = std.Random.DefaultPrng.init(1001);

    const allocator = std.testing.allocator;
    var bplus_tree = try BPlusTree(i32, compare_fn).init(allocator);
    defer bplus_tree.deinit();

    const data1 = try shuffle_array(allocator, &prng, 1, 300);
    defer allocator.free(data1);
    for (data1) |data| {
        try bplus_tree.add(data);
    }
    try expect(bplus_tree.count == 300);
    var iter1 = bplus_tree.iterate();
    for (1..301) |v| {
        try expect(iter1.next().? == v);
    }
}

test "BPlusTree add and remove test" {
    var prng = std.Random.DefaultPrng.init(1001);

    const allocator = std.testing.allocator;
    var bplus_tree = try BPlusTree(i32, compare_fn).init(allocator);
    defer bplus_tree.deinit();

    const data1 = try shuffle_array(allocator, &prng, 1, 100);
    defer allocator.free(data1);
    for (data1) |data| {
        try bplus_tree.add(data);
    }
    try expect(bplus_tree.count == 100);
    var iter1 = bplus_tree.iterate();
    for (1..101) |v| {
        try expect(iter1.next().? == v);
    }

    for (1..51) |v| {
        _ = try bplus_tree.remove(@intCast(v));
    }
    var iter1_1 = bplus_tree.iterate();
    for (51..101) |v| {
        try expect(iter1_1.next().? == v);
    }

    const data2 = try shuffle_array(allocator, &prng, 101, 400);
    defer allocator.free(data2);
    for (data2) |data| {
        try bplus_tree.add(data);
    }
    try expect(bplus_tree.count == 350);
    var iter2 = bplus_tree.iterate();
    for (51..401) |v| {
        try expect(iter2.next().? == v);
    }
}
