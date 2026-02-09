//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//
#import <Foundation/Foundation.h>
#import "AGCServicesConfig.h"

NS_ASSUME_NONNULL_BEGIN

/// AGConnect SDK 实例
@interface AGCInstance : NSObject

/// AGC配置信息
@property(nonatomic,strong,readonly)AGCServicesConfig *config;

/// SDK初始化接口，需要在应用的AppDelegate的Launch中调用
+ (void)startUp;

/// SDK初始化接口，需要在应用的AppDelegate的Launch中调用
/// @param config 使用指定配置初始化
+ (void)startUp:(AGCServicesConfig *)config;

/// 返回默认配置的单例
+ (instancetype)sharedInstance;

/// 返回自定义配置的实例
/// @param config 自定义配置
+ (instancetype)getInstance:(AGCServicesConfig *)config;

/// 获取指定服务
/// @param protocol 服务接口
- (id _Nullable)getService:(Protocol *)protocol;

/// SDK联网能力
/// @param status 是否联网
+ (void)setAccessNetworkStatus:(BOOL)status;

@end

NS_ASSUME_NONNULL_END
