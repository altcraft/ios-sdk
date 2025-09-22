//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <HMFoundation/HMFoundation.h>
#import "AGCModelProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// AGC网关请求回调，会忽略token导致的错误，只关注当前请求
@protocol AGCGWRequestEventDelegate <NSObject>

@optional

/// 开始回调
- (void)onStart;

/// 成功回调
- (void)onSuccess;

/// 失败回调
/// @param error 失败错误
- (void)onFail:(NSError *)error;

@end

/// AGC网关请求协议
@protocol AGCGWRequestProtocol <NSObject>

/// 请求方法
- (NSString *)GWMethod;

/// 请求url路径,无需host
- (NSString *)GWURLString;

@optional

/// 请求体
- (NSDictionary *_Nullable)GWBody;

/// 请求体
- (NSObject *_Nullable)GWObjectBody;

/// 请求参数
- (NSDictionary<NSString *, NSString *> *_Nullable)GWQuerys;

/// 请求头
- (NSDictionary<NSString *, NSString *> *_Nullable)GWHeaders;

/// 请求超时时间
- (NSTimeInterval)GWTimeout;

/// 返回数据的解析类
- (Class<AGCModelProtocol> _Nullable)responseClass;

/// 此请求的回调
- (id<AGCGWRequestEventDelegate> _Nullable)eventDelegate;

@end

NS_ASSUME_NONNULL_END
