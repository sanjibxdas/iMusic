import UIKit
import WebKit

final class AccountViewController: UIViewController, WKNavigationDelegate {

    private let statusCard = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()

    private let connectButton = UIButton(type: .system)
    private let syncButton = UIButton(type: .system)
    private let signOutButton = UIButton(type: .system)
    private let manualTokenButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Account"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupViews()
        updateUI()

        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: YouTubeAccountManager.accountDidChangeNotification, object: nil)
    }

    private func setupNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneAction))
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent
    }

    private func setupViews() {
        // Status card
        statusCard.backgroundColor = AppTheme.surface
        statusCard.layer.cornerRadius = 12
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusCard)

        avatarImageView.image = IconFactory.userProfile(size: 40)
        avatarImageView.tintColor = AppTheme.textSecondary
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 24
        avatarImageView.backgroundColor = AppTheme.surfaceElevated
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(avatarImageView)

        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        nameLabel.textColor = AppTheme.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(nameLabel)

        emailLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        emailLabel.textColor = AppTheme.textSecondary
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(emailLabel)

        // Buttons
        connectButton.setTitle("Sign in to YouTube Music", for: .normal)
        connectButton.backgroundColor = AppTheme.accent
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        connectButton.layer.cornerRadius = 10
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.addTarget(self, action: #selector(connectWebAction), for: .touchUpInside)
        view.addSubview(connectButton)

        syncButton.setTitle("Sync Liked Songs & Playlists", for: .normal)
        syncButton.backgroundColor = AppTheme.surfaceElevated
        syncButton.setTitleColor(AppTheme.accent, for: .normal)
        syncButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        syncButton.layer.cornerRadius = 10
        syncButton.translatesAutoresizingMaskIntoConstraints = false
        syncButton.addTarget(self, action: #selector(syncAction), for: .touchUpInside)
        view.addSubview(syncButton)

        manualTokenButton.setTitle("Paste Cookie / Token Manually", for: .normal)
        manualTokenButton.setTitleColor(AppTheme.textSecondary, for: .normal)
        manualTokenButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        manualTokenButton.translatesAutoresizingMaskIntoConstraints = false
        manualTokenButton.addTarget(self, action: #selector(manualTokenAction), for: .touchUpInside)
        view.addSubview(manualTokenButton)

        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.setTitleColor(.systemRed, for: .normal)
        signOutButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        signOutButton.addTarget(self, action: #selector(signOutAction), for: .touchUpInside)
        view.addSubview(signOutButton)

        NSLayoutConstraint.activate([
            statusCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusCard.heightAnchor.constraint(equalToConstant: 80),

            avatarImageView.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: statusCard.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 48),
            avatarImageView.heightAnchor.constraint(equalToConstant: 48),

            nameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),

            emailLabel.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: -4),
            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            emailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            connectButton.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 24),
            connectButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            connectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            connectButton.heightAnchor.constraint(equalToConstant: 46),

            syncButton.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 12),
            syncButton.leadingAnchor.constraint(equalTo: connectButton.leadingAnchor),
            syncButton.trailingAnchor.constraint(equalTo: connectButton.trailingAnchor),
            syncButton.heightAnchor.constraint(equalToConstant: 44),

            manualTokenButton.topAnchor.constraint(equalTo: syncButton.bottomAnchor, constant: 16),
            manualTokenButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            signOutButton.topAnchor.constraint(equalTo: manualTokenButton.bottomAnchor, constant: 24),
            signOutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func updateUI() {
        if let acc = YouTubeAccountManager.shared.currentAccount {
            nameLabel.text = acc.name
            emailLabel.text = acc.email
            connectButton.isHidden = true
            syncButton.isHidden = false
            signOutButton.isHidden = false
            manualTokenButton.isHidden = true
        } else {
            nameLabel.text = "Not Signed In"
            emailLabel.text = "Sign in to sync your YouTube Music playlists and likes."
            connectButton.isHidden = false
            syncButton.isHidden = true
            signOutButton.isHidden = true
            manualTokenButton.isHidden = false
        }
    }

    @objc private func doneAction() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func connectWebAction() {
        let webVC = YouTubeWebLoginViewController()
        let nav = UINavigationController(rootViewController: webVC)
        present(nav, animated: true, completion: nil)
    }

    @objc private func manualTokenAction() {
        let alert = UIAlertController(title: "Add YouTube Cookie", message: "Paste your cookie header from music.youtube.com (containing SAPISID)", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "SAPISID=...; SSID=..."
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            YouTubeAccountManager.shared.saveAccount(name: "YouTube Music User", email: "Connected via Cookie", cookie: text)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func syncAction() {
        let indicator = UIActivityIndicatorView(style: .white)
        indicator.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: indicator)

        YouTubeAccountManager.shared.syncAccountData { [weak self] success in
            self?.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self?.doneAction))
            let msg = success ? "Your Liked Music and Playlists have been synced." : "Sync completed."
            let alert = UIAlertController(title: "Sync Finished", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self?.present(alert, animated: true, completion: nil)
        }
    }

    @objc private func signOutAction() {
        YouTubeAccountManager.shared.signOut()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Web Login Controller

final class YouTubeWebLoginViewController: UIViewController, WKNavigationDelegate {

    private let webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign In"
        view.backgroundColor = AppTheme.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelAction))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(checkCookiesAction))

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        if let url = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc private func cancelAction() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func checkCookiesAction() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            let sapisid = cookies.first(where: { $0.name == "SAPISID" })?.value

            if let sapisid = sapisid, !sapisid.isEmpty {
                YouTubeAccountManager.shared.saveAccount(name: "YouTube Music Account", email: "Synced Account", cookie: cookieHeader, sapisid: sapisid)
                self?.dismiss(animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Login Required", message: "Please complete the login in the browser first.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
}
