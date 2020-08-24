//

import UIKit

protocol RouterServiceContainer {
    var router: Router { get }
}

protocol Coordinator: class {
    associatedtype ServicesContainerType: RouterServiceContainer
    associatedtype T: UIViewController

    var servicesContainer: ServicesContainerType { get }
    var childCoordinators: [String: Any] { get set }
    var onComplete: (() -> Void)? { get set }

    var initialViewController: T { get }
}

extension Coordinator {
    func push<T: Coordinator>(coordinator: T, from fromViewController: UIViewController, animated: Bool = true) {
        self.servicesContainer.router.push(coordinator: coordinator, from: fromViewController, animated: animated) { [weak self, weak coordinator] in
            guard let coordinator = coordinator else { return }

            self?.free(coordinator: coordinator)
        }

        self.store(coordinator: coordinator)
    }

    func present<T: Coordinator>(coordinator: T) {
        self.servicesContainer.router.present(coordinator: coordinator) { [weak self, weak coordinator] in
            guard let coordinator = coordinator else { return }

            self?.free(coordinator: coordinator)
        }

        self.store(coordinator: coordinator)
    }

    private func store<T: Coordinator>(coordinator: T) {
        self.childCoordinators[String(describing: T.self)] = coordinator
    }

    private func free<T: Coordinator>(coordinator: T) {
        self.childCoordinators[String(describing: T.self)] = nil
    }
}

typealias NavigationBackClosure = (() -> Void)

final class Router: NSObject {
    private var closures: [String: NavigationBackClosure] = [:]
}

extension Router {

    fileprivate func push<A: Coordinator>(coordinator: A,
                                          from fromViewController: UIViewController,
                                          animated: Bool = true,
                                          onNavigateBack closure: NavigationBackClosure?) {

        guard let navigationController = fromViewController.navigationController,
              let currentViewController = navigationController.viewControllers.first else {
            fatalError("Error getting navigation controller from view controller \(String(describing: type(of: fromViewController)))")
        }

        let initialViewController = coordinator.initialViewController
        navigationController.delegate = self
        navigationController.pushViewController(initialViewController, animated: animated)

        if let closure = closure {
            self.closures.updateValue(closure, forKey: initialViewController.description)
        }

        coordinator.onComplete = { [weak navigationController] in
            navigationController?.popToViewController(currentViewController, animated: true)
        }
    }

    fileprivate func present<A: Coordinator>(coordinator: A, onClose closure: NavigationBackClosure?) {
        let initialViewController = coordinator.initialViewController
        self.topViewController.present(initialViewController, animated: true, completion: nil)

        coordinator.onComplete = { [weak self] in
            self?.topViewController.dismiss(animated: true, completion: closure)
        }
    }

    func present(viewController: UIViewController, completion: (() -> Void)? = nil) {
        self.topViewController.present(viewController, animated: true, completion: completion)
    }

    func push<T: UIViewController>(viewController: T,
                                   from fromViewController: UIViewController,
                                   animated: Bool = true,
                                   configurationBlock: ((T) -> Void)? = nil) {

        guard let navigationController = fromViewController.navigationController else {
            fatalError("Error getting navigation controller from view controller \(T.self)")
        }

        configurationBlock?(viewController)
        navigationController.pushViewController(viewController, animated: animated)
    }

    func present<T: UIViewController>(viewController: T,
                                      animated: Bool = true,
                                      configurationBlock: ((T) -> Void)? = nil,
                                      completion: (() -> Void)? = nil) {
        configurationBlock?(viewController)
        self.topViewController.present(viewController, animated: animated, completion: completion)
    }

    func presentPopover<T: UIViewController>(viewController: T, size: CGSize, sourceView: UIView, configurationBlock: ((T) -> Void)? = nil) {
        configurationBlock?(viewController)

        viewController.modalPresentationStyle = .popover
        viewController.preferredContentSize = size

        let presentationController = viewController.presentationController as! UIPopoverPresentationController
        presentationController.sourceView = sourceView
        presentationController.sourceRect = sourceView.bounds
        presentationController.permittedArrowDirections = [.down, .up]

        self.topViewController.present(viewController, animated: true, completion: nil)
    }

    func presentFormSheet<T: UIViewController>(viewController: T, size: CGSize, configurationBlock: ((T) -> Void)? = nil) {
        configurationBlock?(viewController)

        viewController.modalPresentationStyle = .formSheet

        if #available(iOS 13.0, *) {
            viewController.isModalInPresentation = true
        }
        viewController.preferredContentSize = size

        self.topViewController.present(viewController, animated: true, completion: nil)
    }

    func presentFormSheet<T: UIViewController>(with viewController: T, size: CGSize, configurationBlock: ((T) -> Void)? = nil) {
        configurationBlock?(viewController)

        viewController.modalPresentationStyle = .formSheet

        if #available(iOS 13.0, *) {
            viewController.isModalInPresentation = true
        }
        viewController.preferredContentSize = size

        self.topViewController.present(viewController, animated: true, completion: nil)
    }

    func presentPopover<T: UIViewController>(with viewController: T, size: CGSize, sourceView: UIView, configurationBlock: ((T) -> Void)? = nil) {
        viewController.modalPresentationStyle = .popover
        viewController.preferredContentSize = size

        let presentationController = viewController.presentationController as! UIPopoverPresentationController
        presentationController.sourceView = sourceView
        presentationController.sourceRect = sourceView.bounds
        presentationController.permittedArrowDirections = [.down, .up]

        self.topViewController.present(viewController, animated: true, completion: nil)
    }

}

extension Router {

    private var rootViewController: UIViewController {
        return UIApplication.shared.delegate!.window!!.rootViewController!
    }

    var topViewController: UIViewController {
        return self.rootViewController.topViewController
    }
}

extension Router: UINavigationControllerDelegate {

    private func executeClosure(_ viewController: UIViewController) {
        guard let closure = self.closures.removeValue(forKey: viewController.description) else { return }

        closure()
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        guard let previousController = navigationController.transitionCoordinator?.viewController(forKey: .from),
              !navigationController.viewControllers.contains(previousController) else {
                return
        }

        self.executeClosure(previousController)
    }
}

private extension UIViewController {
    private var rootViewController: UIViewController? {
        return UIApplication.shared.delegate?.window??.rootViewController
    }

    var topViewController: UIViewController {
        var current = self.rootViewController ?? self
        while true {
            if let next = current.presentedViewController, !next.isBeingDismissed {
                current = next
            } else {
                return current
            }
        }
    }
}
