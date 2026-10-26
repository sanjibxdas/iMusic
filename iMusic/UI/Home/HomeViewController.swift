import UIKit

final class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .grouped)

    private var recentTracks: [Track] = []
    private var listenAgainTracks: [Track] = []
    private var downloadedTracks: [Track] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupTableView()
        registerObservers()
        refreshLocalSections()
    }

    private func setupNavigation() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.barTintColor = AppTheme.background
        navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        let shortsTitle = SettingsManager.shared.hideShorts ? "Shorts: Hidden" : "Hide Shorts"
        let shortsItem = UIBarButtonItem(title: shortsTitle, style: .plain, target: self, action: #selector(toggleShortsAction))
        shortsItem.tintColor = AppTheme.accent
        navigationItem.rightBarButtonItem = shortsItem
    }

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 106, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 106, right: 0)
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
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(refreshLocalSections), name: StorageManager.historyDidChange, object: nil)
        center.addObserver(self, selector: #selector(refreshLocalSections), name: StorageManager.favoritesDidChange, object: nil)
        center.addObserver(self, selector: #selector(refreshLocalSections), name: DownloadManager.listDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(reloadVisibleRows), name: AudioPlayer.trackDidChange, object: nil)
        center.addObserver(self, selector: #selector(reloadVisibleRows), name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    @objc private func reloadVisibleRows() {
        tableView.reloadData()
    }

    @objc private func toggleShortsAction() {
        SettingsManager.shared.hideShorts.toggle()
        navigationItem.rightBarButtonItem?.title = SettingsManager.shared.hideShorts ? "Shorts: Hidden" : "Hide Shorts"
        refreshLocalSections()
    }

    /// Reads only on-device library state. No recommendation network requests are issued.
    @objc private func refreshLocalSections() {
        let hideShorts = SettingsManager.shared.hideShorts
        func keep(_ track: Track) -> Bool {
            return !hideShorts || !(track.duration > 0 && track.duration <= 60)
        }
        recentTracks = Array(StorageManager.shared.getHistory().filter(keep).prefix(8))
        listenAgainTracks = Array(StorageManager.shared.getFavorites().filter(keep).prefix(8))
        downloadedTracks = Array(DownloadManager.shared.allDownloadedTracks().filter(keep).prefix(8))
        tableView.reloadData()
    }

    private func tracks(in section: Int) -> [Track] {
        switch section {
        case 0: return recentTracks
        case 1: return listenAgainTracks
        default: return downloadedTracks
        }
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int { return 3 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let list = tracks(in: section)
        return list.isEmpty ? 1 : list.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Recent"
        case 1: return "Listen Again"
        default: return "Downloaded"
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textPrimary
            header.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let list = tracks(in: indexPath.section)
        guard !list.isEmpty else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            cell.accessibilityIdentifier = "home.empty"
            switch indexPath.section {
            case 0: cell.textLabel?.text = "Songs you play will appear here."
            case 1: cell.textLabel?.text = "Songs you favorite will appear here."
            default: cell.textLabel?.text = "Downloaded songs will appear here."
            }
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            cell.textLabel?.textColor = AppTheme.textSecondary
            return cell
        }
        let track = list[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else { return UITableViewCell() }
        cell.configure(with: track, isCurrentlyPlaying: AudioPlayer.shared.currentTrack?.id == track.id)
        cell.onMoreTapped = { [weak self] in self?.presentTrackOptions(for: track) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let list = tracks(in: indexPath.section)
        guard indexPath.row < list.count else { return }
        AudioPlayer.shared.play(list, startingAt: indexPath.row)
    }

    private func presentTrackOptions(for track: Track) {
        let alert = UIAlertController(title: track.title, message: track.artist, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Play Next", style: .default) { _ in AudioPlayer.shared.playNext(track) })
        alert.addAction(UIAlertAction(title: "Add to Queue", style: .default) { _ in AudioPlayer.shared.addToQueue(track) })
        let downloaded = DownloadManager.shared.isDownloaded(trackId: track.id)
        alert.addAction(UIAlertAction(title: downloaded ? "Remove Download" : "Download", style: .default) { _ in
            if downloaded {
                DownloadManager.shared.deleteDownload(trackId: track.id)
            } else {
                DownloadManager.shared.download(track: track)
            }
        })
        let favorite = StorageManager.shared.isFavorite(trackId: track.id)
        alert.addAction(UIAlertAction(title: favorite ? "Unfavorite" : "Favorite", style: .default) { _ in
            _ = StorageManager.shared.toggleFavorite(track: track)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
