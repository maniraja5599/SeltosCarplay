import UIKit
import CarPlay

/// Scene delegate managing CarPlay lifecycle, template connection, and vehicle interface
public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?

    // MARK: - CPTemplateApplicationSceneDelegate

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        CarPlayTemplateManager.shared.setInterfaceController(interfaceController)

        // Start motion and safety monitoring
        CarPlaySafetyMonitor.shared.startMonitoring()

        // Create and present root tab bar template
        let rootTemplate = CarPlayTemplateManager.shared.createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: false) { success, error in
            if let error = error {
                print("[CarPlaySceneDelegate] Error setting root template: \(error.localizedDescription)")
            } else {
                print("[CarPlaySceneDelegate] CarPlay root template established successfully.")
            }
        }
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        CarPlaySafetyMonitor.shared.stopMonitoring()
        self.interfaceController = nil
        print("[CarPlaySceneDelegate] CarPlay interface controller disconnected.")
    }
}
