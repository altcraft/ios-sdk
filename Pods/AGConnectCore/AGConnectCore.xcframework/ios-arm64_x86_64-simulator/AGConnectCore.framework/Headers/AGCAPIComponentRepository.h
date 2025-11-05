//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>
#import "AGCAPIComponent.h"

NS_ASSUME_NONNULL_BEGIN
@interface AGCAPIComponentRepository : NSObject

@property(nonatomic, readonly) NSArray<AGCAPIComponent *> *allComponents;

+ (instancetype)defaults;

- (void)registryComponent:(AGCAPIComponent *)component;

- (NSArray<NSString *> *)filterComponents:(Protocol *)api;
- (AGCAPIComponent *)getComponent:(Protocol *)api name:(NSString *)name;
- (id)getObject:(Protocol *)api name:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
