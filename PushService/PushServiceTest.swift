//
//  PushServiceTest.swift
//  PushService
//
//  Created by andrey on 28.08.2025.
//

import Foundation
import UserNotifications

public func prepareRequest(_ method: String, _ url: String, _ body: Data?) -> URLRequest? {
    guard let url = URL(string: url) else {return nil}
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method
    urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
    urlRequest.httpBody = body
    return urlRequest
}

func testSendMessage(request: UNNotificationRequest) {
    print("test send message")
    guard let userInfo = request.content.userInfo as? [String: Any] else {
           print("Error: userInfo format is invalid")
           return
       }
        print("Altcraft test - delivery and comparison of the notification structure")
        let url = "http://push-test-lab.qa.altcraft.com:8080/v1/messages/save"
        
        do {
            let requestBody = try JSONSerialization.data(withJSONObject: userInfo)
            guard let urlRequest = prepareRequest("POST", url, requestBody) else { return }
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    print("Ошибка: \(error.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("Код ответа сервера: \(httpResponse.statusCode)")
                }
                if let data = data {
                    do {
                        if try JSONSerialization.jsonObject(with: data, options: []) is [String: Any] {
                            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                                print("successful test send message")
                            }
                        }
                    } catch {
                        print("testSendMessage: \(error.localizedDescription)")
                    }
                }
            }
            task.resume()
        } catch {
            print("Error SubscribePush request")
    }
}
