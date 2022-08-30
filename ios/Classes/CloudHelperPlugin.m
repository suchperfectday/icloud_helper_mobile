#import "CloudHelperPlugin.h"
#if __has_include(<cloud_helper/cloud_helper-Swift.h>)
#import <cloud_helper/cloud_helper-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "cloud_helper-Swift.h"
#endif

@implementation CloudHelperPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCloudHelperPlugin registerWithRegistrar:registrar];
}
@end
