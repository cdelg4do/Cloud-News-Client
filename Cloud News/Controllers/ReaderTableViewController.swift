//
//  ReaderTableViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import UIKit


class ReaderTableViewController: UITableViewController {
    
    
    // MARK: Propiedades de la clase
    
    // Cliente asociado a la mobile app
    var appClient: MSClient = MSClient(applicationURL: URL(string: Backend.mobileAppUrlString)!)
    
    // Lista de noticias a mostrar en la tabla
    var newsList: [DatabaseRecord]? = []
    
    // Caché de miniaturas
    var thumbsCache = [String:UIImage]()
    
    
    // MARK: Inicialización del controlador
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configuración para refrescar la vista tirando hacia abajo de la tabla (pull refresh)
        // (cuando suceda, se invocará al método loadNews() para actualizar la tabla)
        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.clear
        refreshControl?.tintColor = UIColor.black
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: #selector(loadNews), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl!)
        tableView.dataSource = self
        tableView.delegate = self
        
        // Mostrar un título
        title = "Latest News"
        
        // Obtener y mostrar las noticias
        loadNews()
    }
    

    // MARK: - Table view data source

    // Número de secciones: 1 (0 si no hay datos que mostrar)
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if (newsList?.isEmpty)! {   return 0    }
        else                    {   return 1    }
    }
    
    // Número de filas en una sección: tantas como noticias publicadas (0 si no hay datos que mostrar)
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (newsList?.isEmpty)! {   return 0                    }
        else                    {   return (newsList?.count)!   }
    }
    
    // Configuración de las celdas de la tabla
    // (se muestra el título de la noticia, el autor y una miniatura de la imagen)
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Obtener el elemento correspondiente a la celda
        let thisNews = newsList?[indexPath.row]
        
        // Datos de la noticia
        let newsId = thisNews?["id"] as! String?
        let newsTitle = thisNews?["title"] as! String?
        let newsWriterId = thisNews?["writer"] as! String?
        let newsDate = thisNews?["updatedAt"] as! NSDate?
        let newsImageName = thisNews?["image"] as? String     // La imágen es opcional
        
        
        // Obtención de la celda correspondiente al elemento
        let cellId = "newsCell"
        
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId)
        
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        }
        
        // Configuración de la vista (título de la noticia, autor y fecha)
        cell?.textLabel?.text = newsTitle!
        cell?.detailTextLabel?.text = "by \(newsWriterId!), \(Utils.dateToString(newsDate!))"
        cell?.imageView?.image = UIImage(named: "news_placeholder.png")!

        
        // Si la noticia tiene una imagen asociada, se muestra una miniatura de la misma
        // (obtenida de la caché, si ya se había descargado antes, o del servidor remoto)
        
        if newsImageName != nil {
            
            if let cachedImage = thumbsCache[newsId!] {
                cell?.imageView?.image = cachedImage
            }
            else {
                let thumbnailName = "\(newsImageName!)_thumb.jpg"
                
                Utils.downloadBlobImage(thumbnailName, fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                    
                    if image != nil {
                        self.thumbsCache[newsId!] = image!
                        cell?.imageView?.image = image!
                    }
                }
            }
            
        }

        
        return cell!
    }
    
    
    // Acción al seleccionar una celda de la tabla
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let selectedNews = newsList?[indexPath.row]
        
        let newsId = selectedNews?["id"] as! String?
        
        // Crear el controlador para mostrar el contenido de esa noticia, y mostrarla
        let newsDetailVC = ReaderNewsDetailViewController(id: newsId!, client: appClient)
        navigationController?.pushViewController(newsDetailVC, animated: true)
    }
    
    
    // MARK: Acceso a los datos de la BBDD remota
    
    // Obtener las noticias del servidor y mostrarlas en la tabla
    func loadNews() {
        
        appClient.invokeAPI(Backend.publishedNewsApiName,
                         body: nil,
                         httpMethod: "GET",
                         parameters: nil,
                         headers: nil,
                         completion: { (result, response, error) in
                            
                            // Vaciar la lista de noticias, antes de añadir los nuevos datos
                            if !((self.newsList?.isEmpty)!) {
                                self.newsList?.removeAll()
                            }
                            
                            
                            if let _ = error {
                                print("\nFallo al invocar la api 'published_news':\n\(error)\n")
                                Utils.showInfoDialog(who: self, title: "Error", message: "Unable to load the published news.")
                                
                                // Si estábamos actualizando desde un pull refresh, finalizarlo (en la cola principal)
                                DispatchQueue.main.async {
                                    if (self.refreshControl?.isRefreshing)! {   self.refreshControl?.endRefreshing()    }
                                }
                                
                                return
                            }
                            
                            
                            // Si hemos llegado hasta aquí, es que la petición se realizó correctamente
                            print("\nResultado de la invocación a 'published_news':\n\(result!)\n")
                            
                            
                            // Convertir el JSON recibido en una lista de DatabaseRecord
                            let json = result as! [DatabaseRecord]
                            
                            // Validar y cargar en la lista los registros correctos del JSON
                            // (un registro debe incluir al menos, los campos: id, title, writer y updatedAt)
                            for news in json {
                                
                                if news["id"] != nil && news["title"] != nil && news["writer"] != nil || news["updatedAt"] != nil {
                                    self.newsList?.append(news)
                                }
                                else {
                                    print("\nDescartando elemento por campos incorrectos o ausentes\n")
                                }
                            }
                            
                            // Actualizar la vista, en la cola principal
                            DispatchQueue.main.async {
                                
                                self.tableView.reloadData()
                                
                                // Si estábamos actualizando desde un pull refresh, finalizarlo
                                if (self.refreshControl?.isRefreshing)! {   self.refreshControl?.endRefreshing()    }
                            }
        })
        
    }
    
    

}
