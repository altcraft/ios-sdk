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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EventReport : NSObject

+ (void)InitEventReport;

/**
 * @method  get instance。
 */
+ (EventReport *)getInstance;

/**
 * @method report Push Msg
 * @parameter userInfo: NSDictionary *, from Apn Server
 * @parameter eventID: NSString*, event id
 */
- (void)reportPushMsgEvent:(NSDictionary *)userInfo eventID:(NSString *)eventID;

/**
 * @method report coming Push Msg
 * @parameter userInfo: NSDictionary *, from Apn Server
 */
- (void)reportPushMsgComingEvent:(NSDictionary *)userInfo;

/**
 * @method report click Push Msg
 * @parameter userInfo: NSDictionary *, from Apn Server
 */
- (void)reportPushMsgClickEvent:(NSDictionary *)userInfo;

/**
 * @method report silent Push Msg
 * @parameter userInfo: NSDictionary *, from Apn Server
 */
- (void)reportPushMsgSilentEvent:(NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
