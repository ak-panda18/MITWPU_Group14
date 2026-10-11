import UIKit
import SwiftUI
import FirebaseCore
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var container: AppDependencyContainer?

    /// One Core Data / CloudKit stack for the whole run. Containers are rebuilt around it
    /// (on sign-in and sign-out) so the persistent store is never opened twice.
    private lazy var coreDataStack = CoreDataStack()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let _ = (scene as? UIWindowScene) else { return }

        let c = AppDependencyContainer(coreDataStack: coreDataStack)
        container = c

        iCloudKeyValueStore.shared.startSyncing()

        // One-time JSON → CoreData migration. Runs once per install, no-ops thereafter.
        c.analyticsStore.migrateJSONToCoreData()

        if let currentUser = Auth.auth().currentUser {
            c.childManager.resolveChild(uid: currentUser.uid)
            // Configure UID-scoped stores before showing home
            StreakStore.shared.configure(uid: currentUser.uid)
            // Start Firestore sync — authenticated users who restart the app
            // without signing out would otherwise never get remote data.
            c.syncService.startSync(uid: currentUser.uid)
            syncReminders(uid: currentUser.uid, container: c)
            showHome(container: c)
        } else {
            // TODO: Uncomment the condition below to only show onboarding if the user has never seen it.
            // if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            //     showAuth(container: c)
            // } else {
            //     showOnboarding()
            // }

            // For now, always show onboarding:
            showOnboarding()
        }
    }

    func showOnboarding() {
        guard let c = container else { return }
        let onboardingView = OnboardingView {
            self.showAuth(container: c, startAtSignUp: true)
        }
        let host = UIHostingController(rootView: onboardingView)
        host.modalPresentationStyle = .fullScreen
        window?.rootViewController = host
    }

    func showHome(container c: AppDependencyContainer) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let homeNav = sb.instantiateViewController(
            withIdentifier: "HomeNavController") as? UINavigationController,
              let homeVC = homeNav.viewControllers.first as? HomeViewController
        else { return }
        c.inject(into: homeVC)
        window?.rootViewController = homeNav
    }

    func showAuth(container c: AppDependencyContainer, startAtSignUp: Bool = false) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let signInVC = sb.instantiateViewController(
            withIdentifier: "SignInViewController") as? SignInViewController
        else { return }
        signInVC.childManager = c.childManager

        var vcs: [UIViewController] = [signInVC]

        if startAtSignUp, let signUpVC = sb.instantiateViewController(
            withIdentifier: "SignUpViewController") as? SignUpViewController {
            signUpVC.childManager = c.childManager
            vcs.append(signUpVC)
        }

        let nav = UINavigationController()
        nav.viewControllers = vcs
        nav.setNavigationBarHidden(true, animated: false)
        window?.rootViewController = nav
    }

    // Called after successful sign-in.
    // The container is rebuilt AFTER sign-in so uid-scoped managers (PhonicsFlowManager,
    // SkipManager) are created with the real Firebase uid. The container that exists at this
    // point was built while signed out, so its managers would otherwise keep a guest uid.
    func showHomeAfterAuth() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        container?.syncService.stopSync()

        let c = AppDependencyContainer(coreDataStack: coreDataStack)
        container = c

        c.childManager.resolveChild(uid: uid)
        StreakStore.shared.configure(uid: uid)
        // sceneDidBecomeActive already fired before sign-in, so record today here.
        c.streakStore.recordToday()
        c.profileStore.recordAppOpen(uid: uid)
        c.syncService.startSync(uid: uid)
        syncReminders(uid: uid, container: c)
        _navigateHome(container: c)
    }

    /// Reminders are local notifications, so every device has to schedule its own.
    /// Schedule from the local cache immediately, then again once Firestore's settings arrive.
    private func syncReminders(uid: String, container c: AppDependencyContainer) {
        c.profileStore.scheduleNotifications(uid: uid)
        c.profileStore.fetchSettings(uid: uid) { [weak c] _, _, _, _ in
            c?.profileStore.scheduleNotifications(uid: uid)
        }
    }

    private func _navigateHome(container c: AppDependencyContainer) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let homeNav = sb.instantiateViewController(
            withIdentifier: "HomeNavController") as? UINavigationController,
              let homeVC = homeNav.viewControllers.first as? HomeViewController
        else { return }
        c.inject(into: homeVC)
        window?.rootViewController = homeNav
        guard let window else { return }
        UIView.transition(with: window, duration: 0.35,
                          options: .transitionCrossDissolve, animations: nil)
    }

    // Called after sign-out. Clears all local user state then rebuilds the container.
    func showAuthAfterSignOut() {
        container?.syncService.stopSync()

        try? Auth.auth().signOut()

        // The previous user's reminders must not keep firing for the next account.
        container?.profileStore.cancelAllNotifications()

        container?.streakStore.reset()
        container?.phonicsFlowManager.reset()
        container?.skipManager.reset()
        container?.ocrManager.reset()
        UserDefaults.standard.removeObject(forKey: "firebaseUID")
        UserDefaults.standard.removeObject(forKey: "activeChildId")

        container?.coreDataStack.flushPendingSave()

        let fresh = AppDependencyContainer(coreDataStack: coreDataStack)
        container = fresh

        showAuth(container: fresh)
    }

    // MARK: - Scene Lifecycle
    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let firebaseUID = Auth.auth().currentUser?.uid else { return }
        container?.streakStore.recordToday()
        container?.profileStore.recordAppOpen(uid: firebaseUID)
    }

    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {
        container?.coreDataStack.flushPendingSave()
    }
}
