#import "include/TangoDisplayObjC.h"

BOOL TDTryAudioEngineConnect(AVAudioEngine *engine,
                              AVAudioNode   *source,
                              AVAudioNode   *destination,
                              AVAudioFormat *format,
                              NSString     **outReason) {
    @try {
        [engine connect:source to:destination format:format];
        return YES;
    } @catch (NSException *ex) {
        if (outReason) *outReason = ex.reason ?: ex.name;
        return NO;
    }
}
