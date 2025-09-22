//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AGCAPIComponent : NSObject

@property(nonatomic)NSString *name;
@property(nonatomic)Protocol *api;
@property(nonatomic)BOOL isSharedInstance;
@property(nonatomic)id (^creator)(void);

- (instancetype)initWithName:(NSString *)name api:(Protocol *)api creator:(id (^)(void))creator;

- (instancetype)getObject;

@end

NS_ASSUME_NONNULL_END
