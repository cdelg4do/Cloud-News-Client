//
//  InitialViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 26/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  Este controlador se encarga de mostrar el listado de noticias publicadas para los usuarios anónimos.
//  Desde este controlador se realizan los inicios y cierres de sesión en Facebook.


import UIKit


class InitialViewController: UIViewController {
    
    // Cliente de Azure Mobile
    // (se inicializa aquí, y se comparte en los demás controladores de la aplicación)
    var appClient: MSClient = MSClient(applicationURL: URL(string: Backend.mobileAppUrlString)!)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    // MARK: Acciones al pulsar los botones de la vista
    
    // Botón de leer noticias
    @IBAction func enterReaderMode(_ sender: AnyObject) {
        
        // Crear el controlador para mostrar la lista de noticias publicadas, y mostrarlo
        let readerVC = ReaderTableViewController(client: appClient)
        navigationController?.pushViewController(readerVC, animated: true)
    }
    
    // Botón de escribir noticias
    @IBAction func enterWriterMode(_ sender: AnyObject) {
        
        // Crear el controlador para mostrar la lista de noticias del autor, y mostrarlo
        let writerVC = WriterArticlesViewController(client: appClient)
        navigationController?.pushViewController(writerVC, animated: true)
    }
    
}

