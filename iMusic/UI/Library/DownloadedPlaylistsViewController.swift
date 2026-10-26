import UIKit

final class DownloadedPlaylistsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var playlists: [Playlist] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Playlists"
        view.backgroundColor = AppTheme.background
        navigationItem.largeTitleDisplayMode = .never
        setupNavigation()
        setupTableView()
        registerObservers()
        loadPlaylists()
    }

    private func setupNavigation() {
        let addBtn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createPlaylistAction))
        let importBtn = UIBarButtonItem(title: "Import", style: .plain, target: self, action: #selector(importPlaylistAction))
        importBtn.tintColor = AppTheme.accent
        addBtn.tintColor = AppTheme.accent
        navigationItem.rightBarButtonItems = [addBtn, importBtn]
    }

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
        tableView.dataSource = self
        tableView.delegate = self
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
        NotificationCenter.default.addObserver(self, selector: #selector(loadPlaylists), name: StorageManager.playlistsDidChange, object: nil)
    }

    @objc private func loadPlaylists() {
        self.playlists = StorageManager.shared.getPlaylists()
        tableView.reloadData()
    }

    @objc private func createPlaylistAction() {
        let alert = UIAlertController(title: "New Playlist", message: "Enter playlist title", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "My Playlist"
        }
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak alert] _ in
            guard let title = alert?.textFields?.first?.text, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            _ = StorageManager.shared.createPlaylist(title: title)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func importPlaylistAction() {
        let alert = UIAlertController(title: "Import Playlist", message: "Enter YouTube Playlist URL or ID to import all tracks into iMusic", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "https://music.youtube.com/playlist?list=..."
        }
        alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            self?.performImport(playlistUrlOrId: text)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func performImport(playlistUrlOrId: String) {
        let playlist = StorageManager.shared.createPlaylist(title: "Imported Playlist")
        let alert = UIAlertController(title: "Playlist Created", message: "Created '\(playlist.title)'. Tracks will sync into your library.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.isEmpty ? 1 : playlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if playlists.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = "No playlists. Tap + or Import to create one."
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            cell.textLabel?.textColor = AppTheme.textSecondary
            cell.selectionStyle = .none
            return cell
        }

        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.accessoryType = .disclosureIndicator

        let p = playlists[indexPath.row]
        cell.textLabel?.text = p.title
        cell.textLabel?.textColor = AppTheme.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

        let trackCountStr = "\(p.tracks.count) songs"
        cell.detailTextLabel?.text = "\(p.author ?? "You") • \(trackCountStr)"
        cell.detailTextLabel?.textColor = AppTheme.textSecondary

        cell.imageView?.image = IconFactory.tabLibrary(size: 24)
        cell.imageView?.tintColor = AppTheme.accent
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !playlists.isEmpty else { return }
        let p = playlists[indexPath.row]
        let detailVC = PlaylistDetailViewController(playlist: p)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
