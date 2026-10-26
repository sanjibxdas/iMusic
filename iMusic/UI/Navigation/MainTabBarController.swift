import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }

    private func setupTabs() {
        // Tab 1: Home
        let homeVC = HomeViewController()
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: IconFactory.tabHome(size: 24), tag: 0)

        // Tab 2: Explore
        let exploreVC = ExploreViewController()
        let exploreNav = UINavigationController(rootViewController: exploreVC)
        exploreNav.tabBarItem = UITabBarItem(title: "Explore", image: IconFactory.tabExplore(size: 24), tag: 1)

        // Tab 3: Library
        let libraryVC = LibraryViewController()
        let libraryNav = UINavigationController(rootViewController: libraryVC)
        libraryNav.tabBarItem = UITabBarItem(title: "Library", image: IconFactory.tabLibrary(size: 24), tag: 2)

        // Tab 4: Search
        let searchVC = SearchViewController()
        let searchNav = UINavigationController(rootViewController: searchVC)
        searchNav.tabBarItem = UITabBarItem(title: "Search", image: IconFactory.tabSearch(size: 24), tag: 3)

        viewControllers = [homeNav, exploreNav, libraryNav, searchNav]
    }

    private func setupAppearance() {
        tabBar.tintColor = AppTheme.accent
        tabBar.unselectedItemTintColor = AppTheme.textTertiary
        tabBar.barTintColor = AppTheme.background
        tabBar.isTranslucent = true
    }
}
