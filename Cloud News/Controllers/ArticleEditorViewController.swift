//
//  ArticleEditorViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 31/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  Este controlador muestra la vista de edición de los artículos, por parte de un usuario autenticado.
//  Desde este controlador se editan los borradores, se salvan y se envian para su publicación.


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
    var session: SessionInfo            // Información sobre la sesión del usuario actual
    var articleId: String?              // Id del borrador que se está editando
    var draftData: [AnyHashable : Any]? // Contenedor para los datos del registro de la BBDD sobre el borador
    
    // Flag que indica si ya se escogió una imagen para el artículo
    // (si es false, el botón de seleccionar imagen se desactiva. Y si es true, se activa)
    var hasImageSelected: Bool {
        
        didSet{
            btnClear.isEnabled = hasImageSelected
        }
    }
    
    
    // MARK: Inicialización de la clase
    
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
    
    
    // MARK: Ciclo de vida del controlador

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        btnClear.isEnabled = false
        
        // Si se trata de un borrador ya existente, descargar y mostrar sus datos
        if articleId != nil {
            
            // Todo el contenido de la vista permanecerá oculto
            // hasta que se carge la información de la noticia
            //Utils.changeSubviewsVisibility(ofView: mainView, hide: true)
            
            loadExistingDraft()
        }
    }
    
    
    // MARK: Acciones al pulsar los botones de la interfaz
    
    // Botón de escoger imagen de la galería
    @IBAction func galleryAction(_ sender: AnyObject) {
        
        // Selector de imágenes (acceso a la galería)
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        
        // Mostrarlo de forma modal
        self.present(picker, animated: true) {
            // Acciones a realizar nada más mostrarse el picker
            // ...
        }
    }
    
    // Botón de eliminar imagen escogida
    @IBAction func clearAction(_ sender: AnyObject) {
        
        if hasImageSelected {
            
            imageView.image = UIImage(named: "no_image.png")
            hasImageSelected = false
        }
    }
    
    // Botón de guardar borrador
    @IBAction func saveAction(_ sender: AnyObject) {
        
        // Comprobar que los campos de texto del título y el contenido no estén vacíos
        // (aquí se podrían incluir otras comprobaciones adicionales)
        
        if titleBox.text == "" || contents.text == "" {
            print("\nNo es posible guardar los cambios actuales (título y/o texto del artículo vacíos)\n")
            Utils.showInfoDialog(who: self, title: "Empty fields", message: "Either title or text are empty, please write something :)")
            return
        }
        
        // Obtención de las coordenadas actuales
        let lat = Utils.randomGPSCoordinate(isLat: true)
        let lon = Utils.randomGPSCoordinate(isLat: false)
        
        // Si aún no teníamos datos en draftData, creamos un nuevo borrador en la BBDD.
        // En caso contrario, actualizamos el borrador ya existente.
        if self.draftData == nil {
            
            saveNewDraft(title: titleBox.text!, text: contents.text, latitude: lat, longitude: lon)
        }
        else {
            
            updateExistingDraft(title: titleBox.text!, text: contents.text, latitude: lat, longitude: lon)
        }
    }
    
    // Botón de enviar borrador
    @IBAction func submitAction(_ sender: AnyObject) {
        
        if self.draftData == nil {
            print("\nNo se puede enviar un artículo sin haberlo guardado primero\n")
            Utils.showInfoDialog(who: self, title: "New article", message: "This is a new article: please save it first.")
            return
        }
        
        // Objeto a actualizar en la BBDD
        var updateItem = self.draftData!
        updateItem["status"] = ArticleStatus.submitted.rawValue
        print("\nRegistro a actualizar en la BBDD:\n\(updateItem)\n")
        
        // Actualizar el registro en la BBDD con los datos del registro temporal anterior
        appClient.table(withName: Backend.newsTableName).update(updateItem, completion: { (result, error) in
            
            if let _ = error {
                print("\nError al enviar el borrador:\n\(error)\n")
                Utils.showInfoDialog(who: self, title: "Something went wrong", message: "Possible reason is that a newer draft version exists. Please try going back and loading this draft again.")
                return
            }
            
            // Guardar en el modelo local el registro actualizado devuelto por el servidor
            self.draftData = result!
            print("\nBorrador enviado correctamente:\n\(self.draftData!)\n")
            Utils.showInfoDialog(who: self, title: "Done!", message: "Your article has been submitted. Please allow up to 15 min. until it gets published.")
            
            // Actualizar la fecha de modificación en la vista
            self.updateViewDatesOnly()
            
            // Una vez enviado un borrador, ya no se puede seguir mofificando
            self.disableAllElements()
        })
    }

}


// MARK: Funciones para creación y visualización del modelo local

extension ArticleEditorViewController {
    
    // Descarga del servidor los datos del borrador y los muestra en la vista
    func loadExistingDraft() {
        
        // Referencia a la tabla "Authors"
        let authorsTable = appClient.table(withName: Backend.newsTableName)
        
        // Predicado de búsqueda (id = '<id>' AND status = 'draft')
        let predicate1 = NSPredicate(format: "id == '\(self.articleId!)'")
        let predicate2 = NSPredicate(format: "status == 'draft'")
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        
        // Búsqueda aplicando el predicado anterior
        authorsTable.read(with: predicate) { (result, error) in
            
            if let _ = error {
                print("\nFallo al descargar la información del borrador:\n\(error)\n")
                Utils.showCloseControllerDialog(who: self, title: "Error", message: "Unable to retrieve remote data, please try again.")
                return
            }
            
            if result?.items == nil || result?.items?.count == 0 {
                print("\nLa consulta no devolvió ningún resultado\n")
                Utils.showCloseControllerDialog(who: self, title: "Error", message: "This draft is not available anymore, it might have been either published or deleted.")
                return
            }
            
            // Si la consulta devolvió resultados, guardamos el registro resultante y lo mostramos en la vista
            self.draftData = (result?.items?.first)!
            print("\nResultado de la consulta:\n\(self.draftData!)\n")
            
            DispatchQueue.main.async    {
                self.syncViewFromModel()
            }
        }
    }
    
    
    // Función que intenta actualizar la vista con la info. del modelo local
    // (solo debe invocarse después de haber descargado los datos remotos en loadNewsDetail() )
    func syncViewFromModel() {
        
        let titleString, imageName, content: String?
        let hasImage: Bool?
        let created, updated: NSDate?
        var location: CLLocation? = nil
        
        do {
            // Comprobar que el modelo local no sea nil
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
        
        // Si el borrador descargado tiene una imagen, activar el flag que indica que hay una imagen escogida por el usuario
        // (ya que de lo contrario, el botón de eliminar imagen no funcionaría)
        self.hasImageSelected = hasImage!
        
        // Actualizar las vistas (de forma síncrona)
        self.titleBox.text = titleString
        self.labelCreated.text = "First created: " + Utils.dateToString(created!)
        self.labelUpdated.text = "Last updated: " + Utils.dateToString(updated!)
        self.contents.text = content
        
        // Si tiene una imagen, descargarla en segundo plano y mostrarla
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
    
    // Función que devuelve un objeto que representa a un borrador en la BBDD,
    // preparado para insertar/actualizar en la BBDD.
    // Si fromItem es nil, crea un registro nuevo desde cero.
    // Si no, devuelve una copia del mismo, modificando solo los campos necesarios.
    func buildDatabaseRecord(fromItem originalItem: [AnyHashable : Any]?,
                             withTitle title: String, withText text: String,
                             withLatitude latitude: Double?, withLongitude longitude: Double?,
                             havingImage hasImage: Bool) -> [AnyHashable : Any] {
        
        var result: [AnyHashable : Any]
        
        // Conversión a Int del Booleano que indica si el registro tiene imagen asociada
        var hasAnImage: Int = 0
        if hasImage { hasAnImage = 1 }
        
        // Coordenadas de ubicación
        // (Si alguna coordenada es nil, entonces se enviará nil en las dos.
        // Si no, se enviarán los dos valores desempaquetados)
        var lat, lon: Double?
        if latitude == nil || longitude == nil  {   lat = nil ; lon = nil               }
        else                                    {   lat = latitude! ; lon = longitude!  }
        
        
        // Si se trata de actualizar un registro ya existente
        if originalItem != nil {
            
            result = originalItem!
            
            result["title"] = title
            result["text"] = text
            result["latitude"] = lat!
            result["longitude"] = lon!
            result["hasImage"] = hasAnImage
        }
            
            // Si se trata de crear un nuevo registro,
            // hay que indicarle además los campos status, writer, visits e imageName
        else {
            let imageName = UUID().uuidString    // nombre de fichero aleatorio y único
            
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
    
    
    // Función que crea una nueva entrada remota en la BBDD con los datos del borrador indicados
    func saveNewDraft(title: String, text: String, latitude: Double?, longitude: Double?) {
        
        // Objeto a insertar en la BBDD
        let newItem = buildDatabaseRecord(fromItem: nil,
                                          withTitle: title, withText: text,
                                          withLatitude: latitude, withLongitude: longitude,
                                          havingImage: self.hasImageSelected)
        
        print("\nRegistro a crear en la BBDD:\n\(newItem)\n")
        
        // Inserción de un registro en la tabla,
        // si no hay error devuelve en result el objeto insertado con todos sus campos
        appClient.table(withName: Backend.newsTableName).insert(newItem) { (result, error) in
            
            if let _ = error {
                print("\nFallo al intentar guardar el nuevo borrador:\n\(error!)\n")
                Utils.showInfoDialog(who: self, title: "Save failed", message: "Please try again :'(")
                return
            }
            
            // Guardar en el modelo local el nuevo registro devuelto por el servidor
            self.draftData = result!
            print("\nNuevo borrador insertado en la tabla:\n\(self.draftData!)\n")
            self.articleId = (self.draftData?["id"] as! String)
            
            // Actualizar las fechas de creación y modificación en la vista
            self.updateViewDatesOnly()
            
            // Si tenía una imagen asociada, guardarla también
            if self.hasImageSelected {
                
                self.uploadImage(self.imageView.image!, withName: (self.draftData?["imageName"] as! String) )  { (success: Bool) in
                    
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
    
    
    // Función que actualiza el borrador actual ya existente
    func updateExistingDraft(title: String, text: String, latitude: Double?, longitude: Double?) {
        
        // Determinar si habrá que borrar la imagen asociada del contenedor remoto
        // (solo si antes ya tenía una imagen y ahora el usuario la ha eliminado)
        let hadImage: Bool = self.draftData?["hasImage"] as! Bool
        let remoteImageFileMustBeDeleted: Bool = ( hadImage && !self.hasImageSelected )
        
        
        // Objeto a actualizar en la BBDD
        let updateItem = buildDatabaseRecord(fromItem: self.draftData!,
                                             withTitle: title, withText: text,
                                             withLatitude: latitude, withLongitude: longitude,
                                             havingImage: self.hasImageSelected)
        
        print("\nRegistro a actualizar en la BBDD:\n\(updateItem)\n")
        
        
        // Actualizar el registro en la BBDD con los datos del registro temporal anterior
        appClient.table(withName: Backend.newsTableName).update(updateItem, completion: { (result, error) in
            
            if let _ = error {
                print("\nError al actualizar el borrador en la BBDD:\n\(error)\n")
                Utils.showInfoDialog(who: self, title: "Something went wrong", message: "Possible reason is that a newer draft version exists. Please try going back and loading this draft again.")
                return
            }
            
            // Guardar en el modelo local el registro actualizado devuelto por el servidor
            self.draftData = result!
            print("\nRegistro actualizado correctamente en la BBDD:\n\(self.draftData!)\n")
            
            // Actualizar la fecha de modificación en la vista
            self.updateViewDatesOnly()
            
            
            // Si tiene una imagen asociada, guardarla también
            if self.hasImageSelected {
                
                self.uploadImage(self.imageView.image!, withName: (self.draftData?["imageName"] as! String) )  { (success: Bool) in
                    
                    if !success {
                        print("\nFallo al intentar guardar la imagen del borrador'\n")
                        Utils.showInfoDialog(who: self, title: "Something went wrong", message: "Your draft has been saved, but the picture could not be stored properly. Please try again :'(")
                        return
                    }
                    
                    print("\nSe guardaron correctamente el borrador '\(self.articleId!)' y su imagen asociada!\n")
                    Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
                }
            }
                
            // Si no tiene una imagen asociada, pero antes la tenía, eliminar el fichero del contenedor remoto
            else if remoteImageFileMustBeDeleted {
                
                let imageName: String = self.draftData?["imageName"] as! String
                
                self.deleteRemoteImage(withName: imageName) { (success: Bool) in
                    
                    // Tanto si se pudo eliminar la imagen como si no, al usuario se le muestra un mensaje de éxito (no le afecta)
                    if success  {   print("\nSe guardó correctamente el borrador '\(self.articleId!)'! (sin imagen asociada)\n")    }
                    else        {   print("\nFallo al intentar eliminar la imagen del borrador\n")                                 }
                    
                    Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
                }
            }
            
            // Si no tiene imagen ni hay que eliminarla, terminamos
            else {
                print("\nSe guardó correctamente el borrador '\(self.articleId!)'! (sin imagen asociada)\n")
                Utils.showInfoDialog(who: self, title: "Done!", message: "Your draft has been saved :)")
            }
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
            
            // Después, se genera la miniatura y se intenta guardar
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
    
    
    // Función que intenta eliminar la imagen de un borrador y su miniatura del contenedor remoto en que se encuentran
    // (si logra eliminar las dos, pasará true en la clausura, o false en caso contrario)
    func deleteRemoteImage(withName imageName: String, completion: @escaping (Bool) -> () ) {
        
        // Nombres de fichero de la imagen y de la miniatura a eliminar
        let name = imageName + ".jpg"
        let thumb = imageName + "_thumb.jpg"
        
        Utils.removeBlob(withName: name, fromContainer: Backend.newsImageContainerName) { (success1: Bool) in
            if success1 {   print("\nImagen '\(name)' eliminada del contenedor remoto!\n")                      }
            else        {   print("\nFallo al intentar eliminar la imagen '\(name)' del contenedor remoto\n")   }
            
            Utils.removeBlob(withName: thumb, fromContainer: Backend.newsImageContainerName) { (success2: Bool) in
                if success2 {   print("\nMiniatura '\(thumb)' eliminada del contenedor remoto!\n")                      }
                else        {   print("\nFallo al intentar eliminar la miniatura '\(thumb)' del contenedor remoto\n")   }
                
                completion(success1 && success2)
            }
        }
    }
    
    
    // Función que deshabilita las vistas de la pantalla tras un submit exitoso
    // (para evitar que el borrador se pueda modificar)
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
    
    
    // Función que actualiza la vista con las fechas
    // de creación y modificación del modelo local
    // (para usar después de una operación de guardado del borrador)
    func updateViewDatesOnly() {
        
        let created, updated: NSDate?
        
        do {
            // Comprobar que el modelo local no sea nil
            guard let draft = draftData else { throw JsonError.nilJSONObject }
            
            created = draft["createdAt"] as? NSDate
            updated = draft["updatedAt"] as? NSDate
            
            if created == nil       { throw JsonError.missingJSONField }
            if updated == nil       { throw JsonError.missingJSONField }
            
        }
        catch {
            print("\nError al extraer las fechas de creación/modificación del modelo local\n")
            Utils.showCloseControllerDialog(who: self, title: "Something went wrong", message: "Unable to refresh the view with the latest data. Please get back and try again :'(")
            return
        }
        
        // Actualizar las vistas (de forma síncrona)
        DispatchQueue.main.async {
            self.labelCreated.text = "First created: " + Utils.dateToString(created!)
            self.labelUpdated.text = "Last updated: " + Utils.dateToString(updated!)
        }
    }
}


