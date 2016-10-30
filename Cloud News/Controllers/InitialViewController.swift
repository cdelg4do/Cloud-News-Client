//
//  InitialViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 26/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import UIKit

class InitialViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    // MARK: Acciones al pulsar los botones de la vista
    
    // Botón de leer noticias
    @IBAction func readerMode(_ sender: AnyObject) {
        
        // Crear el controlador para mostrar la lista de noticias publicadas, y mostrarlo
        let readerVC = ReaderTableViewController(nibName: nil, bundle: nil)
        navigationController?.pushViewController(readerVC, animated: true)
    }
    
    // Botón de redactar noticias
    @IBAction func authorMode(_ sender: AnyObject) {
        
        // Crear el controlador para mostrar la lista de noticias del autor, y mostrarlo
        let writerVC = WriterArticlesViewController(nibName: nil, bundle: nil)
        navigationController?.pushViewController(writerVC, animated: true)
    }
    
}

