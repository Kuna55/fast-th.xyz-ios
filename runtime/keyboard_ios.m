/* keyboard_ios.m -- a hardware keyboard on iOS (an iPad's Magic Keyboard, a
 * Bluetooth one): GameController's GCKeyboard -> the game's DirectInput key
 * state and Win32 keyboard messages, the way keyboard_mac.m does on the Mac.
 *
 * GCKeyboard reports keys by position (USB HID usage), which maps straight to
 * DirectInput scan codes (DIK, also positions).  The Win32 messages carry a
 * US layout: WM_KEYDOWN/WM_KEYUP with the virtual-key code and the scan code
 * in lParam, and WM_CHAR for the keys that type something (Shift and Caps
 * Lock applied), enough for the profile name and the menus.  GCKeyboard
 * sends no autorepeat.  The autotest's ns* commands (kbdmac_synth_*) have no
 * iOS path: the scripts run on the Mac and in the browser.
 *
 * Without a keyboard the screen is the input: metal.m (touch) and the
 * on-screen controller. */
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <stdio.h>
#include <string.h>
#include "kbd.h"

#define WM_KEYDOWN 0x0100u
#define WM_KEYUP   0x0101u
#define WM_CHAR    0x0102u
void kbdmac_release_all(const char *why);

/* HID usage (keyboard page) -> DIK, Windows VK, US characters (plain, shifted) */
typedef struct { uint8_t dik, vk; char ch, sh; } KeyMap;
static KeyMap g_map[256];
static void km(unsigned hid, unsigned dik, unsigned vk, char ch, char sh){
    g_map[hid] = (KeyMap){ (uint8_t)dik, (uint8_t)vk, ch, sh };
}
static void map_init(void){
    static const uint8_t letters[26] = { 0x1E,0x30,0x2E,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,
                                         0x31,0x18,0x19,0x10,0x13,0x1F,0x14,0x16,0x2F,0x11,0x2D,0x15,0x2C };
    for (int i = 0; i < 26; i++) km(0x04 + i, letters[i], 'A' + i, (char)('a' + i), (char)('A' + i));
    static const char shd[10] = { '!','@','#','$','%','^','&','*','(',')' };
    for (int i = 0; i < 9; i++) km(0x1E + i, 0x02 + i, '1' + i, (char)('1' + i), shd[i]);
    km(0x27, 0x0B, '0', '0', ')');
    km(0x28, 0x1C, 0x0D, '\r', '\r');   km(0x29, 0x01, 0x1B, 0x1B, 0x1B);
    km(0x2A, 0x0E, 0x08, 0x08, 0x08);   km(0x2B, 0x0F, 0x09, '\t', '\t');
    km(0x2C, 0x39, 0x20, ' ', ' ');     km(0x2D, 0x0C, 0xBD, '-', '_');
    km(0x2E, 0x0D, 0xBB, '=', '+');     km(0x2F, 0x1A, 0xDB, '[', '{');
    km(0x30, 0x1B, 0xDD, ']', '}');     km(0x31, 0x2B, 0xDC, '\\', '|');
    km(0x33, 0x27, 0xBA, ';', ':');     km(0x34, 0x28, 0xDE, '\'', '"');
    km(0x35, 0x29, 0xC0, '`', '~');     km(0x36, 0x33, 0xBC, ',', '<');
    km(0x37, 0x34, 0xBE, '.', '>');     km(0x38, 0x35, 0xBF, '/', '?');
    km(0x39, 0x3A, 0x14, 0, 0);                                      /* Caps Lock */
    for (int i = 0; i < 10; i++) km(0x3A + i, 0x3B + i, 0x70 + i, 0, 0);   /* F1-F10 */
    km(0x44, 0x57, 0x7A, 0, 0);         km(0x45, 0x58, 0x7B, 0, 0);  /* F11, F12 */
    km(0x46, 0xB7, 0x2C, 0, 0);         km(0x47, 0x46, 0x91, 0, 0);  /* Print Screen, Scroll Lock */
    km(0x48, 0xC5, 0x13, 0, 0);         km(0x49, 0xD2, 0x2D, 0, 0);  /* Pause, Insert */
    km(0x4A, 0xC7, 0x24, 0, 0);         km(0x4B, 0xC9, 0x21, 0, 0);  /* Home, Page Up */
    km(0x4C, 0xD3, 0x2E, 0x7F, 0x7F);   km(0x4D, 0xCF, 0x23, 0, 0);  /* Delete, End */
    km(0x4E, 0xD1, 0x22, 0, 0);         km(0x4F, 0xCD, 0x27, 0, 0);  /* Page Down, Right */
    km(0x50, 0xCB, 0x25, 0, 0);         km(0x51, 0xD0, 0x28, 0, 0);  /* Left, Down */
    km(0x52, 0xC8, 0x26, 0, 0);         km(0x53, 0x45, 0x90, 0, 0);  /* Up, Num Lock */
    km(0x54, 0xB5, 0x6F, '/', '/');     km(0x55, 0x37, 0x6A, '*', '*');
    km(0x56, 0x4A, 0x6D, '-', '-');     km(0x57, 0x4E, 0x6B, '+', '+');
    km(0x58, 0x9C, 0x0D, '\r', '\r');                                /* keypad Enter */
    static const uint8_t kp[9] = { 0x4F,0x50,0x51,0x4B,0x4C,0x4D,0x47,0x48,0x49 };
    for (int i = 0; i < 9; i++) km(0x59 + i, kp[i], 0x61 + i, (char)('1' + i), (char)('1' + i));
    km(0x62, 0x52, 0x60, '0', '0');     km(0x63, 0x53, 0x6E, '.', '.');
    km(0x64, 0x56, 0xE2, '\\', '|');                                 /* the ISO key left of Z */
    km(0xE0, 0x1D, 0x11, 0, 0);         km(0xE1, 0x2A, 0x10, 0, 0);  /* left Control, Shift */
    km(0xE2, 0x38, 0x12, 0, 0);         km(0xE3, 0xDB, 0x5B, 0, 0);  /* left Alt (Option), Command */
    km(0xE4, 0x9D, 0x11, 0, 0);         km(0xE5, 0x36, 0x10, 0, 0);  /* right Control, Shift */
    km(0xE6, 0xB8, 0x12, 0, 0);         km(0xE7, 0xDC, 0x5C, 0, 0);  /* right Alt, Command */
}

static uint8_t g_held[256];          /* by HID usage: down as far as the game knows */
static int g_shift, g_caps;
static uint32_t lparam(unsigned dik, int up){
    return 1u | (uint32_t)(dik & 0x7Fu) << 16 | (dik & 0x80u ? 1u << 24 : 0u) | (up ? 3u << 30 : 0u);
}
static void key(unsigned hid, int down){
    if (hid > 255) return;
    const KeyMap *m = &g_map[hid];
    if (!m->dik) return;
    if (!!g_held[hid] == !!down) return;
    g_held[hid] = (uint8_t)down;
    if (hid == 0xE1 || hid == 0xE5) g_shift = g_held[0xE1] || g_held[0xE5];
    if (hid == 0x39 && down) g_caps = !g_caps;
    kbd_set_key(KSRC_HOST, m->dik, down);
    kbd_post(down ? WM_KEYDOWN : WM_KEYUP, m->vk, lparam(m->dik, !down));
    if (down && m->ch){
        char c = g_shift ? m->sh : m->ch;
        if (g_caps && hid >= 0x04 && hid <= 0x1D) c = g_shift ? m->ch : m->sh;   /* Caps Lock: letters only */
        kbd_post(WM_CHAR, (uint8_t)c, lparam(m->dik, 0));
    }
    if (kbd_log()) fprintf(stderr, "[kbd] ios key 0x%02x -> DIK 0x%02x %s\n", hid, m->dik, down ? "down" : "up");
}

static void attach(GCKeyboard *k){
    if (!k) return;
    k.keyboardInput.keyChangedHandler = ^(GCKeyboardInput *in, GCControllerButtonInput *b, GCKeyCode code, BOOL pressed){
        (void)in; (void)b; key((unsigned)code, pressed ? 1 : 0); };
    fprintf(stderr, "[kbd] keyboard connected: %s\n", k.vendorName ? k.vendorName.UTF8String : "?");
}
static void ios_keyboard_init(void){
    static int done;
    if (done) return;
    done = 1;
    map_init();
    attach(GCKeyboard.coalescedKeyboard);
    [[NSNotificationCenter defaultCenter] addObserverForName:GCKeyboardDidConnectNotification object:nil
        queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n){ attach(n.object); }];
    [[NSNotificationCenter defaultCenter] addObserverForName:GCKeyboardDidDisconnectNotification object:nil
        queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n){ (void)n; kbdmac_release_all("keyboard disconnected"); }];
}

/* ---- the keyboard_mac.m interface the rest of the runtime calls ------------ */
/* main thread, every turn of the frame loop: starts listening on first use */
void kbdmac_tick(void){ ios_keyboard_init(); }
void kbdmac_release_all(const char *why){
    int any = 0;
    for (unsigned h = 0; h < 256; h++) if (g_held[h]){ key(h, 0); any = 1; }
    kbd_release_source(KSRC_HOST);
    if (any) fprintf(stderr, "[kbd] all keys released (%s)\n", why);
}
const char *kbdmac_layout_name(unsigned dik){ (void)dik; return 0; }   /* dikeys.c's US names */
int  kbdmac_synth_key(int type, const char *k){ (void)type; (void)k; return 0; }
int  kbdmac_synth_char(int type, uint32_t u){ (void)type; (void)u; return 0; }
void kbdmac_synth_simple(int type, double a, double b){ (void)type; (void)a; (void)b; }
