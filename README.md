# Description

MVVM-C is one of the most common architectures used to develop iOS application (https://iosdevsurvey.com/2019/01-apple-platform-development/#q12). This project shares an approach for the Coordinator component.

# Implemention

According to this solution, the Coordinator is defined by the following:
```Swift
protocol Coordinator: class {
    associatedtype ServicesContainerType: RouterServiceContainer
    associatedtype T: UIViewController

    var servicesContainer: ServicesContainerType { get }
    var childCoordinators: [String: Any] { get set }
    var onComplete: (() -> Void)? { get set }

    var initialViewController: T { get }
}
```

## servicesContainer

`ServicesContainerType` contains all dependencies(services) to initialize this component. As you might notice, this associated type needs to conform to the protocol `RouterServiceContainer`, which requires the existence of a `Router` instance, responsible for the presentation of the view controllers.

## childCoordinators
A coordinator strong references child coordinators. This may be also helpfull for deep linking.

## onComplete
Closure responsible to clean up / finish the coordinator execution. It is assigned automatically while pushing or presenting coordinators.

## initialViewController
Returns the intial view controller to be displayed by this coordinator.

# Usage

## Coordinator

```Swift
final class ProjectsCoordinator: Coordinator {
    
    struct Services: RouterServiceContainer {
        let router: Router

        let projectsProvider: ProjectsProvider
        let activityManager: ActivityManager
        let locationManager: LocationManager
        let accountManager: AccountManager
    }
    
    static let storyboard: Storyboard = .projects
    let servicesContainer: ProjectsCoordinator.Services
    let initialViewController: UINavigationController

    var childCoordinators: [String: Any] = [:]
    var onComplete: (() -> Void)?
    
    init(servicesContainer: ProjectsCoordinator.Services) {
        self.servicesContainer = servicesContainer
        self.initialViewController = Self.makeInitialViewController(with: servicesContainer)
    }
```

## Presenting / Pushing new coordinators

```Swift
let addProjectCoordinator = AddProjectCoordinator(servicesContainer: AddProjectCoordinator.Services(router: self.servicesContainer.router,
                                                                                                    projectsProvider: self.servicesContainer.projectsProvider,
                                                                                                    locationManager: self.servicesContainer.locationManager))
self.present(coordinator: addProjectCoordinator)
```