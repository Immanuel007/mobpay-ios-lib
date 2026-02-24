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
    
    private var mqtt5: CocoaMQTT5!
    
    var merchantId: String!
    var transactionRef: String!
    public var baseURL: String = "https://gatewaybackend-uat.quickteller.co.ke"
    public var mqttHostURL: String = "testmerchant.interswitch-ke.com"
    
    private var onPaymentResult: ((String) -> Void)?
    private weak var navController: UINavigationController?
    
    public var MobpayDelegate: MobpayPaymentDelegate?
    
    public func submitPayment(checkout: CheckoutData, isLive: Bool, previousUIViewController: UIViewController, completion: @escaping(String) -> ()) async throws {
        
        if isLive {
            self.baseURL = "https://gatewaybackend.quickteller.co.ke"
            self.mqttHostURL = "merchant.interswitch-ke.com"
        }

        let headers: HTTPHeaders = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Device": "iOS"
        ]
        
        self.merchantId = checkout.merchantCode
        self.transactionRef = checkout.transactionReference
        self.onPaymentResult = completion
        self.navController = previousUIViewController.navigationController
                
        AF.request("\(self.baseURL)/ipg-backend/api/checkout",
                   method: .post,
                   parameters: checkout,
                   encoder: URLEncodedFormParameterEncoder.default,
                   headers: headers)
        .response { response in
            debugPrint(response)
            
            self.setUpMQTT()
            
            let threeDS = ThreeDSWebView(webCardinalURL: (response.response?.url)!)
            
            DispatchQueue.main.async {
                previousUIViewController.navigationController?.pushViewController(threeDS, animated: true)
                self.navController = previousUIViewController.navigationController
                self.onPaymentResult = completion
            }
        }
    }
    
    func setUpMQTT() {
        let clientID = "iOS-" + String(ProcessInfo().processIdentifier)
        
        let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
        
        mqtt5 = CocoaMQTT5(
            clientID: clientID,
            host: mqttHostURL,
            port: 8084,
            socket: websocket
        )
        
        let connectProperties = MqttConnectProperties()
        connectProperties.topicAliasMaximum = 0
        connectProperties.sessionExpiryInterval = 0
        connectProperties.receiveMaximum = 100
        connectProperties.maximumPacketSize = 500
        
        mqtt5.connectProperties = connectProperties
        
        mqtt5.enableSSL = true
        
        mqtt5.username = ""
        mqtt5.password = ""
        
        mqtt5.willMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
        mqtt5.keepAlive = 60
        mqtt5.delegate = self
        
        // Connect
        mqtt5.connect()
    }
}

extension Mobpay: CocoaMQTT5Delegate {
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        print("MQTT 5 Connected with ack: \(ack)")
        
        if ack == .success {
            let topic = "merchant_portal/\(merchantId!)/\(transactionRef!)"
            print("Subscribing to: \(topic)")
            mqtt5.subscribe(topic, qos: .qos1)
        }
    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didStateChangeTo state: CocoaMQTTConnState) {
        print("MQTT 5 State: \(state)")
    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        guard let messageString = message.string else {
            print("Message string is nil")
            return
        }
        
        print("========================================")
        print("MQTT 5 MESSAGE RECEIVED!")
        print("Topic: \(message.topic)")
        print("Message: \(messageString)")
        print("========================================")
        
        DispatchQueue.main.async {
            mqtt5.disconnect()
            self.navController?.popViewController(animated: true)
            self.onPaymentResult?(messageString)
            self.MobpayDelegate?.launchUIPayload(messageString)
        }
    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        print("MQTT 5 Subscribed to: \(success), failed: \(failed)")
    }
    
    public func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {
        print("MQTT 5 ping")
    }
    
    public func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {
        print("MQTT 5 pong")
    }
    
    public func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: Error?) {
        print("MQTT 5 disconnected: \(String(describing: err))")
    }
    
    // Required delegate methods (empty implementations)
    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {}
    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {}
    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {}
    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishComplete id: UInt16, pubCompData: MqttDecodePubComp?) {}
    public func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?) {}
    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {}
    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {}
}

public protocol MobpayPaymentDelegate {
    func launchUIPayload(_ message: String)
}
