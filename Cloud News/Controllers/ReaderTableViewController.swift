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
    
    var appClient: MSClient = MSClient(applicationURL: URL(string: Backend.mobileAppUrlString)!)    // Cliente de Azure Mobile
    var newsList: [DatabaseRecord]? = []    // Lista de noticias a mostrar en la tabla
    var thumbsCache = [String:UIImage]()    // Caché de miniaturas
    
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)  // Indicador de actividad de la tabla
    let emptyLabel = UILabel()  // Etiqueta para mostrar, en caso de que no haya datos en la tabla
    
    
    // MARK: Inicialización del controlador
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadNews(originIsPullRefresh: false)
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
        
        // Obtener los datos de la noticia correspondiente a la celda
        let thisNews = newsList?[indexPath.row]
        
        let newsId = thisNews?["id"] as! String?
        let newsTitle = thisNews?["title"] as! String?
        let newsWriterId = thisNews?["writer"] as! String?
        let newsDate = thisNews?["publishedAt"] as! NSDate?
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
        
        cell?.imageView?.contentMode = .scaleAspectFit
        cell?.imageView?.image = UIImage(named: "news_placeholder.png")!
        
        // Si la noticia tiene una imagen asociada, mostrarla (si no está cacheada, se descarga)
        if newsImageName != nil {
            
            if let cachedImage = thumbsCache[newsId!] {
                cell?.imageView?.image = cachedImage
            }
            else {
                let thumbnailName = "\(newsImageName!)_thumb.jpg"
                
                Utils.downloadBlobImage(thumbnailName, fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                    
                    // Si se descargó la imagen remota, cachearla y actualizar la vista (en la cola principal)
                    if image != nil {
                        
                        self.thumbsCache[newsId!] = image!
                        DispatchQueue.main.async {
                            cell?.imageView?.image = image!
                        }
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
    
    // Obtener las noticias del servidor y actualizar la vista
    func loadNews(originIsPullRefresh: Bool) {
        
        // Si no estamos haciendo un pull refresh, mostramos el activity indicator de la tabla
        if !originIsPullRefresh {
            Utils.switchActivityIndicator(indicator, show: true)
        }
        
        
        // Invocar a la API remota que devuelve todas las noticias publicadas
        
        appClient.invokeAPI(Backend.publishedNewsApiName,
                         body: nil,
                         httpMethod: "GET",
                         parameters: nil,
                         headers: nil,
                         completion: { (result, response, error) in
                            
                            // Vaciar la lista de noticias, antes de añadir los nuevos datos
                            self.newsList?.removeAll()
                            
                            if let _ = error {
                                print("\nFallo al invocar la api 'published_news':\n\(error)\n")
                                Utils.showInfoDialog(who: self, title: "Error", message: "Unable to load the published news.")
                                
                                self.updateViewFromModel()
                                return
                            }
                            
                            // Si hemos llegado hasta aquí, es que la petición se realizó correctamente
                            print("\nResultado de la invocación a 'published_news':\n\(result!)\n")
                            
                            // Convertir el JSON recibido en una lista de DatabaseRecord y añadir al modelo
                            // solo los registros correctos (los que incluyan, al menos: id, title, writer y publishedAt)
                            let json = result as! [DatabaseRecord]
                            
                            for news in json {
                                
                                if news["id"] == nil || news["title"] == nil || news["writer"] == nil || news["publishedAt"] == nil {
                                    
                                    print("\nDescartado un del JSON elemento por campos incorrectos/ausentes\n")
                                }
                                else {
                                    self.newsList?.append(news)
                                }
                            }
                            
                            // Actualizar la vista, en la cola principal
                            self.updateViewFromModel()
        })
    }
    
    // Realiza la carga de noticias y actualiza la vista, eliminando primero la caché de imágenes
    // (para ejecutar cuando el usuario haga un pull refresh)
    func fullLoadNews() {
        
        thumbsCache.removeAll()
        loadNews(originIsPullRefresh: true)
    }
    
    
    // MARK: Funciones auxiliares para el manejo de la UI
    
    // Configuración inicial de los elementos de la UI de este controlador
    func setupUI() {
        
        // Etiqueta para mostrar si no hay datos en la tabla
        emptyLabel.text = "No news to show right now, please pull down to refresh."
        emptyLabel.textColor = UIColor.gray
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = NSTextAlignment.center
        emptyLabel.sizeToFit()
        
        // RefreshControl para refrescar la tabla tirando de ella hacia abajo (pull refresh)
        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.clear
        refreshControl?.tintColor = UIColor.black
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: #selector(fullLoadNews), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl!)
        tableView.dataSource = self
        tableView.delegate = self
        
        self.tableView.separatorStyle = .none
        
        self.tableView.backgroundView = indicator   // ActivityIndicator que se mostrará durante la carga de la tabla
        title = "Latest News"   // Título para mostrar
    }
    
    // Actualizar la vista con los datos del modelo, en la cola principal
    // (detiene los indicadores de actividad, muestra las celdas y el mensaje de tabla vacía, si es necesario)
    func updateViewFromModel() {
        
        DispatchQueue.main.async {
            self.stopAllActivityIndicators()
            self.tableView.reloadData()
            self.showEmptyLabelIfNeeded()
        }
    }
    
    // Detiene y oculta todos los indicadores de actividad de la tabla
    // (tanto el estándar como el del pull refresh)
    func stopAllActivityIndicators() {
        
        Utils.stopTableRefreshing(self)
        Utils.switchActivityIndicator(self.indicator, show: false)
    }
    
    // Si la tabla está vacía, muestra un aviso al usuario
    // En caso contrario, solo asigna el activity indicator como background de la tabla
    func showEmptyLabelIfNeeded() {
        
        DispatchQueue.main.async {
            
            if (self.newsList?.isEmpty)! {
                self.tableView.backgroundView = self.emptyLabel
            }
            else {
                self.tableView.backgroundView = self.indicator
            }
        }
    }
    

}
