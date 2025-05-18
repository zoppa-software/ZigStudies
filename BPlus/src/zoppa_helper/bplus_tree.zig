const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const store = @import("store.zig");
const bsearch = @import("binary_search.zig");

/// B+木コレクション
/// B+木のコレクションを実装します。
/// データベースやファイルシステムなどの大規模なデータセットを効率的に管理するために使用されるデータ構造です。
/// B木の変種であり、すべての値がリーフノードに格納されることを除いて、B木と同じ特性を持っています。
/// データの挿入、削除、検索を効率的に行うことができるため、大規模なデータセットを扱うアプリケーションに適しています。
pub fn BPlusTree(comptime T: type, compare: fn (@TypeOf(T), lhs: T, rhs: T) i32) type {
    // ブロックサイズ
    const block_size: comptime_int = 1;

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
            pub fn init(self: *@This(), left_value: BParts, right_vale: BParts) void {
                self.count = 2;
                self.value[0] = left_value;
                self.value[1] = right_vale;
                self.head_leaf = self.traverseLeaf();
            }

            /// 先頭の葉要素を取得します。
            pub fn traverseLeaf(self: *@This()) *BLeaf {
                var ptr: BParts = self.value[0];
                while (true) {
                    switch (ptr) {
                        .leaf => {
                            break;
                        },
                        .branch => |branch| {
                            ptr = branch.value[0];
                        },
                        .value => {
                            break;
                        },
                    }
                }
                return ptr.leaf;
            }
        };

        // 枝と葉の要素の共通部分
        const BParts = union(enum) {
            leaf: *BLeaf,
            branch: *BBranch,
            value: *const T,
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
        pub fn initAndRegist(alloc: Allocator, source_collection: *[]T) !Self {
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
                try res.local_add(value);
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

            self.count = 0;
            self.root_branch = null;
            self.start_leaf = self.leaf_store.get();
            self.start_leaf.init();
        }

        /// B+木コレクションに要素を追加します。
        pub fn add(self: *Self, value: T) !void {
            self.leaf_changed = false;
            try self.local_add(value);
        }

        /// B+木コレクションに要素を追加します（内部用）
        fn local_add(self: *Self, value: T) !void {
            if (self.root_branch) |root_bh| {
                // ルートノードが空でない場合、ルートノードに追加する
                const next_branch = try self.branch_add(root_bh, value);
                if (next_branch) |next_bh| {
                    const new_branch = try self.branch_store.get();
                    new_branch.init(.{ .branch = root_bh }, .{ .branch = next_bh });
                    self.root_branch = new_branch;
                }
            } else {
                // ルートノードが空の場合、葉のみを追加する
                const next_leaf = try self.leaf_add(self.start_leaf, value);
                if (next_leaf) |next_lf| {
                    const new_branch = try self.branch_store.get();
                    new_branch.init(.{ .leaf = self.start_leaf }, .{ .leaf = next_lf });
                    self.root_branch = new_branch;
                }
            }
        }

        /// 葉要素に値を追加します。
        pub fn leaf_add(self: *Self, leaf: *BLeaf, value: T) !?*BLeaf {
            if (leaf.count == 0) {
                leaf.value[0] = value;
                leaf.count += 1;
                self.count += 1;
                self.leaf_changed = true;
                return null;
            } else {
                // バイナリサーチを使用して、値を挿入する位置を見つける
                const index: usize = @intCast(try bsearch.binary_search_gt(T, leaf.value[0..leaf.count], value, compare));

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
                    const new_leaf = self.leaf_split(leaf, value, index);
                    self.count += 1;
                    self.leaf_changed = true;
                    return new_leaf;
                }
            }
        }

        /// 葉要素を分割します。
        pub fn leaf_split(self: *Self, leaf: *BLeaf, value: T, index: usize) !*BLeaf {
            var new_leaf = try self.leaf_store.get();
            new_leaf.init();

            if (index < block_size + 1) {
                // 後半部をコピー
                new_leaf.count = block_size + 1;
                for (block_size..bucket_size, 0..new_leaf.count) |i, j| {
                    new_leaf.value[j] = leaf.value[i];
                }

                // 前半部に値を挿入する
                leaf.count = block_size + 1;
                var i: usize = block_size;
                while (i > index) : (i -= 1) {
                    leaf.value[i] = leaf.value[i - 1];
                }
                leaf.value[index] = value;
            } else {
                // 後半部に値を挿入する
                new_leaf.count = block_size + 1;
                var i: usize = block_size;
                while (i > index - block_size) : (i -= 1) {
                    new_leaf.value[i] = new_leaf.value[i - 1];
                }
                new_leaf.value[index - block_size] = value;

                // 前半部分は変更なし
                leaf.count = block_size + 1;
            }

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

        /// 葉要素に値を追加します。
        pub fn branch_add(self: *Self, branch: *BBranch, value: T) !?*BBranch {
            // バイナリサーチを使用して、値を挿入する位置を見つける
            const index: usize = @intCast(try bsearch.binary_search_le(BParts, branch.value[0..branch.count], .{ .value = &value }, compare_parts));
            _ = self;
            _ = index;
            return null;
        }

        /// 先頭要素で比較します。
        fn compare_parts(_: type, lhs: BParts, rhs: BParts) i32 {
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
            return compare(T, left_value, right_value);
        }
    };
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

// ストアを初期化をテストします。
test "BPlusTree init" {
    const allocator = std.testing.allocator;
    var bplus_tree = try BPlusTree(i32, compare_fn).init(allocator);
    defer bplus_tree.deinit();

    try bplus_tree.add(6);
    try bplus_tree.add(4);
    try bplus_tree.add(10);
    try bplus_tree.add(1);
    try bplus_tree.add(7);
}
