#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

BOOL TBPrivateAvailable(void);
void TBAddSystemTrayItem(NSTouchBarItem *item);
void TBSetControlStripPresence(NSTouchBarItemIdentifier identifier, BOOL present);
void TBSetShowsCloseBox(BOOL show);
BOOL TBPresentSystemModal(NSTouchBar *touchBar, NSTouchBarItemIdentifier identifier);
void TBMinimizeSystemModal(NSTouchBar *touchBar);

NS_ASSUME_NONNULL_END
