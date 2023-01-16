const std = @import("std");

pub const Atom = u16;

pub const Window = opaque {}; // HWND
pub const Module = opaque {}; // HMODULE
pub const Instance = opaque {}; // HINSTANCE
pub const Icon = opaque {}; // HICON
pub const Cursor = opaque {}; // HCURSOR
pub const Brush = opaque {}; // HBRUSH
pub const Menu = opaque {}; // HMENU

// pub const ULONG = u32;
// pub const ULONG_PTR = usize;
// pub const LONG_PTR = isize;
// pub const DWORD_PTR = usize;
// pub const DWORD = u32;
// pub const DWORD64 = u64;
// pub const WPARAM = usize;
// pub const LPARAM = isize;
// pub const LRESULT = isize;
// pub const LPVOID = *anyopaque;

pub const Bool = enum(c_int) {
    false = 0,
    true = 1,
};

pub const Status = enum(c_int) {
    err = 0,
    _,
};

pub const PeekMessageOptions = enum(u32) {
    no_remove = 0,
    remove = 1,
    noyield = 2,
};

pub const MessageType = enum(u32) {
    // Window Messages
    null = 0x0000,
    create = 0x0001,
    destroy = 0x0002,
    move = 0x0003,
    size = 0x0005,
    activate = 0x0006,
    set_focus = 0x0007,
    kill_focus = 0x0008,
    enable = 0x000a,
    set_redraw = 0x000b,
    set_text = 0x000c,
    get_text = 0x000d,
    get_text_length = 0x000e,
    paint = 0x000f,
    close = 0x0010,
    query_end_session = 0x0011,
    quit = 0x0012,
    query_open = 0x0013,
    erase_bkgnd = 0x0014,
    sys_color_change = 0x0015,
    end_session = 0x0016,
    show_window = 0x0018,
    ctl_color = 0x0019,
    win_ini_change = 0x001a,
    dev_mode_change = 0x001b,
    activate_app = 0x001c,
    font_change = 0x001d,
    time_change = 0x001e,
    cancel_mode = 0x001f,
    set_cursor = 0x0020,
    mouse_activate = 0x0021,
    child_activate = 0x0022,
    queue_sync = 0x0023,
    get_min_max_info = 0x0024,
    paint_icon = 0x0026,
    icon_erase_bkgnd = 0x0027,
    next_dlgctl = 0x0028,
    spooler_status = 0x002a,
    draw_item = 0x002b,
    measure_item = 0x002c,
    delete_item = 0x002d,
    vkey_to_item = 0x002e,
    char_to_item = 0x002f,
    set_font = 0x0030,
    get_font = 0x0031,
    set_hotkey = 0x0032,
    get_hotkey = 0x0033,
    query_drag_icon = 0x0037,
    compare_item = 0x0039,
    get_object = 0x003d,
    compacting = 0x0041,
    comm_notify = 0x0044,
    window_pos_changing = 0x0046,
    window_pos_changed = 0x0047,
    power = 0x0048,
    copy_global_data = 0x0049,
    copy_data = 0x004a,
    cancel_journal = 0x004b,
    notify = 0x004e,
    input_lang_change_request = 0x0050,
    input_lang_change = 0x0051,
    tcard = 0x0052,
    help = 0x0053,
    user_changed = 0x0054,
    notify_format = 0x0055,
    context_menu = 0x007b,
    style_changing = 0x007c,
    style_changed = 0x007d,
    display_change = 0x007e,
    get_icon = 0x007f,
    set_icon = 0x0080,
    nc_create = 0x0081,
    nc_destroy = 0x0082,
    nc_calc_size = 0x0083,
    nc_hit_test = 0x0084,
    nc_paint = 0x0085,
    nc_activate = 0x0086,
    get_dlg_code = 0x0087,
    sync_paint = 0x0088,
    nc_mouse_move = 0x00a0,
    nc_l_button_down = 0x00a1,
    nc_l_button_up = 0x00a2,
    nc_l_button_dblclk = 0x00a3,
    nc_r_button_down = 0x00a4,
    nc_r_button_up = 0x00a5,
    nc_r_button_dblclk = 0x00a6,
    nc_m_button_down = 0x00a7,
    nc_m_button_up = 0x00a8,
    nc_m_button_dblclk = 0x00a9,
    nc_x_button_down = 0x00ab,
    nc_x_button_up = 0x00ac,
    nc_x_button_dblclk = 0x00ad,

    // Key Events
    key_down = 0x0100,
    key_up = 0x0101,
    char = 0x0102,
    dead_char = 0x0103,
    sys_key_down = 0x0104,
    sys_key_up = 0x0105,
    sys_char = 0x0106,
    sys_dead_char = 0x0107,

    ime_start_composition = 0x010d,
    ime_end_composition = 0x010e,
    ime_composition = 0x010f,

    init_dialog = 0x0110,
    command = 0x0111,
    sys_command = 0x0112,
    timer = 0x0113,
    h_scroll = 0x0114,
    v_scroll = 0x0115,
    init_menu = 0x0116,
    init_menu_popup = 0x0117,
    sys_timer = 0x0118,
    menu_select = 0x011f,
    menu_char = 0x0120,
    enter_idle = 0x0121,
    menu_rbutton_up = 0x0122,
    menu_drag = 0x0123,
    menu_get_object = 0x0124,
    uninit_menu_popup = 0x0125,
    menu_command = 0x0126,
    ctl_color_msgbox = 0x0132,
    ctl_color_edit = 0x0133,
    ctl_color_listbox = 0x0134,
    ctl_color_btn = 0x0135,
    ctl_color_dlg = 0x0136,
    ctl_color_scrollbar = 0x0137,
    ctl_color_static = 0x0138,

    // Mouse Events
    mouse_move = 0x0200,
    l_button_down = 0x0201,
    l_button_up = 0x0202,
    l_button_dblclk = 0x0203,
    r_button_down = 0x0204,
    r_button_up = 0x0205,
    r_button_dblclk = 0x0206,
    m_button_down = 0x0207,
    m_button_up = 0x0208,
    m_button_dblclk = 0x0209,
    mouse_wheel = 0x020a,
    x_button_down = 0x020b,
    x_button_up = 0x020c,
    x_button_dblclk = 0x020d,

    parent_notify = 0x0210,
    enter_menu_loop = 0x0211,
    exit_menu_loop = 0x0212,
    next_menu = 0x0213,
    sizing = 0x0214,
    capture_changed = 0x0215,
    moving = 0x0216,
    power_broadcast = 0x0218,
    device_change = 0x0219,
    mdi_create = 0x0220,
    mdi_destroy = 0x0221,
    mdi_activate = 0x0222,
    mdi_restore = 0x0223,
    mdi_next = 0x0224,
    mdi_maximize = 0x0225,
    mdi_tile = 0x0226,
    mdi_cascade = 0x0227,
    mdi_icon_arrange = 0x0228,
    mdi_get_active = 0x0229,
    mdi_set_menu = 0x0230,
    enter_size_move = 0x0231,
    exit_size_move = 0x0232,
    drop_files = 0x0233,
    mdi_refresh_menu = 0x0234,
    ime_set_context = 0x0281,
    ime_notify = 0x0282,
    ime_control = 0x0283,
    ime_composition_full = 0x0284,
    ime_select = 0x0285,
    ime_char = 0x0286,
    ime_request = 0x0288,
    ime_keydown = 0x0290,
    ime_keyup = 0x0291,
    mouse_hover = 0x02a1,
    mouse_leave = 0x02a3,
    cut = 0x0300,
    copy = 0x0301,
    paste = 0x0302,
    clear = 0x0303,
    undo = 0x0304,
    render_format = 0x0305,
    render_all_formats = 0x0306,
    destroy_clipboard = 0x0307,
    draw_clipboard = 0x0308,
    paint_clipboard = 0x0309,
    v_scroll_clipboard = 0x030a,
    size_clipboard = 0x030b,
    ask_cb_format_name = 0x030c,
    change_cb_chain = 0x030d,
    h_scroll_clipboard = 0x030e,
    query_new_palette = 0x030f,
    palette_is_changing = 0x0310,
    palette_changed = 0x0311,
    hotkey = 0x0312,
    print = 0x0317,
    print_client = 0x0318,

    // EditControl Messages
    ec_get_sel = 0x00b0,
    ec_set_sel = 0x00b1,
    ec_get_rect = 0x00b2,
    ec_set_rect = 0x00b3,
    ec_set_rect_np = 0x00b4,
    ec_scroll = 0x00b5,
    ec_line_scroll = 0x00b6,
    ec_scroll_caret = 0x00b7,
    ec_get_modify = 0x00b8,
    ec_set_modify = 0x00b9,
    ec_get_line_count = 0x00ba,
    ec_line_index = 0x00bb,
    ec_set_handle = 0x00bc,
    ec_get_handle = 0x00bd,
    ec_get_thumb = 0x00be,
    ec_line_length = 0x00c1,
    ec_replace_sel = 0x00c2,
    ec_get_line = 0x00c4,
    ec_limit_text = 0x00c5,
    ec_can_undo = 0x00c6,
    ec_undo = 0x00c7,
    ec_fmt_lines = 0x00c8,
    ec_line_from_char = 0x00c9,
    ec_set_tab_stops = 0x00cb,
    ec_set_password_char = 0x00cc,
    ec_empty_undo_buffer = 0x00cd,
    ec_get_first_visible_line = 0x00ce,
    ec_set_read_only = 0x00cf,
    ec_set_word_break_proc = 0x00d0,
    ec_get_word_break_proc = 0x00d1,
    ec_get_password_char = 0x00d2,
    ec_set_margins = 0x00d3,
    ec_get_margins = 0x00d4,
    ec_get_limit_text = 0x00d5,
    ec_pos_from_char = 0x00d6,
    ec_char_from_pos = 0x00d7,
    ec_set_ime_status = 0x00d8,
    ec_get_ime_status = 0x00d9,
    _,
};

pub const WindowClassEx = extern struct {
    size: c_uint = @sizeOf(WindowClassEx),
    style: ClassStyle,
    window_proc: *const WindowProc,
    class_extra: i32 = 0,
    window_extra: i32 = 0,
    instance: *Instance,
    icon: ?*Icon,
    cursor: ?*Cursor,
    background_brush: ?*Brush,
    menu_name: ?[*:0]const u8,
    class_name: [*:0]const u8,
    icon_small: ?*Icon,
};

pub const WindowStyle = packed struct {
    active_caption: bool = false,
    _: u15 = 0,
    tab_stop: bool = false, // turns to maximize_box when sysmenu is specified
    group: bool = false, // turns to minimize_box when sysmenu is specified
    size_box: bool = false,
    sys_menu: bool = false,
    h_scroll: bool = false,
    v_scroll: bool = false,
    dlg_frame: bool = false, // turns to caption when border is specified
    border: bool = false,
    maximize: bool = false,
    clip_children: bool = false,
    clip_siblings: bool = false,
    disabled: bool = false,
    visible: bool = false,
    minimize: bool = false,
    child: bool = false,
    popup: bool = false,

    pub const overlapped = WindowStyle{};
    pub const caption = WindowStyle{ .border = true, .dlg_frame = true };
    pub const minimize_box = WindowStyle{ .sys_menu = true, .group = true };
    pub const maximize_box = WindowStyle{ .sys_menu = true, .tab_stop = true };
    pub const overlapped_window = WindowStyle{ .border = true, .dlg_frame = true, .sys_menu = true, .size_box = true, .group = true, .tab_stop = true };
    pub const popup_window = WindowStyle{ .popup = true, .border = true, .sys_menu = true };
};

pub const WindowStyleEx = packed struct {
    dlg_modal_frame: bool = false,
    _0: u1 = 0,
    no_parent_notify: bool = false,
    topmost: bool = false,
    accept_files: bool = false,
    transparent: bool = false,
    mdi_child: bool = false,
    tool_window: bool = false,
    window_edge: bool = false,
    client_edge: bool = false,
    context_help: bool = false,
    _1: u1 = 0,
    right: bool = false,
    rtlreading: bool = false,
    leftscrollbar: bool = false,
    _2: u1 = 0,
    controlparent: bool = false,
    static_edge: bool = false,
    app_window: bool = false,
    layered: bool = false,
    no_inherit_layout: bool = false,
    _3: u1 = 0,
    layout_rtl: bool = false,
    _4: u2 = 0,
    composited: bool = false,
    _5: u1 = 0,
    no_activate: bool = false,
    _6: u4 = 0,

    pub const left = WindowStyleEx{};
    pub const overlapped_window = WindowStyleEx{ .window_edge = true, .client_edge = true };
    pub const palette_window = WindowStyleEx{ .window_edge = true, .tool_window = true, .topmost = true };
};

pub const ClassStyle = packed struct {
    v_redraw: bool = false,
    h_redraw: bool = false,
    _0: u1 = 0,
    dbl_clks: bool = false,
    _1: u1 = 0,
    own_dc: bool = false,
    class_dc: bool = false,
    parent_dc: bool = false,
    _2: u1 = 0,
    no_close: bool = false,
    _3: u1 = 0,
    save_bits: bool = false,
    byte_align_client: bool = false,
    byte_align_window: bool = false,
    global_class: bool = false,
    _4: u1 = 0,
    ime: bool = false,
    drop_shadow: bool = false,
    _5: u14 = 0,
};

pub const ShowWindowCommand = enum(c_int) {
    hide = 0,
    show_normal = 1, // and normal
    show_minimized = 2,
    show_maximized = 3, // and maximize
    show_normal_na = 4,
    show = 5,
    minimize = 6,
    show_minimized_na = 7,
    show_na = 8,
    restore = 9,
    show_default = 10,
    force_minimize = 11,
};

pub const Message = extern struct {
    window: ?*Window,
    message_type: MessageType,
    w_param: usize,
    l_param: isize,
    time: u32,
    pt: Point,
    _: u32,
};

pub const Point = extern struct {
    x: i32,
    y: i32,
};

pub const Rect = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

pub const WindowProc = fn (window: *Window, message_type: MessageType, w_param: usize, l_param: isize) callconv(.C) isize;

extern fn CreateWindowExA(ex_style: WindowStyleEx, class_name: [*:0]const u8, window_name: [*:0]const u8, style: WindowStyle, x: c_int, y: c_int, width: c_int, height: c_int, window_parent: ?*Window, menu: *Menu, instance: *Instance, userdata: ?*anyopaque) ?*Window;
pub const createWindowEx = CreateWindowExA;
extern fn DestroyWindow(window: *Window) Status;
pub const destroyWindow = DestroyWindow;
extern fn ShowWindow(window: *Window, cmd_show: ShowWindowCommand) Bool;
pub const showWindow = ShowWindow;
extern fn GetModuleHandleA(module_name: ?[*:0]const u8) ?*Module;
pub const getModuleHandle = GetModuleHandleA;
extern fn RegisterClassExA(*const WindowClassEx) Atom;
pub const registerClassEx = RegisterClassExA;
extern fn UnregisterClassA(class_name: [*:0]const u8, hInstance: *Instance) Status;
pub const unregisterClass = UnregisterClassA;
extern fn PeekMessageA(message: *Message, window: ?*Window, msg_filter_min: c_uint, msg_filter_max: c_uint, remove_msg: PeekMessageOptions) Bool;
pub const peekMessage = PeekMessageA;
extern fn TranslateMessage(message: *const Message) Bool;
pub const translateMessage = TranslateMessage;
extern fn DispatchMessageA(message: *const Message) isize;
pub const dispatchMessage = DispatchMessageA;
extern fn DefWindowProcA(window: *Window, message_type: MessageType, w_param: usize, l_param: isize) isize;
pub const defWindowProc = DefWindowProcA;
extern fn GetWindowRect(window: *Window, rect: *Rect) Status;
pub const getWindowRect = GetWindowRect;
extern fn GetLastError() u16;
pub const getLastError = GetLastError;
