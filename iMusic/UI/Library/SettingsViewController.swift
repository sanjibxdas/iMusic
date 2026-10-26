import UIKit

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private enum Section: Int, CaseIterable {
        case downloads
        case playback
        case dataBackup
        case general

        var title: String {
            switch self {
            case .downloads: return "DOWNLOADS"
            case .playback: return "AUDIO & PLAYBACK"
            case .dataBackup: return "BACKUP & RESTORE"
            case .general: return "GENERAL"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = AppTheme.background
        setupNavigation()
        setupTableView()
    }

    private func setupNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneAction)
        )
        navigationItem.rightBarButtonItem?.tintColor = AppTheme.accent
    }

    private func setupTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
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

    @objc private func doneAction() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .downloads: return 2
        case .playback: return 4
        case .dataBackup: return 2
        case .general: return 2
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = AppTheme.textSecondary
            header.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = AppTheme.surface
        cell.textLabel?.textColor = AppTheme.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        cell.detailTextLabel?.textColor = AppTheme.textSecondary
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)

        let settings = SettingsManager.shared

        switch sec {
        case .downloads:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Download Quality"
                cell.detailTextLabel?.text = settings.downloadQuality.rawValue
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Download over Wi-Fi only"
                let sw = UISwitch()
                sw.isOn = settings.downloadWifiOnly
                sw.onTintColor = AppTheme.accent
                sw.addTarget(self, action: #selector(wifiSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = sw
                cell.selectionStyle = .none
            }

        case .playback:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Output Precision"
                cell.detailTextLabel?.text = settings.outputPrecision.rawValue
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Crossfade"
                let secVal = Int(settings.crossfadeDuration)
                cell.detailTextLabel?.text = secVal == 0 ? "Off" : "\(secVal)s"
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Smart Audio Alignment"
                let sw = UISwitch()
                sw.isOn = settings.smartAudioAlignment
                sw.onTintColor = AppTheme.accent
                sw.addTarget(self, action: #selector(alignmentSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = sw
                cell.selectionStyle = .none
            } else {
                cell.textLabel?.text = "Play Next on Swipe"
                let sw = UISwitch()
                sw.isOn = settings.playNextOnSwipe
                sw.onTintColor = AppTheme.accent
                sw.addTarget(self, action: #selector(swipeSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = sw
                cell.selectionStyle = .none
            }

        case .dataBackup:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Export Data to JSON"
                cell.detailTextLabel?.text = "Backup"
                cell.textLabel?.textColor = AppTheme.accent
            } else {
                cell.textLabel?.text = "Import Data from JSON"
                cell.detailTextLabel?.text = "Restore"
                cell.textLabel?.textColor = AppTheme.accent
            }

        case .general:
            if indexPath.row == 0 {
                cell.textLabel?.text = "App Language"
                cell.detailTextLabel?.text = settings.appLanguage
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = "1.0.0 (iOS 12.5.8)"
                cell.selectionStyle = .none
            }
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sec = Section(rawValue: indexPath.section) else { return }

        switch sec {
        case .downloads:
            if indexPath.row == 0 { pickDownloadQuality() }
        case .playback:
            if indexPath.row == 0 { pickOutputPrecision() }
            if indexPath.row == 1 { pickCrossfade() }
        case .dataBackup:
            if indexPath.row == 0 { exportData() }
            if indexPath.row == 1 { importData() }
        case .general:
            if indexPath.row == 0 { pickLanguage() }
        }
    }

    // MARK: - Handlers

    @objc private func wifiSwitchChanged(_ sender: UISwitch) {
        SettingsManager.shared.downloadWifiOnly = sender.isOn
    }

    @objc private func alignmentSwitchChanged(_ sender: UISwitch) {
        SettingsManager.shared.smartAudioAlignment = sender.isOn
    }

    @objc private func swipeSwitchChanged(_ sender: UISwitch) {
        SettingsManager.shared.playNextOnSwipe = sender.isOn
    }

    private func pickDownloadQuality() {
        let alert = UIAlertController(title: "Download Quality", message: nil, preferredStyle: .actionSheet)
        for q in DownloadQuality.allCases {
            alert.addAction(UIAlertAction(title: q.rawValue, style: .default, handler: { [weak self] _ in
                SettingsManager.shared.downloadQuality = q
                self?.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func pickOutputPrecision() {
        let alert = UIAlertController(title: "Output Precision", message: nil, preferredStyle: .actionSheet)
        for p in OutputPrecision.allCases {
            alert.addAction(UIAlertAction(title: p.rawValue, style: .default, handler: { [weak self] _ in
                SettingsManager.shared.outputPrecision = p
                self?.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func pickCrossfade() {
        let alert = UIAlertController(title: "Crossfade Duration", message: "Select crossfade duration between tracks", preferredStyle: .actionSheet)
        let options: [(String, Double)] = [
            ("Off", 0.0),
            ("2 seconds", 2.0),
            ("4 seconds", 4.0),
            ("6 seconds", 6.0),
            ("8 seconds", 8.0),
            ("12 seconds", 12.0)
        ]
        for opt in options {
            alert.addAction(UIAlertAction(title: opt.0, style: .default, handler: { [weak self] _ in
                SettingsManager.shared.crossfadeDuration = opt.1
                self?.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func pickLanguage() {
        let alert = UIAlertController(title: "App Language", message: nil, preferredStyle: .actionSheet)
        let languages = ["English", "Hindi", "Bengali", "Spanish", "French", "German", "Japanese"]
        for lang in languages {
            alert.addAction(UIAlertAction(title: lang, style: .default, handler: { [weak self] _ in
                SettingsManager.shared.appLanguage = lang
                self?.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Export / Import Data

    private func exportData() {
        let backup: [String: Any] = [
            "favorites": try? JSONSerialization.jsonObject(with: JSONEncoder().encode(StorageManager.shared.getFavorites()), options: []),
            "history": try? JSONSerialization.jsonObject(with: JSONEncoder().encode(StorageManager.shared.getHistory()), options: []),
            "playlists": try? JSONSerialization.jsonObject(with: JSONEncoder().encode(StorageManager.shared.getPlaylists()), options: []),
            "settings": [
                "downloadQuality": SettingsManager.shared.downloadQuality.rawValue,
                "wifiOnly": SettingsManager.shared.downloadWifiOnly,
                "crossfade": SettingsManager.shared.crossfadeDuration,
                "language": SettingsManager.shared.appLanguage,
                "hideShorts": SettingsManager.shared.hideShorts
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: backup, options: [.prettyPrinted]) else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("iMusic_Backup.json")
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        present(activityVC, animated: true, completion: nil)
    }

    private func importData() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.json"], in: .import)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first,
              let data = try? Data(contentsOf: url),
              let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return
        }

        // Restore favorites
        if let favData = try? JSONSerialization.data(withJSONObject: json["favorites"] as Any, options: []),
           let favs = try? JSONDecoder().decode([Track].self, from: favData) {
            for f in favs { _ = StorageManager.shared.toggleFavorite(track: f) }
        }

        let alert = UIAlertController(title: "Import Successful", message: "Your library and settings have been restored.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
