import UIKit

final class LibraryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let librarySections = [
        ("Downloaded Files", "Offline saved songs", IconFactory.downloaded(size: 20)),
        ("Local Music", "Device audio files", IconFactory.tabLibrary(size: 20)),
        ("Downloaded Playlists", "Offline playlists & import", IconFactory.queue(size: 20)),
        ("Liked Music", "Your favorite songs", IconFactory.heart(filled: true, size: 20)),
        ("Artists You Follow", "Artists & recommendations", IconFactory.userProfile(size: 20)),
        ("Subscriptions", "Channels & releases", IconFactory.tabExplore(size: 20)),
        ("Podcasts to Explore", "Talk, comedy & news", IconFactory.tabRadio(size: 20))
    ]

    private var recentlyAdded: [Track] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupTableView()
        registerObservers()
        loadRecentlyAdded()
    }

    private func setupNavigation() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.barTintColor = AppTheme.background
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: AppTheme.textPrimary
        ]
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: AppTheme.textPrimary
        ]

        // Small rounded Profile / Account button at top-right
        let profileBtn = UIButton(type: .custom)
        profileBtn.setImage(IconFactory.userProfile(size: 24), for: .normal)
        profileBtn.tintColor = AppTheme.accent
        profileBtn.backgroundColor = AppTheme.surfaceElevated
        profileBtn.layer.cornerRadius = 16
        profileBtn.clipsToBounds = true
        profileBtn.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        profileBtn.addTarget(self, action: #selector(profileMenuAction), for: .touchUpInside)

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: profileBtn)
    }

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TrackCell.self, forCellReuseIdentifier: TrackCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(loadRecentlyAdded), name: StorageManager.historyDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(loadRecentlyAdded), name: StorageManager.favoritesDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(loadRecentlyAdded), name: DownloadManager.listDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    @objc private func loadRecentlyAdded() {
        self.recentlyAdded = StorageManager.shared.getHistory()
        tableView.reloadData()
    }

    @objc private func reloadTable() {
        tableView.reloadData()
    }

    @objc private func profileMenuAction() {
        let isConnected = YouTubeAccountManager.shared.isConnected
        let accountTitle = isConnected ? "Manage Account (\(YouTubeAccountManager.shared.currentAccount?.name ?? ""))" : "Add YouTube Music Account"

        let alert = UIAlertController(title: "Account & Settings", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: accountTitle, style: .default, handler: { [weak self] _ in
            let accVC = AccountViewController()
            let nav = UINavigationController(rootViewController: accVC)
            self?.present(nav, animated: true, completion: nil)
        }))

        if isConnected {
            alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive, handler: { _ in
                YouTubeAccountManager.shared.signOut()
            }))
        }

        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { [weak self] _ in
            let setVC = SettingsViewController()
            let nav = UINavigationController(rootViewController: setVC)
            self?.present(nav, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return librarySections.count
        } else {
            return recentlyAdded.isEmpty ? 1 : recentlyAdded.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 1 ? "Recently Added" : nil
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textPrimary
            header.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.accessoryType = .disclosureIndicator

            let item = librarySections[indexPath.row]
            cell.textLabel?.text = item.0
            cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
            cell.textLabel?.textColor = AppTheme.textPrimary

            cell.detailTextLabel?.text = item.1
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            cell.detailTextLabel?.textColor = AppTheme.textSecondary

            cell.imageView?.image = item.2
            cell.imageView?.tintColor = AppTheme.accent
            return cell
        } else {
            if recentlyAdded.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = .clear
                cell.textLabel?.text = "Songs you play will appear here."
                cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                cell.textLabel?.textColor = AppTheme.textSecondary
                cell.selectionStyle = .none
                return cell
            }

            guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
                return UITableViewCell()
            }
            let track = recentlyAdded[indexPath.row]
            let isCurrent = (AudioPlayer.shared.currentTrack?.id == track.id)
            cell.configure(with: track, isCurrentlyPlaying: isCurrent)
            cell.onMoreTapped = { [weak self] in
                self?.presentTrackOptions(for: track)
            }
            return cell
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            let sectionName = librarySections[indexPath.row].0
            switch sectionName {
            case "Downloaded Files", "Local Music":
                let downVC = DownloadedTracksViewController()
                navigationController?.pushViewController(downVC, animated: true)

            case "Liked Music":
                let favs = StorageManager.shared.getFavorites()
                let playlist = Playlist(id: "liked_music", title: "Liked Music", author: "You", thumbnailUrl: favs.first?.artworkUrl, trackCount: favs.count, tracks: favs)
                let detailVC = PlaylistDetailViewController(playlist: playlist)
                navigationController?.pushViewController(detailVC, animated: true)

            case "Downloaded Playlists":
                let downVC = DownloadedPlaylistsViewController()
                navigationController?.pushViewController(downVC, animated: true)

            case "Artists You Follow":
                let exploreVC = CategoryDetailViewController(categoryName: "Top Artists")
                navigationController?.pushViewController(exploreVC, animated: true)

            case "Subscriptions":
                let exploreVC = CategoryDetailViewController(categoryName: "Subscriptions")
                navigationController?.pushViewController(exploreVC, animated: true)

            case "Podcasts to Explore":
                let exploreVC = CategoryDetailViewController(categoryName: "Podcasts")
                navigationController?.pushViewController(exploreVC, animated: true)

            default:
                break
            }
        } else if !recentlyAdded.isEmpty {
            AudioPlayer.shared.play(recentlyAdded, startingAt: indexPath.row)
        }
    }

    private func presentTrackOptions(for track: Track) {
        let alert = UIAlertController(title: track.title, message: track.artist, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Play Next", style: .default, handler: { _ in
            AudioPlayer.shared.playNext(track)
        }))
        alert.addAction(UIAlertAction(title: "Add to Queue", style: .default, handler: { _ in
            AudioPlayer.shared.addToQueue(track)
        }))
        let isDownloaded = DownloadManager.shared.isDownloaded(trackId: track.id)
        alert.addAction(UIAlertAction(title: isDownloaded ? "Remove Download" : "Download", style: .default, handler: { _ in
            if isDownloaded {
                DownloadManager.shared.deleteDownload(trackId: track.id)
            } else {
                DownloadManager.shared.download(track: track)
            }
        }))
        let isFav = StorageManager.shared.isFavorite(trackId: track.id)
        alert.addAction(UIAlertAction(title: isFav ? "Unfavorite" : "Favorite", style: .default, handler: { _ in
            _ = StorageManager.shared.toggleFavorite(track: track)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
