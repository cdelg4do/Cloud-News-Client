//
//  ReaderNewsDetailViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import UIKit
import CoreLocation

class ReaderNewsDetailViewController: UIViewController {
    
    // MARK: Referencia a los objetos de la interfaz
    
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var viewsLabel: UILabel!
    @IBOutlet weak var newsImage: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var newsText: UITextView!
    
    // Indicador de actividad de la imagen
    @IBOutlet weak var imageIndicator: UIActivityIndicatorView!
   
    
    // MARK: Propiedades de la clase
    
    var appClient: MSClient             // Cliente asociado a la mobile app
    var currentNewsId: String           // Id de la noticia a mostrar
    var currentNews: DatabaseRecord?    // Contenedor para los datos del registro de la BBDD sobre la noticia a mostrar
    
    let useAnonymousApi: Bool
    
    
    // MARK: Inicialización de la clase
    
    init(id: String, anonymous: Bool, client: MSClient) {
        
        self.currentNewsId = id
        self.useAnonymousApi = anonymous
        self.appClient = client
        
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(id: String, client: MSClient) {
        
        self.init(id: id, anonymous: true, client: client)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: Ciclo de vida del controlador
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Todo el contenido de la vista permanecerá oculto
        // hasta que se carge la información de la noticia
        Utils.changeSubviewsVisibility(ofView: mainView, hide: true)
        
        loadNewsDetail()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    // MARK: Acceso a los datos de la BBDD remota
    
    // Descarga del servidor los datos de la noticia y los muestra en la vista
    func loadNewsDetail() {
        
        let remoteApi: String
        
        if (useAnonymousApi)    {   remoteApi = Backend.readNewsApiName     }    // Api anónima, solo noticias ya publicadas
        else                    {   remoteApi = Backend.readArticleApiName }    // Con autenticación, también para artículos entregados
        
        appClient.invokeAPI(remoteApi,
                            body: nil,
                            httpMethod: "GET",
                            parameters: ["newsId": currentNewsId],
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                if let _ = error {
                                    print("\nFallo al invocar la api '\(remoteApi)':\n\(error)\n")
                                    Utils.showCloseControllerDialog(who: self, title: "Error", message: "Unable to retrieve remote data, please try again.")
                                    return
                                }
                                
                                // Si la petición se realizó correctamente, convertir el JSON recibido en una lista de DatabaseRecord
                                print("\nResultado de la invocación a '\(remoteApi)':\n\(result!)\n")
                                let json = result as! [DatabaseRecord]
                                
                                // Si la respuesta recibida no contiene elementos,
                                // mostrar un aviso y volver al listado de noticias
                                if json.count == 0 {
                                    
                                    Utils.showCloseControllerDialog(who: self, title: "Error", message: "This article is not available anymore, please try refreshing the list.")
                                    return
                                }
                                
                                // La respuesta debe contener 1 elemento,
                                // lo guardamos y mostramos su información en la vista
                                self.currentNews = json.first
                                
                                DispatchQueue.main.async    {
                                    self.syncViewFromModel()
                                }
        })
    }
    
    
    // Intenta actualizar la vista con la info. del modelo
    // (solo debe invocarse después de haber llamado a loadNewsDetail() )
    func syncViewFromModel() {
        
        let titleString, authorString, imageName, content: String?
        let newsDate: NSDate?
        let viewCount: Int?
        var newsLocation: CLLocation? = nil
        
        do {
            // Extraer los datos del JSON enviado por el servidor
            guard let thisNews = currentNews   else { throw JsonError.nilJSONObject }
            
            // Campos que obligatoriamente deben haberse recibido
            titleString = thisNews["title"] as? String
            authorString = thisNews["writer"] as? String
            newsDate = thisNews["date"] as? NSDate
            viewCount = thisNews["visits"] as? Int
            content = thisNews["text"] as? String
            
            if titleString == nil   { throw JsonError.missingJSONField }
            if authorString == nil  { throw JsonError.missingJSONField }
            if newsDate == nil      { throw JsonError.missingJSONField }
            if viewCount == nil     { throw JsonError.missingJSONField }
            if content == nil       { throw JsonError.missingJSONField }
            
            // Campos opcionales
            imageName = thisNews["image"] as? String
            let lat = thisNews["latitude"] as? Double
            let long = thisNews["longitude"] as? Double
            
            if lat != nil && long != nil {  newsLocation = CLLocation(latitude: lat!, longitude: long!) }
        }
        catch {
            print("\nError al extraer la información del JSON recibido\n")
            Utils.showCloseControllerDialog(who: self, title: "Error", message: "Incorrect server response, please try again.")
            return
        }
        
        // Actualizar las vistas (de forma síncrona)
        titleLabel.text = titleString
        authorLabel.text = "by " + authorString!
        dateLabel.text = Utils.dateToString(newsDate!)
        newsText.text = content
        
        if useAnonymousApi  {   viewsLabel.text = "\(viewCount!+1) views"   }
        else                {   viewsLabel.text = "\(viewCount!) views"   }
        
        if newsLocation != nil  {   locationLabel.text = "Resolving location..."}
        else                    {   locationLabel.text = "(Unknown location)"   }
        
        
        // Llegados a este punto, ya podemos hacer visible la vista
        Utils.changeSubviewsVisibility(ofView: mainView, hide: false)
        
        
        // Actualizar las vístas asíncronas (ubicación e imágen)
        if newsLocation != nil {
            
            Utils.asyncReverseGeolocation(location: newsLocation!) { (address: String?) in
                
                if address != nil { self.locationLabel.text = address   }
                else              { self.locationLabel.text = "(\(newsLocation?.coordinate.latitude),\(newsLocation?.coordinate.longitude))>"   }
            }
        }
        
        if imageName != nil {
            
            Utils.switchActivityIndicator(imageIndicator, show: true)
            
            Utils.downloadBlobImage("\(imageName!).jpg", fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                
                if image != nil {
                    
                    let resizedImage = Utils.resizeImage(image!, toSize: Utils.screenSize())
                    
                    DispatchQueue.main.async { self.newsImage.image = resizedImage }
                }
                
                Utils.switchActivityIndicator(self.imageIndicator, show: false)
            }
        }
    }

}




