import UIKit

final class RootContainerViewController: UIViewController {

    private let tabBarVC = MainTabBarController()
    private let miniPlayer = MiniPlayerView()
    private var miniPlayerBottomConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background

        // 1. Add Main Tab Bar Controller
        addChild(tabBarVC)
        tabBarVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBarVC.view)
        tabBarVC.didMove(toParent: self)

        // 2. Add Floating Mini Player
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        miniPlayer.onTap = { [weak self] in
            self?.presentNowPlaying()
        }
        view.addSubview(miniPlayer)

        NSLayoutConstraint.activate([
            tabBarVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            tabBarVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabBarVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            miniPlayer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayer.heightAnchor.constraint(equalToConstant: AppTheme.miniPlayerHeight),
            miniPlayer.bottomAnchor.constraint(equalTo: tabBarVC.tabBar.topAnchor)
        ])
    }

    private func presentNowPlaying() {
        let nowPlayingVC = NowPlayingViewController()
        nowPlayingVC.modalPresentationStyle = .overFullScreen
        nowPlayingVC.modalTransitionStyle = .coverVertical
        present(nowPlayingVC, animated: true, completion: nil)
    }
}
