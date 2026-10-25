import UIKit

final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate {

    private let searchController = UISearchController(searchResultsController: nil)
    private let filterChips = FilterChipsView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let loadingIndicator = UIActivityIndicatorView(style: .white)

    private var results: [Track] = []
    private var filteredResults: [Track] = []
    private var currentFilter: SearchFilter = .all
    private var searchTimer: Timer?

    private let trendingSearches = [
        "Taylor Swift",
        "The Weeknd",
        "Drake",
        "Billie Eilish",
        "Post Malone",
        "Dua Lipa",
        "Kendrick Lamar",
        "Bad Bunny",
        "Ariana Grande",
        "Coldplay"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupSearchController()
        setupFilterChips()
        setupTableView()
        setupLoadingIndicator()
        registerObservers()
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

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = "Artists, Songs, Lyrics, and More"
        searchController.searchBar.barStyle = .black
        searchController.searchBar.tintColor = AppTheme.accent

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func setupFilterChips() {
        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onSelect = { [weak self] filter in
            self?.currentFilter = filter
            self?.applyFilter()
        }
        view.addSubview(filterChips)

        NSLayoutConstraint.activate([
            filterChips.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterChips.heightAnchor.constraint(equalToConstant: 38)
        ])
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
            tableView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 4),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupLoadingIndicator() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    @objc private func reloadTable() {
        tableView.reloadData()
    }

    // MARK: - UISearchResultsUpdating

    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        searchTimer?.invalidate()
        if text.isEmpty {
            results = []
            filteredResults = []
            loadingIndicator.stopAnimating()
            tableView.reloadData()
            return
        }

        loadingIndicator.startAnimating()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.performSearch(query: text)
        }
    }

    private func performSearch(query: String) {
        MusicAPIService.shared.search(query: query) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()
                switch result {
                case .success(let tracks):
                    self.results = tracks
                    self.applyFilter()
                case .failure:
                    self.results = []
                    self.filteredResults = []
                    self.tableView.reloadData()
                }
            }
        }
    }

    private func applyFilter() {
        switch currentFilter {
        case .all, .songs:
            filteredResults = results
        case .albums:
            filteredResults = results.filter { !$0.album.isEmpty }
        case .artists:
            filteredResults = results
        case .playlists:
            filteredResults = results
        }
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return query.isEmpty ? 1 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return query.isEmpty ? trendingSearches.count : filteredResults.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return query.isEmpty ? "Trending Searches" : "Top Results"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textSecondary
            header.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if query.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = trendingSearches[indexPath.row]
            cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            cell.textLabel?.textColor = AppTheme.accent
            cell.imageView?.image = IconFactory.tabSearch(size: 16)
            cell.imageView?.tintColor = AppTheme.accent
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else {
                return UITableViewCell()
            }
            let track = filteredResults[indexPath.row]
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
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if query.isEmpty {
            let trendingTerm = trendingSearches[indexPath.row]
            searchController.searchBar.text = trendingTerm
            searchController.isActive = true
            performSearch(query: trendingTerm)
        } else {
            AudioPlayer.shared.play(filteredResults, startingAt: indexPath.row)
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
