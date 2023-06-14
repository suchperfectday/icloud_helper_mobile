import Flutter
import UIKit
import CloudKit

extension Array {
    func chunk(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
@available(iOS 13.0, *)
public class SwiftCloudHelperPlugin: NSObject, FlutterPlugin {
    private var container: CKContainer?

    private var database:  CKDatabase?
    private var pubDatabase:  CKDatabase?
    private var priDatabase:  CKDatabase?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cloud_helper", binaryMessenger: registrar.messenger())
        let instance = SwiftCloudHelperPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call, result)
        case "addRecord":
            addRecord(call, result)
        case "uploadPublicFile":
            uploadPublicFile(call, result)
        case "getOneRecord":
            getOneRecord(call, result)
        case "editRecord":
            editRecord(call, result)
        case "deleteRecord":
            deleteRecord(call, result)
        case "getAllRecords":
            getAllRecords(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let containerId = args["containerId"] as? String,
              let databaseType = args["databaseType"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "initialize Required arguments are not provided", details: nil))
            return
        }
        container = CKContainer(identifier: containerId)
        priDatabase = container!.privateCloudDatabase;
        pubDatabase = container!.publicCloudDatabase;
        if(databaseType == "B") {
            database = priDatabase
        }else if(databaseType == "A") {
            database = pubDatabase
        }
        result(nil)
    }


    private func addRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let dataString = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
            return
        }
        let recordId = CKRecord.ID(recordName: id)
        let newRecord = CKRecord(recordType: type, recordID: recordId)
        if let jsonData = dataString.data(using: .utf8) {
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    newRecord.setValuesForKeys(jsonDict)
                }
            } catch {
                result(FlutterError.init(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
                return
            }
        }

        Task {
            do {
                let addedRecord = try await database!.save(newRecord)
                let re = try self.parseRecord(addedRecord)
                result(re)
            } catch {
                result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
                return
            }
        }
    }



    private func uploadPublicFile(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let fileBase64String = args["data"] as? String,
              let type = args["type"] as? String,
              let filename = args["name"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "uploadPublicFile Required arguments are not provided", details: nil))
            return
        }

        guard let imageData = Data(base64Encoded: fileBase64String) else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "uploadPublicFile invalid fileBase64String", details: nil))
            return
        }
        let recordId = CKRecord.ID(recordName: id)
        let newRecord = CKRecord(recordType: type, recordID: recordId)
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectoryURL.appendingPathComponent(filename)
        do {
            try imageData.write(to: tempFileURL)
        } catch {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "uploadPublicFile Failed to write image data to temporary file", details: nil))
            return
        }
        let imageAsset = CKAsset(fileURL: tempFileURL)
        newRecord["Image"] = imageAsset
        Task {
            do {
                let addedRecord = try await pubDatabase!.save(newRecord)
                let fileAsset = addedRecord["Image"] as! CKAsset
                result(fileAsset.fileURL?.absoluteString)
            } catch {
                result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
                return
            }
        }
    }


    private func parseRecord(_ record: CKRecord) throws -> String {
        var dic: [String: Any] = [:]
        record.allKeys().forEach { key in
            dic[key] = record[key]
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
           throw error
        }
    }
    private func getOneRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "getOneRecord Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)
        database!.fetch(withRecordID: recordID) { record, error in
            if let newRecord = record, error == nil {
                do {
                    let re = try self.parseRecord(newRecord)
                    result(re)
                }catch {
                    result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
                }
            } else if let error = error {
                result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
            } else {
                result(FlutterError.init(code: "EDIT_ERROR", message: "Record not found", details: nil))
            }
        }
    }
    

    private func editRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let dataString = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "editRecord Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)

        database!.fetch(withRecordID: recordID) { record, error in
            if let newRecord = record, error == nil {
                if let jsonData = dataString.data(using: .utf8) {
                    do {
                        if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            newRecord.setValuesForKeys(jsonDict)
                        }
                    } catch {
                        result(FlutterError.init(code: "ARGUMENT_ERROR", message: "editRecord Required arguments are not provided", details: nil))
                        return
                    }
                }
                // newRecord["data"] = data
                Task {
                    do {
                        let editedRecord = try await self.database!.save(newRecord)
                        let re = try self.parseRecord(editedRecord)
                        result(re)
                    } catch {
                        result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
                        return
                    }
                }
            } else if let error = error {
                result(FlutterError.init(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
            } else {
                result(FlutterError.init(code: "EDIT_ERROR", message: "Record not found", details: nil))
            }
        }
    }

    private func getAllRecords(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let queryString = args["query"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "getAllRecords Required arguments are not provided", details: nil))
            return
        }
        
        var predicateQuery = NSPredicate(value: true)
        if !queryString.isEmpty {
            predicateQuery = NSPredicate(format: queryString)
        }
        let query = CKQuery(recordType: type, predicate: predicateQuery)
        self._keepLoadRecords(query: query,cursor: nil,result: result, data: [])

    }

    private func _keepLoadRecords(query: CKQuery? = nil, cursor: CKQueryOperation.Cursor? = nil,result: @escaping FlutterResult, data: [String]) {
        var mergedData: [String] = data
        var operation: CKQueryOperation
        if query != nil {
            operation = CKQueryOperation(query: query!)
        }else {
            operation = CKQueryOperation(cursor: cursor!)
        }

        operation.resultsLimit = 400;
        operation.recordFetchedBlock = { record in
            do {
                let re: String = try self.parseRecord(record)
                mergedData.append(re)
            } catch {
                // result(FlutterError.init(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
                // return
            }
        }
        operation.queryCompletionBlock = {(cursor : CKQueryOperation.Cursor?, error : Error?) in
            DispatchQueue.main.async {
                if error == nil {
                    if cursor != nil {
                        self._keepLoadRecords(query: nil, cursor: cursor,result: result,data: mergedData)
                    }else {
                        result(mergedData)
                    }

                } else {
                    result(FlutterError.init(code: "GET_DATA_ERROR", message: error?.localizedDescription, details: nil))
                }
            }
        }
        database?.add(operation)

    }
    private func deleteRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError.init(code: "ARGUMENT_ERROR", message: "deleteRecord Required arguments are not provided", details: nil))
            return
        }
        guard database != nil else {
            result(FlutterError.init(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        
        let recordID = CKRecord.ID(recordName: id)
        
        Task {
            do {
                try await database!.deleteRecord(withID: recordID)
                result(nil)
            } catch {
                result(FlutterError.init(code: "DELETE_ERROR", message: "Failed to delete data", details: nil))
            }
        }
    }
}
