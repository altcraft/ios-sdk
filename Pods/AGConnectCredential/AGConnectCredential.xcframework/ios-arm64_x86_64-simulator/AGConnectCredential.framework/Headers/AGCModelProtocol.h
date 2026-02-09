//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

/// 数据解析协议
@protocol AGCModelProtocol <NSObject>

/// 根据返回的json数据转换为model类型
/// @param json json的字典，暂不支持array的json
+ (instancetype)modelWithJSON:(NSDictionary *)json;

@end
