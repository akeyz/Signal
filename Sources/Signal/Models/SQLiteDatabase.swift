import Foundation
import SQLite3

class SQLiteDatabase {
    private var db: OpaquePointer?
    
    init?(path: String) {
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            if let db = db {
                sqlite3_close(db)
            }
            return nil
        }
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    func query(sql: String, parameters: [String] = []) -> [[String: String]] {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            return []
        }
        
        for (index, param) in parameters.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), (param as NSString).utf8String, -1, nil)
        }
        
        var results: [[String: String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: String] = [:]
            let columnCount = sqlite3_column_count(stmt)
            for i in 0..<columnCount {
                if let columnNamePointer = sqlite3_column_name(stmt, i) {
                    let columnName = String(cString: columnNamePointer)
                    if let valPointer = sqlite3_column_text(stmt, i) {
                        let val = String(cString: valPointer)
                        row[columnName] = val
                    } else {
                        row[columnName] = ""
                    }
                }
            }
            results.append(row)
        }
        
        sqlite3_finalize(stmt)
        return results
    }
}
