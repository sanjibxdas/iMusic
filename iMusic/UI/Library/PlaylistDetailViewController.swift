import UIKit

final class PlaylistDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var playlist: Playlist
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerContainer = UIView()
    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let playButton = UIButton(type: .custom)
    private let shuffleButton = UIButton(type: .custom)

    init(playlist: Playlist) {
        self.playlist = playlist
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        navigationItem.largeTitleDisplayMode = .never
        setupNavigation()
        setupHeader()
        setupTableView()
        registerObservers()
    }

    private func setupNavigation() {
        let downloadBtn = UIBarButtonItem(image: IconFactory.download(size: 20), style: .plain, target: self, action: #selector(downloadAllAction))
        downloadBtn.tintColor = AppTheme.accent
        navigationItem.rightBarButtonItem = downloadBtn
    }

    @objc private func downloadAllAction() {
        DownloadManager.shared.downloadPlaylist(tracks: playlist.tracks)
        let alert = UIAlertController(title: "Downloading Playlist", message: "\(playlist.tracks.count) tracks are queued for offline download.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func setupHeader() {
        headerContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 280)

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 8
        artworkView.backgroundColor = AppTheme.surfaceElevated
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(artworkView)

        if let thumb = playlist.thumbnailUrl, !thumb.isEmpty {
            ImageLoader.shared.loadImage(from: thumb) { [weak self] img in
                self?.artworkView.image = img
            }
        }

        titleLabel.text = playlist.title
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(titleLabel)

        authorLabel.text = playlist.author ?? "Apple Music"
        authorLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        authorLabel.textColor = AppTheme.accent
        authorLabel.textAlignment = .center
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(authorLabel)

        // Play button (solid red pill)
        playButton.setTitle(" Play", for: .normal)
        playButton.setImage(IconFactory.play(size: 14), for: .normal)
        playButton.tintColor = .white
        playButton.backgroundColor = AppTheme.accent
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        playButton.layer.cornerRadius = 10
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playAllAction), for: .touchUpInside)
        headerContainer.addSubview(playButton)

        // Shuffle button (gray pill)
        shuffleButton.setTitle(" Shuffle", for: .normal)
        shuffleButton.setImage(IconFactory.shuffle(size: 14), for: .normal)
        shuffleButton.tintColor = AppTheme.accent
        shuffleButton.backgroundColor = AppTheme.surfaceElevated
        shuffleButton.setTitleColor(AppTheme.accent, for: .normal)
        shuffleButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        shuffleButton.layer.cornerRadius = 10
        shuffleButton.translatesAutoresizingMaskIntoConstraints = false
        shuffleButton.addTarget(self, action: #selector(shuffleAllAction), for: .touchUpInside)
        headerContainer.addSubview(shuffleButton)

        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 16),
            artworkView.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 140),
            artworkView.heightAnchor.constraint(equalToConstant: 140),

            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),

            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            authorLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            playButton.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 16),
            playButton.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 24),
            playButton.trailingAnchor.constraint(equalTo: headerContainer.centerXAnchor, constant: -8),
            playButton.heightAnchor.constraint(equalToConstant: 40),

            shuffleButton.topAnchor.constraint(equalTo: playButton.topAnchor),
            shuffleButton.leadingAnchor.constraint(equalTo: headerContainer.centerXAnchor, constant: 8),
            shuffleButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -24),
            shuffleButton.heightAnchor.constraint(equalToConstant: 40)
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
        tableView.tableHeaderView = headerContainer
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
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    @objc private func reloadTable() {
        tableView.reloadData()
    }

    @objc private func playAllAction() {
        guard !playlist.tracks.isEmpty else { return }
        AudioPlayer.shared.play(playlist.tracks, startingAt: 0)
    }

    @objc private func shuffleAllAction() {
        guard !playlist.tracks.isEmpty else { return }
        var shuffled = playlist.tracks
        shuffled.shuffle()
        AudioPlayer.shared.play(shuffled, startingAt: 0)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlist.tracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
            return UITableViewCell()
        }
        let track = playlist.tracks[indexPath.row]
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
        AudioPlayer.shared.play(playlist.tracks, startingAt: indexPath.row)
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
