import UIKit

final class ImageLoader {

    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)

        // Strict memory caps for iPhone 6 (1 GB RAM total, ~300 MB Jetsam floor)
        cache.totalCostLimit = 20 * 1024 * 1024 // 20 MB max
        cache.countLimit = 60

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        cache.removeAllObjects()
    }

    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let key = urlString as NSString
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let cost = data.count
            self.cache.setObject(image, forKey: key, cost: cost)

            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
    }
}
