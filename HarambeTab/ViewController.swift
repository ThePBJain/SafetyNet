//
//  ViewController.swift
//  HarambeTab
//
//  Created by Pranav Jain on 10/22/16.
//  Copyright © 2016 Pranav Jain. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var dangerLabel: UILabel!
    @IBOutlet weak var checkButton: UIButton!
    
    @IBOutlet weak var starRating: CosmosView!
    
    let manager = CLLocationManager();
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.manager.requestAlwaysAuthorization()
        checkButton.layer.shadowOpacity = 0.7
        checkButton.layer.shadowOffset = CGSize(width: 3.0, height: 1.0)
        checkButton.layer.shadowRadius = 5.0
        // For use in foreground
        self.manager.requestWhenInUseAuthorization()
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "background.jpg")!)
        checkButton.layer.cornerRadius = 5
        checkButton.layer.borderWidth = 1
        checkButton.layer.borderColor = UIColor.clear.cgColor
        if CLLocationManager.locationServicesEnabled() {
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
        starRating.settings.updateOnTouch = false;
        checkButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5);
        UIView.animate(withDuration: 3.0,
                       delay: 0,
                       usingSpringWithDamping: 0.2,
                       initialSpringVelocity: 4.0,
                       options: .allowUserInteraction,
                       animations: { [weak self] in
                        self?.checkButton.transform = .identity
            },
                       completion: nil)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func checkDanger(_ sender: AnyObject) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true;
        checkButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.2,
                       initialSpringVelocity: 2.0,
                       options: .allowUserInteraction,
                       animations: { [weak self] in
                        self?.checkButton.transform = .identity
            },
                       completion: nil)
        starRating.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 10.0,
                       delay: 0,
                       usingSpringWithDamping: 0.05,
                       initialSpringVelocity: 2.0,
                       options: .allowUserInteraction,
                       animations: { [weak self] in
                        self?.starRating.transform = .identity
            },
        completion: nil)
        manager.startUpdatingLocation()
    }
    func postData(url: String, params: NSDictionary, completionHandler: @escaping (_ data: NSData?, _ response: URLResponse?, _ error:NSError?) -> ()) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        let url = NSURL(string: url)!
        //        print("URL: \(url)")
        let request = NSMutableURLRequest(url: url as URL)
        let session = URLSession.shared
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Verify downloading data is allowed
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
        } catch let error as NSError {
            print("Error in request post: \(error)")
            request.httpBody = nil
        } catch {
            print("Catch all error: \(error)")
        }
        
        // Post the data
        let task = session.dataTask(with: request as URLRequest) { data, response, error in
            completionHandler(data as NSData?, response, error as NSError?)
            
            // Stop download indication
            UIApplication.shared.isNetworkActivityIndicatorVisible = false // Stop download indication
            
        }
        task.resume()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print("Found user's location: \(location)")
            self.manager.stopUpdatingLocation()
            let lat = location.coordinate.latitude
            let long = location.coordinate.longitude
            let time = location.timestamp.description
            let url = URL(string: "http://api.spotcrime.com/crimes.json?lat=\(lat)&lon=\(long)&radius=0.02&key=.")
            
            let task = URLSession.shared.dataTask(with: url!, completionHandler: {(data, response, error) in
                if error != nil {
                    print(error.debugDescription)
                } else {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            do {
                                if let data = data, let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary {
                                    //stuff happens
                                    print(jsonResult)
                                    self.postData(url: "http://hackharambe.com:8000/rating?lat=\(lat)&lon=\(long)&time=\(2)", params: jsonResult) { (data, response, error) -> Void in
                                        guard error == nil && data != nil else {                                                          // check for fundamental networking error
                                            print("error=\(error)")
                                            return
                                        }
                                        
                                        if let httpStatus = response as? HTTPURLResponse , httpStatus.statusCode != 200 {           // check for http errors
                                            print("statusCode should be 200, but is \(httpStatus.statusCode)")
                                            print("response = \(response)")
                                            
                                        }
                                        
                                        //let responseString = NSString(data: data! as Data, encoding: String.Encoding.utf8.rawValue)
                                        //print("responseString = \(responseString)")
                                        do{
                                            if let data = data, let responseString = try JSONSerialization.jsonObject(with: data as Data, options: []) as? NSDictionary{
                                                let crimeCount = responseString.value(forKey: "rating") as! Int
                                                print(crimeCount)
                                                let stars = 5.0 - 5.0*(Double(crimeCount)/50.0)
                                                DispatchQueue.main.async {
                                                    self.starRating.rating = stars
                                                    self.view.setNeedsDisplay()
                                                    self.starRating.setNeedsDisplay()
                                                    self.starRating.layoutIfNeeded()
                                                }
                                            }
                                        
                                        }catch let JSONError as NSError{
                                            print(JSONError)
                                        }

                                    }
                                }
                            } catch let JSONError as NSError {
                                print(JSONError)
                            }
                        }
                    } else {
                        print("Can't cast response to NSHTTPURLResponse")
                    }
                }
            })
            task.resume()
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = false;
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
   
    

}

