# GeoGio

GeoGio es una aplicación Flutter diseñada para proporcionar una experiencia de mapeo y geolocalización. La aplicación permite a los usuarios navegar por diferentes vistas de mapas, iniciar sesión, registrarse y gestionar sus datos de ubicación.

Esta aplicación depende de un servidor en línea o local que se adjunta.
Antes de iniciar la aplicación, inicie el servidor y cambie la dirección IP que está en la ruta 
`/lib/misc/config.dart`.

## Características

- **Mapa Interactivo**: Navega por diferentes vistas de mapas.
- **Autenticación**: Inicia sesión y regístrate para acceder a funciones personalizadas.
- **Notificaciones**: Notificaciones al generar algun cambio en las zonas.
- **Gestión de Datos**: Almacena y elimina datos de ubicación y zonas en una base de datos SQLite.
- **Cierre de Sesión**: Elimina todos los datos almacenados al cerrar sesión.

## Uso de aplicación

1. **Descomprime**
2. **Navega al directorio del proyecto**: cd geo_gio
3. **Instala las dependencias**: flutter pub get
4. **Inicia la aplicacion**: flutter run
5. **Sigue las instrucciones en pantalla para navegar por la aplicación.**
6. **Un tap para agregar una ubicacion y tap sostenido para agregar una zona.**

## Inicio del servidor

1. **Descomprime**
2. **Navega al directorio del servidor**: cd server_geo_gio
3. **Instala las dependencias javascript**: npm install
3. **Instala las dependencias composer**: composer install
4. **Inicia el servidor**: php artisan serve --host=0.0.0.0 --port=8000
4. **Inicia el servidor de npm (No se requiere)**: npm run dev
5. **Asegúrate de que el servidor esté corriendo**




