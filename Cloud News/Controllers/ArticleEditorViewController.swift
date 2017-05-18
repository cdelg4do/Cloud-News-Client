//
//  ArticleEditorViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 31/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  This controller is in charge to show the editable view of an article written by an authenticated user.
//  Drafts are updated, saved and submitted from here.


import UIKit
import CoreLocation


class ArticleEditorViewController: UIViewController {
    
    var appClient: MSClient             // Azure client tied to the mobile app
    var session: SessionInfo            // Info about the current user session
    var articleId: String?              // Article Id
    var draftData: [AnyHashable : Any]? // Article data container
    
    // Flag that indicates if an image for the article was already chosen.
    // (When its value changes to false, the 'select image' button is disabled. When changes to true, the button is enabled)
    var hasImageSelected: Bool {
        
        didSet{
            btnClear.isEnabled = hasImageSelected
        }
    }
    
    
    //MARK: Reference to UI elements
    
    @IBOutlet weak var titleBox: UITextField!
    @IBOutlet weak var labelCreated: UILabel!
    @IBOutlet weak var labelUpdated: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var btnGallery: UIButton!
    @IBOutlet weak var btnClear: UIButton!
    @IBOutlet weak var contents: UITextView!
    @IBOutlet weak var btnSave: UIBarButtonItem!
    @IBOutlet weak var btnSubmit: UIBarButtonItem!
    
    
    //MARK: Initializers
    
    init(id: String?, client: MSClient, session: SessionInfo) {
        
        self.articleId = id
        self.appClient = client
        self.session = session
        
        self.draftData = nil
        self.hasImageSelected = false
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    //MARK: controller lifecycle events

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        btnClear.isEnabled = false
        
        // If we are editing an existing draft, load and show the data from the server
        if articleId != nil {
            
            loadExistingDraft()
        }
    }
    
    
    //MARK: actions from UI elements
    
    // 'Choose from gallery' button
    @IBAction func galleryAction(_ sender: AnyObject) {
        
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        
        // Show the image selector in modal way
        self.present(picker, animated: true) {
            // Additional actions to do right after the picker is shown
            // ...
        }
    }
    
    // 'Clear image' button
    @IBAction func clearAction(_ sender: AnyObject) {
        
        if hasImageSelected {
            
            imageView.image = UIImage(named: "no_image.png")
            hasImageSelected = false
        }
    }
    
    // 'Save draft' button
    @IBAction func saveAction(_ sender: AnyObject) {
        
        // Make sure the title and text fields are not empty
        if titleBox.text == "" || contents.text == "" {
            print("\nERROR: Unalble to save current draft (title and/or article text empty)\n")
            Utils.showInfoDialog(who: self, title: "Empty fields", message: "Either title or text are empty, please write something :)")
            return
        }
        
        // Location for the article
        // (TO-DO: replace these debug calls with an actual request to get the device location)
        let lat = Utils.randomGPSCoordinate(isLat: true)
        let lon = Utils.randomGPSCoordinate(isLat: false)
        
        // Send appropriate request to the server: save the new draft or update the existing one
        if self.draftData == nil {
            saveNewDraft(title: titleBox.text!, text: contents.text, latitude: lat, longitude: lon)
        }
        else {
            updateExistingDraft(title: titleBox.text!, text: contents.text, latitude: lat, longitude: lon)
        }
    }
    
    // 'Submit draft' button
    @IBAction func submitAction(_ sender: AnyObject) {
        
        if self.draftData == nil {
            print("\nERROR: Unable to submit an unsaved draft,\n")
            Utils.showInfoDialog(who: self, title: "Submit New article", message: "This is a new article: please save it first.")
            return
        }
        
        // Object to update in the database
        var updateItem = self.draftData!
        updateItem["status"] = ArticleStatus.submitted.rawValue
        
        print("\nRecord to be updated in the database:\n\(updateItem)\n")
        
        appClient.table(withName: Backend.newsTableName).update(updateItem, completion: { (result, error) in
            
            if let _ = error {
                print("\nERROR: Failed to submit draft:\n\(error)\n")
                Utils.showInfoDialog(who: self, title: "Something went wrong", message: "It might happen that a newer draft version exists. Please try going back and loading this draft again.")
                return
            }
            
            // Update the local model with the updated data returned by the server
            self.draftData = result!
            
            print("\nERROR: draft submitted successfully:\n\(self.draftData!)\n")
            Utils.showInfoDialog(who: self, title: "Done!", message: "Your article has been submitted. Please allow up to 15 min. until it gets published.")
            
            // Update the modified date on screen and disable editing
            self.updateViewDatesOnly()
            self.disableAllElements()
        })
    }
}


//MARK: class extensions

// Methods to create and show the local model
extension ArticleEditorViewController {
    
    // Descarga del servidor los datos del borrador y los muestra en la vista
    func loadExistingDraft() {
        
        // Reference to the table "News" in the remote database
        let authorsTable = appClient.table(withName: Backend.newsTableName)
        
        // Search predicate (id = '<id>' AND status = 'draft')
        let predicate1 = NSPredicate(format: "id == '\(self.articleId!)'")
        let predicate2 = NSPredicate(format: "status == 'draft'")
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        
        // Execute the search predicate in the remote server
        authorsTable.read(with: predicate) { (result, error) in
            
            if let _ = error {
                print("\nERROR: Failed to fetch draft data:\n\(error)\n")
                Utils.showCloseControllerDialog(who: self, title: "Error", message: "Unable to retrieve remote data, please try again.")
                return
            }
            
            if result?.items == nil || result?.items?.count == 0 {
                
                print("\nThe query did not returned any match\n")
                Utils.showCloseControllerDialog(who: self, title: "Error", message: "This draft is not available anymore, it might have been either published or deleted.")
                return
            }
            
            print("\nQuery result:\n\(self.draftData!)\n")
            
            // If the query returned some match (should be one) then take the first row and show its data on screen
            self.draftData = (result?.items?.first)!
            
            DispatchQueue.main.async    {
                self.syncViewFromModel()
            }
        }
    }
    
    
    // Updates the view with data from the model
    func syncViewFromModel() {
        
        let titleString, imageName, content: String?
        let hasImage: Bool?
        let created, updated: NSDate?
        var location: CLLocation? = nil
        
        do {
            // Make sure the local model is not nil
            guard let draft = draftData else { throw JsonError.nilJSONObject }
            
            titleString = draft["title"] as? String
            created = draft["createdAt"] as? NSDate
            updated = draft["updatedAt"] as? NSDate
            content = draft["text"] as? String
            hasImage = draft["hasImage"] as? Bool
            imageName = draft["imageName"] as? String
            
            if titleString == nil   { throw JsonError.missingJSONField }
            if created == nil       { throw JsonError.missingJSONField }
            if updated == nil       { throw JsonError.missingJSONField }
            if content == nil       { throw JsonError.missingJSONField }
            if hasImage == nil      { throw JsonError.missingJSONField }
            if imageName == nil     { throw JsonError.missingJSONField }
            
            // Optional fields
            let lat = draft["latitude"] as? Double
            let long = draft["longitude"] as? Double
            
            if lat != nil && long != nil {  location = CLLocation(latitude: lat!, longitude: long!) }
        }
        catch {
            print("\nERROR: The response sent by the server is not valid\n")
            Utils.showCloseControllerDialog(who: self, title: "Error", message: "Incorrect server response, please try again.")
            return
        }
        
        // Set the value for the image flag (enables/disables the 'select image' button)
        self.hasImageSelected = hasImage!
        
        // Update views
        self.titleBox.text = titleString
        self.labelCreated.text = "First created: " + Utils.dateToString(created!)
        self.labelUpdated.text = "Last updated: " + Utils.dateToString(updated!)
        self.contents.text = content
        
        // If there is an image to show, download and show it (asynchronously)
        if hasImage! {
            
            Utils.downloadBlobImage("\(imageName!).jpg", fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                
                if image != nil {
                    let resizedImage = Utils.resizeImage(image!, toSize: Utils.screenSize())
                    DispatchQueue.main.async { self.imageView.image = resizedImage }
                }
            }
        }
    }
}


// MARK: Implementation of the UIImagePickerController and UINavigationController protocols

extension ArticleEditorViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // What to do after an image is picked
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        let pickedImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        // Resize the picked image to the screen size (to prevent memory warnings)
        let screenSize = UIScreen.main.nativeBounds.size
        let resizedImage = Utils.resizeImage(pickedImage, toSize: screenSize )
        
        // Update the model and the view
        imageView.image = resizedImage
        hasImageSelected = true
        
        // Dismiss the UIImagePickerController
        self.dismiss(animated: true) {}
    }
}


// MARK: Auxiliary functions

extension ArticleEditorViewController {
    
    // Returns an object representing a draft ready to be inserted/updated in the remote database.
    // If fromItme is nil, creates a new object. Otherwise, returns a copy updating the necessary fields.
    func buildDatabaseRecord(fromItem originalItem: [AnyHashable : Any]?,
                             withTitle title: String, withText text: String,
                             withLatitude latitude: Double?, withLongitude longitude: Double?,
                             havingImage hasImage: Bool) -> [AnyHashable : Any] {
        
        var result: [AnyHashable : Any]
        
        // Convert to int the boolean flag that indicates if the draft has an image
        var hasAnImage: Int = 0
        if hasImage { hasAnImage = 1 }
        
        // Location coordinates
        var lat, lon: Double?
        if latitude == nil || longitude == nil  {   lat = nil ; lon = nil               }
        else                                    {   lat = latitude! ; lon = longitude!  }
        
        // If we are updating an existing draft
        if originalItem != nil {
            
            result = originalItem!
            
            result["title"] = title
            result["text"] = text
            result["latitude"] = lat!
            result["longitude"] = lon!
            result["hasImage"] = hasAnImage
        }
            
        // If we are creating a new draft, use the given fields and add status, writer, visit counter and image name too
        else {
            let imageName = UUID().uuidString    // random name to store the draft image, in case it has an image
            
            result = [ "title": title,
                       "status": ArticleStatus.draft.rawValue,
                       "writer": self.session.userId,
                       "latitude": lat!,
                       "longitude": lon!,
                       "visits": 0,
                       "text": text,
                       "hasImage": hasAnImage,
                       "imageName": imageName ]
        }
        
        return result
    }
    
    
    // Creates a new draft entry in the remote database using the given data
    func saveNewDraft(title: String, text: String, latitude: Double?, longitude: Double?) {
        
        // Get the object to insert in the database
        let newItem = buildDatabaseRecord(fromItem: nil,
                                          withTitle: title, withText: text,
                                          withLatitude: latitude, withLongitude: longitude,
                                          havingImage: self.hasImageSelected)
        
        print("\nEntry to insert in the database:\n\(newItem)\n")
        
        // Insert the registry in the remote database
        appClient.table(withName: Backend.newsTableName).insert(newItem) { (result, error) in
            
            if let _ = error {
                print("\nERROR: failed to insert the new draft in the remote database:\n\(error!)\n")
                Utils.showInfoDialog(who: self, title: "Save failed", message: "Please try again :'(")
                return
            }
            
            // Save the new inserted registry returned by the server, and update the view (creation and modification date)
            self.draftData = result!
            print("\nNew registry inserted in the database:\n\(self.draftData!)\n")
            self.articleId = (self.draftData?["id"] as! String)
            
            self.updateViewDatesOnly()
            
            // If the draft has an image, upload it to Azure Storage (asynchronously)
            if self.hasImageSelected {
                
                self.uploadImage(self.imageView.image!, withName: (self.draftData?["imageName"] as! String) )  { (success: Bool) in
                    
                    if !success {
                        print("\nERROR: failed to store the draft image'\n")
                        Utils.showInfoDialog(who: self, title: "Something went wrong", message: "Your new draft has been saved, but the picture could not be stored properly. Please try again :'(")
                        return
                    }
                    
                    print("\nThe draft was successfully saved '\(self.articleId!)', including the image!\n")
                    Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
                }
            }
            else {
                print("\nThe draft was successfully saved '\(self.articleId!)'! (no image to save)\n")
                Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
            }
        }
    }
    
    
    // Updates the existing draft in the remote database
    func updateExistingDraft(title: String, text: String, latitude: Double?, longitude: Double?) {
        
        // Determine if the draft had a previous image that should be removed from the Azure Storage
        let hadImage: Bool = self.draftData?["hasImage"] as! Bool
        let remoteImageFileMustBeDeleted: Bool = ( hadImage && !self.hasImageSelected )
        
        
        // Registry to update in the remote database
        let updateItem = buildDatabaseRecord(fromItem: self.draftData!,
                                             withTitle: title, withText: text,
                                             withLatitude: latitude, withLongitude: longitude,
                                             havingImage: self.hasImageSelected)
        
        print("\nEntry to update in the database:\n\(updateItem)\n")
        
        
        // Update the registry in the database
        appClient.table(withName: Backend.newsTableName).update(updateItem, completion: { (result, error) in
            
            if let _ = error {
                print("\nERROR: failed to update the draft in the remot database:\n\(error)\n")
                Utils.showInfoDialog(who: self, title: "Something went wrong", message: "A possible reason is that a newer draft version exists. Please try going back and loading this draft again.")
                return
            }
            
            // Save the updated registry returned by the server, and update the view (creation and modification date)
            self.draftData = result!
            print("\nSuccessfully updated registry in the remote database:\n\(self.draftData!)\n")
            
            self.updateViewDatesOnly()
            
            
            // If the draft has an image, upload it to Azure Storage (replacing the previous file, if any)
            if self.hasImageSelected {
                
                self.uploadImage(self.imageView.image!, withName: (self.draftData?["imageName"] as! String) )  { (success: Bool) in
                    
                    if !success {
                        print("\nERROR: failed to update the draft image file'\n")
                        Utils.showInfoDialog(who: self, title: "Something went wrong", message: "Your draft has been saved, but the picture could not be stored properly. Please try again :'(")
                        return
                    }
                    
                    print("\nThe draft was succesfully updated '\(self.articleId!)' including the image!\n")
                    Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
                }
            }
                
            // If the image now does not have an image (but it had in the previous version), remove the file from the remote container
            else if remoteImageFileMustBeDeleted {
                
                let imageName: String = self.draftData?["imageName"] as! String
                
                self.deleteRemoteImage(withName: imageName) { (success: Bool) in
                    
                    if success  {   print("\nThe draft was succesfully updated '\(self.articleId!)'! (the previous image file was removed)\n")    }
                    else        {   print("\nERROR: failed to remove the previous image file\n")                                 }
                    
                    Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
                }
            }
            
            // If no image to remove or save, finish
            else {
                print("\nThe draft was succesfully updated '\(self.articleId!)'! (no image to save)\n")
                Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
            }
        })
    }
    
    
    // Stores a given UIImage (and its thumbnail) as Jpeg in the remote Azure Storage container
    func uploadImage(_ image: UIImage, withName imageName: String, completion: @escaping (Bool) -> () ) {
        
        // First, attempt to store the 'big' picture
        let imageFileName = imageName + ".jpg"
        
        Utils.uploadBlobImage(image, blobName: imageFileName, toContainer: Backend.newsImageContainerName, activityIndicator: nil) { (success1: Bool) in
            
            if !success1 {
                print("\nERROR: failed to upload image '\(imageFileName)' to the storage container\n")
                completion(false)
                return
            }
            
            print("\nImage '\(imageFileName)' successfully uploaded to the storage container\n")
            
            // Second, generate the thumbnail and attempt to store it
            let thumbnail = Utils.resizeImage(image, toSize: CGSize(width: 40, height: 40))
            let thumbFileName = imageName + "_thumb.jpg"
            
            Utils.uploadBlobImage(thumbnail, blobName: thumbFileName, toContainer: Backend.newsImageContainerName, activityIndicator:nil) { (success2: Bool) in
                
                if !success2 {
                    print("\nERROR: failed to upload thumbnail '\(thumbFileName)' to the storage container\n")
                    completion(false)
                    return
                }
                
                print("\nThumbnail '\(thumbFileName)' successfully uploaded to the storage container\n")
                completion(true)
            }
        }
    }
    
    
    // Deletes an image file (and its thumbnail) stored in the storage container
    func deleteRemoteImage(withName imageName: String, completion: @escaping (Bool) -> () ) {
        
        let name = imageName + ".jpg"
        let thumb = imageName + "_thumb.jpg"
        
        Utils.removeBlob(withName: name, fromContainer: Backend.newsImageContainerName) { (success1: Bool) in
            if success1 {   print("\nImage '\(name)' successfully removed from the storage container!\n")                      }
            else        {   print("\nERROR: Failed to remove image '\(name)' from the storage container\n")   }
            
            Utils.removeBlob(withName: thumb, fromContainer: Backend.newsImageContainerName) { (success2: Bool) in
                if success2 {   print("\nThumbnail '\(thumb)' successfully removed from the storage container!\n")                      }
                else        {   print("\nERROR: Failed to remove thumbnail '\(thumb)' from the storage container\n")   }
                
                completion(success1 && success2)
            }
        }
    }
    
    
    // Disables all views in the controller
    // (to prevent further editing once the draft has been submitted)
    func disableAllElements() {
        
        DispatchQueue.main.async {
            
            self.titleBox.isEnabled = false
            self.btnGallery.isEnabled = false
            self.btnClear.isEnabled = false
            self.contents.isEditable = false
            self.btnSave.isEnabled = false
            self.btnSubmit.isEnabled = false
        }
    }
    
    
    // Updates all draft dates, created & updated, on screen with the data from the model
    // (to invoke when the server returns the registry after saving the draft)
    func updateViewDatesOnly() {
        
        let created, updated: NSDate?
        
        // Make sure the local model is not nil and includes all the needed dates
        do {
            guard let draft = draftData else { throw JsonError.nilJSONObject }
            
            created = draft["createdAt"] as? NSDate
            updated = draft["updatedAt"] as? NSDate
            
            if created == nil       { throw JsonError.missingJSONField }
            if updated == nil       { throw JsonError.missingJSONField }
        }
        catch {
            print("\nERROR: failed to obtain cration/update dates from the local model\n")
            Utils.showCloseControllerDialog(who: self, title: "Something went wrong", message: "Unable to refresh the view with the latest data. Please get back and try again :'(")
            return
        }
        
        // Update the dates on screen
        DispatchQueue.main.async {
            self.labelCreated.text = "First created: " + Utils.dateToString(created!)
            self.labelUpdated.text = "Last updated: " + Utils.dateToString(updated!)
        }
    }
}
