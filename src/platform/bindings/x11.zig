pub const ID = c_ulong;
pub const Mask = c_ulong;
pub const Atom = c_ulong;
pub const VisualID = c_ulong;
pub const Time = c_ulong;

pub const Window = ID;
pub const Drawable = ID;
pub const Font = ID;
pub const Pixmap = ID;
pub const Cursor = ID;
pub const Colormap = ID;
pub const GContext = ID;
pub const KeySym = ID;

pub const KeyCode = u8;

pub const GC = opaque {};
pub const Display = opaque {};
pub const XrmDatabase = opaque {};
pub const IM = opaque {
    pub const preeditArea = @as(c_long, 0x0001);
    pub const preeditCallbacks = @as(c_long, 0x0002);
    pub const preeditPosition = @as(c_long, 0x0004);
    pub const preeditNothing = @as(c_long, 0x0008);
    pub const preeditNone = @as(c_long, 0x0010);
    pub const statusArea = @as(c_long, 0x0100);
    pub const statusCallbacks = @as(c_long, 0x0200);
    pub const statusNothing = @as(c_long, 0x0400);
    pub const statusNone = @as(c_long, 0x0800);
};
pub const IC = opaque {};

pub const Bool = enum(c_int) {
    false = 0,
    true = 1,
};

pub const Status = enum(c_int) {
    err = 0,
    _,
};

pub const Event = extern union {
    type: EventType,
    any: AnyEvent,
    key: KeyEvent,
    button: ButtonEvent,
    motion: MotionEvent,
    crossing: CrossingEvent,
    focus: FocusEvent,
    expose: ExposeEvent,
    graphics_expose: GraphicsExposeEvent,
    no_expose: NoExposeEvent,
    visibility: VisibilityEvent,
    create: CreateEvent,
    destroy: DestroyEvent,
    unmap: UnmapEvent,
    map: MapEvent,
    map_request: MapRequestEvent,
    reparent: ReparentEvent,
    configure: ConfigureEvent,
    gravity: GravityEvent,
    resize_request: ResizeRequestEvent,
    configure_request: ConfigureRequestEvent,
    circulate: CirculateEvent,
    circulate_request: CirculateRequestEvent,
    property: PropertyEvent,
    selection_clear: SelectionClearEvent,
    selection_request: SelectionRequestEvent,
    selection: SelectionEvent,
    colormap: ColormapEvent,
    client_message: ClientMessageEvent,
    mapping: MappingEvent,
    error_: ErrorEvent,
    keymap: KeymapEvent,
    generic: GenericEvent,
    cookie: GenericEventCookie,
    pad: [24]c_long,
};

pub const EventType = enum(c_int) {
    key_press = 2,
    key_release = 3,
    button_press = 4,
    button_release = 5,
    motion = 6,
    crossing_enter = 7,
    crossing_leave = 8,
    focus_in = 9,
    focus_out = 10,
    keymap = 11,
    expose = 12,
    graphics_expose = 13,
    no_expose = 14,
    visibility = 15,
    create = 16,
    destroy = 17,
    unmap = 18,
    map = 19,
    map_request = 20,
    reparent = 21,
    configure = 22,
    configure_request = 23,
    gravity = 24,
    resize_request = 25,
    circulate = 26,
    circulate_request = 27,
    property = 28,
    selection_clear = 29,
    selection_request = 30,
    selection = 31,
    colormap = 32,
    client_message = 33,
    mapping = 34,
    generic = 35,
};

pub const KeyEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    keycode: c_uint,
    same_screen: c_int,
};

pub const ButtonEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    button: c_uint,
    same_screen: c_int,
};

pub const MotionEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    is_hint: u8,
    same_screen: c_int,
};

pub const CrossingEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    mode: NotifyMode,
    detail: c_int,
    same_screen: Bool,
    focus: Bool,
    state: c_uint,
};

pub const FocusEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    mode: NotifyMode,
    detail: c_int,
};

pub const KeymapEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    key_vector: [32]u8,
};

pub const ExposeEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    count: c_int,
};

pub const GraphicsExposeEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    drawable: Drawable,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    count: c_int,
    major_code: c_int,
    minor_code: c_int,
};

pub const NoExposeEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    drawable: Drawable,
    major_code: c_int,
    minor_code: c_int,
};

pub const VisibilityEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    state: c_int,
};

pub const CreateEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    override_redirect: c_int,
};

pub const DestroyEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
};

pub const UnmapEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    from_configure: c_int,
};

pub const MapEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    override_redirect: c_int,
};

pub const MapRequestEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
};

pub const ReparentEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    parent: Window,
    x: c_int,
    y: c_int,
    override_redirect: c_int,
};

pub const ConfigureEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    above: Window,
    override_redirect: c_int,
};

pub const GravityEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    x: c_int,
    y: c_int,
};

pub const ResizeRequestEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    width: c_int,
    height: c_int,
};

pub const ConfigureRequestEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    above: Window,
    detail: c_int,
    value_mask: c_ulong,
};

pub const CirculateEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    place: c_int,
};

pub const CirculateRequestEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
    place: c_int,
};

pub const PropertyEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    atom: Atom,
    time: Time,
    state: c_int,
};

pub const SelectionClearEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    selection: Atom,
    time: Time,
};

pub const SelectionRequestEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    owner: Window,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const SelectionEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const ColormapEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    colormap: Colormap,
    new: c_int,
    state: c_int,
};

pub const ClientMessageEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    message_type: Atom,
    format: c_int,
    data: extern union {
        b: [20]u8,
        s: [10]c_short,
        l: [5]c_long,
    },
};

pub const MappingEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
    request: c_int,
    first_keycode: c_int,
    count: c_int,
};

pub const ErrorEvent = extern struct {
    type: EventType,
    display: *Display,
    resourceid: *anyopaque,
    serial: c_ulong,
    error_code: u8,
    request_code: u8,
    minor_code: u8,
};

pub const AnyEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    window: Window,
};

pub const GenericEvent = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    extension: c_int,
    evtype: c_int,
};

pub const GenericEventCookie = extern struct {
    type: EventType,
    serial: c_ulong,
    send_event: Bool,
    display: *Display,
    extension: c_int,
    evtype: c_int,
    cookie: c_uint,
    data: ?*anyopaque,
};

pub const GrabMode = enum(c_int) {
    grab_sync = 0,
    grab_async = 1,
};

pub const GrabResult = enum(c_int) {
    grab_success = 0,
    already_grabbed = 1,
    grab_invalid_time = 2,
    grab_not_viewable = 3,
    grab_frozen = 4,
};

pub const NotifyMode = enum(c_int) {
    normal = 0,
    grab = 1,
    ungrab = 2,
    while_grabbed = 3,
};

pub const EventMask = packed struct {
    key_press: bool = false,
    key_release: bool = false,
    button_press: bool = false,
    button_release: bool = false,
    crossing_enter: bool = false,
    crossing_leave: bool = false,
    motion: bool = false,
    motion_hint: bool = false,
    button1_motion: bool = false,
    button2_motion: bool = false,
    button3_motion: bool = false,
    button4_motion: bool = false,
    button5_motion: bool = false,
    button_motion: bool = false,
    keymap: bool = false,
    expose: bool = false, // expose, graphics_expose, no_expose
    visibility: bool = false,
    structure: bool = false, // circulate, configure, destroy, gravity, map, reparent, unmap
    resize_request: bool = false,
    substructure: bool = false, // circulate, configure, create, destroy, gravity, map, reparent, unmap
    substructure_request: bool = false, // circulate_request, configure_request, map_request
    focus: bool = false, // focus_in, focus_out
    property: bool = false,
    colormap: bool = false,
    owner_grab_button: bool = false,
    _: if (@sizeOf(c_long) == 8) u39 else u7 = 0,
};

pub const Visual = extern struct {
    ext_data: ?*anyopaque,
    visual_id: VisualID,
    class: c_int,
    red_mask: c_ulong,
    green_mask: c_ulong,
    blue_mask: c_ulong,
    bits_per_rgb: c_int,
    map_entries: c_int,
};

pub const VisualInfo = extern struct {
    visual: *Visual,
    visualid: VisualID,
    screen: c_int,
    depth: c_int,
    class: c_int,
    red_mask: c_ulong,
    green_mask: c_ulong,
    blue_mask: c_ulong,
    colormap_size: c_int,
    bits_per_rgb: c_int,
};

pub const Depth = extern struct {
    depth: c_int,
    nvisuals: c_int,
    visuals: [*]Visual,
};

pub const Screen = extern struct {
    ext_data: ?*anyopaque,
    display: *Display,
    root: Window,
    width: c_int,
    height: c_int,
    mwidth: c_int,
    mheight: c_int,
    ndepths: c_int,
    depths: *Depth,
    root_depth: c_int,
    root_visual: *Visual,
    default_gc: *GC,
    cmap: Colormap,
    white_pixel: c_ulong,
    black_pixel: c_ulong,
    max_maps: c_int,
    min_maps: c_int,
    backing_store: c_int,
    save_unders: c_int,
    root_input_mask: c_long,
};

pub const WindowAttributes = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    depth: c_int,
    visual: *Visual,
    root: Window,
    class: c_int,
    bit_gravity: c_int,
    win_gravity: c_int,
    backing_store: c_int,
    backing_planes: c_ulong,
    backing_pixel: c_ulong,
    save_under: c_int,
    colormap: Colormap,
    map_installed: c_int,
    map_state: c_int,
    all_event_masks: c_long,
    your_event_mask: c_long,
    do_not_propagate_mask: c_long,
    override_redirect: c_int,
    screen: *Screen,
};

pub const clientWindow = "clientWindow";
pub const inputStyle = "inputStyle";
pub const focusWindow = "focusWindow";
pub const resourceName = "resourceName";
pub const resourceClass = "resourceClass";
pub const geometryCallback = "geometryCallback";
pub const destroyCallback = "destroyCallback";
pub const filterEvents = "filterEvents";

extern fn XOpenDisplay(display_name: ?[*:0]const u8) ?*Display;
pub const openDisplay = XOpenDisplay;
extern fn XCloseDisplay(display: *Display) void;
pub const closeDisplay = XCloseDisplay;
extern fn XDefaultRootWindow(display: *Display) Window;
pub const defaultRootWindow = XDefaultRootWindow;
extern fn XCreateSimpleWindow(display: *Display, parent: Window, x: c_int, y: c_int, width: c_uint, height: c_uint, border_width: c_uint, border: c_ulong, background: c_ulong) Window;
pub const createSimpleWindow = XCreateSimpleWindow;
extern fn XDestroyWindow(display: *Display, window: Window) void;
pub const destroyWindow = XDestroyWindow;
extern fn XSelectInput(display: *Display, window: Window, event_mask: EventMask) void;
pub const selectInput = XSelectInput;
extern fn XInternAtom(display: *Display, atom_name: [*:0]const u8, only_if_exists: Bool) Atom;
pub const internAtom = XInternAtom;
extern fn XSetWMProtocols(display: *Display, window: Window, protocols: [*]Atom, count: c_int) Status;
pub const setWMProtocols = XSetWMProtocols;
extern fn XMapWindow(display: *Display, window: Window) void;
pub const mapWindow = XMapWindow;
extern fn XMoveWindow(display: *Display, window: Window, x: c_int, y: c_int) void;
pub const moveWindow = XMoveWindow;
extern fn XResizeWindow(display: *Display, window: Window, width: c_uint, height: c_uint) void;
pub const resizeWindow = XResizeWindow;
extern fn XStoreName(display: *Display, window: Window, name: [*:0]const u8) void;
pub const storeName = XStoreName;
extern fn XGrabPointer(display: *Display, window: Window, owner_events: Bool, event_mask: c_uint, pointer_mode: GrabMode, keyboard_mode: GrabMode, confine_to: Window, cursor: Cursor, time: Time) GrabResult;
pub const grabPointer = XGrabPointer;
extern fn XUngrabPointer(display: *Display, time: Time) void;
pub const ungrabPointer = XUngrabPointer;
extern fn XPending(display: *Display) c_int;
pub const pending = XPending;
extern fn XNextEvent(display: *Display, event_return: *Event) void;
pub const nextEvent = XNextEvent;
extern fn XPeekEvent(display: *Display, event_return: *Event) void;
pub const peekEvent = XPeekEvent;
extern fn XLookupKeysym(key_event: *KeyEvent, index: c_int) KeySym;
pub const lookupKeysym = XLookupKeysym;
extern fn XRefreshKeyboardMapping(mapping_event: *MappingEvent) void;
pub const refreshKeyboardMapping = XRefreshKeyboardMapping;
extern fn XQueryPointer(display: *Display, window: Window, root_return: *Window, child_return: *Window, root_x_return: *c_int, root_y_return: *c_int, x_return: *c_int, y_return: *c_int, mask_return: *c_uint) Bool;
pub const queryPointer = XQueryPointer;
extern fn XGetWindowAttributes(display: *Display, window: Window, window_attributes_return: *WindowAttributes) Status;
pub const getWindowAttributes = XGetWindowAttributes;
extern fn XWarpPointer(display: *Display, src_w: Window, dest_w: Window, src_x: c_int, src_y: c_int, src_width: c_uint, src_height: c_uint, dest_x: c_int, dest_y: c_int) void;
pub const warpPointer = XWarpPointer;
extern fn XDefaultScreen(display: *Display) c_int;
pub const defaultScreen = XDefaultScreen;
extern fn XFree(data: *anyopaque) void;
pub const free = XFree;
extern fn XInitThreads() Status;
pub const initThreads = XInitThreads;
extern fn XFilterEvent(event: *Event, window: Window) Bool;
pub const filterEvent = XFilterEvent;
extern fn XLookupString(event: *KeyEvent, buffer_return: [*]u8, bytes_buffer: c_int, keysym_return: ?*KeySym, status_return: ?*Status) c_int;
pub const lookupString = XLookupString;

extern fn Xutf8LookupString(ic: *IC, event: *KeyEvent, buffer_return: [*]u8, bytes_buffer: c_int, keysym_return: ?*KeySym, status_return: ?*Status) c_int;
pub const utf8LookupString = Xutf8LookupString;
extern fn XOpenIM(display: *Display, db: ?*XrmDatabase, res_name: ?[*:0]u8, res_class: ?[*:0]u8) ?*IM;
pub const openIM = XOpenIM;
extern fn XCloseIM(im: *IM) Status;
pub const closeIM = XCloseIM;
extern fn XCreateIC(im: *IM, ...) ?*IC;
pub const createIC = XCreateIC;
extern fn XDestroyIC(ic: *IC) void;
pub const destroyIC = XDestroyIC;
