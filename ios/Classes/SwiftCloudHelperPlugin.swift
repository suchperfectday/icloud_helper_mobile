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

public class SwiftCloudHelperPlugin: NSObject, FlutterPlugin {
    private var container: CKContainer?

    private var database: CKDatabase?

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
        case "addRecordFile":
            addRecordFile(call, result)
        case "getOneRecord":
            getOneRecord(call, result)
        case "getOneRecordFile":
            getOneRecordFile(call, result)
        case "checkOneRecordAvailable":
            checkOneRecordAvailable(call, result)
        case "editRecord":
            editRecord(call, result)
        case "editFileRecord":
            editFileRecord(call, result)
        case "deleteRecord":
            deleteRecord(call, result)
        case "deleteManyRecords":
            deleteManyRecords(call, result)
        case "getAllRecords":
            getAllRecords(call, result)
        case "getRecordFileInfo":
            getRecordFileInfo(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let containerId = args["containerId"] as? String,
              let databaseType = args["databaseType"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "initialize Required arguments are not provided", details: nil))
            return
        }
        container = CKContainer(identifier: containerId)
        if databaseType == "B" {
            database = container!.privateCloudDatabase
        } else if databaseType == "A" {
            database = container!.publicCloudDatabase
        }
        result(nil)
    }

    private func addRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let dataString = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
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
                result(FlutterError(code: "ARGUMENT_ERROR", message: "addRecord Required arguments are not provided", details: nil))
                return
            }
        }

        Task {
            do {
                let addedRecord = try await database!.save(newRecord)
                let re = try self.parseRecord(addedRecord)
                result(re)
            } catch {
                result(FlutterError(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func addRecordFile(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let fileUrl = args["fileUrl"] as? String,
              let fieldName = args["fieldName"] as? String,
              let metadata = args["metadata"] as? String,
              let bkType = args["bkType"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "addRecordFile Required arguments are not provided", details: nil))
            return
        }
        let recordId = CKRecord.ID(recordName: id)
        let newRecord = CKRecord(recordType: type, recordID: recordId)

        let fileURL = URL(fileURLWithPath: fileUrl)
        let asset = CKAsset(fileURL: fileURL)

        newRecord[fieldName] = asset
        newRecord.setValue(metadata, forKey: "metadata")
        newRecord.setValue(bkType, forKey: "bk_type")
        Task {
            do {
                _ = try await database!.save(newRecord)
                result(fileUrl)
            } catch {
                result(FlutterError(code: "UPLOAD_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func editFileRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let fileUrl = args["fileUrl"] as? String,
              let fieldName = args["fieldName"] as? String,
              let metadata = args["metadata"] as? String,
              let bkType = args["bkType"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "editFileRecord Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)

        Task {
            do {
                let newRecord = try await database!.record(for: recordID)

                let fileURL = URL(fileURLWithPath: fileUrl)
                let asset = CKAsset(fileURL: fileURL)

                newRecord[fieldName] = asset
                newRecord.setValue(metadata, forKey: "metadata")
                newRecord.setValue(bkType, forKey: "bk_type")

                _ = try await self.database!.save(newRecord)
                result(fileUrl)
            } catch {
                result(FlutterError(code: "UPDATE_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }


    private func parseRecord(_ record: CKRecord) throws -> String {
        var dic: [String: Any] = [:]
        record.allKeys().forEach { key in
            dic[key] = record[key]
        }
        let jsonData = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8)!
    }

    private func getOneRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "getOneRecord Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)
        Task {
            do {
                let record = try await database!.record(for: recordID)
                let re = try self.parseRecord(record)
                result(re)
            } catch {
                result(FlutterError(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func getOneRecordFile(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }

        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "getOneRecordFile Required arguments are not provided", details: nil))
            return
        }
        let fieldName = args["fieldName"] as? String ?? "sqlite_file"

        let recordID = CKRecord.ID(recordName: id)
        Task {
            do {
                let fetchedRecord = try await database!.record(for: recordID)
                if let asset = fetchedRecord[fieldName] as? CKAsset,
                   let assetURL = asset.fileURL {
                    result(assetURL.absoluteString)
                } else {
                    result(FlutterError(code: "ASSET_ERROR", message: "Asset not found or invalid", details: nil))
                }
            } catch {
                result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func checkOneRecordAvailable(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }

        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "checkOneRecordAvailable Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)
        Task {
            do {
                _ = try await database!.record(for: recordID)
                result(id)
            } catch {
                if error.localizedDescription.contains("Record not found") {
                    result(nil)
                } else {
                    result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func editRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let dataString = args["data"] as? String,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "editRecord Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)

        Task {
            do {
                let newRecord = try await database!.record(for: recordID)
                if let jsonData = dataString.data(using: .utf8) {
                    if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                        newRecord.setValuesForKeys(jsonDict)
                    }
                }
                let editedRecord = try await self.database!.save(newRecord)
                let re = try self.parseRecord(editedRecord)
                result(re)
            } catch {
                result(FlutterError(code: "EDIT_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func getAllRecords(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? Dictionary<String, Any>,
              let type = args["type"] as? String,
              let queryString = args["query"] as? String,
              let fields = args["fields"] as? [String]
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "getAllRecords Required arguments are not provided", details: nil))
            return
        }
        let limit = args["limit"] as? Int
        var predicateQuery = NSPredicate(value: true)
        if !queryString.isEmpty {
            predicateQuery = NSPredicate(format: queryString)
        }
        let query = CKQuery(recordType: type, predicate: predicateQuery)
        var fieldToGet = fields
        fieldToGet.append("creationDate")
        self._keepLoadRecords(query: query, cursor: nil, result: result, data: [], fields: fieldToGet, limit: limit)
    }

    private func getRecordFileInfo(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String,
              let fields = args["fields"] as? [String]
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "getRecordFileInfo Required arguments are not provided", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)
        Task {
            do {
                let fetchedRecord = try await database!.record(for: recordID)
                let fileName = fetchedRecord.recordID.recordName
                var dictionary: [String: String] = ["id": fileName]
                if let creationDate = fetchedRecord.creationDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let dateString = dateFormatter.string(from: creationDate)
                    dictionary["creationDate"] = dateString
                }
                for field in fields {
                    if let value = fetchedRecord[field] as? String {
                        dictionary[field] = value
                    }
                }
                result(dictionary)
            } catch {
                result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func _keepLoadRecords(query: CKQuery? = nil, cursor: CKQueryOperation.Cursor? = nil, result: @escaping FlutterResult, data: [Any], fields: [String], limit: Int? = nil) {
        var mergedData: [Any] = data
        var operation: CKQueryOperation
        if let query = query {
            operation = CKQueryOperation(query: query)
        } else {
            operation = CKQueryOperation(cursor: cursor!)
        }

        operation.resultsLimit = limit ?? 400
        operation.desiredKeys = fields
        operation.recordMatchedBlock = { _, recordResult in
            switch recordResult {
            case .success(let record):
                let fileName = record.recordID.recordName
                var dictionary: [String: String] = ["id": fileName]
                if let creationDate = record.creationDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let dateString = dateFormatter.string(from: creationDate)
                    dictionary["creationDate"] = dateString
                }
                for field in fields {
                    if let value = record[field] as? String {
                        dictionary[field] = value
                    }
                }
                mergedData.append(dictionary)
            case .failure:
                break
            }
        }
        operation.queryResultBlock = { operationResult in
            DispatchQueue.main.async {
                switch operationResult {
                case .success(let cursor):
                    if mergedData.count >= limit ?? 0 {
                        result(mergedData)
                    } else if let cursor = cursor {
                        self._keepLoadRecords(query: nil, cursor: cursor, result: result, data: mergedData, fields: fields, limit: limit)
                    } else {
                        result(mergedData)
                    }
                case .failure(let error):
                    result(FlutterError(code: "GET_DATA_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
        database?.add(operation)
    }

    private func deleteRecord(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let id = args["id"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "deleteRecord Required arguments are not provided", details: nil))
            return
        }
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }

        let recordID = CKRecord.ID(recordName: id)

        Task {
            do {
                try await database!.deleteRecord(withID: recordID)
                result(nil)
            } catch {
                result(FlutterError(code: "DELETE_ERROR", message: "Failed to delete data", details: nil))
            }
        }
    }

    private func deleteManyRecords(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let ids = args["ids"] as? String
        else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "deleteRecord Required arguments are not provided", details: nil))
            return
        }
        guard database != nil else {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Storage not initialized", details: nil))
            return
        }

        let stringRecordIDs: [String] = ids.split(separator: ",").map { String($0) }
        var recordIDsToDelete: [CKRecord.ID] = []

        for stringID in stringRecordIDs {
            let recordID = CKRecord.ID(recordName: stringID)
            recordIDsToDelete.append(recordID)
        }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
        operation.modifyRecordsResultBlock = { operationResult in
            switch operationResult {
            case .success:
                print("Records deleted successfully")
            case .failure(let error):
                print("Error deleting records: \(error)")
            }
        }

        operation.qualityOfService = .userInitiated
        database?.add(operation)
        result(nil)
    }
}
