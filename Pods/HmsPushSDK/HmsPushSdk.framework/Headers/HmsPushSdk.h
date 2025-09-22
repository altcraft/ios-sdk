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
#import "HmsInstanceId.h"
#import "HmsMessaging.h"
#import "EventReport.h"

//! Project version number for PushSdk.
FOUNDATION_EXPORT double PushSdkVersionNumber ;

//! Project version string for PushSdk.
FOUNDATION_EXPORT const unsigned char PushSdkVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PushSdk/PublicHeader.h>

typedef enum _ErrorEnum{
    SUCCESS=0,
    
    //   No token. Apply for a token.
    ERROR_NO_TOKEN= 907122030,
    
    //  Network unavailable. Check the network connection.
    ERROR_NO_NETWORK = 907122031,
    
    //  Invalid token. Delete the token and apply for a new one.
    ERROR_TOKEN_INVALID=907122032,
    
    //    HUAWEI Push Kit unavailable. Contact Huawei technical support.
    ERROR_SERVICE_NOT_AVAILABLE = 907122046,
    
    //    HUAWEI Push Kit server error. Contact Huawei technical support.
    ERROR_PUSH_SERVER= 907122047,
    
    //    Unknown error. Contact Huawei technical support.
    ERROR_UNKNOWN=907122045,
    //The number of topics to be subscribed to exceeds the threshold (2000).
    ERROR_TOPIC_EXCEED= 907122034,
    
    //Failed to send the topic subscription request. Contact Huawei technical support.
    ERROR_TOPIC_SEND=907122035,
    //HUAWEI Push Kit is not enabled. Enable the service and configure service parameters in AppGallery Connect.
    ERROR_NO_RIGHT=907122036,
    //Failed to apply for the token. Contact Huawei technical support.
    ERROR_GET_TOKEN_ERR=907122037,
    // No storage location is selected for the app or the storage location is invalid.
    ERROR_STORAGE_LOCATION_EMPTY=907122038,
    
    //  Failed to apply for the token. Cross-region application is not allowed.
    ERROR_NOT_ALLOW_CROSS_APPLY=907122053,
    
    //  The message body size exceeds the maximum (1 KB).
    ERROR_SIZE=907122041,
    //   The message contains invalid parameters.
    ERROR_INVALID_PARAMETERS=907122042,
    //   The number of messages sent reaches the upper limit, and this message will be discarded.
    ERROR_TOO_MANY_MESSAGES=907122043,
    //   The message TTL ends before the message arrives at the app server.
    ERROR_TTL_EXCEEDED=907122044,
    //    HMS Core (APK) cannot connect to HUAWEI Push Kit.
    ERROR_HMS_CLIENT_API=907122048,
    //    The EMUI version is too early and the capability is unavailable.
    ERROR_OPERATION_NOT_SUPPORTED=907122049,
    //    The operation cannot be performed in the main thread.
    ERROR_MAIN_THREAD=907122050,
    //   Failed to authenticate the device certificate.
    ERROR_HMS_DEVICE_AUTH_FAILED_SELF_MAPPING=907122051,
    
    //   Failed to bind the service.
    ERROR_BIND_SERVICE_SELF_MAPPING=907122052,
    
    //    The HMS Core Push SDK is being automatically initialized. Please try again later.
    ERROR_AUTO_INITIALIZING=907122054,
    
    
    //   The system is busy. Please try again later.
    ERROR_RETRY_LATER=907122055,
    
    //    Failed to send a device group message or an uplink message.
    ERROR_SEND= 907122056,
    
    //   The device is not in the device group.
    ERROR_DEVICE_NOT_IN_GROUP=907122057,
    
    
    //   The number of cached uplink messages from the app exceeds 20 (maximum).
    
    ERROR_CACHE_SIZE_EXCEED=907122058,
    
    //    The uplink message sent by the app is cached due to a cause such as network unavailability.
    
    ERROR_MSG_CACHE=907122059,
    
    
    //   The app server is offline.
    ERROR_APP_SERVER_NOT_ONLINE= 907122060,
    
    //    Flow control is performed because the frequency for the app to send uplink messages is too high.
    
    ERROR_OVER_FLOW_CONTROL_SIZE=907122061,
    
    //   Incorrect input parameters. Check whether related configurations are correct. For example, check the value of app_id in the agconnect-services.json file and check whether the certificate signature is configured in the build.gradle file.
    ERROR_ARGUMENTS_INVALID=907135000,
    //   HUAWEI Push Kit internal error. Contact Huawei technical support.
    ERROR_INTERNAL_ERROR=907135001,
    
    //    The service or called API does not exist.
    ERROR_NAMING_INVALID=907135002,
    //    Invalid ApiClient object.
    ERROR_CLIENT_API_INVALID=907135003,
    //    AIDL call timed out. Contact Huawei technical support.
    ERROR_EXECUTE_TIMEOUT=907135004,
    //    This service is unavailable in this region.
    ERROR_NOT_IN_SERVICE=907135005,
    //    Invalid AIDL connection session. Contact Huawei technical support.
    ERROR_SESSION_INVALID=907135006,
    //    An error occurred during the call of an undesignated API.
    ERROR_API_NOT_SPECIFIED=1002,
    /*
     Failed to call the gateway to query the app scope. Check whether the app has been created and the service is enabled in AppGallery Connect. If the app has been created and the service is enabled, contact Huawei technical support.
     */
    ERROR_GET_SCOPE_ERROR=907135700,
    /*
     No scope is configured in AppGallery Connect. Check whether the app has been created and the service is enabled in AppGallery Connect. If the app has been created and the service is enabled, contact Huawei technical support.
     */
    ERROR_SCOPE_LIST_EMPTY=907135701,
    
    
    /*
     No certificate fingerprint is configured in AppGallery Connect.
     1. Check whether your phone has Internet access permission.
     2. Check whether the correct certificate fingerprint is configured in AppGallery Connect. For details, please refer to Preparations > Configuring App Information in AppGallery Connect in the HUAWEI Push Kit Developer Guide.
     3. If the fault persists, contact Huawei technical support.
     */
    ERROR_CERT_FINGERPRINT_EMPTY=907135702,
    
    //    No permission is configured in AppGallery Connect.
    ERROR_PERMISSION_LIST_EMPTY=907135703,
    //    The app's authentication information does not exist.
    ERROR_AUTH_INFO_NOT_EXIST= 6002,
    /*
     Certificate fingerprint verification error. Check whether the correct certificate fingerprint is configured in AppGallery Connect. For details, please refer to Preparations > Configuring App Information in AppGallery Connect in the HUAWEI Push Kit Developer Guide.
     */
    ERROR_CERT_FINGERPRINT_ERROR=6003,
    //    API authentication: Permission not granted from AppGallery Connect website.
    ERROR_PERMISSION_NOT_EXIST=6004,
    //   API authentication: Permission not granted.
    ERROR_PERMISSION_NOT_AUTHORIZED=6005,
    //  API authentication: Permission expired
    ERROR_PERMISSION_EXPIRED=6006,
    
}ErrorEnum;

