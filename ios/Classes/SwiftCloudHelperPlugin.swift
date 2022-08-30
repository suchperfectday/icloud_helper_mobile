import Flutter
import UIKit
import CloudKit


public class SwiftCloudHelperPlugin: NSObject, FlutterPlugin {
    
    private(set) var seedsName: [String] = []

    
    private var seeds: [String: String] = [:]
    
    var container = CKContainer(identifier: "")

    private lazy var database = container.privateCloudDatabase

    private let zone = CKRecordZone(zoneName: "Seeds")

    private let subscriptionID = "changes-subscription-id"

    private(set) var lastChangeToken: CKServerChangeToken?
    

    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "cloud_helper", binaryMessenger: registrar.messenger())
    let instance = SwiftCloudHelperPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
      
  }
    

   public func handle(_ call: FlutterMethodCall,_ result: @escaping FlutterResult) {
         switch call.method {
           case "initialize":
             initialize(call, result)
           case "upload":
             upload(call, result)
           default:
             result(FlutterMethodNotImplemented)
         }
   }

   private func initialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
         guard let args = call.arguments as? Dictionary<String, Any>,
               let containerId = args["containerId"] as? String
         else {
           // result(argumentError)
           return
         }
         self.container = CKContainer(identifier: containerId)
         result(nil)
   }

    @available(iOS 13.0.0, *)
    private func upload(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let name = args["name"] as? String,
              let phrase = args["phrase"] as? String,
              let publicKey = args["publicKey"] as? String
        else {
//           result(argumentError)
             return
        }

        let newRecordID = CKRecord.ID(zoneID: zone.zoneID)
        let newRecord = CKRecord(recordType: "Seed", recordID: newRecordID)
        newRecord["name"] = name
        newRecord["phrase"] = phrase
        newRecord["publicKey"] = publicKey

        let savedRecord = try await database.save(newRecord)
        seeds[savedRecord.recordID.recordName] = name
        saveLocalCache()
   }
    
    
    private func saveLocalCache() {
        UserDefaults.standard.set(seeds, forKey: "seeds")
    }
}
