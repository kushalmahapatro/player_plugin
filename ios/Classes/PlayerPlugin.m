#import "PlayerPlugin.h"
#if __has_include(<player_plugin/player_plugin-Swift.h>)
#import <player_plugin/player_plugin-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "player_plugin-Swift.h"
#endif

@implementation PlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPlayerPlugin registerWithRegistrar:registrar];
}
@end
