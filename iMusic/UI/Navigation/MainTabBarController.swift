import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }

    private func setupTabs() {
        // Tab 1: Library
        let libraryVC = LibraryViewController()
        let libraryNav = UINavigationController(rootViewController: libraryVC)
        libraryNav.tabBarItem = UITabBarItem(title: "Library", image: IconFactory.tabLibrary(size: 24), tag: 0)

        // Tab 2: For You
        let forYouVC = ForYouViewController()
        let forYouNav = UINavigationController(rootViewController: forYouVC)
        forYouNav.tabBarItem = UITabBarItem(title: "For You", image: IconFactory.tabForYou(size: 24), tag: 1)

        // Tab 3: Browse
        let browseVC = BrowseViewController()
        let browseNav = UINavigationController(rootViewController: browseVC)
        browseNav.tabBarItem = UITabBarItem(title: "Browse", image: IconFactory.tabBrowse(size: 24), tag: 2)

        // Tab 4: Radio
        let radioVC = RadioViewController()
        let radioNav = UINavigationController(rootViewController: radioVC)
        radioNav.tabBarItem = UITabBarItem(title: "Radio", image: IconFactory.tabRadio(size: 24), tag: 3)

        // Tab 5: Search
        let searchVC = SearchViewController()
        let searchNav = UINavigationController(rootViewController: searchVC)
        searchNav.tabBarItem = UITabBarItem(title: "Search", image: IconFactory.tabSearch(size: 24), tag: 4)

        viewControllers = [libraryNav, forYouNav, browseNav, radioNav, searchNav]
    }

    private func setupAppearance() {
        tabBar.tintColor = AppTheme.accent
        tabBar.unselectedItemTintColor = AppTheme.textTertiary
        tabBar.barTintColor = AppTheme.background
        tabBar.isTranslucent = true
    }
}
