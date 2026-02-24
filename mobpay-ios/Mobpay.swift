//
//  Mobpay.swift
//  mobpay-ios
//
//  Created by interswitchke on 21/05/2019.
//  Copyright © 2019 interswitchke. All rights reserved.
//


import Foundation
import CryptoSwift
import SwiftyRSA
import SafariServices
import CocoaMQTT
import Alamofire
import Starscream

public class Mobpay: UIViewController {

    public static let instance = Mobpay()
    
    private var mqtt: CocoaMQTT!
    var merchantId: String!
    var transactionRef: String!
    public var baseURL: String = "https://gatewaybackend-uat.quickteller.co.ke"
    public var mqttHostURL: String = "testmerchant.interswitch-ke.com"
    
    public var MobpayDelegate: MobpayPaymentDelegate?
    
    public func submitPayment(checkout:CheckoutData, isLive:Bool ,previousUIViewController:UIViewController,completion:@escaping(String)->())async throws{
            do {
                if(isLive){
                    self.baseURL = "https://gatewaybackend.quickteller.co.ke"
                    self.mqttHostURL = "merchant.interswitch-ke.com"
                }

                let headers: HTTPHeaders = [
                        "Content-Type" : "application/x-www-form-urlencoded",
                        "Device" : "iOS"
                    ]
                self.merchantId = checkout.merchantCode
                self.transactionRef = checkout.transactionReference
                
                AF.request("\(self.baseURL)/ipg-backend/api/checkout",
                            method: .post,
                            parameters: checkout,
                            encoder: URLEncodedFormParameterEncoder.default, headers: headers)
                    .response { response in
                        debugPrint(response)
                        self.setUpMQTT()
                        let threeDS = ThreeDSWebView(webCardinalURL: (response.response?.url)!)
                        DispatchQueue.main.async {
                            previousUIViewController.navigationController?.pushViewController(threeDS, animated: true)
                        }
                        self.mqtt.didReceiveMessage = { mqtt, message, id in
                            mqtt.disconnect()
                            previousUIViewController.navigationController?.popViewController(animated: true)
                            completion(message.string!)
                        }
                    }
            } catch {
                throw error
            }
        }
    
    func setUpMQTT() {
        let clientID = "iOS-" + String(ProcessInfo().processIdentifier)
        
        let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
        websocket.enableSSL = true
        websocket.headers = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Device": "iOS"
        ]
        
        mqtt = CocoaMQTT(
            clientID: clientID,
            host: mqttHostURL,
            port: 8084,
            socket: websocket
        )
        
        mqtt.username = ""
        mqtt.password = ""
        
        mqtt.willMessage = CocoaMQTTMessage(
            topic: "/will",
            string: "dieout"
        )
        
        mqtt.keepAlive = 60
        mqtt.delegate = self
        
        mqtt.connect()
    }
    
//    func connect() {
//        guard let mqtt = mqtt else { return }
//        mqtt.connect()
//    }
}

extension Mobpay: CocoaMQTTDelegate {
    
    public func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    public func mqttUrlSession(_ mqtt: CocoaMQTT, didReceiveTrust trust: SecTrust, didReceiveChallenge challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("\(#function), \n result:- \(challenge.debugDescription)")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("Connected to MQTT broker with acknowledgment: \(ack)")
        print("Subscribing to: merchant_portal/\(self.merchantId!)/\(self.transactionRef!)")
        
        let topic1 = "merchant_portal/\(merchantId!)/\(transactionRef!)"

            mqtt.subscribe(topic1)
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didChangeState state: CocoaMQTTConnState) {
        print("MQTT STATE => \(state)")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let messageString = message.string
        
        print("========================================")
        print("MQTT MESSAGE RECEIVED!")
        print("Topic: \(message.topic)")
        print("Message: \(messageString)")
        print("========================================")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("Subscribed to topics: \(success), failed: \(failed)")
        print("Now waiting for payment completion message...")
    }
    
    public func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("MQTT ping - connection alive")
    }
    
    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print("MQTT pong received")
    }
    
    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: (any Error)?) {
        print("MQTT disconnected: \(String(describing: err))")
    }
    
    // Other delegate methods...
    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}
}

public protocol MobpayPaymentDelegate {
    func launchUIPayload(_ message: String)
}
