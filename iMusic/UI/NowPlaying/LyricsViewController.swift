import UIKit

final class LyricsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView()
    private var lyricsDocument: LyricsDocument?
    private var activeLineIndex: Int = -1
    private var isUserScrolling = false
    private let emptyLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .white)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupTableView()
        setupEmptyLabel()
        registerObservers()
        loadCurrentLyrics()
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 80, right: 0)
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
        emptyLabel.text = "No Lyrics Available"
        emptyLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        emptyLabel.textColor = AppTheme.textSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTrackChange), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProgressUpdate), name: AudioPlayer.playbackProgressDidChange, object: nil)
    }

    @objc private func handleTrackChange() {
        loadCurrentLyrics()
    }

    private func loadCurrentLyrics() {
        guard let track = AudioPlayer.shared.currentTrack else {
            lyricsDocument = nil
            tableView.reloadData()
            emptyLabel.isHidden = false
            return
        }

        lyricsDocument = nil
        activeLineIndex = -1
        tableView.reloadData()
        emptyLabel.isHidden = true
        loadingIndicator.startAnimating()

        LyricsService.shared.fetchLyrics(for: track) { [weak self] doc in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.lyricsDocument = doc
            self.emptyLabel.isHidden = (doc != nil)
            self.tableView.reloadData()
            self.updateActiveLine(time: AudioPlayer.shared.currentTime, animated: false)
        }
    }

    @objc private func handleProgressUpdate() {
        guard !isUserScrolling else { return }
        updateActiveLine(time: AudioPlayer.shared.currentTime, animated: true)
    }

    private func updateActiveLine(time: TimeInterval, animated: Bool) {
        guard let doc = lyricsDocument, doc.hasTiming else { return }
        guard let newIndex = doc.lineIndex(at: time) else { return }

        if newIndex != activeLineIndex {
            let prev = activeLineIndex
            activeLineIndex = newIndex

            var indexPathsToReload: [IndexPath] = []
            if prev >= 0 && prev < doc.lines.count {
                indexPathsToReload.append(IndexPath(row: prev, section: 0))
            }
            if newIndex < doc.lines.count {
                indexPathsToReload.append(IndexPath(row: newIndex, section: 0))
            }

            tableView.reloadRows(at: indexPathsToReload, with: .none)

            if newIndex < doc.lines.count {
                let targetPath = IndexPath(row: newIndex, section: 0)
                tableView.scrollToRow(at: targetPath, at: .middle, animated: animated)
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let doc = lyricsDocument {
            return doc.hasTiming ? doc.lines.count : 1
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.textAlignment = .left

        guard let doc = lyricsDocument else { return cell }

        if doc.hasTiming {
            let line = doc.lines[indexPath.row]
            cell.textLabel?.text = line.text

            if indexPath.row == activeLineIndex {
                cell.textLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
                cell.textLabel?.textColor = .white
            } else {
                cell.textLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
                cell.textLabel?.textColor = UIColor(white: 0.5, alpha: 0.6)
            }
        } else if let plain = doc.plainLyrics {
            cell.textLabel?.text = plain
            cell.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            cell.textLabel?.textColor = .white
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let doc = lyricsDocument, doc.hasTiming, indexPath.row < doc.lines.count else { return }
        let targetTime = doc.lines[indexPath.row].time
        AudioPlayer.shared.seek(to: targetTime)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, decelerate: Bool) {
        if !decelerate { isUserScrolling = false }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserScrolling = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
