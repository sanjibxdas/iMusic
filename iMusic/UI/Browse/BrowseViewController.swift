import UIKit

final class BrowseViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var topTracks: [Track] = []
    private var featuredPlaylists: [Playlist] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Browse"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupTableView()
        loadData()
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

    private func loadData() {
        MusicAPIService.shared.fetchTopCharts { [weak self] tracks in
            DispatchQueue.main.async {
                self?.topTracks = tracks
                self?.tableView.reloadData()
            }
        }

        MusicAPIService.shared.fetchFeaturedPlaylists { [weak self] list in
            DispatchQueue.main.async {
                self?.featuredPlaylists = list
                self?.tableView.reloadData()
            }
        }
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return featuredPlaylists.count
        } else {
            return topTracks.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Featured Playlists" : "Top Charts"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textPrimary
            header.textLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
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
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
                return UITableViewCell()
            }
            let track = topTracks[indexPath.row]
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
            var playlist = featuredPlaylists[indexPath.row]
            if playlist.tracks.isEmpty {
                playlist.tracks = topTracks
            }
            let detailVC = PlaylistDetailViewController(playlist: playlist)
            navigationController?.pushViewController(detailVC, animated: true)
        } else {
            AudioPlayer.shared.play(topTracks, startingAt: indexPath.row)
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
}
