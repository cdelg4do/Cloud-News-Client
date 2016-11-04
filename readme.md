# Práctica Cloud Computing para Desarrollo Mobile de Carlos Delgado Andrés

**Cloud News** es un prototipo de aplicación para iOS realizada en Swift 3.0 y Xcode 8.

Se trata de un sencillo agregador de noticias para iPhone, que utiliza un perfil de autor autenticado (mediante una cuenta de Facebook) para la edición y publicación de noticias en el sistema. Las noticias publicadas se pueden consultar libremente mediante un perfil de lector anónimo.

La aplicación utiliza los siguientes dos frameworks de Microsoft Azure:

- Azure Storage Client Library for iOS (https://github.com/azure/azure-storage-ios)
- Mobile Services iOS SDK 3.2.0 (https://go.microsoft.com/fwLink/?LinkID=529823).

.
#### Consideraciones adicionales:

- El código del backend que da soporte al cliente móvil está disponible en el repositorio **Cloud News Backend** (https://github.com/cdelg4do/Cloud-News-Backend).

- Los artículos/noticias pasan por 3 estados diferentes: en primer lugar, se crean en estado borrador **(draft)**, en el que pueden ser salvados y editados múltiples veces. Una vez completados, el usuario puede pasarlos a estado enviado **(submitted)** en el que permanecerán a la espera de ser publicados en el sistema. Por último, los artículos pasan a estar publicados **(published)** y serán visibles por todos los usuarios.

- Existen dos perfiles de usuario en la aplicación: **usarios anónimos** que pueden consultar y leer todas las noticias que se hayan publicado en el sistema sin falta de identificarse, y **usuarios autenticados** que pueden crear, editar y enviar noticias para que sean publicadas.

- Para la identificación de usuarios autenticados se utiliza **Facebook** como provedor de identidad, por lo que será necesario tener una cuenta en este servicio para iniciar sesión en la aplicación.

- Dado que el SDK de Mobile Services no implementa ningún método para el cierre de sesión con el provedor de Facebook, es posible cerrar la sesión de usuario en el servicio de Azure y volverla a iniciar pero siempre con las mismas credenciales. **Para forzar la aparición del formulario de inicio de sesión en Facebook, al cerrar la sesión se eliminan las cookies locales del dispositivo**. Esto funciona si la app se ejecuta en un dispositivo físico, pero no funciona si se ejecuta en el simulador de Xcode. Si se desea volver a mostrar el formulario de *login* en Facebook, será necesario desinstalar y volver a instalar la aplicación en el simulador.

- Toda la información de los artículos se almacena en la *cloud* de Microsoft Azure, así que se puede reinstalar la app en el dispositivo cliente sin que se pierda ninguna información. Los únicos datos que almacena el cliente en *caché* local son las miniaturas de imagen para mostrar en los listados de artículos (tanto los de usuarios autenticados como los de usuarios anónimos). **Esta *caché* se recrea automáticamente cuando el usuario hace un *pull refresh*** (arrastrar con el dedo hacia abajo) en la lista.

- Se ha configurado una tarea programada **(Web Job)** en la *cloud* de Azure para publicar las noticias que envían los usuarios autenticados. Esta tarea se ejecuta cíclicamente **cada 15 minutos**.

- La app implementa **geolocalización inversa** para mostrar la ubicación aproximada del sitio en que se escribió cada noticia publicada. Sin embargo, no se ha implementado la captura de la ubicación actual. En su lugar, **se generan unas coordenadas GPS aleatorias para cada artículo**, lo que permite probar el correcto funcionamiento de la geolocalización inversa para múltiples ubicaciones sin necesidad de desplazarse. En una app en producción, bastaría sustituir la generación de coordenadas aleatorias por una llamada al sistema para capturar la ubicación real del dispositivo cliente.

- Cada vez que se visualiza una noticia publicada por parte de un usuario anónimo, se incrementa el contador de visitas de la misma. Sin embargo, si los usuarios autenticados visualizan sus propias publicaciones desde su panel de ***"My published articles"*** entonces no se modificará dicho contador.

