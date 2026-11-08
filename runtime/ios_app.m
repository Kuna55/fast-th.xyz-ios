/* ios_app.m -- the iOS app around the port: the application and scene
 * delegates, and the start of boot.c's main (built with -Dmain=nfsu2_main).
 *
 * iOS owns main(): ios/main.m calls UIApplicationMain with these classes.
 * The game's main is started from a run-loop timer once the first scene is
 * connected (performSelector:afterDelay:0, never a main-queue block, see
 * ios_pump in metal.m) and runs the Mac's frame loop on the main thread from
 * there on.  One game per process: a second scene (an iPad window) gets only
 * a black window.
 *
 * Messages for the player (no game folder, a wrong SPEED2.EXE) are alerts,
 * one after the other (ios_app_message, from bundle.m). */
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <stdlib.h>

int  nfsu2_main(int argc, char **argv);          /* tests/boot.c */
long metal_frames(void);
void metal_ios_attach_scene(UIWindowScene *s);    /* metal.m */
void metal_ios_active(int on);
void metal_ios_background(int bg);

static int g_started;
static UIWindow *g_first_window;                  /* the first scene's placeholder: alerts show on it */

/* ---- alerts ------------------------------------------------------------- */
static NSMutableArray<NSArray<NSString *> *> *g_msgs;
static int g_msg_up;
static UIViewController *top_vc(void){
    UIWindow *w = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes){
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *x in ((UIWindowScene *)s).windows) if (x.isKeyWindow){ w = x; break; }
        if (w) break;
    }
    if (!w) w = g_first_window;
    UIViewController *vc = w.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}
static void msg_next(void){
    if (g_msg_up || !g_msgs.count) return;
    UIViewController *vc = top_vc();
    if (!vc) return;
    NSArray<NSString *> *m = g_msgs.firstObject;
    [g_msgs removeObjectAtIndex:0];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:m[0] message:m[1]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *x){ (void)x; g_msg_up = 0; msg_next(); }]];
    g_msg_up = 1;
    [vc presentViewController:a animated:YES completion:nil];
}
void ios_app_message(const char *title, const char *msg){
    NSString *t = @(title ? title : ""), *m = @(msg ? msg : "");
    void (^show)(void) = ^{
        if (!g_msgs) g_msgs = [NSMutableArray array];
        [g_msgs addObject:@[ t, m ]];
        msg_next();
    };
    if ([NSThread isMainThread]) show(); else dispatch_async(dispatch_get_main_queue(), show);
}

/* ---- scene ---------------------------------------------------------------- */
@interface NfsuSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation NfsuSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)opts {
    (void)session; (void)opts;
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    UIWindowScene *ws = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:ws];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor blackColor];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    if (g_started) return;
    g_started = 1;
    g_first_window = self.window;
    metal_ios_attach_scene(ws);
    [self performSelector:@selector(startGame) withObject:nil afterDelay:0.0];
}
- (void)startGame {
    static char arg0[] = "NFSU2";
    static char *argv[] = { arg0, NULL };
    int r = nfsu2_main(1, argv);
    if (metal_frames() > 0){
        /* the game was played and quit itself (Quit Game): the app ends too */
        fprintf(stderr, "app: the game ended (%d)\n", r);
        exit(r);
    }
    /* it never started (no game folder): stay, with the alert telling why */
    fprintf(stderr, "app: the game did not start (%d)\n", r);
    msg_next();
}
- (void)sceneDidBecomeActive:(UIScene *)s     { (void)s; metal_ios_active(1); }
- (void)sceneWillResignActive:(UIScene *)s    { (void)s; metal_ios_active(0); }
- (void)sceneDidEnterBackground:(UIScene *)s  { (void)s; metal_ios_background(1); }
- (void)sceneWillEnterForeground:(UIScene *)s { (void)s; metal_ios_background(0); }
@end

/* ---- application ------------------------------------------------------------- */
@interface NfsuAppDelegate : UIResponder <UIApplicationDelegate> @end
@implementation NfsuAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    (void)app; (void)opts;
    return YES;
}
- (UISceneConfiguration *)application:(UIApplication *)app
    configurationForConnectingSceneSession:(UISceneSession *)session
                                   options:(UISceneConnectionOptions *)opts {
    (void)app; (void)opts;
    UISceneConfiguration *c = [[UISceneConfiguration alloc] initWithName:@"Game" sessionRole:session.role];
    c.delegateClass = [NfsuSceneDelegate class];
    return c;
}
@end

/* ios/main.m's entry: the delegate class by name keeps this file's classes
 * linked (with -ObjC as well) */
int nfsu2_ios_run(int argc, char **argv){
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([NfsuAppDelegate class]));
    }
}
