import UIKit

final class RadioViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let stations: [(name: String, desc: String, query: String, icon: String)] = [
        ("Apple Music 1", "The new music that matters today. Live.", "Apple Music 1 Hits", "radio"),
        ("Apple Music Hits", "Songs you know and love from the '80s, '90s, and 2000s.", "Greatest Pop Hits", "radio"),
        ("Apple Music Country", "The past, present, and future of country music.", "Top Country Hits", "radio"),
        ("Lo-Fi Chill Radio", "Relaxing beats to focus, study, and unwind.", "Lofi Chill Beats", "radio"),
        ("Hip-Hop Workout Radio", "High-energy rap to power through your day.", "Workout Hip Hop", "radio"),
        ("Classic Rock Station", "The legends and guitar anthems of rock & roll.", "Classic Rock Anthems", "radio"),
        ("Deep Focus Radio", "Ambient soundscapes and electronic instrumentals.", "Focus Electronic Ambient", "radio")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Radio"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupTableView()
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
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
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

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.accessoryType = .disclosureIndicator

        let station = stations[indexPath.row]
        cell.textLabel?.text = station.name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cell.textLabel?.textColor = (indexPath.row == 0) ? AppTheme.accent : AppTheme.textPrimary

        cell.detailTextLabel?.text = station.desc
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        cell.detailTextLabel?.textColor = AppTheme.textSecondary
        cell.detailTextLabel?.numberOfLines = 2

        cell.imageView?.image = IconFactory.tabRadio(size: 24)
        cell.imageView?.tintColor = (indexPath.row == 0) ? AppTheme.accent : AppTheme.textTertiary

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let station = stations[indexPath.row]

        // Search station tracks and start radio playback
        MusicAPIService.shared.search(query: station.query) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tracks) where !tracks.isEmpty:
                    AudioPlayer.shared.play(tracks, startingAt: 0)
                default:
                    break
                }
            }
        }
    }
}
