import UIKit

final class QueueViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView()
    private let headerLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupViews()
        registerObservers()
    }

    private func setupViews() {
        headerLabel.text = "UP NEXT"
        headerLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        headerLabel.textColor = AppTheme.textSecondary
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        tableView.backgroundColor = .clear
        tableView.separatorColor = AppTheme.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TrackCell.self, forCellReuseIdentifier: TrackCell.reuseIdentifier)
        tableView.rowHeight = 64
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadQueue), name: AudioPlayer.queueDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadQueue), name: AudioPlayer.trackDidChange, object: nil)
    }

    @objc private func reloadQueue() {
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AudioPlayer.shared.queue.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
            return UITableViewCell()
        }
        let track = AudioPlayer.shared.queue[indexPath.row]
        let isPlaying = (indexPath.row == AudioPlayer.shared.currentIndex)
        cell.configure(with: track, isCurrentlyPlaying: isPlaying)
        return cell
    }

    // MARK: - UITableViewDelegate & Reordering

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        AudioPlayer.shared.play(AudioPlayer.shared.queue, startingAt: indexPath.row)
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        AudioPlayer.shared.moveTrack(from: sourceIndexPath.row, to: destinationIndexPath.row)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            AudioPlayer.shared.removeTrack(at: indexPath.row)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
