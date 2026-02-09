/**
 Copyright 2020. Huawei Technologies Co., Ltd. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */

#ifndef HmsInstanceId_h
#define HmsInstanceId_h

#import <Foundation/Foundation.h>

@interface HmsInstanceId : NSObject

/**
 * @method  get instance。
 */
+ (HmsInstanceId *)getInstance;

/**
 * @method  get AAID。
 */
- (NSString *)getAAID;

/**
 * @method   delete AAID
 */
- (void)deleteAAID;

/**
 * @method  AAID timestamp
 */
- (NSNumber *)getCreationTime;

/**
 * @method  get token
 * @parameter pnToken: NSString*,is it apn token from apn server
 */
- (NSString *)getToken:(NSString *)apnToken;

/**
 * @method: delete token
 */
- (void)deleteToken;

/**
 * @method delete token by subject id
 * @parameter apnToken: NSString*,is it apn token from apn server
 * @parameter subjectId: NSString*
 */
- (NSString *)getToken:(NSString *)apnToken subjectId:(NSString *)subjectId;

/**
 * @method delete token by subject id
 * @parameter subjectId:NSString*
 */
- (void)deleteToken:(NSString *)subjectId;

@end

#endif /* HmsInstanceId_h */
