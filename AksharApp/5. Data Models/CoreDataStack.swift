import CoreData
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "CoreDataStack")

final class CoreDataStack {

    init() {}

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AksharDataModel")

        let storeURL = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("AksharDataModel.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(["journal_mode": "WAL"] as NSDictionary,
                              forKey: NSSQLitePragmasOption)
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                logger.fault("CoreDataStack: failed to load store – \(error), \(error.userInfo)")
                fatalError("CoreDataStack: failed to load store – \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    // MARK: - Contexts
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    // MARK: - Save
    func saveContext() {
        let context = persistentContainer.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            logger.error("CoreDataStack save error: \(nserror), \(nserror.userInfo)")
            assertionFailure("CoreDataStack save error: \(nserror), \(nserror.userInfo)")
        }
    }

    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            logger.error("CoreDataStack background save error: \(nserror), \(nserror.userInfo)")
        }
    }

    // MARK: - Deferred Save 
    private var saveTimer: Timer?

    func deferredSave(after delay: TimeInterval = 1.5) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.saveContext()
        }
    }

    func flushPendingSave() {
        saveTimer?.invalidate()
        saveTimer = nil
        saveContext()
    }
}
