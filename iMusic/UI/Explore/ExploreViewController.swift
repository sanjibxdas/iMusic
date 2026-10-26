import UIKit

final class ExploreViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let segmentedControl = UISegmentedControl(items: ["Moods & Activities", "Genres & Regions"])

    private let moods = [
        "Commute", "Energize", "Feel Good", "Focus", "Gaming",
        "Party", "Romance", "Sad", "Sleep", "Workout"
    ]

    private let genres = [
        "African", "Arabic", "Bengali", "Bhojpuri", "Carnatic", "Classical",
        "Country & Americana", "Dance & Electronic", "Decades", "Desi Hip Hop",
        "Devotional", "Family", "Folk & Acoustic", "Ghazal", "Gujarati",
        "Haryanvi", "Hindi", "Hindustani Classical", "Hip Hop", "Indian Indie",
        "Indian Pop", "Indian Alternative", "J-Pop", "Jazz", "K-Pop",
        "Kannada", "Latin", "Malayalam", "Marathi", "Metal", "Monsoon",
        "Pop", "Punjabi", "R&B & Soul", "Reggae & Caribbean", "Rock",
        "Tamil", "Telugu"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Explore"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupHeaderControl()
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

    private func setupHeaderControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.tintColor = AppTheme.accent
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32)
        ])
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
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    @objc private func segmentChanged() {
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return segmentedControl.selectedSegmentIndex == 0 ? moods.count : genres.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.accessoryType = .disclosureIndicator

        let title = (segmentedControl.selectedSegmentIndex == 0) ? moods[indexPath.row] : genres[indexPath.row]
        cell.textLabel?.text = title
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cell.textLabel?.textColor = AppTheme.textPrimary

        cell.imageView?.image = IconFactory.tabExplore(size: 20)
        cell.imageView?.tintColor = AppTheme.accent

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let categoryName = (segmentedControl.selectedSegmentIndex == 0) ? moods[indexPath.row] : genres[indexPath.row]
        let detailVC = CategoryDetailViewController(categoryName: categoryName)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Category Detail View Controller

final class CategoryDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let categoryName: String
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let indicator = UIActivityIndicatorView(style: .white)
    private var tracks: [Track] = []

    init(categoryName: String) {
        self.categoryName = categoryName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = categoryName
        view.backgroundColor = AppTheme.background
        navigationItem.largeTitleDisplayMode = .never
        setupTableView()
        loadCategoryTracks()
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

        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func loadCategoryTracks() {
        indicator.startAnimating()
        let query = "\(categoryName) Hits"
        MusicAPIService.shared.search(query: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.indicator.stopAnimating()
                switch result {
                case .success(let items):
                    self?.tracks = items
                    self?.tableView.reloadData()
                case .failure:
                    self?.tracks = []
                    self?.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
            return UITableViewCell()
        }
        let track = tracks[indexPath.row]
        let isCurrent = (AudioPlayer.shared.currentTrack?.id == track.id)
        cell.configure(with: track, isCurrentlyPlaying: isCurrent)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        AudioPlayer.shared.play(tracks, startingAt: indexPath.row)
    }
}
