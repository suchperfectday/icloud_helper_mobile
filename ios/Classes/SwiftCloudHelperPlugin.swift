import Flutter
import UIKit
import CloudKit


@available(iOS 15.0, *)
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
           case "delete":
             delete(call, result)
           default:
             result(FlutterMethodNotImplemented)
         }
   }
    
    func fetchLatestChanges() async throws {
        var awaitingChanges = true

        while awaitingChanges {
            let changes = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: lastChangeToken)

            let changedRecords = changes.modificationResultsByID.compactMapValues { try? $0.get().record }
            let deletedRecordIDs = changes.deletions.map { $0.recordID.recordName }

            changedRecords.forEach { id, record in
                if let seedName = record["name"] as? String {
                    seeds[id.recordName] = seedName
                }
            }

            deletedRecordIDs.forEach { seeds.removeValue(forKey: $0) }

            saveChangeToken(changes.changeToken)

            saveLocalCache()

            awaitingChanges = changes.moreComing
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
        seeds[savedRecord.recordID.recordName] = publicKey
        saveLocalCache()
   }
    
   func delete(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async throws {
       guard let args = call.arguments as? Dictionary<String, Any>,
             let publicKey = args["publicKey"] as? String
       else {
//           result(argumentError)
           return
       }
           
        guard let matchingID = seeds.first(where: { _, value in publicKey == publicKey })?.key else {
            debugPrint("Seed not found on deletion for publicKey: \(publicKey)")
            throw PrivateSyncError.seedNotFound
        }

        let recordID = CKRecord.ID(recordName: matchingID, zoneID: zone.zoneID)

        try await database.deleteRecord(withID: recordID)

        seeds.removeValue(forKey: matchingID)
        saveLocalCache()
    }
    
    
    private func saveLocalCache() {
        UserDefaults.standard.set(seeds, forKey: "seeds")
    }
    
    private func saveChangeToken(_ token: CKServerChangeToken) {
        let tokenData = try! NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)

        lastChangeToken = token
        UserDefaults.standard.set(tokenData, forKey: "lastChangeToken")
    }
    
    
    
    
    
    
    enum PrivateSyncError: Error {
        case seedNotFound
    }
}
