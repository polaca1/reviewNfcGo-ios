import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MonitorViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class MeterCard: UIView {
    let main = UILabel()
    let sub = UILabel()
    let gauge = UIProgressView(progressViewStyle: .default)

    init(_ name: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 0.10, green: 0.15, blue: 0.23, alpha: 1)
        layer.cornerRadius = 14
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = name.uppercased()
        title.textColor = UIColor(red: 0.58, green: 0.70, blue: 0.85, alpha: 1)
        title.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        main.font = UIFont.monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        main.textColor = .white
        main.text = "—"
        main.adjustsFontSizeToFitWidth = true
        main.minimumScaleFactor = 0.6
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)

        sub.text = "Esperando datos"
        sub.numberOfLines = 2
        sub.font = UIFont.systemFont(ofSize: 12)
        sub.textColor = UIColor(white: 0.68, alpha: 1)
        sub.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sub)

        gauge.trackTintColor = UIColor(white: 0.22, alpha: 1)
        gauge.progressTintColor = UIColor(red: 0.27, green: 0.82, blue: 0.79, alpha: 1)
        gauge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gauge)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 145),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            main.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            main.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            main.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 7),
            sub.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            sub.trailingAnchor.constraint(equalTo: trailingAnchor),
            sub.topAnchor.constraint(equalTo: main.bottomAnchor, constant: 2),
            gauge.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            gauge.trailingAnchor.constraint(equalTo: trailingAnchor),
            gauge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            gauge.heightAnchor.constraint(equalToConstant: 6)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func display(_ value: String, note: String, percent: Float? = nil) {
        main.text = value
        sub.text = note
        if let p = percent {
            gauge.isHidden = false
            gauge.setProgress(max(0, min(1, p / 100)), animated: true)
        } else {
            gauge.isHidden = true
        }
    }
}

final class MonitorViewController: UIViewController, UITextFieldDelegate {
    private let host = UITextField()
    private let stateLabel = UILabel()
    private let cpu = MeterCard("CPU")
    private let ram = MeterCard("RAM")
    private let gpu = MeterCard("GPU")
    private let temp = MeterCard("Temperatura CPU")
    private let disk = MeterCard("Disco")
    private let network = MeterCard("Red")
    private let fans = MeterCard("Ventiladores")
    private let io = MeterCard("Lectura / escritura")
    private var timer: Timer?
    private var busy = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.055, green: 0.078, blue: 0.13, alpha: 1)
        buildLayout()
        if UserDefaults.standard.string(forKey: "hackintoshAddress") != nil {
            connect()
        }
    }

    private func buildLayout() {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 22),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -22),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -44)
        ])

        let heading = UILabel()
        heading.text = "HACKMONITOR"
        heading.textColor = .white
        heading.font = UIFont.systemFont(ofSize: 29, weight: .heavy)
        content.addArrangedSubview(heading)

        let detail = UILabel()
        detail.text = "Sonoma · Intel · Monitor de sensores"
        detail.textColor = UIColor(white: 0.65, alpha: 1)
        detail.font = UIFont.systemFont(ofSize: 14)
        content.addArrangedSubview(detail)

        host.placeholder = "IP del Hackintosh (ej. 192.168.1.50)"
        host.text = UserDefaults.standard.string(forKey: "hackintoshAddress") ?? ""
        host.autocapitalizationType = .none
        host.autocorrectionType = .no
        host.keyboardType = .URL
        host.returnKeyType = .done
        host.delegate = self
        host.textColor = .white
        host.tintColor = .white
        host.backgroundColor = UIColor(red: 0.10, green: 0.15, blue: 0.23, alpha: 1)
        host.layer.cornerRadius = 9
        host.borderStyle = .roundedRect
        host.translatesAutoresizingMaskIntoConstraints = false

        let connectButton = UIButton(type: .system)
        connectButton.setTitle("Conectar", for: .normal)
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        connectButton.tintColor = UIColor(red: 0.33, green: 0.88, blue: 0.83, alpha: 1)
        connectButton.addTarget(self, action: #selector(connectPressed), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.widthAnchor.constraint(equalToConstant: 110).isActive = true

        let address = UIStackView(arrangedSubviews: [host, connectButton])
        address.axis = .horizontal
        address.spacing = 8
        address.alignment = .fill
        content.addArrangedSubview(address)
        address.heightAnchor.constraint(equalToConstant: 46).isActive = true

        stateLabel.text = "Escribe la IP de tu Mac y pulsa Conectar"
        stateLabel.textColor = UIColor(red: 0.89, green: 0.70, blue: 0.43, alpha: 1)
        stateLabel.font = UIFont.systemFont(ofSize: 13)
        stateLabel.numberOfLines = 0
        content.addArrangedSubview(stateLabel)

        let rows: [[MeterCard]] = [[cpu, ram], [gpu, temp], [disk, network], [fans, io]]
        for cards in rows {
            let row = UIStackView(arrangedSubviews: cards)
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            content.addArrangedSubview(row)
        }
        let footer = UILabel()
        footer.text = "Solo red local · Actualización cada 2 s · Los sensores no disponibles aparecen como —"
        footer.textColor = UIColor(white: 0.53, alpha: 1)
        footer.numberOfLines = 0
        footer.font = UIFont.systemFont(ofSize: 11)
        content.addArrangedSubview(footer)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        connect()
        return true
    }

    @objc private func connectPressed() { connect() }

    private func connect() {
        view.endEditing(true)
        let value = (host.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            stateLabel.text = "Introduce la IP del Hackintosh."
            return
        }
        UserDefaults.standard.set(value, forKey: "hackintoshAddress")
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 2, target: self,
                                     selector: #selector(refresh), userInfo: nil, repeats: true)
        refresh()
    }

    @objc private func refresh() {
        guard !busy else { return }
        let address = (host.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let base = address.hasPrefix("http://") || address.hasPrefix("https://")
            ? address : "http://" + address + (address.contains(":") ? "" : ":8765")
        guard let url = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/status") else {
            stateLabel.text = "Dirección no válida."
            return
        }
        busy = true
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.busy = false
                guard error == nil, let data = data,
                      let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.stateLabel.text = "Sin conexión: comprueba la IP, el puerto 8765 y el servidor del Mac."
                    self.stateLabel.textColor = UIColor(red: 1, green: 0.56, blue: 0.48, alpha: 1)
                    return
                }
                self.updateCards(status)
            }
        }.resume()
    }

    private func number(_ data: [String: Any], _ key: String) -> Double? {
        (data[key] as? NSNumber)?.doubleValue
    }
    private func formatted(_ data: [String: Any], _ key: String, suffix: String = "") -> String {
        guard let value = number(data, key) else { return "—" }
        return String(format: "%.1f", value) + suffix
    }
    private func updateCards(_ info: [String: Any]) {
        let machine = info["hostname"] as? String ?? "Hackintosh"
        stateLabel.text = "● Conectado con " + machine
        stateLabel.textColor = UIColor(red: 0.33, green: 0.88, blue: 0.68, alpha: 1)
        let count = (info["cores"] as? [Any])?.count ?? 0
        cpu.display(formatted(info, "cpu", suffix: "%"), note: "\(count) hilos lógicos", percent: number(info, "cpu").map(Float.init))
        ram.display(formatted(info, "ram", suffix: "%"),
                    note: formatted(info, "ram_used_gb", suffix: " / ") + formatted(info, "ram_total_gb", suffix: " GiB"),
                    percent: number(info, "ram").map(Float.init))
        let gpuTemperature = formatted(info, "gpu_temp", suffix: " °C")
        gpu.display(formatted(info, "gpu_usage", suffix: "%"),
                    note: "Temperatura GPU: " + gpuTemperature, percent: number(info, "gpu_usage").map(Float.init))
        temp.display(formatted(info, "cpu_temp", suffix: " °C"), note: "Sensor Intel / VirtualSMC")
        disk.display(formatted(info, "disk_percent", suffix: "%"),
                     note: formatted(info, "disk_used_gb", suffix: " / ") + formatted(info, "disk_total_gb", suffix: " GiB"),
                     percent: number(info, "disk_percent").map(Float.init))
        network.display("↓ " + formatted(info, "net_down_mbs"), note: "↑ " +
                        formatted(info, "net_up_mbs") + " MiB/s · descarga en MiB/s")
        let list = info["fans"] as? [[String: Any]] ?? []
        let desc = list.prefix(2).compactMap { item -> String? in
            guard let rpm = item["rpm"] as? NSNumber else { return nil }
            return "\(rpm.intValue) RPM"
        }.joined(separator: " · ")
        fans.display(list.isEmpty ? "—" : "\(list.count)", note: desc.isEmpty ? "Sensores no disponibles" : desc)
        io.display("↓ " + formatted(info, "disk_read_mbs"),
                   note: "↑ " + formatted(info, "disk_write_mbs") + " MiB/s · escritura")
    }
}
