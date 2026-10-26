import UIKit

private enum SearchRow {
    case track(Track)
    case album(Album)
    case trending(String)
    case message(String)
    case retry
}

final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    private let searchController = UISearchController(searchResultsController: nil)
    private let filterChips = FilterChipsView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let loadingIndicator = UIActivityIndicatorView(style: .white)

    private var tracks: [Track] = []
    private var albums: [Album] = []
    private var rows: [SearchRow] = []
    private var currentFilter: SearchFilter = .all
    private var searchTimer: Timer?
    private var queryGeneration = 0
    private var lastQuery = ""
    private var loadError: String?
    private var isLoading = false

    private let trendingSearches = ["Taylor Swift", "The Weeknd", "Drake", "Billie Eilish", "Post Malone", "Dua Lipa", "Kendrick Lamar", "Bad Bunny", "Ariana Grande", "Coldplay"]

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
        rebuildRows()
    }

    private var currentQuery: String {
        return searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func row(at index: Int) -> SearchRow? {
        guard index >= 0 && index < rows.count else { return nil }
        return rows[index]
    }

    private func setupNavigation() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.barTintColor = AppTheme.background
        navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Songs, Albums, Artists"
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
            self?.rebuildRows()
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
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 106, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 106, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
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

    // MARK: - Search

    func updateSearchResults(for searchController: UISearchController) {
        let query = currentQuery
        searchTimer?.invalidate()
        queryGeneration += 1
        let generation = queryGeneration

        if query.isEmpty {
            lastQuery = ""
            tracks = []
            albums = []
            loadError = nil
            isLoading = false
            loadingIndicator.stopAnimating()
            rebuildRows()
            return
        }

        lastQuery = query
        isLoading = true
        loadingIndicator.startAnimating()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.performSearch(query: query, generation: generation)
        }
    }

    private func performSearch(query: String, generation: Int) {
        MusicAPIService.shared.searchCatalog(query: query) { [weak self] result in
            guard let self = self, generation == self.queryGeneration, query == self.currentQuery else { return }
            self.isLoading = false
            self.loadingIndicator.stopAnimating()
            switch result {
            case .success(let catalog):
                self.tracks = catalog.tracks
                self.albums = catalog.albums
                self.loadError = nil
            case .failure(let error):
                self.tracks = []
                self.albums = []
                self.loadError = error.localizedDescription
            }
            self.rebuildRows()
        }
    }

    private func retrySearch() {
        guard !lastQuery.isEmpty else { return }
        queryGeneration += 1
        let generation = queryGeneration
        isLoading = true
        loadingIndicator.startAnimating()
        performSearch(query: lastQuery, generation: generation)
    }

    private func startSearch(term: String) {
        searchController.searchBar.text = term
        updateSearchResults(for: searchController)
    }

    private func rebuildRows() {
        if lastQuery.isEmpty {
            rows = trendingSearches.map { .trending($0) }
            tableView.reloadData()
            return
        }
        if let loadError = loadError {
            rows = [.message(loadError), .retry]
            tableView.reloadData()
            return
        }
        var listed: [SearchRow] = []
        switch currentFilter {
        case .all: listed = albums.map { .album($0) } + tracks.map { .track($0) }
        case .songs: listed = tracks.map { .track($0) }
        case .albums: listed = albums.map { .album($0) }
        case .artists, .playlists: listed = []
        }
        if listed.isEmpty && !isLoading {
            let reason: String
            switch currentFilter {
            case .albums: reason = "No albums matched this search."
            case .artists, .playlists: reason = "Artist and playlist browsing is not available in this build."
            default: reason = "No results for \"\(lastQuery)\"."
            }
            listed = [.message(reason)]
        }
        rows = listed
        tableView.reloadData()
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return lastQuery.isEmpty ? "Trending Searches" : "Top Results"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textSecondary
            header.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = row(at: indexPath.row) else { return UITableViewCell() }
        switch row {
        case .track(let track):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseIdentifier, for: indexPath) as? TrackCell else { return UITableViewCell() }
            cell.configure(with: track, isCurrentlyPlaying: AudioPlayer.shared.currentTrack?.id == track.id)
            cell.onMoreTapped = { [weak self] in self?.presentTrackOptions(for: track) }
            return cell
        case .album(let album):
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.accessoryType = .disclosureIndicator
            cell.imageView?.image = IconFactory.tabLibrary(size: 24)
            cell.imageView?.tintColor = AppTheme.accent
            cell.textLabel?.text = album.title
            cell.textLabel?.textColor = AppTheme.textPrimary
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            cell.detailTextLabel?.text = "Album • \(album.artist)"
            cell.detailTextLabel?.textColor = AppTheme.textSecondary
            return cell
        case .trending(let text):
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = text
            cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            cell.textLabel?.textColor = AppTheme.accent
            cell.imageView?.image = IconFactory.tabSearch(size: 16)
            cell.imageView?.tintColor = AppTheme.accent
            return cell
        case .message(let text):
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.accessibilityIdentifier = "search.message"
            cell.textLabel?.text = text
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            cell.textLabel?.textColor = AppTheme.textSecondary
            cell.selectionStyle = .none
            return cell
        case .retry:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.accessibilityIdentifier = "search.retry"
            cell.textLabel?.text = "Retry"
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            cell.textLabel?.textColor = AppTheme.accent
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = row(at: indexPath.row) else { return }
        switch row {
        case .track(let track):
            guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
            AudioPlayer.shared.play(tracks, startingAt: index)
        case .album(let album):
            openAlbum(album)
        case .trending(let term):
            startSearch(term: term)
        case .retry:
            retrySearch()
        case .message:
            break
        }
    }

    private func openAlbum(_ album: Album) {
        let controller = AlbumDetailViewController(album: album)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentTrackOptions(for track: Track) {
        let alert = UIAlertController(title: track.title, message: track.artist, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Play Next", style: .default) { _ in AudioPlayer.shared.playNext(track) })
        alert.addAction(UIAlertAction(title: "Add to Queue", style: .default) { _ in AudioPlayer.shared.addToQueue(track) })
        let downloaded = DownloadManager.shared.isDownloaded(trackId: track.id)
        alert.addAction(UIAlertAction(title: downloaded ? "Remove Download" : "Download", style: .default) { _ in
            if downloaded {
                DownloadManager.shared.deleteDownload(trackId: track.id)
            } else {
                DownloadManager.shared.download(track: track)
            }
        })
        let favorite = StorageManager.shared.isFavorite(trackId: track.id)
        alert.addAction(UIAlertAction(title: favorite ? "Unfavorite" : "Favorite", style: .default) { _ in
            _ = StorageManager.shared.toggleFavorite(track: track)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTimer?.invalidate()
        searchTimer = nil
    }

    deinit {
        searchTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
