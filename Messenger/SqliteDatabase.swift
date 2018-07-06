import Foundation
import SQLite

protocol TableManager {
    func create(_ db:SqliteDatabase) throws
    func revision(_ db:SqliteDatabase, fromVersion:Int, toVersion:Int) throws
    func clear(_ db:SqliteDatabase) throws
}

class SqliteDatabase {
    
    static let DEBUG = false
    fileprivate let filename:String
    fileprivate let dbVersion:Int
    var conn:Connection?    // created on start()
    fileprivate(set) var ready = false
    
    // db version has to be 1 or above
    init( name:String, version:Int ) {
        dbVersion = version
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        filename = (dir as NSString).appendingPathComponent("\(name)DB.sqlite")

    }
    
    func start() {
        DebugLogger.instance.append( function: "start()", message:"Opening SQLite DB at \(filename)")
        
        do {
            conn = try Connection(filename, readonly:false)
            try updateTables()
            DebugLogger.instance.append( function: "start()", message:"Database ready")
            ready = true
        } catch Result.error(let message){
            DebugLogger.instance.append( function: "start()", message:"Failed to connect to SQLite database at \(filename): \(message)")
        } catch {
            DebugLogger.instance.append( function: "start()", error:error )
        }
    }
    
    func stop() {
        
    }
    
    //
    // MARK: Override these...
    //
    
    func tableManagers() -> [TableManager] {
        assert(false, "Override this function!")
        return [TableManager]()
    }
    
    //
    // MARK: Update tables
    //
    
    fileprivate func updateTables() throws {
        
        // make sure there's a metadata table for this database
        let count = try scalarSql( "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='metadata'" )
        if count == 0 {
            // we need to create the metadata table
            runSql( "CREATE TABLE metadata(name TEXT PRIMARY KEY, value TEXT)" )
        }
        
        // what version is this database?
        let value = try scalarSql( "SELECT value FROM metadata WHERE name='version'" )
        let currentVersion = value == nil ? 0 : Int(value!)
        if dbVersion == currentVersion {
            return  // alls well
        }
        
        if currentVersion == 0 {
            // simply create the desired tables
            createTables()
        } else {
            // otherwise, we need to step the current tables forward
            for v in currentVersion..<dbVersion {
                for mgr in tableManagers() {
                    do {
                        DebugLogger.instance.append( function:"updateTables()", message:"Revising \(mgr) from \(v) to \(v+1)")
                        try mgr.revision(self, fromVersion:v, toVersion:v+1)
                    } catch {
                        DebugLogger.instance.append( function:"updateTables()", message: "Problem revising \(mgr) from \(v) to \(v+1): \(error)")
                    }
                }
            }
        }
        
        // finally, update metadata with new table version
        let params:[Binding?] = ["version",dbVersion]
        runSql( "INSERT OR REPLACE INTO metadata(name,value) VALUES(?,?)", params:params )
    }
    
    //
    // MARK: Execute SQL
    //
    
    @discardableResult func runSql(_ sql:String) -> Bool {
        do {
            if SqliteDatabase.DEBUG { print( "Running \(sql)") }
            try conn!.execute( sql )
            return true
        } catch {
            DebugLogger.instance.append( function:"runSql()", message: "Failed to execute \(sql) because \(error)")
            return false
        }
    }
    
    @discardableResult func runSql(_ sql:String, params:[Binding?] ) -> Statement? {
        do {
            if SqliteDatabase.DEBUG { print( "Running \(sql) \(params)") }
            return try conn!.run( sql, params )
        } catch {
            DebugLogger.instance.append( function:"runSql()", message: "Failed to execute \(sql) with params \(params) because \(error)")
            return nil
        }
    }
    
    func scalarSql(_ sql:String, params:[Binding?] ) throws -> Int64? {
        if SqliteDatabase.DEBUG { print( "Running \(sql) \(params)") }
        return try asScalar( conn!.scalar( sql, params ) )
    }
    
    func scalarSql(_ sql:String ) throws -> Int64? {
        if SqliteDatabase.DEBUG { print( "Running \(sql)") }
        return try asScalar( conn!.scalar( sql ) )
    }
    
    fileprivate func asScalar( _ binding:Binding? ) -> Int64? {
        if let i = binding as? Int64 {
            return i
        } else if let s = binding as? String {
            return Int64(s)
        } else {
            print( "Unknown type \(binding)")
            return nil
        }
    }
    
    func prepare( _ sql:String ) -> Statement {
        if SqliteDatabase.DEBUG {  print( "Preparing \(sql)") }
        let stmt = try! conn!.prepare( sql )
        return stmt
    }
    
    func prepare( _ sql:String, params:[Binding?] ) -> Statement {
        if SqliteDatabase.DEBUG {  print( "Preparing \(sql) with \(params)") }
        let stmt = try! conn!.prepare( sql, params )
        return stmt
    }
    
    func update( _ sql:String, params:[Binding?] ) throws -> Int {
        let count = try conn!.run( Update( sql, params ) )
        return count
    }
    
    // process deletes in batches of 100
    // sqlPartial is of the form "DELETE FROM tablename WHERE id IN("
    func deleteRows(_ sqlPartial:String, keys:[Binding?]) {
        if keys.isEmpty {
            return
        }
        
        var keys = keys
        repeat {
            let params = Array(keys.prefix(100))
            keys.removeFirst(params.count)
            
            let sql = sqlPartial + placeholders(params.count) + ")"
            runSql( sql, params:params )
        } while !keys.isEmpty
    }
    
    // sqlPartial is of the form "DELETE FROM tablename WHERE tid=? AND cid IN("
    func deleteRows(_ sqlPartial:String, fixedParams:[Binding?], inParams:[Binding?]) {
        if inParams.isEmpty {
            return
        }
        
        var inParams = inParams
        repeat {
            var params = Array(inParams.prefix(100))
            inParams.removeFirst(params.count)
            
            params.insert(contentsOf: fixedParams, at: 0)
            
            let sql = sqlPartial + placeholders(params.count - fixedParams.count) + ")"
            runSql( sql, params:params )
        } while !inParams.isEmpty
    }
    
    //
    // MARK: Utility
    //
    
    fileprivate func createTables() {
        print( "Creating tables for new database \(filename)")
        for mgr in tableManagers() {
            do {
                try mgr.create(self)
            } catch {
                DebugLogger.instance.append( function:"createTables()", message:"Problem creating \(mgr) of \(error)")
            }
        }
    }
    
    func clear() {
        for mgr in tableManagers() {
            do {
                try mgr.clear(self)
            } catch {
                DebugLogger.instance.append( function:"clear()", message:"Problem clearing \(mgr) of \(error)")
            }
        }
    }
    
    fileprivate func placeholders(_ count:Int) -> String {
        var result = "?"
        for _ in 1..<count {
            result.append(",?")
        }
        return result
    }
}
