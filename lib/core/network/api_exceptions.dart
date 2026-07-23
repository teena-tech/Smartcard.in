class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'Unable to reach server. Please check your connection and try again.']);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([super.message = 'Session expired. Please login again.']) : super(statusCode: 401);
}

class NotFoundException extends ApiException {
  NotFoundException([super.message = 'Endpoint not found. Restart backend server and retry.'])
      : super(statusCode: 404);
}

class BadRequestException extends ApiException {
  BadRequestException([super.message = 'Invalid request']) : super(statusCode: 400);
}

class ServerException extends ApiException {
  ServerException([super.message = 'Internal Server Error']) : super(statusCode: 500);
}
