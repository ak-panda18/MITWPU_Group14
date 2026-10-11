import CoreData
import UIKit
import FirebaseAuth
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "ChildManager")

final class ChildManager {

    private let coreData: CoreDataStack
    private let activeKey = "activeChildId"
    private(set) var currentChild: ChildEntity

    // Injected after both objects are created in AppDependencyContainer.
    weak var syncService: FirestoreSyncService?

    // True only when `currentChild` belongs to a signed-in account (not the signed-out guest).
    var hasSignedInChild: Bool {
        currentChild.managedObjectContext != nil && currentChild.firebaseUID != nil
    }

    // MARK: - Init
    init(coreDataStack: CoreDataStack) {
        self.coreData = coreDataStack
        if let uid = Auth.auth().currentUser?.uid,
           let match = ChildManager.fetchChild(uid: uid, context: coreDataStack.context) {
            currentChild = match
        } else {
            currentChild = ChildManager.makeGuestChild(context: coreDataStack.context)
        }
    }

    // MARK: - Firebase UID
    func linkFirebaseUID(_ uid: String) {
        guard currentChild.managedObjectContext != nil else { return }
        currentChild.firebaseUID = uid
        coreData.saveContext()
        UserDefaults.standard.set(uid, forKey: "firebaseUID")
    }

    // Finds (or creates) the child that belongs to this Firebase UID and makes it current.
    func resolveChild(uid: String) {
        if let match = ChildManager.fetchChild(uid: uid, context: coreData.context) {
            logger.info("ChildManager: resolved existing child id=\(match.id?.uuidString ?? "nil")")
            currentChild = match
        } else {
            logger.info("ChildManager: no entity found for uid \(uid) — creating new ChildEntity")
            let child         = ChildEntity(context: coreData.context)
            child.id          = UUID()
            child.firebaseUID = uid
            let displayName   = Auth.auth().currentUser?.displayName
            child.name        = displayName ?? "Child"
            child.firstName   = displayName ?? ""
            child.createdAt   = Date()
            coreData.saveContext()
            currentChild = child
        }
        UserDefaults.standard.set(currentChild.id?.uuidString, forKey: activeKey)
        UserDefaults.standard.set(uid, forKey: "firebaseUID")
    }

    // Call on sign-out: drops back to the un-persisted guest so nothing can write to the old account.
    func clearCurrentChild() {
        currentChild = ChildManager.makeGuestChild(context: coreData.context)
        UserDefaults.standard.removeObject(forKey: activeKey)
        UserDefaults.standard.removeObject(forKey: "firebaseUID")
    }

    // MARK: - Profile data save
    func saveProfileData() {
        coreData.saveContext()
        guard hasSignedInChild else { return }
        let child = currentChild
        syncService?.pushProfile(
            firstName: child.firstName ?? "",
            lastName:  child.lastName  ?? "",
            age:       Int(child.age),
            gender:    child.gender    ?? "",
            name:      child.name      ?? ""
        )
    }

    // MARK: - Account deletion
    func deleteCurrentChild() {
        if currentChild.managedObjectContext != nil {
            coreData.context.delete(currentChild)
            coreData.saveContext()
        }
        clearCurrentChild()
        logger.info("ChildManager: deleted current child and cleared device-local keys")
    }

    // MARK: - Child Management
    func allChildren() -> [ChildEntity] {
        let r: NSFetchRequest<ChildEntity> = ChildEntity.fetchRequest()
        r.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? coreData.context.fetch(r)) ?? []
    }

    func setActiveChild(_ child: ChildEntity) {
        guard let id = child.id?.uuidString else { return }
        UserDefaults.standard.set(id, forKey: activeKey)
        currentChild = child
    }

    @discardableResult
    func addChild(name: String) -> ChildEntity {
        let child = ChildEntity(context: coreData.context)
        child.id = UUID(); child.name = name; child.createdAt = Date()
        coreData.saveContext()
        return child
    }

    // MARK: - Private
    private static func fetchChild(uid: String, context: NSManagedObjectContext) -> ChildEntity? {
        let request: NSFetchRequest<ChildEntity> = ChildEntity.fetchRequest()
        request.predicate       = NSPredicate(format: "firebaseUID == %@", uid)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.fetchLimit      = 1
        return try? context.fetch(request).first
    }

    private static func makeGuestChild(context: NSManagedObjectContext) -> ChildEntity {
        guard let entity = NSEntityDescription.entity(forEntityName: "ChildEntity", in: context) else {
            fatalError("ChildManager: ChildEntity missing from the Core Data model")
        }
        let guest       = ChildEntity(entity: entity, insertInto: nil)
        guest.id        = UUID()
        guest.name      = "Guest"
        guest.createdAt = Date()
        return guest
    }
}
