//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 网关返回的错误，只针对NSURLErrorBadServerResponse场景进行处理
@interface AGCGWError : NSError

/// 错误码
@property(nonatomic, readonly) NSInteger agcCode;

/// 错误信息
@property(nonatomic, readonly) NSString *agcMessage;

/// 如果agcCode返回的是401，则进一步判断是否是ClientToken失效
@property(nonatomic, readonly) BOOL isClientTokenInvalid;

/// 如果agcCode返回的是401，则进一步判断是否是AccessToken失效
@property(nonatomic, readonly) BOOL isAccessTokenInvalid;

@end

NS_ASSUME_NONNULL_END
