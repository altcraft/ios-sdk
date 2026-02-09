//
//  HiAnalytics.h
//  HiAnalytics
//
//  Created by cbg_bigdata on 2019/12/27.
//  Copyright © 2019 cbg_bigdata. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HAEventType.h"
#import "HAParamType.h"
#import "HAReportPolicy.h"
#import "HALogConfig.h"
#import "HAUserProfileType.h"

@interface HiAnalytics : NSObject

/// Initialize configuration.
+ (void)config;

/// Initialize configuration with route policy.
/// @param routePolicy routePolicy
+ (void)configWithRoutePolicy:(nonnull NSString *)routePolicy;

/// Set WXUnionId.
/// @param unionId WXUnionId
+ (void)setWXUnionId:(nullable NSString *)unionId;

/// Set WXOpenId.
/// @param openId WXOpenId
+ (void)setWXOpenId:(nullable NSString *)openId;

/// Set WXAppId.
/// @param appId WXAppId
+ (void)setWXAppId:(nullable NSString *)appId;

/// Configure report policies.
/// @param policies policies
+ (void)setReportPolicies:(nullable NSArray<HAReportPolicy *> *)policies;

/// Report custom events.
/// @param eventId Event ID, a string that contains a maximum of 256 characters excluding spaces and invisible characters. The value cannot be empty or set to the ID of an automatically collected event.
/// @param params Information carried in the event. The key value cannot contain spaces or invisible characters.
+ (void)onEvent:(nonnull NSString *)eventId setParams:(nonnull NSDictionary<NSString *, id> *)params;

/// Add default events  params
/// @param params Information carried in the event. The key value cannot contain spaces or invisible characters. Pass nil to clear params
+ (void)addDefaultEventParams:(nullable NSDictionary<NSString *, id> *)params;

/// User attribute values remain unchanged throughout the app's lifecycle and session. A maximum of 25 user attribute names are supported. If an attribute name is duplicate with an existing one, the attribute names needs to be changed.
/// @param name User attribute name, a string that contains a maximum of 256 characters excluding spaces and invisible characters. The value cannot be empty.
/// @param value Attribute value, a string that contains a maximum of 256 characters.
+ (void)setUserProfile:(nonnull NSString *)name setValue:(nullable NSString *)value;

/// Get predefined or custom user attributes.
/// @param preDefined Indicates whether to obtain predefined user attributes.
+ (nullable NSDictionary<NSString *, id> *)userProfiles:(BOOL)preDefined;

/// Enable event collection. No data will be collected when this function is disabled.
/// @param enabled Indicates whether to enable event collection. YES: enabled (default); NO: disabled.
+ (void)setAnalyticsEnabled:(BOOL)enabled;


/// Obtains the restriction status of  HiAnalytics.
+ (BOOL)isRestrictionEnabled;

/// Specifies whether to enable IDFA collection. Value true means to enable IDFA collection.
/// @param enabled Set enable status.true: enabled (default); false: disabled.
+ (void)setCollectAdsIdEnabled:(BOOL)enabled;

/// Sets the restriction status of HiAnalytics.
/// @param enabled The default value is false, which means that HUAWEI Analytics is enabled.
+ (void)setRestrictionEnabled:(BOOL)enabled;

/// Sets whether to disable data sharing.
/// @param enabled The default value is false, which means that data sharing is enabled.
+ (void)setRestrictionShared:(BOOL)enabled;

/// Checks whether data sharing is disabled.
+ (BOOL)isRestrictionShared;

///Obtain the app instance ID from AppGallery Connect.
+ (nonnull NSString *)AAID;

/// Set a user ID.When the setUserId API is called, if the old userId is not empty and is different from the new userId, a new session is generated. If you do not want to use setUserId to identify a user (for example, when a user signs out), set userId to NULL. User Id that identifies a subscriber. Analytics Kit uses this ID to associate user data. The use of userId must comply with related privacy regulations. Please declare how it is used in the privacy statement of your app.
/// @param userId User ID, a string that contains a maximum of 256 characters. The value cannot be empty.
+ (void)setUserId:(nullable NSString *)userId;

/// Set the session timeout interval. The app is running in the foreground. When the interval between two adjacent events exceeds the specified timeout interval, a new session is generated. The default value is 30 minutes.
/// @param milliseconds Session timeout interval, in milliseconds.
+ (void)setSessionDuration:(NSTimeInterval)milliseconds;

/// milliseconds Enter background refresh session interval, in milliseconds.
/// @param milliseconds milliseconds
+ (void)setMinActivitySession:(NSTimeInterval)milliseconds;

#if TARGET_OS_IPHONE

/// Set a device token. Device token is the device identifier by APNs
/// @param deviceToken NSData deviceToken
+ (void)setDeviceToken:(nonnull NSData *)deviceToken;

#endif

/// Delete all collected data in the local cache, including the cached data that fails to be sent.
+ (void)clearCachedData;

/// Report logs.
/// @param logConfig logConfig
/// @param content content
+ (void)writeLog:(nonnull HALogConfig *)logConfig setContent:(nonnull NSString *)content;

@end
  
