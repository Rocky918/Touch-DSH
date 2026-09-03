#import "TouchBarPrivate.h"
#import <dlfcn.h>
#import <objc/message.h>

typedef void (*SetPresenceFn)(NSString *, BOOL);
typedef void (*SetCloseBoxFn)(BOOL);

static void *DFRHandle(void) {
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

BOOL TBPrivateAvailable(void) {
    return DFRHandle() != NULL && NSClassFromString(@"NSTouchBar") != Nil;
}

void TBAddSystemTrayItem(NSTouchBarItem *item) {
    Class cls = NSClassFromString(@"NSTouchBarItem");
    SEL sel = NSSelectorFromString(@"addSystemTrayItem:");
    if ([cls respondsToSelector:sel]) ((void (*)(id, SEL, id))objc_msgSend)(cls, sel, item);
}

void TBSetControlStripPresence(NSTouchBarItemIdentifier identifier, BOOL present) {
    SetPresenceFn fn = (SetPresenceFn)dlsym(DFRHandle(), "DFRElementSetControlStripPresenceForIdentifier");
    if (fn) fn(identifier, present);
}

void TBSetShowsCloseBox(BOOL show) {
    SetCloseBoxFn fn = (SetCloseBoxFn)dlsym(DFRHandle(), "DFRSystemModalShowsCloseBoxWhenFrontMost");
    if (fn) fn(show);
}

BOOL TBPresentSystemModal(NSTouchBar *touchBar, NSTouchBarItemIdentifier identifier) {
    Class cls = NSClassFromString(@"NSTouchBar");
    SEL modernPlacement = NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:");
    SEL legacyPlacement = NSSelectorFromString(@"presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:");
    SEL modern = NSSelectorFromString(@"presentSystemModalTouchBar:systemTrayItemIdentifier:");
    SEL legacy = NSSelectorFromString(@"presentSystemModalFunctionBar:systemTrayItemIdentifier:");

    if ([cls respondsToSelector:modernPlacement]) {
        ((void (*)(id, SEL, id, long long, id))objc_msgSend)(cls, modernPlacement, touchBar, 1, identifier);
        return YES;
    }
    if ([cls respondsToSelector:legacyPlacement]) {
        ((void (*)(id, SEL, id, long long, id))objc_msgSend)(cls, legacyPlacement, touchBar, 1, identifier);
        return YES;
    }
    if ([cls respondsToSelector:modern]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(cls, modern, touchBar, identifier);
        return YES;
    }
    if ([cls respondsToSelector:legacy]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(cls, legacy, touchBar, identifier);
        return YES;
    }
    return NO;
}

void TBMinimizeSystemModal(NSTouchBar *touchBar) {
    Class cls = NSClassFromString(@"NSTouchBar");
    SEL modern = NSSelectorFromString(@"minimizeSystemModalTouchBar:");
    SEL legacy = NSSelectorFromString(@"minimizeSystemModalFunctionBar:");
    SEL sel = [cls respondsToSelector:modern] ? modern : legacy;
    if ([cls respondsToSelector:sel]) ((void (*)(id, SEL, id))objc_msgSend)(cls, sel, touchBar);
}
