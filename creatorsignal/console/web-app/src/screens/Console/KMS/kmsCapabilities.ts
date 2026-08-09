// This file is part of MinIO Console Server
// Copyright (c) 2026 MinIO, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// The built-in key implementation supports status and cryptographic operations,
// but intentionally does not implement the metrics, API-list, or version calls.
// Only enable those panels for server implementations that advertise them.
const ADVANCED_KMS_IMPLEMENTATIONS = new Set(["MinIO KMS", "MinIO KES"]);

export const supportsAdvancedKMSMonitoring = (name?: string): boolean =>
  Boolean(name && ADVANCED_KMS_IMPLEMENTATIONS.has(name));
