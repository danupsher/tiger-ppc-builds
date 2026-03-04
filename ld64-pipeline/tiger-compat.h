/* tiger-compat.h — Compatibility typedefs for Mac OS X 10.4 Tiger SDK.
 * Force-included via -include in CFLAGS/CXXFLAGS to provide types and
 * constants introduced in 10.5+ that the codebase expects. */

#ifndef TIGER_COMPAT_H
#define TIGER_COMPAT_H

#include <AvailabilityMacros.h>
#include <stdint.h>

#if !defined(MAC_OS_X_VERSION_10_5) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5

/* CGFloat: float on 32-bit, double on 64-bit.  Tiger PPC is always 32-bit. */
#ifndef CGFLOAT_DEFINED
#define CGFLOAT_DEFINED 1
#if defined(__LP64__) && __LP64__
typedef double CGFloat;
#define CGFLOAT_MIN DBL_MIN
#define CGFLOAT_MAX DBL_MAX
#define CGFLOAT_IS_DOUBLE 1
#else
typedef float CGFloat;
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#define CGFLOAT_IS_DOUBLE 0
#endif
#endif /* CGFLOAT_DEFINED */

/* NSInteger / NSUInteger: sized to pointer width. */
#ifndef NSINTEGER_DEFINED
#define NSINTEGER_DEFINED 1
#if defined(__LP64__) && __LP64__
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#endif /* NSINTEGER_DEFINED */

/* NSSpeechSynthesizer boundary constants (10.5+) */
#ifndef NSSpeechImmediateBoundary
enum {
    NSSpeechImmediateBoundary = 0,
    NSSpeechWordBoundary = 1,
    NSSpeechSentenceBoundary = 2
};
#endif

/* CGBlendMode extras (10.5+).  Tiger ends at kCGBlendModeLuminosity = 15.
   Use #define with casts so the values match the CGBlendMode enum type
   (Tiger typedef's CGBlendMode from a named enum). */
#ifndef kCGBlendModeClear
#define kCGBlendModeClear           ((CGBlendMode)16)
#define kCGBlendModeCopy            ((CGBlendMode)17)
#define kCGBlendModeSourceIn        ((CGBlendMode)18)
#define kCGBlendModeSourceOut       ((CGBlendMode)19)
#define kCGBlendModeSourceAtop      ((CGBlendMode)20)
#define kCGBlendModeDestinationOver ((CGBlendMode)21)
#define kCGBlendModeDestinationIn   ((CGBlendMode)22)
#define kCGBlendModeDestinationOut  ((CGBlendMode)23)
#define kCGBlendModeDestinationAtop ((CGBlendMode)24)
#define kCGBlendModeXOR             ((CGBlendMode)25)
#define kCGBlendModePlusDarker      ((CGBlendMode)26)
#define kCGBlendModePlusLighter     ((CGBlendMode)27)
#endif

/* Virtual key codes (10.5+ Carbon/HIToolbox/Events.h) */
#ifndef kVK_UpArrow
enum {
    kVK_ANSI_A    = 0x00,
    kVK_ANSI_S    = 0x01,
    kVK_ANSI_D    = 0x02,
    kVK_ANSI_F    = 0x03,
    kVK_ANSI_H    = 0x04,
    kVK_ANSI_G    = 0x05,
    kVK_ANSI_Z    = 0x06,
    kVK_ANSI_X    = 0x07,
    kVK_ANSI_C    = 0x08,
    kVK_ANSI_V    = 0x09,
    kVK_ANSI_B    = 0x0B,
    kVK_ANSI_Q    = 0x0C,
    kVK_ANSI_W    = 0x0D,
    kVK_ANSI_E    = 0x0E,
    kVK_ANSI_R    = 0x0F,
    kVK_ANSI_Y    = 0x10,
    kVK_ANSI_T    = 0x11,
    kVK_ANSI_1    = 0x12,
    kVK_ANSI_2    = 0x13,
    kVK_ANSI_3    = 0x14,
    kVK_ANSI_4    = 0x15,
    kVK_ANSI_6    = 0x16,
    kVK_ANSI_5    = 0x17,
    kVK_ANSI_Equal = 0x18,
    kVK_ANSI_9    = 0x19,
    kVK_ANSI_7    = 0x1A,
    kVK_ANSI_Minus = 0x1B,
    kVK_ANSI_8    = 0x1C,
    kVK_ANSI_0    = 0x1D,
    kVK_ANSI_RightBracket = 0x1E,
    kVK_ANSI_O    = 0x1F,
    kVK_ANSI_U    = 0x20,
    kVK_ANSI_LeftBracket = 0x21,
    kVK_ANSI_I    = 0x22,
    kVK_ANSI_P    = 0x23,
    kVK_Return    = 0x24,
    kVK_ANSI_L    = 0x25,
    kVK_ANSI_J    = 0x26,
    kVK_ANSI_Quote = 0x27,
    kVK_ANSI_K    = 0x28,
    kVK_ANSI_Semicolon = 0x29,
    kVK_ANSI_Backslash = 0x2A,
    kVK_ANSI_Comma = 0x2B,
    kVK_ANSI_Slash = 0x2C,
    kVK_ANSI_N    = 0x2D,
    kVK_ANSI_M    = 0x2E,
    kVK_ANSI_Period = 0x2F,
    kVK_Tab       = 0x30,
    kVK_Space     = 0x31,
    kVK_ISO_Section = 0x0A,
    kVK_ANSI_Grave = 0x32,
    kVK_Delete    = 0x33,
    kVK_Escape    = 0x35,
    /* kVK_RightCommand (0x36) defined in TextInputHandler.h namespace */
    kVK_Command   = 0x37,
    kVK_Shift     = 0x38,
    kVK_CapsLock  = 0x39,
    kVK_Option    = 0x3A,
    kVK_Control   = 0x3B,
    kVK_RightShift = 0x3C,
    kVK_RightOption = 0x3D,
    kVK_RightControl = 0x3E,
    kVK_Function  = 0x3F,
    kVK_F17       = 0x40,
    kVK_ANSI_KeypadDecimal = 0x41,
    kVK_ANSI_KeypadMultiply = 0x43,
    kVK_ANSI_KeypadPlus = 0x45,
    kVK_ANSI_KeypadClear = 0x47,
    kVK_VolumeUp  = 0x48,
    kVK_VolumeDown = 0x49,
    kVK_Mute      = 0x4A,
    kVK_ANSI_KeypadDivide = 0x4B,
    kVK_ANSI_KeypadEnter = 0x4C,
    kVK_ANSI_KeypadMinus = 0x4E,
    kVK_F18       = 0x4F,
    kVK_F19       = 0x50,
    kVK_ANSI_KeypadEquals = 0x51,
    kVK_ANSI_Keypad0 = 0x52,
    kVK_ANSI_Keypad1 = 0x53,
    kVK_ANSI_Keypad2 = 0x54,
    kVK_ANSI_Keypad3 = 0x55,
    kVK_ANSI_Keypad4 = 0x56,
    kVK_ANSI_Keypad5 = 0x57,
    kVK_ANSI_Keypad6 = 0x58,
    kVK_ANSI_Keypad7 = 0x59,
    kVK_F20       = 0x5A,
    kVK_ANSI_Keypad8 = 0x5B,
    kVK_ANSI_Keypad9 = 0x5C,
    kVK_F5        = 0x60,
    kVK_F6        = 0x61,
    kVK_F7        = 0x62,
    kVK_F3        = 0x63,
    kVK_F8        = 0x64,
    kVK_F9        = 0x65,
    kVK_F11       = 0x67,
    kVK_F13       = 0x69,
    kVK_F16       = 0x6A,
    kVK_F14       = 0x6B,
    kVK_F10       = 0x6D,
    kVK_F12       = 0x6F,
    kVK_F15       = 0x71,
    kVK_Help      = 0x72,
    kVK_Home      = 0x73,
    kVK_PageUp    = 0x74,
    kVK_ForwardDelete = 0x75,
    kVK_F4        = 0x76,
    kVK_End       = 0x77,
    kVK_F2        = 0x78,
    kVK_PageDown  = 0x79,
    kVK_F1        = 0x7A,
    kVK_LeftArrow = 0x7B,
    kVK_RightArrow= 0x7C,
    kVK_DownArrow = 0x7D,
    kVK_UpArrow   = 0x7E,
    /* JIS keyboard keys */
    kVK_JIS_Yen           = 0x5D,
    kVK_JIS_Underscore    = 0x5E,
    kVK_JIS_KeypadComma   = 0x5F,
    kVK_JIS_Eisu          = 0x66,
    kVK_JIS_Kana          = 0x68
};
#endif

/* Core Text (10.5+).  Provide opaque types so code compiles;
   actual CT calls are stubbed in tiger-cg-compat.h or runtime-checked. */
#ifndef CTFONT_H_
typedef const struct __CTFont *CTFontRef;
typedef uint32_t CTFontOrientation;
enum { kCTFontDefaultOrientation = 0 };
#endif
typedef const struct __CTRun *CTRunRef;
typedef const struct __CTLine *CTLineRef;
typedef const struct __CTFontDescriptor *CTFontDescriptorRef;
typedef const struct __CTTypesetter *CTTypesetterRef;

/* CTFont symbolic trait type — used in gfxCoreTextShaper */
typedef uint32_t CTFontSymbolicTraits;
enum {
    kCTFontTraitItalic = (1 << 0),
    kCTFontTraitBold   = (1 << 1)
};


/* CGGradient stubs (10.5+).  CGGradient doesn't exist on Tiger.
   Provide opaque type and no-op stubs; code using gradients will
   just not draw them (graceful degradation). */
#ifndef CGGRADIENT_H_
typedef const struct CGGradient *CGGradientRef;
#define CGGradientCreateWithColorComponents(space, comps, locs, cnt) ((CGGradientRef)0)
#define CGGradientCreateWithColors(space, colors, locs) ((CGGradientRef)0)
#define CGGradientRelease(gradient) ((void)0)
/* CGContextDrawLinearGradient and CGContextDrawRadialGradient are 10.5+ functions.
   Provide as no-op macros. */
enum { kCGGradientDrawsBeforeStartLocation = (1 << 0), kCGGradientDrawsAfterEndLocation = (1 << 1) };
#define CGContextDrawLinearGradient(ctx, gradient, start, end, opts) ((void)0)
#define CGContextDrawRadialGradient(ctx, gradient, sc, sr, ec, er, opts) ((void)0)
#endif

/* NSWindowCollectionBehavior (10.5+) */
#ifndef NSWindowCollectionBehaviorDefault
typedef NSUInteger NSWindowCollectionBehavior;
enum {
    NSWindowCollectionBehaviorDefault = 0,
    NSWindowCollectionBehaviorCanJoinAllSpaces = (1 << 0),
    NSWindowCollectionBehaviorMoveToActiveSpace = (1 << 1)
};
/* Note: NSWindowCollectionBehaviorFullScreenPrimary is defined in nsCocoaWindow.h */
#endif

/* NSTrackingAreaOptions (10.5+) */
#ifndef NSTrackingMouseEnteredAndExited
typedef NSUInteger NSTrackingAreaOptions;
enum {
    NSTrackingMouseEnteredAndExited = 0x01,
    NSTrackingMouseMoved           = 0x02,
    NSTrackingCursorUpdate         = 0x04,
    NSTrackingActiveWhenFirstResponder = 0x10,
    NSTrackingActiveInKeyWindow    = 0x20,
    NSTrackingActiveInActiveApp    = 0x40,
    NSTrackingActiveAlways         = 0x80,
    NSTrackingAssumeInside         = 0x100,
    NSTrackingInVisibleRect        = 0x200,
    NSTrackingEnabledDuringMouseDrag = 0x400
};
#endif

/* NSOpenGLPFAAllowOfflineRenderers (10.5+) */
#ifndef NSOpenGLPFAAllowOfflineRenderers
#define NSOpenGLPFAAllowOfflineRenderers ((NSOpenGLPixelFormatAttribute)96)
#endif

/* kEventMouseScroll — Carbon scroll event kind.
   Should be in CarbonEvents.h but may be missing in some SDK versions. */
#ifndef kEventMouseScroll
#define kEventMouseScroll 11
#endif

/* class_getMethodImplementation (ObjC 2.0 runtime, 10.5+).
   On Tiger, get the IMP from the Method struct directly. */
#ifdef __OBJC__
#include <objc/objc-runtime.h>
static inline IMP class_getMethodImplementation(Class cls, SEL name) {
    Method m = class_getInstanceMethod(cls, name);
    return m ? m->method_imp : (IMP)0;
}
#endif

/* NS<->CG geometry conversion inlines (10.5+) */
#ifdef __OBJC__
#import <Foundation/NSGeometry.h>
#include <ApplicationServices/ApplicationServices.h>

/* Empty protocol stubs for 10.5+ ObjC APIs */
@protocol NSTextInputClient @end
@protocol NSPrintPanelAccessorizing @end

/* Forward declarations for 10.5+ classes used as pointer types */
@class NSTrackingArea;
@class NSDockTile;
@class NSViewController;

/* NSPrintPanel constants (10.5+) */
#ifndef NSPrintPanelShowsCopies
enum {
    NSPrintPanelShowsCopies = 0x01,
    NSPrintPanelShowsPageRange = 0x02,
    NSPrintPanelShowsPaperSize = 0x04,
    NSPrintPanelShowsOrientation = 0x08,
    NSPrintPanelShowsScaling = 0x10
};
#endif

#ifndef NSPrintPanelAccessorySummaryItemNameKey
#define NSPrintPanelAccessorySummaryItemNameKey @"name"
#define NSPrintPanelAccessorySummaryItemDescriptionKey @"description"
#endif

#ifndef NSGEOMETRY_TYPES_SAME_AS_CGGEOMETRY_TYPES

static inline CGPoint NSPointToCGPoint(NSPoint p) {
    return *(CGPoint*)&p;
}
static inline NSPoint NSPointFromCGPoint(CGPoint p) {
    return *(NSPoint*)&p;
}
static inline CGSize NSSizeToCGSize(NSSize s) {
    return *(CGSize*)&s;
}
static inline NSSize NSSizeFromCGSize(CGSize s) {
    return *(NSSize*)&s;
}
static inline CGRect NSRectToCGRect(NSRect r) {
    return *(CGRect*)&r;
}
static inline NSRect NSRectFromCGRect(CGRect r) {
    return *(NSRect*)&r;
}

#endif /* !NSGEOMETRY_TYPES_SAME_AS_CGGEOMETRY_TYPES */
#endif /* __OBJC__ */

/* CGEvent scroll wheel (10.5+).  Tiger SDK has CGEventRef/CGEventSourceRef
   types but NOT CGEventCreateScrollWheelEvent or CGScrollEventUnit.
   Provide the missing enum/function.  Use a macro for the function stub
   to avoid typedef conflicts with Tiger's existing CGEventRef. */
#ifndef kCGScrollEventUnitPixel
typedef uint32_t CGScrollEventUnit;
enum {
    kCGScrollEventUnitPixel = 0,
    kCGScrollEventUnitLine = 1
};
/* Stub: returns NULL so callers handle gracefully (e.g. nsChildView.mm). */
#define CGEventCreateScrollWheelEvent(source, units, wheelCount, ...) ((CGEventRef)0)
#endif /* kCGScrollEventUnitPixel */


#endif /* pre-10.5 */

/* Tiger lacks memmem() */
#ifdef __cplusplus
extern "C" {
#endif
#include <string.h>
#ifndef TIGER_COMPAT_MEMMEM
#define TIGER_COMPAT_MEMMEM
static __inline__ void *memmem(const void *haystack, size_t haystacklen,
                           const void *needle, size_t needlelen) {
    if (needlelen == 0) return (void *)haystack;
    if (needlelen > haystacklen) return (void *)0;
    const char *h = (const char *)haystack;
    const char *end = h + haystacklen - needlelen;
    for (; h <= end; h++) {
        if (__builtin_memcmp(h, needle, needlelen) == 0)
            return (void *)h;
    }
    return (void *)0;
}
#endif
#ifdef __cplusplus
}
#endif

/* Tiger has arc4random() but not arc4random_buf() — declared here,
   implemented in libtiger_runtime.a */
#ifdef __cplusplus
extern "C"
#endif
void arc4random_buf(void *buf, size_t nbytes);


/* strndup, posix_memalign, memalign -- exist in Tiger libc but
   not declared in SDK headers. Add declarations so code compiles. */
#ifdef __cplusplus
extern "C" {
#endif
char *strndup(const char *, size_t);
int posix_memalign(void **, size_t, size_t);
void *memalign(size_t, size_t);
#ifdef __cplusplus
}
#endif


#ifdef HAVE___SINCOS
#undef HAVE___SINCOS
#endif
#ifdef HAVE_SINCOS
#undef HAVE_SINCOS
#endif
#ifdef HAVE_PTHREAD_GETNAME_NP
#undef HAVE_PTHREAD_GETNAME_NP
#endif
#ifdef HAVE_GETC_UNLOCKED
#undef HAVE_GETC_UNLOCKED
#endif
#ifdef HAVE__GETC_NOLOCK
#undef HAVE__GETC_NOLOCK
#endif

#ifdef HAVE_SYS_STATVFS_H
#undef HAVE_SYS_STATVFS_H
#endif
#ifdef HAVE_STATVFS64
#undef HAVE_STATVFS64
#endif
#ifdef HAVE_STATVFS
#undef HAVE_STATVFS
#endif
#ifdef HAVE_TRUNCATE64
#undef HAVE_TRUNCATE64
#endif
#ifdef HAVE_STAT64
#undef HAVE_STAT64
#endif
#ifdef HAVE_LSTAT64
#undef HAVE_LSTAT64
#endif
#ifdef HAVE_SYSCALL
#undef HAVE_SYSCALL
#endif
/* Cross-compile configure detects Linux host functions that do not exist
   on Tiger. Undefine them so code falls back to portable paths. */
#ifdef HAVE_POSIX_FALLOCATE
#undef HAVE_POSIX_FALLOCATE
#endif
#ifdef HAVE_POSIX_FADVISE
#undef HAVE_POSIX_FADVISE
#endif
#ifdef HAVE_MALLINFO
#undef HAVE_MALLINFO
#endif
#ifdef HAVE_GETTID
#undef HAVE_GETTID
#endif
#ifdef HAVE_MALLOC_H
#undef HAVE_MALLOC_H
#endif
#ifdef HAVE_MALLOC_USABLE_SIZE
#undef HAVE_MALLOC_USABLE_SIZE
#endif
#ifdef MALLOC_H
#undef MALLOC_H
#endif

#endif /* TIGER_COMPAT_H */
/* Tiger 10.4 cannot draw in the titlebar — disable this feature.
   Without this, traffic light (close/minimize/zoom) buttons are hidden. */
#ifdef MOZ_CAN_DRAW_IN_TITLEBAR
#undef MOZ_CAN_DRAW_IN_TITLEBAR
#endif
