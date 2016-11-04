//
//  WriterArticlesViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 30/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  Este controlador se encarga de mostrar los listados de artículos publicados, enviados o borradores del usuario.
//  Desde este controlador se realizan los inicios y cierres de sesión en Facebook.


import UIKit


class WriterArticlesViewController: UIViewController {
    
    // MARK: Propiedades de la clase
    
    var appClient: MSClient                     // Cliente de Azure Mobile
    var articleList: [DatabaseRecord]? = []     // Lista de artículos a mostrar en la tabla
    var thumbsCache = [String:UIImage]()        // Caché de miniaturas
    
    var currentArticleStatus: ArticleStatus = ArticleStatus.draft   // Estado de los artículos que se muestran (por defecto: borradores)
    
    var sessionInfo: SessionInfo?               // Información sobre la sesión actual del usuario
    
    
    // MARK: Inicialización de la clase
    
    init(client: MSClient) {
        
        self.appClient = client
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: Elementos de la interfaz
    
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)  // Indicador de actividad de la tabla
    let emptyLabel = UILabel()  // Etiqueta para mostrar, en caso de que no haya datos en la tabla
    
    var refreshControl: UIRefreshControl?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnDraft: UIBarButtonItem!
    @IBOutlet weak var btnSubmitted: UIBarButtonItem!
    @IBOutlet weak var btnPublished: UIBarButtonItem!
    
    
    // MARK: Ciclo de vida del controlador
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        // Si hay una sesión activa, se cargan los artículos en la tabla
        // Si no, primero intentar iniciar sesión con Facebook y después cargar los artículos
        if let _ = appClient.currentUser    {   loadArticles(originIsPullRefresh: false) }
        else                                {   loginWithFacebookThenLoadNews()   }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        thumbsCache.removeAll()
    }
    
    
    // MARK: Acciones a realizar al pulsar los botones de la toolbar inferior
    
    // Mostrar los borradores del usuario
    @IBAction func btnDraftAction(_ sender: AnyObject) {
        currentArticleStatus = .draft
        loadArticles(originIsPullRefresh: false)
    }
    
    // Mostrar los artículos enviados del usuario
    @IBAction func btnSubmittedAction(_ sender: AnyObject) {
        currentArticleStatus = .submitted
        loadArticles(originIsPullRefresh: false)
    }
    
    // Mostrar los artículos publicados del usuario
    @IBAction func btnPublishedAction(_ sender: AnyObject) {
        currentArticleStatus = .published
        loadArticles(originIsPullRefresh: false)
    }
    
}


// MARK: Implementación de los protocolos UITableViewDataSource y TableViewDelegate

extension WriterArticlesViewController: UITableViewDataSource {
    
    // Número de secciones: 1 (0 si no hay datos que mostrar)
    func numberOfSections(in tableView: UITableView) -> Int {
        
        if (articleList?.isEmpty)!  {   return 0    }
        else                        {   return 1    }
    }
    
    // Número de filas en una sección: tantas como noticias publicadas (0 si no hay datos que mostrar)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (articleList?.isEmpty)!  {   return 0                    }
        else                        {   return (articleList?.count)!   }
    }
    
    // Configuración de las celdas de la tabla
    // (se muestra el título del artículo, el autor y una miniatura de la imagen)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Obtener los datos del artículo correspondiente a la celda
        let article = articleList?[indexPath.row]
        
        let articleId = article?["id"] as! String?
        let articleTitle = article?["title"] as! String?
        let articleVisits = article?["visits"] as! Int?
        let articleDate = article?["date"] as! NSDate?
        let articleHasImage = article?["hasImage"] as! Bool?
        let articleImageName = article?["imageName"] as! String?
        
        let dateString = Utils.dateToString(articleDate!)
        var detailLabelText: String
        
        switch (currentArticleStatus) {
            
            case .published:    detailLabelText = "\(articleVisits!) views since \(dateString)"
                                break
            
            case .submitted:    detailLabelText = "Submitted on \(dateString)"
                                break
        
            case .draft:        detailLabelText = "Last updated on \(dateString)"
                                break
        }
        
        
        // Obtención de la celda correspondiente al elemento
        let cellId = "articleCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId)
        
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        }
        
        // Configuración de la vista (título de la noticia, visitas y fecha)
        cell?.textLabel?.text = articleTitle!
        cell?.detailTextLabel?.text = detailLabelText
        
        cell?.imageView?.contentMode = .scaleAspectFit
        cell?.imageView?.image = UIImage(named: "news_placeholder.png")!
        
        // Si el artículo tiene una imagen asociada, mostrarla (si no está cacheada, se descarga)
        if articleHasImage! {
            
            if let cachedImage = thumbsCache[articleId!] {
                cell?.imageView?.image = cachedImage
            }
            else {
                let thumbnailName = "\(articleImageName!)_thumb.jpg"
                
                Utils.downloadBlobImage(thumbnailName, fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                    
                    // Si se descargó la imagen remota, cachearla y actualizar la vista (en la cola principal)
                    if image != nil {
                        
                        self.thumbsCache[articleId!] = image!
                        DispatchQueue.main.async {
                            cell?.imageView?.image = image!
                        }
                    }
                }
            }
        }
        
        return cell!
    }

}

extension WriterArticlesViewController: UITableViewDelegate {
    
    // Acción al seleccionar una celda de la tabla
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let selectedNews = articleList?[indexPath.row]
        let newsId = selectedNews?["id"] as! String?
        
        // Si estamos viendo un artículo entregado o ya publicado,
        // se muestra el controlador de lectura (ReaderNewsDetailViewController)
        // usando una api con autenticación para cargar los detalles
        if currentArticleStatus == .published || currentArticleStatus == .submitted {
            
            let detailVC = ReaderNewsDetailViewController(id: newsId!, anonymous: false, client: appClient)
            navigationController?.pushViewController(detailVC, animated: true)
        }

        // Si es un borrador, se muestra el controlador de edición (ArticleEditorViewController)
        else {
         
            let detailVC = ArticleEditorViewController(id: newsId!, client: appClient, session: sessionInfo!)
            navigationController?.pushViewController(detailVC, animated: true)
        }

    }

}


// MARK: Funciones auxiliares

extension WriterArticlesViewController {
    
    
    // Inicio de sesión con Facebook y carga de datos
    
    func loginWithFacebookThenLoadNews() {
        
        print("\nSolicitando inicio de sesión en Facebook...\n")
        
        appClient.login(withProvider: "facebook", parameters: nil, controller: self, animated: true) { (user, error) in
            
            if let _ = error {
                print("\nFallo al iniciar sesión en Facebook:\n\(error)\n")
                Utils.showInfoDialog(who: self, title: "Login Failure", message: "Unable to login into Facebook.")
                return
            }
            
            // Si se inició sesión correctamente, obtener los datos del usuario logueado (nombre, etc)
            print("\nInicio de sesión correcto en Facebook con el usuario:\n\((user?.userId)!)\n")
            
            self.appClient.invokeAPI(Backend.sessionInfoApiName,
                                     body: nil,
                                     httpMethod: "GET",
                                     parameters: nil,
                                     headers: nil,
                                     completion: { (result, response, error) in
                                        
                                        if let _ = error {
                                            print("\nFallo al invocar la api '\(Backend.sessionInfoApiName)':\n\(error)\n")
                                            Utils.showInfoDialog(who: self, title: "Error", message: "Unable to identify facebook user.")
                                            return
                                        }
                                        
                                        // Almacenamos la información del usuario
                                        print("\nResultado de la invocación a '\(Backend.sessionInfoApiName)':\n\(result!)\n")
                                        
                                        let json = result as! JsonElement
                                        self.sessionInfo = SessionInfo.validate(json)
                                        
                                        if self.sessionInfo == nil {
                                            print("\nRespuesta incorrecta desde '\(Backend.sessionInfoApiName)':\n\(result)\n")
                                            Utils.showInfoDialog(who: self, title: "Error", message: "Unable to identify facebook user.")
                                            return
                                        }
                                        
                                        // Actualizar la vista con los datos del usuario (en la cola principal)
                                        self.setupUserUIElements()
                                        
                                        // Por último, solicitamos del servidor los artículos del usuario y los cargamos en la tabla
                                        self.loadArticles(originIsPullRefresh: false)
            })
        }
    }
    
    
    // Obtener las noticias del servidor y actualizar la vista
    
    func loadArticles(originIsPullRefresh: Bool) {
        
        // Lo primero, comprobar que haya una sesión activa
        if appClient.currentUser == nil {
            
            print("\nIntento de refrescar la tabla sin tener una sesión activa.\n")
            Utils.showInfoDialog(who: self, title: "Not logged in", message: "Please use the Log in button at the navigation bar first.")
            
            self.stopAllActivityIndicators()
            return
        }
        
        
        // Si no estamos haciendo un pull refresh, mostramos el activity indicator de la tabla
        if !originIsPullRefresh {
            Utils.switchActivityIndicator(indicator, show: true)
        }
        
        
        // Invocar a la API remota que devuelve todos los artículos del tipo actual
        
        appClient.invokeAPI(Backend.myArticlesApiName,
                            body: nil,
                            httpMethod: "GET",
                            parameters: ["status": currentArticleStatus.rawValue],
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                // Vaciar la lista de noticias, antes de añadir los nuevos datos
                                self.articleList?.removeAll()
                                
                                if let _ = error {
                                    print("\nFallo al invocar la api '\(Backend.myArticlesApiName)':\n\(error)\n")
                                    Utils.showInfoDialog(who: self, title: "Error", message: "Unable to load your " + self.currentArticleStatus.rawValue + " articles.")
                                    
                                    self.updateViewFromModel()
                                    return
                                }
                                
                                // Si hemos llegado hasta aquí, es que la petición se realizó correctamente
                                print("\nResultado de la invocación a '\(Backend.myArticlesApiName)':\n\(result!)\n")
                                
                                // Convertir el JSON recibido en una lista de DatabaseRecord y añadir al modelo
                                // solo los registros correctos: (deben incluir: id, title, hasImage, imageName, visits, date)
                                let json = result as! [DatabaseRecord]
                                
                                for article in json {
                                    
                                    if article["id"] == nil
                                        || article["title"] == nil
                                        || article["hasImage"] == nil
                                        || article["imageName"] == nil
                                        || article["visits"] == nil
                                        || article["date"] == nil {
                                        
                                        print("\nDescartado un elemento del JSON por campos incorrectos/ausentes\n")
                                    }
                                    else {
                                        self.articleList?.append(article)
                                    }
                                }
                                
                                // Actualizar la vista, en la cola principal
                                self.updateViewFromModel()
        })
    }
    
    
    // Realiza la carga de noticias y actualiza la vista, eliminando primero la caché de imágenes
    // (para ejecutar cuando el usuario haga un pull refresh)
    
    func fullLoadArticles() {
        
        thumbsCache.removeAll()
        loadArticles(originIsPullRefresh: true)
    }
    
    
    // Usar esta función para mostrar algún dato del usuario después de iniciar sesión (nombre, etc)
    // Se ejecuta siempre en la cola principal
    
    func setupUserUIElements() {
        
        DispatchQueue.main.async {
            
            Utils.showInfoDialog(who: self, title: "Log in", message: "You are now connected as \((self.sessionInfo?.fullName)!). Enjoy!")
            
            // Otros ajustes
            // ...
        }
    }
    
    
    // Configuración inicial de los elementos de la UI de este controlador
    
    func setupUI() {
        
        // Añadir botones de sesión y de crear nuevo artículo
        addNavigationButtons()
        
        // Configuración de la etiqueta que se mostrará cuando la tabla esté vacía
        emptyLabel.textColor = UIColor.gray
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = NSTextAlignment.center
        emptyLabel.sizeToFit()
        
        // RefreshControl para refrescar la tabla tirando de ella hacia abajo (pull refresh)
        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.clear
        refreshControl?.tintColor = UIColor.black
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: #selector(fullLoadArticles), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl!)
        tableView.dataSource = self
        tableView.delegate = self

        self.tableView.separatorStyle = .none
        self.tableView.backgroundView = indicator   // ActivityIndicator que se mostrará durante la carga de la tabla
        title = "My " + currentArticleStatus.rawValue + " articles"   // Título para mostrar
    }
    
    
    // Actualizar la vista con los datos del modelo local, en la cola principal
    // (detiene los indicadores de actividad, muestra el título, las celdas y el mensaje de tabla vacía, si es necesario)
    
    func updateViewFromModel() {
        
        DispatchQueue.main.async {
            self.stopAllActivityIndicators()
            self.title = "My " + self.currentArticleStatus.rawValue + " Articles"
            self.tableView.reloadData()
            self.showEmptyLabelIfNeeded()
        }
    }
    
    
    // Detiene y oculta todos los indicadores de actividad de la tabla
    // (tanto el estándar como el del pull refresh)
    
    func stopAllActivityIndicators() {
        
        Utils.stopTableRefreshing(refreshControl)
        Utils.switchActivityIndicator(self.indicator, show: false)
    }
    
    
    // Si la tabla está vacía, muestra un aviso al usuario
    // En caso contrario, solo asigna el activity indicator como background de la tabla
    
    func showEmptyLabelIfNeeded() {
        
        DispatchQueue.main.async {
            
            if (self.articleList?.isEmpty)! {
                
                if self.appClient.currentUser == nil    {   self.emptyLabel.text = "Please log in to see your articles."    }
                else                                    {   self.emptyLabel.text = "No articles to show, please pull down to refresh."    }
                
                self.tableView.backgroundView = self.emptyLabel
            }
            else {
                
                self.tableView.backgroundView = self.indicator
            }
        }
    }
    
    
    // Creación de los botones de crear un nuevo articulo y de iniciar/finalizar sesión como botones derechos del navigation controller
    
    func addNavigationButtons() {
        
        let btn1 = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newArticleAction))
        navigationItem.rightBarButtonItem = btn1
        
        let btn2 = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(toggleSessionAction))
        navigationItem.rightBarButtonItems?.append(btn2)
    }
    
    
    // Acción al pulsar el botón de nuevo artículo
    
    func newArticleAction() {
        
        let editVC = ArticleEditorViewController(id: nil, client: appClient, session: sessionInfo!)
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    
    // Acción al pulsar el botón de sesión
    
    func toggleSessionAction() {
        
        // Si ya había una sesión iniciada, se cierra
        if let _ = appClient.currentUser {
            
            print("\nFinalizando la sesión de Facebook actual...\n")
            
            appClient.logout() { error in
                
                if let _ = error {
                    print("\nFallo al cerrar la sesión de Facebook activa:\n\(error)\n")
                    Utils.showInfoDialog(who: self, title: "Log out Failure", message: "There was an error while trying to log out.")
                    return
                }
                
                // El metodo anterior cierra la sesión, pero no elimina las cookies
                print("\nCOOKIES ANTES:\n")
                for value in HTTPCookieStorage.shared.cookies! {
                    print(value)
                }
                
                for c in HTTPCookieStorage.shared.cookies! {
                    HTTPCookieStorage.shared.deleteCookie(c)
                }
                
                
                print("\nSesión finalizada correctamente!\n")
                Utils.showInfoDialog(who: self, title: "Log out", message: "See you soon, \((self.sessionInfo?.firstName)!)! Press the button again to Log in.")
                
                // Eliminar los datos del usuario descargados y vaciar la tabla de artículos
                self.sessionInfo = nil
                self.articleList?.removeAll()
                self.updateViewFromModel()
            }
        }
        
        // Si no, se intenta iniciar sesión en Facebook
        else {
            loginWithFacebookThenLoadNews()
        }
        
    }
}





