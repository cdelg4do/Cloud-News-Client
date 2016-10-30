//
//  Utils.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation


class Utils {
    
    // Clausuras de finalización, funciones que reciben un UIImage?, un Data?, o un String?
    // y que se ejecutarán siempre en la cola principal
    
    typealias imageClosure = (UIImage?) -> ()
    typealias dataClosure = (Data?) -> ()
    typealias stringClosure = (String?) -> ()
    
    
    // Función que realiza la descarga de un blob de una imagen contenida en un Storage Container remoto, en segundo plano
    // Si la descarga se realiza con éxito, produce la UIImage resultante.
    // Si no se pudo descargar o no es una imagen, produce nil.
    //
    // Parámetros:
    //
    // - blobName: nombre del blob que se quiere descargar
    // - containerName: cadena con el nombre del container en que se encuentra el blob
    // - activityIndicator: activa y desactiva el indicador de actividad antes y después de la operación asíncrona (si no se usa, dejar a nil)
    // - completion: clausura de finalización que recibe un UIImage? resultante, que se ejecutará en la cola principal
    
    class func downloadBlobImage(_ blobName: String, fromContainer containerName: String, activityIndicator: UIActivityIndicatorView?, completion: @escaping imageClosure) {
        
        // Obtener el enlace al blob
        // (credenciales > cuenta de storage > cliente de storage asociado > contenedor remoto > blob de la imagen)
        
        var imageBlob: AZSCloudBlockBlob
        
        do {
            // Configuración del cliente de Storage
            let storageCredentials = AZSStorageCredentials(accountName: Backend.storageAccountName, accountKey: Backend.storageKeyString)
            let storageAccount = try AZSCloudStorageAccount(credentials: storageCredentials, useHttps: true)
            let storageClient = ( storageAccount.getBlobClient() )!
            
            // Contenedor de las imagenes
            let imagesContainer: AZSCloudBlobContainer = storageClient.containerReference(fromName: containerName)
            
            // Blob de la imagen
            imageBlob = imagesContainer.blockBlobReference(fromName: blobName)
        }
        
            
        // Si hubo errores, invocar a la clausura con nil y finalizar
        catch {
            print("\nNo pudo construirse el blob de la imagen a descargar\n")
            
            completion(nil)
            return
        }
        
        
        // Si no hubo errores, intentamos descargar el blob en segundo plano
        imageBlob.downloadToData { (error, data) in
            
            if let _ = error {
                
                print("\nError al descargar el blob remoto\n\(error)\n")
                
                completion(nil)
                return
            }
            
            print("\nBlob descargado con éxito! (\((data?.count)!) bytes)\n")
            completion( UIImage(data: data!) )
        }
        
    }
    
    
    // Función que realiza la descarga de datos de una URL remota en segundo plano
    // Si la descarga se realiza con éxito, produce el Data resultante.
    // Si no, produce nil.
    //
    // Parámetros:
    //
    // - fromUrl: cadena con la url remota
    // - activityIndicator: activa y desactiva el indicador de actividad antes y después de la operación asíncrona (si no se usa, dejar a nil)
    // - completion: clausura de finalización que recibe un Data? resultante, que se ejecutará en la cola principal
    
    class func asyncDownloadData(fromUrl urlString: String, activityIndicator: UIActivityIndicatorView?, completion: @escaping dataClosure) {
        
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimating()
        
        // Carga de datos (en segundo plano)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(1) ) {
            
            var remoteData: Data?
            
            do {
                let remoteURL = URL(string: urlString)
                
                if remoteURL != nil {   remoteData = try Data(contentsOf: remoteURL!, options: Data.ReadingOptions.mappedIfSafe)    }
                else                {   remoteData = nil    }
            }
            catch {
                remoteData = nil
            }
            
            // Pasar los datos obtenidos a la clausura de finalización (en la cola principal)
            DispatchQueue.main.async {
                
                activityIndicator?.stopAnimating()
                activityIndicator?.isHidden = true
                
                completion(remoteData)
            }
        }
        
    }
    
    
    // Función que obtiene (en segundo plano) la dirección física correspondiente a unas coordenadas
    // Si la dirección dispone de varios niveles de detalle, devolverá solo los dos niveles más generales (ej. Provincia y País)
    //
    // Si la operación se realiza con éxito, produce el String correspondiente.
    // Si no, produce nil.
    //
    // Parámetros:
    //
    // - lat, long: coordenadas de la ubicación que se quiere identificar
    // - completion: clausura de finalización que recibe un String? resultante, que se ejecutará en la cola principal
    
    class func asyncReverseGeolocation(location: CLLocation, completion: @escaping stringClosure) {
        
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
            
            if error != nil {
                print("\nERROR: No ha sido posible realizar la geolocalización inversa\n" + (error?.localizedDescription)!)
                completion(nil)
            }
            
            else if let placemarks = placemarks,
                    let placemark = placemarks.last,
                    let lines: Array<String> = placemark.addressDictionary?["FormattedAddressLines"] as? Array<String> {
                
                        //completion( lines.joined(separator: ", ") )
                
                        var address = lines[0]
                        if lines.count > 1  {   address = lines[lines.count-2] + ", " + lines[lines.count-1] }
                        completion(address)
            }
                
            else {
                    print("\nERROR: No fue posible hallar una dirección para las coordenadas dadas\n")
                    completion(nil)
                }
        })
        
    }
    
    
    // Función que re-escala una imagen, para que entre dentro del CGSize indicado
    // (la imagen resultante mantiene su proporción original)
    // (ver https://iosdevcenters.blogspot.com/2015/12/how-to-resize-image-in-swift-in-ios.html)
    class func resizeImage(_ image: UIImage, toSize targetSize: CGSize) -> UIImage {
        
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    
    // Función que indica el tamaño de la pantalla del dispositivo
    class func screenSize() -> CGSize {
        
        return UIScreen.main.nativeBounds.size
    }
    
    
    // Función que convierte un objeto NSDate a la correspondiente cadena de texto
    class func dateToString(_ date: NSDate) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        
        return formatter.string(from: date as Date)
    }
    
    
    // Función que muestra/oculta todas las subvistas de una vista
    class func changeSubviewsVisibility(ofView parentView: UIView, hide newStatus: Bool) {
        
        for view in parentView.subviews {
            view.isHidden = newStatus
        }
    }
    
    
    // Función que muestra en un ViewController un diálogo (con un título, un mensaje y un botón de aceptar)
    class func showInfoDialog( who parent: UIViewController, title dialogTitle: String, message dialogMessage: String) {
        
        let alert = UIAlertController(title: dialogTitle, message: dialogMessage, preferredStyle: .alert)
        alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
        parent.present(alert, animated: true, completion: nil)
    }
    
    
    // Función que muestra un diálogo (con un título, un mensaje y un botón de cerrar el controlador actual)
    class func showCloseControllerDialog( who parent: UIViewController, title dialogTitle: String, message dialogMessage: String) {
        
        let actionClose = UIAlertAction(title: "Close", style: .default) { (alertAction) in
            
            let _ = parent.navigationController?.popViewController(animated: true)
        }
        
        let alert = UIAlertController(title: dialogTitle, message: dialogMessage, preferredStyle: .alert)
        alert.addAction( actionClose )
        parent.present(alert, animated: true, completion: nil)
    }
    
    
    // Función que muestra/oculta un ActivityIndicatorView
    class func switchActivityIndicator(_ indicator: UIActivityIndicatorView?, show: Bool) {
        
        DispatchQueue.main.async {
            
            if show {
                indicator?.isHidden = false
                indicator?.startAnimating()
            }
            else {
                indicator?.stopAnimating()
                indicator?.isHidden = true
            }
        }
    }
    
    
    // Función que detiene el pull refresh de un UITableViewController, si estaba teniendo lugar
    class func stopTableRefreshing(_ controller: UITableViewController) {
        
        DispatchQueue.main.async {
            
            if (controller.refreshControl?.isRefreshing)! {
                controller.refreshControl?.endRefreshing()
            }
        }
    }
    
    class func stopTableRefreshing(_ refreshControl: UIRefreshControl?) {
        
        DispatchQueue.main.async {
            
            if (refreshControl?.isRefreshing)! {
                refreshControl?.endRefreshing()
            }
        }
    }
    
}

