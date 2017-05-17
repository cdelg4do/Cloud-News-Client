//
//  Utils.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//  
//  This class provides auxiliary functions to perform common operations.
//  All of its methods are static.


import Foundation
import UIKit
import CoreLocation


class Utils {
    
    // Aliases for trailing closures, these functions will always be executed in the main queue.
    // They receive an optional so that they can manage nil as the result of some previous operation.
    
    typealias imageClosure = (UIImage?) -> ()
    typealias dataClosure = (Data?) -> ()
    typealias stringClosure = (String?) -> ()
    typealias userClosure = (UserInfo?) -> ()
    typealias boolClosure = (Bool) -> ()
    
    
    // Method to perform the async download of an image blob stored in a remote Azure Storage Container.
    // If the download succeeds, passes a new UIImage object with the image to the closure. Otherwise, passes nil.
    //
    // Parameters:
    //
    // - blobName: name of the blob to be downloaded
    // - containerName: name of the Storage Container where the blob is located
    // - activityIndicator: activity indicator to enable while the async task is performed (if not used, leave it to nil)
    // - completion: trailing closure that processes the resulting UIImage? in the main thread
    
    class func downloadBlobImage(_ blobName: String, fromContainer containerName: String, activityIndicator: UIActivityIndicatorView?, completion: @escaping imageClosure) {
        
        // Build a link to the blob
        // (credentials > storage account > storage client tied to the account > remote container > image blob)
        
        var imageBlob: AZSCloudBlockBlob
        
        do {
            let storageCredentials = AZSStorageCredentials(accountName: Backend.storageAccountName, accountKey: Backend.storageKeyString)
            let storageAccount = try AZSCloudStorageAccount(credentials: storageCredentials, useHttps: true)
            let storageClient = ( storageAccount.getBlobClient() )!
            
            let imagesContainer: AZSCloudBlobContainer = storageClient.containerReference(fromName: containerName)
            
            imageBlob = imagesContainer.blockBlobReference(fromName: blobName)
        }
        catch {
            print("\nERROR: Unable to build the link for the target blob\n")
            
            completion(nil)
            return
        }
        
        imageBlob.downloadToData { (error, data) in
            
            if let _ = error {
                print("\nERROR: unable to download remote blob:\n\(error!)\n")
                
                completion(nil)
                return
            }
            
            print("\nBlob successfully downloaded! (\((data?.count)!) bytes)\n")
            completion( UIImage(data: data!) )
        }
    }
    
    
    // Method to perform the async upload of an image to a remote Azure Storage Container.
    // The image will be encoded as JPEG with no compression.
    // If the upload succeeds, passes 'true' to the closure. Otherwise, passes 'false'.
    //
    // Parameters:
    //
    // - image: UIImage object to upload
    // - blobName: name for the new blob created in the container
    // - containerName: name of the Storage Container where the blob will be stored
    // - activityIndicator: activity indicator to enable while the async task is performed (if not used, leave it to nil)
    // - completion: trailing closure that receives a boolean with the operation result, to be executed in the main thread
    
    class func uploadBlobImage(_ image: UIImage, blobName: String, toContainer containerName: String, activityIndicator: UIActivityIndicatorView?, completion: @escaping boolClosure) {
        
        var imageBlob: AZSCloudBlockBlob
        
        do {
            let storageCredentials = AZSStorageCredentials(accountName: Backend.storageAccountName, accountKey: Backend.storageKeyString)
            let storageAccount = try AZSCloudStorageAccount(credentials: storageCredentials, useHttps: true)
            let storageClient = ( storageAccount.getBlobClient() )!
            
            let imagesContainer: AZSCloudBlobContainer = storageClient.containerReference(fromName: containerName)
            
            imageBlob = imagesContainer.blockBlobReference(fromName: blobName)
        }
        catch {
            print("\nERROR: Unable to build the link for the target blob\n")
            completion(false)
            return
        }
        
        imageBlob.upload(from: UIImageJPEGRepresentation(image, 1.0)!, completionHandler: { (error) in
            
            if error != nil {
                print("\nERROR: unable to upload image to a remote blob:\n\(error)\n")
                
                completion(false)
                return
            }
            
            print("\nImage successfully uploaded!\n")
            completion(true)
        })
    }
    
    
    // Method to perform the async deletion of a blob stored in a remote Azure Storage Container.
    // If the operation succeeds, passes 'true' to the closure. Otherwise, passes 'false'.
    //
    // Parameters:
    //
    // - blobName: name of the blob to be deleted
    // - containerName: name of the Storage Container where the blob is stored
    // - completion: trailing closure that receives a boolean with the operation result, to be executed in the main thread
    
    class func removeBlob(withName blobName: String, fromContainer containerName: String, completion: @escaping boolClosure) {
        
        var myBlob: AZSCloudBlockBlob
        
        do {
            let storageCredentials = AZSStorageCredentials(accountName: Backend.storageAccountName, accountKey: Backend.storageKeyString)
            let storageAccount = try AZSCloudStorageAccount(credentials: storageCredentials, useHttps: true)
            let storageClient = ( storageAccount.getBlobClient() )!
            
            let imagesContainer: AZSCloudBlobContainer = storageClient.containerReference(fromName: containerName)
            
            myBlob = imagesContainer.blockBlobReference(fromName: blobName)
        }
        catch {
            print("\nERROR: Unable to build the link for the target blob\n")
            completion(false)
            return
        }
        
        myBlob.delete(completionHandler: { (error) in
            
            if error != nil {
                print("\nERROR: unable to remove remote blob:\n\(error)\n")
                completion(false)
                return
            }
            
            print("\nBlob successfully removed!\n")
            completion(true)
        })
    }
    
    
    // Method to request the user information for a given Facebook UserId from the Facebook Graph API.
    // If the operation succeeds, passes a UserInfo object to the trailing closure. Otherwise, passes nil.
    
    class func asyncGetFacebookUserInfo(userId: String, withClient appClient: MSClient, completion: @escaping userClosure) {
        
        appClient.invokeAPI(Backend.fbGraphApiName,
                            body: nil,
                            httpMethod: "GET",
                            parameters: ["id": userId],
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                if let _ = error {
                                    print("\nERROR: failed request to '\(Backend.fbGraphApiName)':\n\(error!)\n")
                                    completion(nil)
                                    return
                                }
                                
                                print("\nResponse from '\(Backend.fbGraphApiName)':\n\(result!)\n")
                                
                                // Validate the response (if it is correct, builds a new UserInfo object. If not, returns nil)
                                let userInfo = UserInfo.validate(result as! JsonElement)
                                
                                completion(userInfo)
        })
    }
 
    
    // Async method to get the address corresponding to some Gps coordinates (given by a CLLocation object)
    // If the resolved address has several detail levels, will return only the top two (i.e. region and country).
    // 
    // If the operation succeeds, passes a String with the address to the trailing closure. Otherwise passes nil.
    
    class func asyncReverseGeolocation(location: CLLocation, completion: @escaping stringClosure) {
        
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
            
            if error != nil {
                print("\nERROR: Unable to perform the reverse geolocation\n" + (error?.localizedDescription)!)
                completion(nil)
            }
            
            else if let placemarks = placemarks,
                    let placemark = placemarks.last,
                    let lines: Array<String> = placemark.addressDictionary?["FormattedAddressLines"] as? Array<String> {
                
                        var address = lines[0]
                
                        if lines.count > 1  {
                            address = lines[lines.count-2] + ", " + lines[lines.count-1]
                        }
                
                        completion(address)
            }
                
            else {
                    print("\nERROR: Unable to resolve an address for the given coordinates\n")
                    completion(nil)
            }
        })
    }
    
    
    // Re-scales a given UIImage to fit inside the the given CGSize (the image keeps its aspect ratio)
    // (based on code from https://iosdevcenters.blogspot.com/2015/12/how-to-resize-image-in-swift-in-ios.html)
    
    class func resizeImage(_ image: UIImage, toSize targetSize: CGSize) -> UIImage {
        
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    
    // Gets the device screen size
    class func screenSize() -> CGSize {
        
        return UIScreen.main.nativeBounds.size
    }
    
    
    // Method to generate a random value for a GPS coordinate, useful to mock locations in the simulator.
    // (if isLat is true, value is between -90º and 90º. Otherwise, value is between -180º and 180º)
    
    class func randomGPSCoordinate(isLat: Bool) -> Double {
        
        var abs: CGFloat = CGFloat(Float(arc4random()) / Float(UINT32_MAX))   // this gives a value between 0 and 1
        if isLat    {   abs = abs * 90.0    }
        else        {   abs = abs * 180.0   }
        
        var sign: CGFloat
        if CGFloat(Float(arc4random()) / Float(UINT32_MAX)) > 0.5   {   sign = 1.0  }
        else                                                        {   sign = -1.0 }
        
        return Double(abs * sign)
    }
    
    
    // Converts a NSDate date object to a formatted String
    class func dateToString(_ date: NSDate) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        
        return formatter.string(from: date as Date)
    }
    
    
    // Shows/hides all the subviews of a given view
    class func changeSubviewsVisibility(ofView parentView: UIView, hide newStatus: Bool) {
        
        for view in parentView.subviews {
            view.isHidden = newStatus
        }
    }
    
    
    // Shows an information dialog box (with title, message and an 'OK' button) in a ViewController
    // (always in the main queue)
    class func showInfoDialog( who parent: UIViewController, title dialogTitle: String, message dialogMessage: String) {
        
        DispatchQueue.main.async {
            
            let alert = UIAlertController(title: dialogTitle, message: dialogMessage, preferredStyle: .alert)
            alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
            parent.present(alert, animated: true, completion: nil)
        }
    }
    
    
    // Shows an information dialog box (with title, message, and a 'Close' button to close the current controller)
    class func showCloseControllerDialog( who parent: UIViewController, title dialogTitle: String, message dialogMessage: String) {
        
        let actionClose = UIAlertAction(title: "Close", style: .default) { (alertAction) in
            
            let _ = parent.navigationController?.popViewController(animated: true)
        }
        
        let alert = UIAlertController(title: dialogTitle, message: dialogMessage, preferredStyle: .alert)
        alert.addAction( actionClose )
        parent.present(alert, animated: true, completion: nil)
    }
    
    
    // Shows/hides a given ActivityIndicatorView
    // (always in the main queue)
    class func switchActivityIndicator(_ indicator: UIActivityIndicatorView?, show: Bool) {
        
        DispatchQueue.main.async {
            
            if show {
                indicator?.isHidden = false
                indicator?.startAnimating()
            }
            else {
                indicator?.stopAnimating()
                indicator?.isHidden = true
            }
        }
    }
    
    
    // Stops a pull refresh happening in a given UITableViewController (if it was happening)
    class func stopTableRefreshing(_ controller: UITableViewController) {
        
        DispatchQueue.main.async {
            
            if (controller.refreshControl?.isRefreshing)! {
                controller.refreshControl?.endRefreshing()
            }
        }
    }
    
    
    // Stops a UIRefreshControl from keep refreshing (if it was refreshing)
    class func stopTableRefreshing(_ refreshControl: UIRefreshControl?) {
        
        DispatchQueue.main.async {
            
            if (refreshControl?.isRefreshing)! {
                refreshControl?.endRefreshing()
            }
        }
    }
    
}

