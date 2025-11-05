//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>
#import "AGCSessionTask.h"

NS_ASSUME_NONNULL_BEGIN


/// 发送网络请求类
@interface AGCBackend : NSObject

/// 原始的url session对象
@property(nonatomic, strong, readonly) NSURLSession *session;

/// 单例
+ (instancetype)sharedInstance;

/// 发送数据
/// @param request 请求
/// @result 请求对应的Task，在Task的结果中返回网络请求结果
- (AGCSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;

/// 上传文件
/// @param request 请求
/// @param fileURL 要上传的文件路径
/// @result 请求对应的Task，在Task的结果中返回网络请求结果
- (AGCSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;

/// 上传文件
/// @param request 请求
/// @param bodyData 要上传的文件
/// @result 请求对应的Task，在Task的结果中返回网络请求结果
- (AGCSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;

/// 下载文件
/// @param request 请求
/// @result 请求对应的Task，在Task的结果中返回网络请求结果, 在DownloadTask里设置文件存储路径
- (AGCSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
