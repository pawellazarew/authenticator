import os.log
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene,
              let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        else { return }
        let contentView = ContentView().environment(\.managedObjectContext, context)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidEnterBackground(_: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }
}

let logger = Logger(subsystem: "io.ososo.Authenticator", category: "debug")
