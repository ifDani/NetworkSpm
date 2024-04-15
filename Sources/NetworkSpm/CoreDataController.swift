//
//  File.swift
//  
//
//  Created by Daniel Carracedo  on 15/4/24.
//

import CoreData

open class CoreData: CoreDataProtocol {
    public var manager: CoreDataController = CoreDataController()

    public init() {}
}

public class CoreDataController: CoreDataControllerProtocol {
    public static let shared = CoreDataController()

    private static var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CoreDataModel")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("💾🟢 [COREDATA]: [SUCCESS CONFIGURED]")
        })
        return container
    }()

    public lazy var mainQueueContext: NSManagedObjectContext = {
        let context = Self.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        return context
    }()

    @discardableResult
    public func saveData() -> Result<Void, CoreDataError> {
        let context = self.mainQueueContext

        if context.hasChanges {
            do {
                try context.save()
                print("💾🔵 [COREDATA]: [SAVEDATA SUCCESS]")
                return .success(())
            } catch {
                let nserror = error as NSError
                print("💾🔴 [COREDATA] [SAVEDATA][ERROR]: [\(nserror) -- \(nserror.userInfo)]")
                return .failure(.saveError)
            }
        } else {
            return .success(())
        }
    }

    public func getSavedData<T: NSManagedObject>(_ objectType: T.Type) -> Result<[T], CoreDataError> {
        let context = self.mainQueueContext

        let entityName = String(describing: objectType)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        do {
            let fetchedObjects = try context.fetch(fetchRequest) as? [T]
            print("💾🔵 [COREDATA]: [GET-SAVEDATA SUCCESS]")
            return .success(fetchedObjects ?? [T]())
        } catch {
            print("💾🔴 [COREDATA] [GET-SAVEDATA][ERROR]: [\(error.localizedDescription)]")
            return .failure(.fetchError)
        }
    }

    @discardableResult
    public func deleteSavedData<T: NSManagedObject>(_ objectType: T.Type) -> Result<Void, CoreDataError> {
        let context = self.mainQueueContext

        let entityName = String(describing: objectType)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            print("💾🔵 [COREDATA]: [DELETE-SAVEDATA SUCCESS]")
            return .success(())
        } catch let error {
            print("💾🔴 [COREDATA] [DELETE-SAVEDATA][ERROR]: [\(error.localizedDescription)]")
            return .failure(.deleteError)
        }
    }
}

// MARK: - CRUD Methods
extension CoreDataController {
    private func create<T: NSManagedObject>(_ objectType: T.Type) -> T? {
        let context = mainQueueContext
        if let entityName = T.entity().name {
            if let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? T {
                return newObject
            }
        }
        return nil
    }

    private func get<T: NSManagedObject>(predicate: NSPredicate? = nil) throws -> [T] {
        let context = self.mainQueueContext

        // Define the request.
        let entityName = String(describing: T.self)
        let request = NSFetchRequest<T>(entityName: entityName)

        if let predicate = predicate {
            request.predicate = predicate
        }

        // Query objects.
        return try context.fetch(request)
    }

    private func getFirst<T: NSManagedObject>(predicate: NSPredicate) throws -> T {
        let matches: [T] = try self.get(predicate: predicate)
        guard let match = matches.first else {
            throw CoreDataError.fetchError
        }
        return match
    }

    private func exists<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate) -> Bool {
        guard let _: T = try? getFirst(predicate: predicate) else {
            return false
        }
        return true
    }

    private func count<T: NSManagedObject>(_ type: T.Type) -> Int {
        let context = self.mainQueueContext

        // Define the request.
        let entityName = String(describing: T.self)
        let request = NSFetchRequest<NSNumber>(entityName: entityName)
        request.resultType = .countResultType

        do {
            let counts: [NSNumber] = try! context.fetch(request)
            return Int(truncating: counts[0])
        }
    }

    private func delete<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate) throws {
        let context = self.mainQueueContext

        // Query the objects with the given predicate format.
        let matches: [T] = try self.get(predicate: predicate)

        // Try to delete them from context.
        matches.forEach {
            context.delete($0)
        }

        // Save context.
        try context.save()
    }

    // MARK: ‼️ Used for delete objects specifing context ‼️
    private func delete<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate, context: NSManagedObjectContext) throws {
        // Query the objects with the given predicate format.
        let matches: [T] = try self.get(predicate: predicate)

        // Try to delete them from context.
        matches.forEach {
            context.delete($0)
        }

        // Save context.
        try context.save()
    }
}

