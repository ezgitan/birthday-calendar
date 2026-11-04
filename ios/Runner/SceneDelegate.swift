import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    private func openWidgetAction(_ url: URL) -> Bool {
        let number = String(url.path.dropFirst())
        guard url.scheme == "iyiki-contact",
              number.range(of: #"^[+][1-9][0-9]{6,14}$"#, options: .regularExpression) != nil else { return false }
        let target: String
        switch url.host {
        case "call": target = "tel:" + number
        case "chat": target = "https://wa.me/" + String(number.dropFirst())
        default: return false
        }
        guard let destination = URL(string: target) else { return false }
        DispatchQueue.main.async { UIApplication.shared.open(destination) }
        return true
    }
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        if let url = connectionOptions.urlContexts.first?.url { _ = openWidgetAction(url) }
    }
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url, openWidgetAction(url) { return }
        super.scene(scene, openURLContexts: URLContexts)
    }
}
