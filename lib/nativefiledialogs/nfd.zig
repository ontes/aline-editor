pub const PathSet = extern struct {
    buf: [*]u8,
    indices: [*]usize,
    count: usize,

    extern fn NFD_PathSet_GetCount(pathSet: *const PathSet) usize;
    pub const getCount = NFD_PathSet_GetCount;
    extern fn NFD_PathSet_GetPath(pathSet: *const PathSet, index: usize) [*c]u8;
    pub const getPath = NFD_PathSet_GetPath;
    extern fn NFD_PathSet_Free(pathSet: *PathSet) void;
    pub const free = NFD_PathSet_Free;
};

pub const Result = enum(c_int) {
    err = 0,
    okay = 1,
    cancel = 2,
};

extern fn NFD_OpenDialog(filter_list: ?[*:0]const u8, default_path: ?[*:0]const u8, out_path: *[*:0]u8) Result;
pub const openDialog = NFD_OpenDialog;
extern fn NFD_OpenDialogMultiple(filter_list: ?[*:0]const u8, default_path: ?[*:0]const u8, out_paths: *PathSet) Result;
pub const openDialogMultiple = NFD_OpenDialogMultiple;
extern fn NFD_SaveDialog(filter_list: ?[*:0]const u8, default_path: ?[*:0]const u8, out_path: *[*:0]u8) Result;
pub const saveDialog = NFD_SaveDialog;
extern fn NFD_PickFolder(default_path: ?[*:0]const u8, out_path: *[*:0]u8) Result;
pub const pickFolder = NFD_PickFolder;
extern fn NFD_GetError() ?[*:0]const u8;
pub const getError = NFD_GetError;
