import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:logger/logger.dart';

/// JWT authentication middleware for WebSocket and HTTP requests.
///
/// Validates JWT tokens in the Authorization header and extracts user identity.
/// Enforces security as specified in ADR-0002 acceptance criteria.
class AuthMiddleware {
  final String jwtSecret;
  final Logger logger;
  final Duration tokenExpiry;

  AuthMiddleware({
    required this.jwtSecret,
    Logger? logger,
    this.tokenExpiry = const Duration(hours: 24),
  }) : logger = logger ?? Logger();

  /// Validates a JWT token and returns the decoded payload.
  ///
  /// Throws [JWTExpiredException] if token is expired.
  /// Throws [JWTException] if token is invalid.
  Map<String, dynamic>? validateToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload as Map<String, dynamic>;
    } on JWTExpiredException {
      logger.w('JWT token expired');
      rethrow;
    } on JWTException catch (e) {
      logger.w('JWT validation failed: $e');
      rethrow;
    }
  }

  /// Extracts and validates JWT token from Authorization header.
  ///
  /// Returns null if token is missing or invalid.
  Map<String, dynamic>? validateRequest(HttpRequest request) {
    final authHeader = request.headers.value('authorization');
    if (authHeader == null) {
      logger.w('Missing Authorization header');
      return null;
    }

    if (!authHeader.startsWith('Bearer ')) {
      logger.w('Invalid Authorization header format');
      return null;
    }

    final token = authHeader.substring(7);
    try {
      return validateToken(token);
    } catch (e) {
      logger.w('Token validation failed: $e');
      return null;
    }
  }

  /// Extracts user ID from validated token payload.
  String? extractUserId(Map<String, dynamic> payload) {
    return payload['userId'] as String?;
  }

  /// Extracts user display name from validated token payload.
  String? extractDisplayName(Map<String, dynamic> payload) {
    return payload['displayName'] as String?;
  }

  /// Creates a new JWT token for a user.
  ///
  /// Used for testing and development. In production, tokens should be
  /// issued by a dedicated authentication service.
  String createToken({
    required String userId,
    String? displayName,
    String? email,
    Map<String, dynamic>? additionalClaims,
  }) {
    final payload = {
      'userId': userId,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(tokenExpiry).millisecondsSinceEpoch ~/ 1000,
      ...?additionalClaims,
    };

    final jwt = JWT(payload);
    return jwt.sign(SecretKey(jwtSecret));
  }

  /// Validates WebSocket connection request and extracts user identity.
  ///
  /// Checks for JWT token in either Authorization header or 'token' query param.
  Map<String, dynamic>? validateWebSocketRequest(HttpRequest request) {
    // Try Authorization header first
    final headerAuth = validateRequest(request);
    if (headerAuth != null) {
      return headerAuth;
    }

    // Fallback to query parameter
    final uri = request.uri;
    final token = uri.queryParameters['token'];
    if (token != null) {
      try {
        return validateToken(token);
      } catch (e) {
        logger.w('Query param token validation failed: $e');
        return null;
      }
    }

    logger.w('No valid authentication found for WebSocket request');
    return null;
  }
}

/// Exception thrown when authentication fails.
class AuthenticationException implements Exception {
  final String message;

  AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Exception thrown when user is not authorized for an action.
class AuthorizationException implements Exception {
  final String message;

  AuthorizationException(this.message);

  @override
  String toString() => 'AuthorizationException: $message';
}
