import UIKit

final class DownloadedTracksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var downloadedTracks: [Track] = []
    private let emptyLabel = UILabel()
    private let headerContainer = UIView()
    private let playButton = UIButton(type: .custom)
    private let shuffleButton = UIButton(type: .custom)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Files"
        view.backgroundColor = AppTheme.background
        navigationItem.largeTitleDisplayMode = .never
        setupHeader()
        setupTableView()
        setupEmptyLabel()
        registerObservers()
        loadDownloadedTracks()
    }

    private func setupHeader() {
        headerContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 70)

        playButton.setTitle(" Play", for: .normal)
        playButton.setImage(IconFactory.play(size: 14), for: .normal)
        playButton.tintColor = .white
        playButton.backgroundColor = AppTheme.accent
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        playButton.layer.cornerRadius = 10
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playAllAction), for: .touchUpInside)
        headerContainer.addSubview(playButton)

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
            playButton.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            playButton.trailingAnchor.constraint(equalTo: headerContainer.centerXAnchor, constant: -6),
            playButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            playButton.heightAnchor.constraint(equalToConstant: 38),

            shuffleButton.leadingAnchor.constraint(equalTo: headerContainer.centerXAnchor, constant: 6),
            shuffleButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            shuffleButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            shuffleButton.heightAnchor.constraint(equalToConstant: 38)
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

    private func setupEmptyLabel() {
        emptyLabel.text = "No Downloaded Songs\nDownload songs to listen offline."
        emptyLabel.numberOfLines = 2
        emptyLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        emptyLabel.textColor = AppTheme.textSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(loadDownloadedTracks), name: DownloadManager.listDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    @objc private func reloadTable() {
        tableView.reloadData()
    }

    @objc private func loadDownloadedTracks() {
        self.downloadedTracks = DownloadManager.shared.allDownloadedTracks()
        emptyLabel.isHidden = !downloadedTracks.isEmpty
        headerContainer.isHidden = downloadedTracks.isEmpty
        tableView.tableHeaderView = downloadedTracks.isEmpty ? nil : headerContainer
        tableView.reloadData()
    }

    @objc private func playAllAction() {
        guard !downloadedTracks.isEmpty else { return }
        AudioPlayer.shared.play(downloadedTracks, startingAt: 0)
    }

    @objc private func shuffleAllAction() {
        guard !downloadedTracks.isEmpty else { return }
        var shuffled = downloadedTracks
        shuffled.shuffle()
        AudioPlayer.shared.play(shuffled, startingAt: 0)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadedTracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
            return UITableViewCell()
        }
        let track = downloadedTracks[indexPath.row]
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
        AudioPlayer.shared.play(downloadedTracks, startingAt: indexPath.row)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let track = downloadedTracks[indexPath.row]
            DownloadManager.shared.deleteDownload(trackId: track.id)
            loadDownloadedTracks()
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
        alert.addAction(UIAlertAction(title: "Delete from Device", style: .destructive, handler: { [weak self] _ in
            DownloadManager.shared.deleteDownload(trackId: track.id)
            self?.loadDownloadedTracks()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
