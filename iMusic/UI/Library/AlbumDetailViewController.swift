import UIKit

final class AlbumDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let album: Album
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerView = UIView()
    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let playButton = UIButton(type: .custom)
    private let indicator = UIActivityIndicatorView(style: .white)
    private var playlist: Playlist?

    init(album: Album) {
        self.album = album
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = album.title
        view.backgroundColor = AppTheme.background
        navigationItem.largeTitleDisplayMode = .never
        setupHeader()
        setupTableView()
        setupIndicator()
        loadAlbum()
    }

    private func setupHeader() {
        headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 250)
        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.backgroundColor = AppTheme.surfaceElevated
        artworkView.layer.cornerRadius = 8
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(artworkView)
        if let url = album.thumbnailUrl {
            ImageLoader.shared.loadImage(from: url) { [weak self] image in self?.artworkView.image = image }
        }

        titleLabel.text = album.title
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        artistLabel.text = album.artist
        artistLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        artistLabel.textColor = AppTheme.textSecondary
        artistLabel.textAlignment = .center
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(artistLabel)

        playButton.setImage(IconFactory.play(size: 16), for: .normal)
        playButton.tintColor = .white
        playButton.backgroundColor = AppTheme.accent
        playButton.layer.cornerRadius = 22
        playButton.isHidden = true
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playAlbum), for: .touchUpInside)
        headerView.addSubview(playButton)

        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 12),
            artworkView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 130),
            artworkView.heightAnchor.constraint(equalToConstant: 130),
            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            playButton.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 10),
            playButton.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 106, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 106, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableHeaderView = headerView
        tableView.register(TrackCell.self, forCellReuseIdentifier: TrackCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRows), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRows), name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    private func setupIndicator() {
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func loadAlbum() {
        indicator.startAnimating()
        tableView.reloadData()
        MusicAPIService.shared.fetchAlbum(album) { [weak self] result in
            guard let self = self else { return }
            self.indicator.stopAnimating()
            switch result {
            case .success(let loaded):
                self.playlist = loaded
                self.playButton.isHidden = loaded.tracks.isEmpty
            case .failure(let error):
                self.playlist = nil
                self.lastError = error.localizedDescription
                self.presentError(error.localizedDescription)
            }
            self.tableView.reloadData()
        }
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Couldn't load album", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in self?.loadAlbum() })
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func playAlbum() {
        guard let tracks = playlist?.tracks, !tracks.isEmpty else { return }
        AudioPlayer.shared.play(tracks, startingAt: 0)
    }

    @objc private func reloadRows() {
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let playlist = playlist else {
            return (indicator.isAnimating || lastError == nil) ? 0 : 1
        }
        return playlist.tracks.count
    }

    private var lastError: String?

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let playlist = playlist else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = "Album failed to load. Tap to retry."
            cell.textLabel?.textColor = AppTheme.accent
            cell.textLabel?.numberOfLines = 0
            return cell
        }
        let track = playlist.tracks[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else { return UITableViewCell() }
        cell.configure(with: track, isCurrentlyPlaying: AudioPlayer.shared.currentTrack?.id == track.id)
        cell.onMoreTapped = { [weak self] in self?.presentTrackOptions(for: track) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let playlist = playlist else {
            loadAlbum()
            return
        }
        AudioPlayer.shared.play(playlist.tracks, startingAt: indexPath.row)
    }

    private func presentTrackOptions(for track: Track) {
        let alert = UIAlertController(title: track.title, message: track.artist, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Play Next", style: .default) { _ in AudioPlayer.shared.playNext(track) })
        alert.addAction(UIAlertAction(title: "Add to Queue", style: .default) { _ in AudioPlayer.shared.addToQueue(track) })
        let downloaded = DownloadManager.shared.isDownloaded(trackId: track.id)
        alert.addAction(UIAlertAction(title: downloaded ? "Remove Download" : "Download", style: .default) { _ in
            if downloaded { DownloadManager.shared.deleteDownload(trackId: track.id) }
            else { DownloadManager.shared.download(track: track) }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
