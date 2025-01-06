// lib/utils/js_interop.dart
import 'package:js/js.dart';

@JS('Promise')
class PromiseJsImpl<T> {
  external PromiseJsImpl(void Function(void Function(T) resolve, Function reject) executor);
  external PromiseJsImpl then(Function onFulfilled, [Function? onRejected]);
}

@JS()
external dynamic Function(dynamic any) get dartify;

@JS()
external dynamic Function(dynamic any) get jsify;