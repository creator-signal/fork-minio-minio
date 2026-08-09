// This file is part of MinIO Console Server
// Copyright (c) 2026 MinIO, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import { LOGIN_REDIRECT_TARGET } from "./routeContracts";

describe("protected-route login redirect", () => {
  test("targets the canonical absolute login route", () => {
    expect(LOGIN_REDIRECT_TARGET).toEqual({ pathname: "/login" });
    expect(LOGIN_REDIRECT_TARGET.pathname.startsWith("/")).toBe(true);
  });
});
