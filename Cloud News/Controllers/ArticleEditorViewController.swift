//
//  ArticleEditorViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 31/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import UIKit
import CoreLocation

class ArticleEditorViewController: UIViewController {
    
    // MARK: Referencia a los objetos de la interfaz
    
    @IBOutlet weak var titleBox: UITextField!
    @IBOutlet weak var labelCreated: UILabel!
    @IBOutlet weak var labelUpdated: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var btnGallery: UIButton!
    @IBOutlet weak var btnClear: UIButton!
    @IBOutlet weak var contents: UITextView!
    @IBOutlet weak var btnSave: UIBarButtonItem!
    @IBOutlet weak var btnSubmit: UIBarButtonItem!
    
    
    // MARK: Propiedades de la clase
    
    var appClient: MSClient             // Cliente asociado a la mobile app
    var session: SessionInfo               // Información sobre la sesión del usuario actual
    var articleId: String?              // Id del borrador que se está editando
    var draftData: DatabaseRecord?      // Contenedor para los datos del registro de la BBDD sobre el borador que se está editando
    
    var hasImageSelected: Bool = false  // Flag que indica si ya se escogió una imagen para el artículo
    var remoteImageName: String = ""          // Nombre para almacenar la imagen en el contenedor remoto (si tiene imagen)
    
    
    // MARK: Inicialización de la clase
    
    init(id: String?, client: MSClient, session: SessionInfo) {
        
        self.articleId = id
        self.appClient = client
        self.session = session
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: Ciclo de vida del controlador

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Descargar y mostrar los datos de un borrador ya existente
        if articleId != nil {
            
            // Todo el contenido de la vista permanecerá oculto
            // hasta que se carge la información de la noticia
            //Utils.changeSubviewsVisibility(ofView: mainView, hide: true)
            
            loadExistingDraft()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    // MARK: Acciones al pulsar los botones de la interfaz
    
    @IBAction func galleryAction(_ sender: AnyObject) {
        
        // Selector de imágenes (acceso a la galería)
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        
        // Mostrarlo de forma modal
        self.present(picker, animated: true) {
            // Acciones a realizar nada más mostrarse el picker
        }
    }
    
    
    @IBAction func clearAction(_ sender: AnyObject) {
        
        if hasImageSelected {
            
            imageView.image = UIImage(named: "no_image.png")
            hasImageSelected = false
        }
    }
    
    
    @IBAction func saveAction(_ sender: AnyObject) {
        
        // Comprobar que los campos de texto de título y contenido no estén vacíos
        // (aquí se podrían incluir otras comprobaciones adicionales)
        
        if titleBox.text == "" || contents.text == "" {
            
            print("\nNo es posible guardar los cambios actuales (título y/o texto del artículo vacíos)\n")
            Utils.showInfoDialog(who: self, title: "Empty fields", message: "Either title or text are empty, please write something :)")
            return
        }
        
        
        // obtención de las coordenadas actuales
        let lat = Utils.randomGPSCoordinate(isLat: true)
        let lon = Utils.randomGPSCoordinate(isLat: false)
        
        
        // Si el id del artículo es nil, se trata de una nueva entrada
        if self.articleId == nil {
            
            saveNewDraft(title: titleBox.text!, text: contents.text, latitude: lat, longitude: lon)
        }
        
        // Si no, se actualiza la entrada ya existente en la BBDD
        else {
/*
            asyncUploadToDatabase(title: titleBox.text!, text: contents.text, latitude: lat, longitude: lon) { (returnedId: String?) in
                
                if returnedId == nil {
                    print("\nFallo al intentar guardar el borrador'\n")
                    Utils.showInfoDialog(who: self, title: "Save failed", message: "Please try again :'(")
                    return
                }
                
                // Si no hubo errores, guardamos el id devuelto
                self.articleId = returnedId
                
                // Una vez guardado el borrador en la BBDD, se sube la imagen (si tiene)
                if self.hasImageSelected {
                    
                    let image = self.imageView.image!
                    let imageName = self.remoteImageName + ".jpg"
                    let thumbnail = Utils.resizeImage(image, toSize: CGSize(width: 40, height: 40))
                    let thumbName = self.remoteImageName + "_thumb.jpg"
                    
                    Utils.uploadBlobImage(image, blobName: imageName, toContainer: Backend.newsImageContainerName, activityIndicator:nil) { (success: Bool) in
                        
                        if !success {
                            print("\nFallo al intentar subir la imagen '\(imageName)' al contenedor remoto\n")
                            Utils.showInfoDialog(who: self, title: "Image upload failed", message: "Please try again :'(")
                            
                            self.imageView.image = UIImage(named: "no_image.png")
                            self.hasImageSelected = false
                            
                            return
                        }
                        
                        print("\nSe ha subido correctamente la imagen '\(imageName)' al contenedor remoto\n")
                        
                        // Por último, se intenta subir la miniatura de la imagen
                        Utils.uploadBlobImage(thumbnail, blobName: thumbName, toContainer: Backend.newsImageContainerName, activityIndicator:nil) { (success: Bool) in
                            
                            if !success {
                                print("\nFallo al intentar subir la miniatura '\(thumbName)' al contenedor remoto\n")
                                Utils.showInfoDialog(who: self, title: "Image upload failed", message: "Please try again :'(")
                                
                                self.imageView.image = UIImage(named: "no_image.png")
                                self.hasImageSelected = false
                                
                                return
                            }
                            
                            print("\nSe ha subido correctamente la miniatura '\(thumbName)' al contenedor remoto\n")
                        }
                    }
                    
                }
                
                print("\nTodo el proceso de guardado del borrador '\(returnedId!)' se ha completado con éxito!\n")
                Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
            }
*/
        }
        
        
        
        
        
    }
    
    
    @IBAction func submitAction(_ sender: AnyObject) {
        
        if self.articleId == nil {
            print("\nNo se puede enviar un artículo sin haberlo guardado primero\n")
            Utils.showInfoDialog(who: self, title: "New article", message: "This is a new article: please save it first.")
            return
        }
        
        asyncSubmitDraft() { (returnedId: String?) in
            
            if returnedId == nil {
                print("\nFallo al intentar enviar el borrador\n")
                Utils.showInfoDialog(who: self, title: "Submit failed", message: "Please try again :'(")
                return
            }
            
            print("\nBorrador '\(returnedId!)' enviado con éxito!\n")
            Utils.showInfoDialog(who: self, title: "Done!", message: "Your article has been submitted. Please allow up to 15 min. until it gets published.")
            
            self.disableAllElements()
        }
        
        
    }
    

}


// MARK: Descarga de los datos remotos del borrador

extension ArticleEditorViewController {
    
    
    // Descarga del servidor los datos del borrador noticia y los muestra en la vista
    func loadExistingDraft() {
        
        appClient.invokeAPI(Backend.draftApiName,
                            body: nil,
                            httpMethod: "GET",
                            parameters: ["id": self.articleId!],
                            headers: nil,
                            completion: { (result, response, error) in
                                
	                                if let _ = error {
                                    print("\nFallo al invocar la api '\(Backend.draftApiName)':\n\(error)\n")
                                    Utils.showCloseControllerDialog(who: self, title: "Error", message: "Unable to retrieve remote data, please try again.")
                                    return
                                }
                                
                                // Si la petición se realizó correctamente, convertir el JSON recibido en una lista de DatabaseRecord
                                print("\nResultado de la invocación a '\(Backend.draftApiName)':\n\(result!)\n")
                                let json = result as! [DatabaseRecord]
                                
                                // Si la respuesta recibida no contiene elementos,
                                // mostrar un aviso y volver a la vista anterior
                                if json.count == 0 {
                                    
                                    Utils.showCloseControllerDialog(who: self, title: "Error", message: "This draft is not available anymore, it might have been either published or deleted.")
                                    return
                                }
                                
                                // La respuesta debe contener 1 elemento,
                                // lo guardamos y mostramos su información en la vista
                                self.draftData = json.first
                                
                                DispatchQueue.main.async    {
                                    self.syncViewFromModel()
                                }
        })
    }
    
    
    // Intenta actualizar la vista con la info. del modelo
    // (solo debe invocarse después de haber llamado a loadNewsDetail() )
    func syncViewFromModel() {
        
        let titleString, imageName, content: String?
        let hasImage: Bool?
        let created, updated: NSDate?
        var location: CLLocation? = nil
        
        do {
            // Extraer los datos del JSON enviado por el servidor
            guard let draft = draftData else { throw JsonError.nilJSONObject }
            
            // Campos que obligatoriamente deben haberse recibido
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
            
            // Campos opcionales
            let lat = draft["latitude"] as? Double
            let long = draft["longitude"] as? Double
            
            if lat != nil && long != nil {  location = CLLocation(latitude: lat!, longitude: long!) }
        }
        catch {
            print("\nError al extraer la información del JSON recibido\n")
            Utils.showCloseControllerDialog(who: self, title: "Error", message: "Incorrect server response, please try again.")
            return
        }
        
        // Actualizar las vistas (de forma síncrona)
        self.titleBox.text = titleString
        self.labelCreated.text = "First created: " + Utils.dateToString(created!)
        self.labelUpdated.text = "Last updated: " + Utils.dateToString(updated!)
        self.contents.text = content
        
//        if newsLocation != nil  {   locationLabel.text = "Resolving location..."}
//        else                    {   locationLabel.text = "(Unknown location)"   }
        
        
        // Llegados a este punto, ya podemos hacer visible la vista
//        Utils.changeSubviewsVisibility(ofView: mainView, hide: false)
        
        
        // Actualizar las vístas asíncronas (ubicación e imágen)
/*        if newsLocation != nil {
            
            Utils.asyncReverseGeolocation(location: newsLocation!) { (address: String?) in
                
                if address != nil { self.locationLabel.text = address   }
                else              { self.locationLabel.text = "(\(newsLocation?.coordinate.latitude),\(newsLocation?.coordinate.longitude))>"   }
            }
        }
*/
        if hasImage! {
            
//            Utils.switchActivityIndicator(imageIndicator, show: true)
            
            Utils.downloadBlobImage("\(imageName!).jpg", fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                
                if image != nil {
                    
                    let resizedImage = Utils.resizeImage(image!, toSize: Utils.screenSize())
                    
                    DispatchQueue.main.async { self.imageView.image = resizedImage }
                }
                
//                Utils.switchActivityIndicator(self.imageIndicator, show: false)
            }
        }
    }
    
    
}





// MARK: Implementación de los protocolos de delegado de UIImagePickerController y de UINavigationController

extension ArticleEditorViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Acción a realizar cuando se escoge una imagen
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        let pickedImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        // Redimensionar la imagen escogida antes de mostrarla, para evitar problemas de memoria
        let screenSize = UIScreen.main.nativeBounds.size
        let resizedImage = Utils.resizeImage(pickedImage, toSize: screenSize )
        
        // Actualizar el modelo y la vista
        imageView.image = resizedImage
        hasImageSelected = true
        
        // Eliminar el UIImagePickerController
        self.dismiss(animated: true) {}
    }
}


// MARK: Funciones auxiliares

extension ArticleEditorViewController {
    

    // Deshabilitar los botones de la pantalla tras un submit exitoso
    
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
    
    
    // Función que crea una nueva entrada remota en la BBDD con los datos del borrador indicados
    
    func saveNewDraft(title: String, text: String, latitude: Double?, longitude: Double?) {
        
        // String que indica si el registro tiene imagen asociada
        var hasAnImage: Int = 0
        if self.hasImageSelected { hasAnImage = 1 }
        
        // Si es una nueva entrada, generar un nombre aleatorio para el fichero de imagen
        var imageName = ""
        if self.articleId == nil {
            
            self.remoteImageName = UUID().uuidString
            imageName = self.remoteImageName
        }
        
        // Coordenadas de ubicación
        var lat, lon: Double?
        
        if latitude == nil || longitude == nil {
            lat = nil
            lon = nil
        }
        else {
            lat = latitude!
            lon = longitude!
        }
        
        // Objeto a insertar en la BBDD
        let newItem: [AnyHashable : Any] = [ "title": title,
                                             "status": ArticleStatus.draft.rawValue,
                                             "writer": session.userId,
                                             "latitude": lat!,
                                             "longitude": lon!,
                                             "visits": 0,
                                             "text": text,
                                             "hasImage": hasAnImage,
                                             "imageName": imageName  ]
        
        // Inserción de un registro en la tabla,
        // si no hay error devuelve en result el objeto insertado con todos sus campos
        appClient.table(withName: "News").insert(newItem) { (result, error) in
            
            if let _ = error {
                print("\nFallo al intentar guardar el nuevo borrador:\n\(error!)\n")
                Utils.showInfoDialog(who: self, title: "Save failed", message: "Please try again :'(")
                return
            }
            
            // Si no hubo errores, guardar el id del nuevo registro creado
            print("\nNuevo borrador insertado en la tabla:\n\(result!)\n")
            
            let returnedItem = (result as [AnyHashable : Any]?)!
            self.articleId = (returnedItem["id"] as! String)
            
            
            // Si tenía una imagen asociada, guardarla también
            if self.hasImageSelected {
                
                self.uploadImage(self.imageView.image!, withName: self.remoteImageName) { (success: Bool) in
                    
                    if !success {
                        print("\nFallo al intentar guardar la imagen del nuevo borrador'\n")
                        Utils.showInfoDialog(who: self, title: "Something went wrong", message: "Your new draft has been saved, but the picture could not be stored properly. Please try again :'(")
                        return
                    }
                    
                    	print("\nSe guardaron correctamente el borrador '\(self.articleId!)' y su imagen asociada!\n")
                    Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
                }
            }
            else {
                print("\nSe guardó correctamente el borrador '\(self.articleId!)'! (sin imagen asociada)\n")
                Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
            }
            
        }
    }
    
    
    
    // Función que envía al backend la información del borrador actual, y devuelve un String? con el id de artículo creado/actualizado,
    // para ser tratado en la clausura correspondiente
    
    func asyncUploadToDatabase(title: String, text: String, latitude: Double?, longitude: Double?, completion: @escaping (String?) -> () ) {
        
        // Si el id del artículo es nil, se trata de una nueva entrada
        var id = "new_article"
        if self.articleId != nil { id = self.articleId! }
        
        // String que indica si el registro tiene imagen asociada
        var hasAnImage: String = "false"
        if self.hasImageSelected { hasAnImage = "true" }
        
        // Si es una nueva entrada, generar un nombre aleatorio para el fichero de imagen
        var imageName = ""
        if self.articleId == nil {
            
            self.remoteImageName = UUID().uuidString
            imageName = self.remoteImageName
        }
        
        // Coordenadas de ubicación
        var lat, lon: String
        
        if latitude == nil || longitude == nil {
            lat = ""
            lon = ""
        }
        else {
            lat = String(describing: latitude!)
            lon = String(describing: longitude!)
        }
        
        // Parámetros de la petición
        let bodyParams = ["id": id,
                      "title": title,
                      "hasImage": hasAnImage,
                      "imageName": imageName,
                      "text": text,
                      "lat": lat,
                      "long": lon]
        
        // Invocar a la API remota que sube los datos a la BBDD
        appClient.invokeAPI(Backend.draftApiName,
                            body: bodyParams,
                            httpMethod: "POST",
                            parameters: nil,
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                if let _ = error {
                                    print("\nFallo al invocar a '\(Backend.draftApiName)':\n\(error!)\n")
                                    completion(nil)
                                    return
                                }
                                
                                // Si la petición se realizó correctamente, obtener el id devuelto
                                print("\nResultado de la invocación a '\(Backend.draftApiName)':\n\(result!)\n")
                                
                                let json = result as! JsonElement
                                let returnedId = json["id"] as! String?
                                completion(returnedId)
        })
        
    }
    
    
    // Entrega un artículo que ya estuviera previamente en estado borrador
    
    func asyncSubmitDraft(completion: @escaping (String?) -> () ) {
        
        // Si el id del artículo es nil, se trata de una nueva entrada y por tanto debe ser guardada primero
        if self.articleId == nil {
            print("\nNo se puede enviar un artículo sin haberlo guardado primero\n")
            completion(nil)
            return
        }
        
        // Parámetros de la petición
        let bodyParams = ["id": self.articleId!]
        
        // Invocar a la API remota que sube los datos a la BBDD
        appClient.invokeAPI(Backend.submittedApiName,
                            body: bodyParams,
                            httpMethod: "POST",
                            parameters: nil,
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                if let _ = error {
                                    print("\nFallo al invocar a '\(Backend.submittedApiName)':\n\(error!)\n")
                                    completion(nil)
                                    return
                                }
                                
                                // Si la petición se realizó correctamente, obtener el id devuelto
                                print("\nResultado de la invocación a '\(Backend.submittedApiName)':\n\(result!)\n")
                                
                                let json = result as! JsonElement
                                let returnedId = json["id"] as! String?
                                completion(returnedId)
        })
        
    }
    
    
    
    // Guarda una imagen jpg (y su miniatura correspondiente en el contendor remoto de Azure Storage correspondiente)
    
    func uploadImage(_ image: UIImage, withName imageName: String, completion: @escaping (Bool) -> () ) {
        
        // Primero se intenta almacenar la imagen "grande"
        let imageFileName = imageName + ".jpg"
        
        Utils.uploadBlobImage(image, blobName: imageFileName, toContainer: Backend.newsImageContainerName, activityIndicator: nil) { (success1: Bool) in
            
            if !success1 {
                print("\nFallo al intentar subir la imagen '\(imageFileName)' al contenedor remoto\n")
                completion(false)
                return
            }
            
            print("\nSe ha subido correctamente la imagen '\(imageFileName)' al contenedor remoto\n")
            
            // Después, se genera la miniatura y se inenta guardar
            let thumbnail = Utils.resizeImage(image, toSize: CGSize(width: 40, height: 40))
            let thumbFileName = imageName + "_thumb.jpg"
            
            Utils.uploadBlobImage(thumbnail, blobName: thumbFileName, toContainer: Backend.newsImageContainerName, activityIndicator:nil) { (success2: Bool) in
                
                if !success2 {
                    print("\nFallo al intentar subir la miniatura '\(thumbFileName)' al contenedor remoto\n")
                    completion(false)
                    return
                }
                
                print("\nSe ha subido correctamente la miniatura '\(thumbFileName)' al contenedor remoto\n")
                completion(true)
            }
        }
    }
    
}


