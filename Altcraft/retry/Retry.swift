//
//  Retry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

private let pushSubscribe = PushSubscribe.shared
private let tokenUpdate = TokenUpdate.shared
private let pushEvent = PushEvent.shared
private let userDefault = StoredVariablesManager.shared
private let networkMonitor = NetworkMonitor.shared

/// Handles retrying of various requests based on the provided request name.
///
/// - Parameters:
///   - request: A string identifying the type of request to retry.
///   - context: An optional Core Data context used for push event retries.
///   - event: An optional push event entity used for push event retries.
///
/// This function handles retries for push/subscribe, push/update, and event/push requests.
func requestRetry(
    request: String,
    context: NSManagedObjectContext? = nil,
    event: PushEventEntity? = nil) {
    switch request {
    case Constants.FunctionsCode.SS:
        localPushSubscribeRetry()
        
    case Constants.FunctionsCode.SU:
        localTokenUpdateRetry()
        
    case Constants.FunctionsCode.SE:
        localPushEventRetry(context: context, event: event)
        
    default: print("unknown function")
    }
}

/// Retries the "push/subscribe" request if the retry count is within the allowed limit.
/// The retry is performed with a delay that increases exponentially based on the retry count.
func localPushSubscribeRetry() {
    guard let localRetryCount = userDefault.getSubRetryCount() else {
        return
    }
    
    let work = DispatchWorkItem {
        if localRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                pushSubscribe.startSubscribe()
                userDefault.setSubRetryCount(value: localRetryCount + 1)
            }
        }
    }
    
    RetryManager.shared.store(key: "subscribe", work: work)
    RetryManager.shared.subscribeQueue.asyncAfter(
        deadline: .now() + delay(retryCount: localRetryCount), execute: work
    )
}

/// Retries the "push/update" request if the retry count is within the allowed limit.
/// The retry is performed with a delay that increases exponentially based on the retry count.
private func localTokenUpdateRetry() {
    guard let localRetryCount = userDefault.getUpdateRetryCount() else {
        return
    }
    
    let work = DispatchWorkItem {
        if localRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                tokenUpdate.startUpdate()
                userDefault.setUpdateRetryCount(value: localRetryCount + 1)
            }
        }
    }
    
    RetryManager.shared.store(key: "tokenUpdate", work: work)
    RetryManager.shared.tokenUpdateQueue.asyncAfter(
        deadline: .now() + delay(retryCount: localRetryCount), execute: work
    )
}

/// Retries the "event/push" request if the retry count is within the allowed limit.
///
/// - Parameters:
///   - context: The managed object context used to access Core Data.
///   - event: The push event entity containing the event to retry.
///
/// The retry is performed with a delay that increases exponentially based on the retry count.
/// If parameters are invalid, it performs the request using the given event.
private func localPushEventRetry(context: NSManagedObjectContext?, event: PushEventEntity?) {
    guard let event = event,
          let context = context,
          let uid = event.uid,
          let type = event.type,
          let localRetryCount = userDefault.getPushEventRetryCount() else {
        return
    }
    
    let work = DispatchWorkItem {
        if localRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                pushEvent.sendPushEvent(context: context, entity: event)
                userDefault.setPushEventRetryCount(value: localRetryCount + 1)
            }
        }
    }
    
    let key = "pushEvent-\(uid)-\(type)"
    RetryManager.shared.store(key: key, work: work)
    
    RetryManager.shared.pushEventQueue.asyncAfter(
        deadline: .now() + delay(retryCount: localRetryCount),execute: work
    )
}

/// Calculates the delay before retrying based on the retry count.
///
/// - Parameter retryCount: The current retry count.
/// - Returns: The calculated delay before the next retry attempt.
func delay(retryCount: Int) -> Double {
    return pow(Double(Constants.Retry.initialDelay) + 3, Double(retryCount))
}
