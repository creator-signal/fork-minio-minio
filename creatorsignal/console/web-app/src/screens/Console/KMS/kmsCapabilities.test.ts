// This file is part of MinIO Console Server
// Copyright (c) 2026 MinIO, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import { supportsAdvancedKMSMonitoring } from "./kmsCapabilities";

describe("KMS monitoring capabilities", () => {
  test.each(["SecretKey", "MinIO builtin"])(
    "does not probe unsupported APIs for %s",
    (name) => {
      expect(supportsAdvancedKMSMonitoring(name)).toBe(false);
    },
  );

  test.each(["MinIO KMS", "MinIO KES"])(
    "enables advanced monitoring for %s",
    (name) => {
      expect(supportsAdvancedKMSMonitoring(name)).toBe(true);
    },
  );

  test.each([undefined, "", "Future KMS"])(
    "fails closed when the KMS implementation is %s",
    (name) => {
      expect(supportsAdvancedKMSMonitoring(name)).toBe(false);
    },
  );
});
