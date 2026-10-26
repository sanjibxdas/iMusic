import UIKit

final class RootContainerViewController: UIViewController {

    private let tabBarVC = MainTabBarController()
    private let miniPlayer = MiniPlayerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background

        addChild(tabBarVC)
        tabBarVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBarVC.view)
        tabBarVC.didMove(toParent: self)

        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        miniPlayer.onTap = { [weak self] in self?.presentNowPlaying() }
        miniPlayer.onPlayPause = { AudioPlayer.shared.togglePlayPause() }
        miniPlayer.onNext = { AudioPlayer.shared.next() }
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
        guard presentedViewController == nil, AudioPlayer.shared.currentTrack != nil else { return }
        let nowPlayingVC = NowPlayingViewController()
        nowPlayingVC.modalPresentationStyle = .fullScreen
        nowPlayingVC.modalTransitionStyle = .coverVertical
        present(nowPlayingVC, animated: true, completion: nil)
    }
}
