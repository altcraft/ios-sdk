//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AGCDeviceUtil : NSObject

+ (NSString *)model;

+ (NSString *)systemVersion;

+ (NSString *)systemName;

+ (CGFloat)screenScale;

@end

NS_ASSUME_NONNULL_END
