abstract class CloudError implements Exception {
  final String message;

  const CloudError(this.message);

  @override
  String toString() => 'iCloud exception: $message';
}

class InitializeError extends CloudError {
  const InitializeError() : super('Storage not initialized');
}

class ArgumentsError extends CloudError {
  const ArgumentsError() : super('Required arguments are not provided');
}

class ItemNotFoundError extends CloudError {
  const ItemNotFoundError() : super('Record this with id not found');
}

class PermissionError extends CloudError {
  const PermissionError() : super('Permission access was denied by user settings');
}

class AlreadyExists extends CloudError {
  const AlreadyExists() : super('Record with this key already exists');
}

class UnknownError extends CloudError {
  const UnknownError(super.message);
}

class QuotaExceededError extends CloudError {
  const QuotaExceededError() : super('Quota Exceeded');
}
