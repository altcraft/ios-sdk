//
//  HAReportPolicy.h
//  HiAnalytics
//
//  Created by  epro123 on 2020/8/14.
//  Copyright © 2020 cbg_bigdata. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HAReportPolicy : NSObject
/// Event reporting at scheduled time.
/// @param seconds Scheduled time interval, in seconds (value range: 60 to 1800).
+ (HAReportPolicy *)onScheduledTimePolicy:(NSInteger)seconds;

/// Event reporting on app launch.
+ (HAReportPolicy *)onAppLaunchPolicy;

/// Event reporting when the app moves to the background (enabled by default).
+ (HAReportPolicy *)onMoveBackgroundPolicy;

/// Event reporting when the specified threshold is reached (enabled by default). The default value is 200 (value range: 30 to 1000). This policy remains effective after being enabled.
/// @param threshold Threshold for event reporting.
+ (HAReportPolicy *)onCacheThresholdPolicy:(NSInteger)threshold;

@end

NS_ASSUME_NONNULL_END
