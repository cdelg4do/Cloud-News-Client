//
//  ArticleEditorViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 31/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import UIKit

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
    var articleId: String?              // Id del artículo que se está editando
    //var articleData: DatabaseRecord?    // Contenedor para los datos del registro de la BBDD sobre el artículo que se está editando
    
    var hasImageSelected: Bool = false  // Flag que indica si ya se escogió una imagen para el artículo
    var remoteImageName: String = ""          // Nombre para almacenar la imagen en el contenedor remoto (si tiene imagen)
    
    
    // MARK: Inicialización de la clase
    
    init(id: String?, client: MSClient) {
        
        self.articleId = id
        self.appClient = client
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: Ciclo de vida del controlador

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
    
/*    func validateData(title: String, text: String) -> Bool {
        
        if title.characters.count > 0 && text.characters.count > 0  {   return true }
        return false
    }
*/
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
            lat = String(describing: latitude)
            lon = String(describing: longitude)
        }
        
        // Parámetros de la petición
        let params = ["id": id,
                      "title": title,
                      "hasImage": hasAnImage,
                      "imageName": imageName,
                      "text": text,
                      "lat": lat,
                      "long": lon]
        
        // Invocar a la API remota que sube los datos a la BBDD
        appClient.invokeAPI(Backend.draftApiName,
                            body: nil,
                            httpMethod: "POST",
                            parameters: params,
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
        let body = ["id": self.articleId!]
        
        // Invocar a la API remota que sube los datos a la BBDD
        appClient.invokeAPI(Backend.submittedApiName,
                            body: body,
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
    
}


