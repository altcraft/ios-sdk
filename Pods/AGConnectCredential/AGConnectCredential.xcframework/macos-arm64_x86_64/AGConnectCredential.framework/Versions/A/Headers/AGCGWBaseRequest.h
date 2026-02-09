//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>
#import "AGCGWRequestProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// 网关请求父类，所有参数都是定义在header中
@interface AGCGWBaseRequest : NSObject <AGCGWRequestProtocol>

@property(nonatomic,strong,nullable)NSString *sdkServiceName;//需要子类赋值
@property(nonatomic,strong,nullable)NSString *sdkVersion;//需要子类赋值
@property(nonatomic,strong,nullable)NSString *sdkType;
@property(nonatomic,strong,nullable)NSString *sdkPlatform;
@property(nonatomic,strong,nullable)NSString *sdkPlatformVersion;
@property(nonatomic,strong,nullable)NSString *packageName;
@property(nonatomic,strong,nullable)NSString *appVersion;
@property(nonatomic,strong,nullable)NSString *productId;
@property(nonatomic,strong,nullable)NSString *appId;
@property(nonatomic,strong,nullable)NSString *clientId;
@property(nonatomic,strong,nullable)NSString *clientSecret;
@property(nonatomic,strong,nullable)NSString *aaId;//需要子类赋值
@property(nonatomic,strong,nullable)NSString *authorization;//需要子类赋值
@property(nonatomic,strong,nullable)NSString *accessToken;//需要子类赋值
@property(nonatomic, strong, nullable) NSString *apiKey;//平台分配的apiKey
@property(nonatomic) BOOL isNetworkApikey;//网络鉴权方式 1 apikey鉴权 0  ClientToken鉴权 需要子类赋值
@end

NS_ASSUME_NONNULL_END
