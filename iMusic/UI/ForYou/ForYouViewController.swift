import UIKit

final class ForYouViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private var collectionView: UICollectionView!
    private var playlists: [Playlist] = []
    private var topTracks: [Track] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "For You"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupCollectionView()
        loadData()
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

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 80, right: 16)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = AppTheme.background
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MediaCardCell.self, forCellWithReuseIdentifier: MediaCardCell.reuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func loadData() {
        MusicAPIService.shared.fetchFeaturedPlaylists { [weak self] list in
            DispatchQueue.main.async {
                self?.playlists = list
                self?.collectionView.reloadData()
            }
        }

        MusicAPIService.shared.fetchTopCharts { [weak self] tracks in
            DispatchQueue.main.async {
                self?.topTracks = tracks
                self?.collectionView.reloadData()
            }
        }
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return playlists.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCardCell.reuseIdentifier, for: indexPath) as? MediaCardCell else {
            return UICollectionViewCell()
        }
        let item = playlists[indexPath.item]
        cell.configure(title: item.title, subtitle: item.author ?? "Apple Music", artworkUrl: item.thumbnailUrl)
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalSpacing: CGFloat = 16 * 3 // left + middle + right
        let width = (collectionView.bounds.width - totalSpacing) / 2.0
        return CGSize(width: width, height: width + 48)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var playlist = playlists[indexPath.item]
        // If playlist tracks are empty, attach top tracks as sample tracks
        if playlist.tracks.isEmpty {
            playlist.tracks = topTracks
        }
        let detailVC = PlaylistDetailViewController(playlist: playlist)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
