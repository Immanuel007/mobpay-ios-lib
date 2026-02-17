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

public class Mobpay:UIViewController {

    public static let instance = Mobpay()
    
    var mqtt: CocoaMQTT!
    var merchantId:String!
    var transactionRef:String!
    public var baseURL: String = "https://gatewaybackend-uat.quickteller.co.ke"
    public var mqttHostURL: String = "testmerchant.interswitch-ke.com"
    
    public var MobpayDelegate:MobpayPaymentDelegate?
    
    
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
    
    // MQTT
    
//    func setUpMQTT(){
//        let clientID = "iOS-" + String(ProcessInfo().processIdentifier)
//        mqtt = CocoaMQTT(clientID: clientID, host: self.mqttHostURL, port: 8084)
//        mqtt.username = ""
//        mqtt.password = ""
//        mqtt.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
//        mqtt.keepAlive = 60
//        mqtt.connect()
//        mqtt.delegate = self
//    }
    
    
    // MQTT 5
    
//    func setUpMQTT(){
//        let clientID = "iOS-" + String(ProcessInfo().processIdentifier)
//
//        // Use MQTTS (MQTT over TLS) - no WebSocket needed
//        mqtt = CocoaMQTT5(clientID: clientID, host: self.mqttHostURL, port: 8084)
//
//        mqtt.username = ""
//        mqtt.password = ""
//
//        // Enable SSL
//        mqtt.enableSSL = true
//        mqtt.allowUntrustCACertificate = true
//
//        // MQTT 5 properties
//        let connectProperties = MqttConnectProperties()
//        connectProperties.topicAliasMaximum = 10
//        connectProperties.sessionExpiryInterval = 0
//        connectProperties.receiveMaximum = 100
//        connectProperties.maximumPacketSize = 500
//
//        mqtt.connectProperties = connectProperties
//        mqtt.keepAlive = 60
//        mqtt.willMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
//
//        mqtt.delegate = self
//        mqtt.connect()
//    }
    
    
    // MQTT with Web Sockets
    
    func setUpMQTT() {
        let clientID = "iOS-" + String(ProcessInfo().processIdentifier)
        
        let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
        websocket.enableSSL = true

        let mqtt = CocoaMQTT(
            clientID: clientID,
            host: self.mqttHostURL,
            port: 8084,
            socket: websocket
        )

        mqtt.username = ""
        mqtt.password = ""
        mqtt.allowUntrustCACertificate = true


        
        mqtt.willMessage = CocoaMQTTMessage(
            topic: "/will",
            string: "dieout"
        )

        mqtt.keepAlive = 60
        mqtt.delegate = self
        self.mqtt = mqtt
        connect()

    }
    func connect() {
            guard let mqttClient = mqtt else { return }
            mqttClient.connect()
        }

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
    
    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("Published message with ID: \(id)")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print("Unsubscribed from topics: \(topics)")
    }
    
    public func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("MQTT did ping")
    }
    
    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print("MQTT did receive pong")
    }
    
    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: (any Error)?) {
        print("Disconnected from MQTT broker with error: \(String(describing: err))")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("Connected to MQTT broker with acknowledgment: \(ack)")
        
        // Subscribe after successful connection
        self.mqtt.subscribe("merchant_portal/\(self.merchantId!)/\(self.transactionRef!)")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        if let messageString = message.string {
            print("Received message: \(messageString) on topic: \(message.topic)")
            
            DispatchQueue.main.async {
                mqtt.disconnect()
                self.MobpayDelegate?.launchUIPayload(messageString)
            }
        }
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("Published message: \(message.string ?? "") with ID: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("Subscribed to topics: \(success), failed to subscribe to: \(failed)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didDisconnectWithError err: Error?) {
        print("Disconnected from MQTT broker with error: \(String(describing: err))")
    }
}


public protocol MobpayPaymentDelegate {
    func launchUIPayload(_ message: String)
}
