//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//
#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol AGCApplicationDelegateObserver <NSObject>

@optional
#if TARGET_OS_IPHONE
- (void)didFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions;
- (BOOL)continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;
- (BOOL)openURL:(NSURL *)url options:(nullable NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;
#elif TARGET_OS_MAC
#endif

@end

@interface AGCApplicationDelegate : NSObject

+ (instancetype)sharedInstance;

- (void)addObserver:(id<AGCApplicationDelegateObserver>)observer;
- (void)removeObserver:(id<AGCApplicationDelegateObserver>)observer;

#if TARGET_OS_IPHONE
- (void)didFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions;
- (BOOL)continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;
- (BOOL)openURL:(NSURL *)url options:(nullable NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;
#elif TARGET_OS_MAC
#endif



@end

NS_ASSUME_NONNULL_END
