// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_cloudflare_suppression.dart';

const _tracerName = 'dartastic_otel_libs_cloudflare';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedCloudflareR2*` callbacks.
class CloudflareR2CallResult<T> {
  const CloudflareR2CallResult({required this.value, this.bytes, this.etag});
  final T value;
  final int? bytes;
  final String? etag;
}

/// Wraps a Cloudflare R2 object operation (S3-compatible) in a
/// CLIENT span using OTel object-store conventions.
Future<T> tracedCloudflareR2<T>({
  required String operation,
  required String bucket,
  required String objectKey,
  required Future<CloudflareR2CallResult<T>> Function() invoke,
}) {
  return _runR2(
    operation: operation,
    bucket: bucket,
    objectKey: objectKey,
    invoke: invoke,
  );
}

/// Wraps a Cloudflare KV operation in a CLIENT span.
Future<T> tracedCloudflareKv<T>({
  required String operation,
  required String namespace,
  required String kvKey,
  required Future<T> Function() invoke,
}) async {
  if (cloudflareInstrumentationSuppressed()) {
    return invoke();
  }
  final span = _tracer().startSpan(
    'kv $operation $namespace',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap({
      'cloudflare.service': 'kv',
      'cloudflare.kv.namespace': namespace,
      'cloudflare.kv.key': kvKey,
      'cloudflare.operation': operation,
    }),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps a Cloudflare Workers RPC call (service binding `fetch`)
/// in a CLIENT span.
Future<T> tracedCloudflareWorkerRpc<T>({
  required String binding,
  required String method,
  required Future<T> Function() invoke,
}) async {
  if (cloudflareInstrumentationSuppressed()) {
    return invoke();
  }
  final span = _tracer().startSpan(
    'worker $binding.$method',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap({
      'cloudflare.service': 'workers',
      'cloudflare.worker.binding': binding,
      'cloudflare.worker.method': method,
    }),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

Future<T> _runR2<T>({
  required String operation,
  required String bucket,
  required String objectKey,
  required Future<CloudflareR2CallResult<T>> Function() invoke,
}) async {
  if (cloudflareInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final span = _tracer().startSpan(
    'r2 $operation $bucket',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap({
      'cloudflare.service': 'r2',
      'cloudflare.r2.bucket': bucket,
      'cloudflare.r2.object.key': objectKey,
      'cloudflare.operation': operation,
    }),
  );
  try {
    final r = await invoke();
    final extra = <Attribute<Object>>[];
    if (r.bytes != null) {
      extra.add(OTel.attributeInt('cloudflare.r2.object.size', r.bytes!));
    }
    if (r.etag != null) {
      extra.add(OTel.attributeString('cloudflare.r2.object.etag', r.etag!));
    }
    if (extra.isNotEmpty) span.addAttributes(OTel.attributes(extra));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
