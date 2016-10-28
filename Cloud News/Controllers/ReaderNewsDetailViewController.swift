//
//  ReaderNewsDetailViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import UIKit

class ReaderNewsDetailViewController: UIViewController {
    
    // MARK: Referencia a los objetos de la interfaz
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var viewsLabel: UILabel!
    @IBOutlet weak var newsImage: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var newsText: UITextView!
   
    
    // MARK: Propiedades de la clase
    
    var appClient: MSClient             // Cliente asociado a la mobile app
    var currentNewsId: String           // Id de la noticia a mostrar
    var currentNews: DatabaseRecord?    // Datos del registro de la BBDD sobre la noticia a mostrar
    
    
    // MARK: Inicialización de la clase
    
    init(id: String, client: MSClient) {
        
        self.currentNewsId = id
        self.appClient = client
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Cargar los datos de la noticia
        loadNewsDetail()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    // MARK: Acceso a los datos de la BBDD remota
    
    // Descarga los datos de la noticia del servidor y los muestra en la vista
    func loadNewsDetail() {
        
        appClient.invokeAPI(Backend.readNewsApiName,
                            body: nil,
                            httpMethod: "GET",
                            parameters: ["newsId": currentNewsId],
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                if let _ = error {
                                    print("\nFallo al invocar la api 'read_news':\n\(error)\n")
                                    Utils.showInfoDialog(who: self, title: "Error", message: "Unable to retrieve remote data.")
                                    return
                                }
                                
                                // Si la petición se realizó correctamente, convertir el JSON recibido en una lista de DatabaseRecord
                                // (solo debería contener un registro, que conservaremos)
                                print("\nResultado de la invocación a 'read_news':\n\(result!)\n")
                                let json = result as! [DatabaseRecord]
                                self.currentNews = json.first
                                
                                // Actualizar la vista, en la cola principal
                                DispatchQueue.main.async {
                                    
                                    self.syncViewFromModel()
                                }
        })
    }
    
    
    // MARK: Funciones auxiliares
    
    // Intenta actualizar la vista con la info. del modelo
    // (Si no hay errores, devuelve true. Y false en caso contrario)
    
    func syncViewFromModel() {
        
        let titleString, authorString, content: String
        let imageName: String?
        let newsDate: NSDate
        let viewCount: Int
        let lat, long: Double
        
        
        // Extraer los datos del JSON enviado por el servidor
        do {
            let thisNews = currentNews!
            
            titleString = thisNews["title"] as! String
            authorString = thisNews["writer"] as! String
            newsDate = thisNews["updatedAt"] as! NSDate
            viewCount = thisNews["visits"] as! Int
            imageName = thisNews["image"] as? String
            lat = thisNews["latitude"] as! Double
            long = thisNews["longitude"] as! Double
            content = thisNews["text"] as! String
        }
        catch {
            Utils.showInfoDialog(who: self, title: "Error", message: "Unable to show the news data, please go back and try again.")
            return
        }
        
        // Actualizar las vistas (de forma síncrona)
        titleLabel.text = titleString
        authorLabel.text = "by " + authorString
        dateLabel.text = Utils.dateToString(newsDate)
        viewsLabel.text = "\(viewCount+1) views"
        newsText.text = content
        
        locationLabel.text = "Resolving location..."
        
        
        // Actualizar la localización (de forma asíncrona)
        Utils.asyncReverseGeolocation(lat: lat, long: long) { (address: String?) in
            
            if address != nil   {   self.locationLabel.text = address                                   }
            else                {   self.locationLabel.text = "<Unknown location: (\(lat),\(long))>"    }
        }
        
        // Actualizar la imagen (de forma asíncrona)
        if imageName != nil {
            
            let imageName = "\(imageName!).jpg"
            
            Utils.downloadBlobImage(imageName, fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                
                if image != nil {   self.newsImage.image = image    }
            }
        }
    }

}




