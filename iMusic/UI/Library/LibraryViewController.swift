import UIKit

final class LibraryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let menuItems = [
        "Playlists",
        "Artists",
        "Albums",
        "Songs",
        "Favorites"
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

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(editAction)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent
    }

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
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
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.trackDidChange, object: nil)
    }

    @objc private func loadRecentlyAdded() {
        self.recentlyAdded = StorageManager.shared.getHistory()
        tableView.reloadData()
    }

    @objc private func reloadTable() {
        tableView.reloadData()
    }

    @objc private func editAction() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        navigationItem.rightBarButtonItem?.title = tableView.isEditing ? "Done" : "Edit"
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return menuItems.count
        } else {
            return recentlyAdded.isEmpty ? 1 : recentlyAdded.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Recently Added"
        }
        return nil
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textPrimary
            header.textLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = menuItems[indexPath.row]
            cell.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular)
            cell.textLabel?.textColor = AppTheme.accent
            cell.accessoryType = .disclosureIndicator
            return cell
        } else {
            if recentlyAdded.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = .clear
                cell.textLabel?.text = "Songs you play will appear here."
                cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
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
            let item = menuItems[indexPath.row]
            switch item {
            case "Favorites":
                let favs = StorageManager.shared.getFavorites()
                let playlist = Playlist(id: "favorites", title: "Favorite Songs", author: "You", thumbnailUrl: favs.first?.artworkUrl, trackCount: favs.count, tracks: favs)
                let detailVC = PlaylistDetailViewController(playlist: playlist)
                navigationController?.pushViewController(detailVC, animated: true)
            case "Playlists":
                let userPlaylists = StorageManager.shared.getPlaylists()
                let playlist = Playlist(id: "all_playlists", title: "Playlists", author: "You", tracks: userPlaylists.flatMap { $0.tracks })
                let detailVC = PlaylistDetailViewController(playlist: playlist)
                navigationController?.pushViewController(detailVC, animated: true)
            default:
                let songs = StorageManager.shared.getHistory()
                let playlist = Playlist(id: "all_songs", title: item, author: "Library", tracks: songs)
                let detailVC = PlaylistDetailViewController(playlist: playlist)
                navigationController?.pushViewController(detailVC, animated: true)
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
