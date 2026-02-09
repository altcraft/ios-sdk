//
//  Copyright (c) Huawei Technologies Co., Ltd. 2020. All rights reserved
//

#import <Foundation/Foundation.h>
#import <HMFoundation/HMFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 网络请求Task
@interface AGCSessionTask<TResult> : HMFTask <TResult>

- (NSData *)responseData;

@end

/// 数据请求Task
@interface AGCSessionDataTask : AGCSessionTask <NSData *>

/// 原始的网络请求sessionTask
@property(nonatomic, readonly) NSURLSessionDataTask *URLTask;

@end

/// 上传请求Task
@interface AGCSessionUploadTask : AGCSessionTask <NSData *>

/// 原始的网络请求sessionTask
@property(nonatomic, readonly) NSURLSessionUploadTask *URLTask;

/// 上传进度
@property(nonatomic, readonly) NSProgress *uploadProgress;

/// 设置上传进度回调，不支持多回调
/// @param progressCallback 上传进度回调
/// @result 返回当前对象
- (AGCSessionTask *)addOnProgressCallback:(void (^)(NSProgress *progress))progressCallback;

@end

/// 下载请求Task
@interface AGCSessionDownloadTask : AGCSessionTask <NSURL *>

/// 原始的网络请求sessionTask
@property(nonatomic, readonly) NSURLSessionDownloadTask *URLTask;

/// 下载进度
@property(nonatomic, readonly) NSProgress *downloadProgress;

/// 设置下载进度回调，不支持多回调
/// @param progressCallback 下载进度回调
/// @result 返回当前对象
- (AGCSessionTask *)addOnProgressCallback:(void (^)(NSProgress *progress))progressCallback;

/// 设置下载文件目标路径
/// @param destination 下载文件目标路径，targetPath是换成路径
/// @result 返回当前对象
- (AGCSessionDownloadTask *)addDestinationCallback:(NSURL * (^)(NSURL *targetPath))destination;

@end

NS_ASSUME_NONNULL_END
