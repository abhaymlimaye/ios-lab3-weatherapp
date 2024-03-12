//
//  ViewController.swift
//  iOS_Lab3-WeatherApp_Abhay
//
//  Created by Abhay Limaye on 09-03-2024.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var labelLocation: UILabel!
    @IBOutlet weak var labelTemperature: UILabel!
    @IBOutlet weak var imageConditions: UIImageView!
    @IBOutlet weak var labelConditions: UILabel!
    
    @IBOutlet weak var stackedviewTempCond: UIStackView!
    
    @IBOutlet weak var segmentUnit: UISegmentedControl!
    @IBOutlet weak var txtfieldSearch: UITextField!
    
    @IBOutlet weak var stackedviewTemp: UIStackView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private let locationManager = CLLocationManager()
    
    private var weatherData: WeatherData?
    private var iconColorMapping: [IconColorMapping]?
    private let systemColors: [String: UIColor] = [
        "orange": .systemOrange,
        "blue": .systemBlue,
        "teal": .systemTeal,
        "tertiary": .systemGray2,
        "quaternary": .systemGray4,
        "gray": .systemGray
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
 
        createIconColorMapping()
        
        imageConditions.preferredSymbolConfiguration = UIImage.SymbolConfiguration(paletteColors: [.white, .black, .systemGreen])
        
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        locationManager.delegate = self
        txtfieldSearch.delegate = self
        
        locationManager.requestWhenInUseAuthorization()
    }

    @IBAction func onPressBtnSearch(_ sender: Any) {
        txtfieldSearch.resignFirstResponder()
        
        guard let city = txtfieldSearch.text else { return }
        guard let url = ApiManager.getUrl(city: city) else { return }
        
        apifetchWeather(url: url)
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onPressBtnSearch(textField)
        return true
    }
    
    @IBAction func onPressBtnLocation(_ sender: Any) {
        txtfieldSearch.resignFirstResponder()
        handleLoading(isLoading: true)
        locationManager.requestLocation()
    }
    
    @IBAction func onSegmentUnitChanged(_ sender: Any) {
        switch (sender as AnyObject).selectedSegmentIndex {
            case 0: labelTemperature.text = String(Int(round(weatherData?.current.temp_c ?? 0.0)))
            case 1: labelTemperature.text = String(Int(round(weatherData?.current.temp_f ?? 0.0)))
            default: break
        }
    }
    
    private func apifetchWeather(url: URL) {
        handleLoading(isLoading: true)
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async { self.handleLoading(isLoading: false) }
            
            guard error == nil else {
                DispatchQueue.main.async { self.displayError() }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.displayError() }
                return
            }
            
            if let weatherData = self.parseWeatherJSON(data) {
                self.weatherData = weatherData
                DispatchQueue.main.async { self.displayWeather() }
            }
            else {
                self.weatherData = nil
                DispatchQueue.main.async { self.displayError() }
            }
        }
        dataTask.resume()
    }
    
    private func parseWeatherJSON(_ weatherJSON: Data) -> WeatherData? {
        var weatherData: WeatherData?
        do { weatherData = try JSONDecoder().decode(WeatherData.self, from: weatherJSON) }
        catch { return nil }
        return weatherData
    }
    
    private func displayWeather() {
        labelLocation.text = "\(weatherData?.location.name ?? ""), \(weatherData?.location.country ?? "")"
        
        switch(segmentUnit.selectedSegmentIndex) {
            case 0: labelTemperature.text = String(Int(round(weatherData?.current.temp_c ?? 0.0)))
            case 1: labelTemperature.text = String(Int(round(weatherData?.current.temp_f ?? 0.0)))
            default: break
        }
        
        labelConditions.text = weatherData?.current.condition.text ?? ""
        
        if let mapping = iconColorMapping?.first(where: { $0.code == weatherData?.current.condition.code ?? 0 }) {
            let icon = isDayTime() ? mapping.iconDay : mapping.iconNight
            imageConditions.image = UIImage(systemName: icon)
            let color = isDayTime() ? mapping.colorDay : mapping.colorNight
            if let systemColor = systemColors[color] {
                view.backgroundColor = systemColor
            }
        }
    }
    
    func isDayTime() -> Bool {
        guard let localtimeString = weatherData?.location.localtime else { return true }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let localDateTime = dateFormatter.date(from: localtimeString) else { return true }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: localDateTime)
        return hour >= 6 && hour < 18
    }


    private func handleLoading(isLoading: Bool) {
        if isLoading {
            stackedviewTemp.isHidden = true
            labelLocation.text = "Loading..."
            activityIndicator.startAnimating()
            imageConditions.image = UIImage(systemName: "arrow.triangle.2.circlepath.icloud")
            labelConditions.text = ""
        }
        else {
            activityIndicator.stopAnimating()
            stackedviewTemp.isHidden = false
        }
    }
    
    private func displayError() {
        displayError(as: "Couldn't get the weather")
    }
    private func displayError(as error: String){
        labelLocation.text = error + "!"
        labelTemperature.text = "--"
        imageConditions.image = UIImage(systemName: "exclamationmark.icloud")
        labelConditions.text = "Oops"
    }
    
    private func createIconColorMapping() {
        guard let url = Bundle.main.url(forResource: "Weather-Icon_Mapping", withExtension: "json")
        else { return }

        do {
            let data = try Data(contentsOf: url)
            iconColorMapping = try JSONDecoder().decode([IconColorMapping].self, from: data)
        }
        catch { iconColorMapping = nil }
    }
    
    @objc func orientationDidChange() {
        if UIDevice.current.orientation.isPortrait || UIDevice.current.orientation.isFlat {
            stackedviewTempCond.axis = .vertical
        } else {
            stackedviewTempCond.axis = .horizontal
        }
    }
}

struct ApiManager {
    static private let baseUrl = "https://api.weatherapi.com/v1/"
    static private let endpoint = "current.json"
    static private let apiKey = "7838b4c13c7b49a0876225608240903"
    
    static func getUrl(city: String) -> URL? {
        guard let url = 
                "\(baseUrl+endpoint)?key=\(apiKey)&q=\(city)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        
        return URL(string: url)
    }
    
    static func getUrl(lat: String, long: String) -> URL? {
        guard let url =
                "\(baseUrl+endpoint)?key=\(apiKey)&q=\(lat),\(long)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        
        return URL(string: url)
    }
}

struct WeatherData: Decodable {
    let location: Location
    let current: Current
}
struct Location: Decodable {
    let name: String
    let country: String
    let localtime: String
}
struct Current: Decodable {
    let temp_c: Float
    let temp_f: Float
    let condition: Condition
}
struct Condition: Decodable {
    let text: String
    let code: Int
}

struct IconColorMapping: Decodable {
    let code: Int
    let day: String
    let night: String
    let iconDay: String
    let iconNight: String
    let colorDay: String
    let colorNight: String
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        handleLoading(isLoading: false)
        
        if let location = locations.last {
            guard let url = ApiManager.getUrl(lat: String(location.coordinate.latitude), long: String(location.coordinate.longitude))
            else {
                displayError(as: "Couldn't get the location!")
                return
            }
            
            apifetchWeather(url: url)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        handleLoading(isLoading: false)
        displayError(as: "Couldn't get the location!")
    }
}

