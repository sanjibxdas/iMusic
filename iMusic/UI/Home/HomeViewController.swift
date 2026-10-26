import UIKit

final class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private var recentTracks: [Track] = []
    private var listenAgainTracks: [Track] = []
    private var quickPicks: [Track] = []
    private var featuredPlaylists: [Playlist] = []
    private var freshFinds: [Track] = []
    private var oldFavorites: [Track] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupTableView()
        registerObservers()
        loadHomeData()
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

        // Hide Shorts toggle button in navbar
        let shortsTitle = SettingsManager.shared.hideShorts ? "Shorts: Hidden" : "Hide Shorts"
        let shortsItem = UIBarButtonItem(title: shortsTitle, style: .plain, target: self, action: #selector(toggleShortsAction))
        shortsItem.tintColor = AppTheme.accent
        navigationItem.rightBarButtonItem = shortsItem
    }

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
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
        NotificationCenter.default.addObserver(self, selector: #selector(loadHomeData), name: StorageManager.historyDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(loadHomeData), name: StorageManager.favoritesDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    @objc private func reloadTable() {
        tableView.reloadData()
    }

    @objc private func toggleShortsAction() {
        SettingsManager.shared.hideShorts.toggle()
        let shortsTitle = SettingsManager.shared.hideShorts ? "Shorts: Hidden" : "Hide Shorts"
        navigationItem.rightBarButtonItem?.title = shortsTitle
        loadHomeData()
    }

    @objc private func loadHomeData() {
        let history = StorageManager.shared.getHistory()
        let favorites = StorageManager.shared.getFavorites()

        // Filter out tracks < 60s if hideShorts is enabled
        let filterShorts: (Track) -> Bool = { track in
            if SettingsManager.shared.hideShorts && track.duration > 0 && track.duration <= 60 {
                return false
            }
            return true
        }

        self.recentTracks = Array(history.filter(filterShorts).prefix(8))
        self.listenAgainTracks = Array(favorites.filter(filterShorts).prefix(8))

        MusicAPIService.shared.fetchTopCharts { [weak self] tracks in
            guard let self = self else { return }
            let filtered = tracks.filter(filterShorts)
            self.quickPicks = Array(filtered.prefix(6))
            self.freshFinds = Array(filtered.dropFirst(6).prefix(6))
            self.oldFavorites = Array(filtered.suffix(6))
            self.tableView.reloadData()
        }

        MusicAPIService.shared.fetchFeaturedPlaylists { [weak self] playlists in
            guard let self = self else { return }
            self.featuredPlaylists = playlists
            self.tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return recentTracks.isEmpty ? 1 : recentTracks.count
        case 1: return listenAgainTracks.isEmpty ? 1 : listenAgainTracks.count
        case 2: return quickPicks.count
        case 3: return featuredPlaylists.count
        case 4: return freshFinds.count
        case 5: return oldFavorites.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Recent"
        case 1: return "Listen Again"
        case 2: return "Quick Picks"
        case 3: return "Featured Playlists for You"
        case 4: return "Fresh Finds"
        case 5: return "Old Favorites"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textPrimary
            header.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Handle Empty States
        if indexPath.section == 0 && recentTracks.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = "Recently played tracks will appear here."
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            cell.textLabel?.textColor = AppTheme.textSecondary
            cell.selectionStyle = .none
            return cell
        }

        if indexPath.section == 1 && listenAgainTracks.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = "Songs you favorite will appear here."
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            cell.textLabel?.textColor = AppTheme.textSecondary
            cell.selectionStyle = .none
            return cell
        }

        // Featured Playlists section
        if indexPath.section == 3 {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.accessoryType = .disclosureIndicator
            let p = featuredPlaylists[indexPath.row]
            cell.textLabel?.text = p.title
            cell.textLabel?.textColor = AppTheme.textPrimary
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            cell.detailTextLabel?.text = p.author ?? "Apple Music"
            cell.detailTextLabel?.textColor = AppTheme.textSecondary
            return cell
        }

        // Track list cells
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
            return UITableViewCell()
        }

        let track: Track
        switch indexPath.section {
        case 0: track = recentTracks[indexPath.row]
        case 1: track = listenAgainTracks[indexPath.row]
        case 2: track = quickPicks[indexPath.row]
        case 4: track = freshFinds[indexPath.row]
        case 5: track = oldFavorites[indexPath.row]
        default: return UITableViewCell()
        }

        let isCurrent = (AudioPlayer.shared.currentTrack?.id == track.id)
        cell.configure(with: track, isCurrentlyPlaying: isCurrent)
        cell.onMoreTapped = { [weak self] in
            self?.presentTrackOptions(for: track)
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 3 {
            let playlist = featuredPlaylists[indexPath.row]
            var detailPlaylist = playlist
            if detailPlaylist.tracks.isEmpty {
                detailPlaylist.tracks = quickPicks + freshFinds
            }
            let detailVC = PlaylistDetailViewController(playlist: detailPlaylist)
            navigationController?.pushViewController(detailVC, animated: true)
            return
        }

        let targetList: [Track]
        switch indexPath.section {
        case 0: targetList = recentTracks
        case 1: targetList = listenAgainTracks
        case 2: targetList = quickPicks
        case 4: targetList = freshFinds
        case 5: targetList = oldFavorites
        default: return
        }

        guard !targetList.isEmpty && indexPath.row < targetList.count else { return }
        AudioPlayer.shared.play(targetList, startingAt: indexPath.row)
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
