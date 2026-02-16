//
//  RSAUtil.swift
//  mobpay-ios
//
//  Created by Allan Mageto on 30/05/2019.
//  Copyright © 2019 Allan Mageto. All rights reserved.
//

import Foundation
import SwiftyRSA

public class RSAUtil{
    public static func getAuthDataMerchant(panOrToken: String, cvv: String?,expiry:String?,tokenize:String,separator:String)throws ->String{
        do {
            let publicKey = try!PublicKey(base64Encoded: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnHs7piGibEsC9Iz8B+9u4K7Y4StL0RxcwKv4DVIGvmnhiR5g/Iji1WXi+r5NDPYw4ximxyHD3tcY0MUwzfBQOHrQowozaJm72od9DsfHw//mk5iL+uD/urcbJUaMeBSSTwIstf2jbg0sMKcWH6HG+1+9fQWtvvfmjUj4tsX1EYJ8Sxxe0VtvIFVa/8TQhX73qytcGLoivqXTp5vRg0uttYeNjHpLGdogwfYjQLH3+/AdLy6XyXFKnfN2rA6lgHKyt3rreHK1SolmdRneRND8c1QL7q7Ey3eKRe6/vv4tgXqKgxmyvG2fpxT1KJ7HwNvENJbXHPKmQstnmw/EBy/SzwIDAQAB");
            let cipherParts:Array = [panOrToken,cvv!,expiry!,"",tokenize];
            let authDataCipher = cipherParts.joined(separator: separator)
            let clear = try ClearMessage(string: authDataCipher, using: .utf8)
            let encrypted = try clear.encrypted(with: publicKey, padding: .PKCS1)
            return encrypted.base64String;
        } catch {
            throw error
        }
}
    
    public static func encryptBrowserPayload(payload:String)throws ->String{
        do {
            let browserPublicKey = try PublicKey(base64Encoded: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjJ84cM/HJEOvuxxWwbOTsF+GeFD7qQCMaSSbfWo7x0oiNEMxRGZOCPpQI+SNt8D4n+U4YroRmo4W4wgNkkJWQJkx5EyDJePGv5NSGXW+27uQpOin7G2h7JAHq+mF3hcR4uR7GlMw4MpTdNyYfb2L/8RvCdIXzANQOpdNFsbNm62qJSOO/gq1jCTl/+8HudIQHR7Vyw1QrL+3Sp0ZlkzlUr2SouPVyEVodcea2z4gkH1AQMwXGXUzALMqtYo3uUaOZb5E3vKDzTeTkVzujefloPUxVBJXfW0ypkH452ccOywH6Fv/aJaVUvQCe5arEO4IPg9HjsWrxsqkvZ2xnPrkfQIDAQAB");
            let clear = try ClearMessage(string: payload, using: .utf8)
            let encryptedPayload = try clear.encrypted(with: browserPublicKey, padding: .PKCS1)
            return encryptedPayload.base64String;
        } catch {
            throw error
        }
        
    }
}

//MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnHs7piGibEsC9Iz8B+9u4K7Y4StL0RxcwKv4DVIGvmnhiR5g/Iji1WXi+r5NDPYw4ximxyHD3tcY0MUwzfBQOHrQowozaJm72od9DsfHw//mk5iL+uD/urcbJUaMeBSSTwIstf2jbg0sMKcWH6HG+1+9fQWtvvfmjUj4tsX1EYJ8Sxxe0VtvIFVa/8TQhX73qytcGLoivqXTp5vRg0uttYeNjHpLGdogwfYjQLH3+/AdLy6XyXFKnfN2rA6lgHKyt3rreHK1SolmdRneRND8c1QL7q7Ey3eKRe6/vv4tgXqKgxmyvG2fpxT1KJ7HwNvENJbXHPKmQstnmw/EBy/SzwIDAQAB

//"MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCcS3/OiYyHdlCHicBm9yHiOQdvJ/8XRR3dHSaezR5SjlrUEiul4MeNdmqYU7IB7zXG+4aW2OtrdUkfVLXkxjqO4IW8B1cfdXOxNzrq1/NUUKYdepcAGcT1xMtvRgqPXd7ja+U5lLNT2n3GLYuLAVuk987bgVKQQ4gBAls5WIwGIQIDAQAB"

