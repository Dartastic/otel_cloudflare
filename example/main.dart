// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_cloudflare/otel_cloudflare.dart';

/// Traces Cloudflare Workers RPC calls with OpenTelemetry.
///
/// `otel_cloudflare` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Cloudflare Workers RPC call in
/// [tracedCloudflareWorkerRpc]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'cloudflare-example');

  // Wraps a Cloudflare Workers RPC call (service binding fetch) in a CLIENT span.
  final cloudflareWorkerRpcId = await tracedCloudflareWorkerRpc<String>(
    binding: 'example',
    method: 'POST',
    invoke: () async {
      // Make the Cloudflare Workers RPC call here, then report what it returned.
      return 'cloudflare_8f3a2c';
    },
  );
  OTelLog.info('tracedCloudflareWorkerRpc returned $cloudflareWorkerRpcId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutCloudflareInstrumentationAsync.
  await runWithoutCloudflareInstrumentationAsync(
    () => tracedCloudflareWorkerRpc<String>(
      binding: 'example',
      method: 'POST',
      invoke: () async {
        return 'cloudflare_8f3a2c';
      },
    ),
  );

  await OTel.shutdown();
}
