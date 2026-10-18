import 'package:firebase_core/firebase_core.dart';

/// Converts application errors into user-facing Spanish messages.
abstract final class AppErrorMessages {
  /// Returns a message suitable for displaying to the user.
  ///
  /// Recognizes authentication, database, validation, and session errors.
  /// Returns a generic message for unsupported errors.
  /// Internal exception messages are not exposed.
  static String fromError(Object error) {
    if (error is FirebaseException) {
      if (error.plugin == 'firebase_auth') {
        return _authenticationMessage(error.code);
      }

      if (error.plugin == 'cloud_firestore') {
        return _databaseMessage(error.code);
      }
    }

    if (error is FormatException) {
      return 'No se pudo procesar la información. Revisá los datos.';
    }

    if (error is StateError) {
      return 'No se pudo completar la operación con la sesión actual. '
          'Volvé a iniciar sesión.';
    }

    return 'No pudimos completar la operación. Intentá nuevamente.';
  }

  /// Translates a Firebase Authentication error [code].
  ///
  /// Uses a generic authentication message for unsupported codes.
  static String _authenticationMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo electrónico no tiene un formato válido.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'El correo o la contraseña son incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo electrónico.';
      case 'weak-password':
        return 'La contraseña no cumple los requisitos de seguridad.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Contactá al administrador.';
      case 'too-many-requests':
        return 'Se hicieron demasiados intentos. Esperá un momento.';
      case 'network-request-failed':
        return 'No pudimos conectar. Revisá tu conexión a internet.';
      case 'operation-not-allowed':
        return 'El acceso no está disponible. Contactá al administrador.';
      default:
        return 'No pudimos completar la operación de acceso.';
    }
  }

  /// Translates a Cloud Firestore error [code].
  ///
  /// Uses a generic database message for unsupported codes.
  static String _databaseMessage(String code) {
    switch (code) {
      case 'permission-denied':
        return 'No tenés permiso para realizar esta acción.';
      case 'unauthenticated':
        return 'Tu sesión no está disponible. Volvé a iniciar sesión.';
      case 'unavailable':
        return 'El servicio no está disponible. Intentá nuevamente.';
      case 'deadline-exceeded':
        return 'La operación tardó demasiado. Intentá nuevamente.';
      case 'not-found':
        return 'La información solicitada ya no está disponible.';
      default:
        return 'No pudimos consultar o guardar la información.';
    }
  }
}
