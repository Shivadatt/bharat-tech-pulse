import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exceptions.dart';

/// Maps Supabase/PostgREST failures onto the app exception family and
/// guarantees raw Postgres messages never reach the UI (they are kept in
/// `details` for debugging only).
extension PostgrestErrorMapper on PostgrestException {
  AppException toAppException() => mapPostgrestException(this);
}

AppException mapPostgrestException(PostgrestException e) {
  switch (e.code) {
    case '23505':
      return ValidationException(
        'A record with this value already exists. Please use a unique value.',
        code: e.code,
        details: e.message,
      );
    case '42501':
      return AppException(
        "You don't have permission to perform this action.",
        code: e.code,
        details: e.message,
      );
    case 'PGRST116':
      return NotFoundException(
        'The requested record was not found.',
        code: e.code,
        details: e.message,
      );
    default:
      return AppException(
        'Something went wrong. Please try again.',
        code: e.code,
        details: e.message,
      );
  }
}

/// Duck-typed network failure detection. On Flutter Web there is no
/// [SocketException]; failed XHR/fetch calls surface as http ClientException
/// or browser-flavored messages, so match on type name and message text.
bool isNetworkError(Object error) {
  if (error is SocketException) return true;
  final typeName = error.runtimeType.toString().toLowerCase();
  if (typeName.contains('socketexception') ||
      typeName.contains('clientexception')) {
    return true;
  }
  final message = error.toString().toLowerCase();
  return message.contains('xmlhttprequest') ||
      message.contains('failed to fetch') ||
      message.contains('connection refused') ||
      message.contains('network is unreachable') ||
      message.contains('networkerror');
}

/// Runs a repository operation and converts every provider-level failure
/// into a friendly [AppException]. App-level exceptions pass through
/// unchanged so [ValidationException]/[NotFoundException] semantics survive.
Future<T> guardPostgrest<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on AppException {
    rethrow;
  } on PostgrestException catch (e) {
    throw mapPostgrestException(e);
  } catch (e) {
    if (isNetworkError(e)) {
      throw NetworkException(
        'Network error. Please check your connection and try again.',
        details: e,
      );
    }
    throw AppException('Something went wrong. Please try again.', details: e);
  }
}
