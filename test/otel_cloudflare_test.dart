// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_cloudflare/otel_cloudflare.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_cloudflare-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('R2 put records bytes + etag', () async {
    await tracedCloudflareR2<String>(
      operation: 'put',
      bucket: 'assets',
      objectKey: 'images/a.png',
      invoke: () async => const CloudflareR2CallResult(
        value: 'ok',
        bytes: 4096,
        etag: 'abc123',
      ),
    );
    final span = spans.findSpanByName('r2 put assets');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.client);
    final a = attrsOf(span);
    expect(a['cloudflare.service'], 'r2');
    expect(a['cloudflare.r2.bucket'], 'assets');
    expect(a['cloudflare.r2.object.key'], 'images/a.png');
    expect(a['cloudflare.operation'], 'put');
    expect(a['cloudflare.r2.object.size'], 4096);
    expect(a['cloudflare.r2.object.etag'], 'abc123');
  });

  test('KV get records namespace + key', () async {
    await tracedCloudflareKv<String>(
      operation: 'get',
      namespace: 'cache',
      kvKey: 'session:42',
      invoke: () async => 'cached',
    );
    final a = attrsOf(spans.findSpanByName('kv get cache')!);
    expect(a['cloudflare.service'], 'kv');
    expect(a['cloudflare.kv.namespace'], 'cache');
    expect(a['cloudflare.kv.key'], 'session:42');
    expect(a['cloudflare.operation'], 'get');
  });

  test('Worker RPC records binding + method', () async {
    await tracedCloudflareWorkerRpc<String>(
      binding: 'AUTH',
      method: 'verify',
      invoke: () async => 'ok',
    );
    final a = attrsOf(spans.findSpanByName('worker AUTH.verify')!);
    expect(a['cloudflare.service'], 'workers');
    expect(a['cloudflare.worker.binding'], 'AUTH');
    expect(a['cloudflare.worker.method'], 'verify');
  });

  test('records exception on throw', () async {
    await expectLater(
      tracedCloudflareKv<String>(
        operation: 'get',
        namespace: 'n',
        kvKey: 'k',
        invoke: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(spans.findSpanByName('kv get n')!.status, SpanStatusCode.Error);
  });

  test('suppression skips spans', () async {
    await runWithoutCloudflareInstrumentationAsync(() async {
      await tracedCloudflareR2<String>(
        operation: 'put',
        bucket: 'b',
        objectKey: 'k',
        invoke: () async => const CloudflareR2CallResult(value: 'v'),
      );
      await tracedCloudflareKv<String>(
        operation: 'put',
        namespace: 'n',
        kvKey: 'k',
        invoke: () async => 'ok',
      );
      await tracedCloudflareWorkerRpc<String>(
        binding: 'b',
        method: 'm',
        invoke: () async => 'ok',
      );
    });
    expect(spans.findSpansStartingWith('r2 '), isEmpty);
    expect(spans.findSpansStartingWith('kv '), isEmpty);
    expect(spans.findSpansStartingWith('worker '), isEmpty);
  });
}
