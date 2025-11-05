//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>
#import "AGCModelProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AGCGWBaseResponse : NSObject<NSCoding,AGCModelProtocol>

@property(nonatomic) NSInteger retCode;
@property(nonatomic) NSString *retMsg;

- (BOOL)isSuccess;
- (NSError *)failError;

@end

NS_ASSUME_NONNULL_END
