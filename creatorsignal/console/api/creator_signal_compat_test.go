// Copyright (c) 2026 Creator Signal
//
// This file is part of MinIO Console Server.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"github.com/go-openapi/loads"
	authApi "github.com/minio/console/api/operations/auth"
	"github.com/minio/console/models"
	consoleoauth2 "github.com/minio/console/pkg/auth/idp/oauth2"
)

func TestCreatorSignalFullConsoleRouteContract(t *testing.T) {
	spec, err := loads.Embedded(SwaggerJSON, FlatSwaggerJSON)
	if err != nil {
		t.Fatal(err)
	}

	paths := spec.Spec().Paths.Paths
	if got, want := len(paths), 89; got != want {
		t.Fatalf("full console route count changed: got %d, want %d", got, want)
	}

	requiredPaths := []string{
		"/login/oauth2/auth",
		"/service-accounts",
		"/users",
		"/groups",
		"/policies",
		"/configs",
		"/admin/info",
		"/admin/notification_endpoints",
		"/remote-buckets",
		"/logs/search",
		"/kms/status",
		"/admin/inspect",
		"/idp/{type}",
		"/buckets/{bucket_name}/replication",
		"/buckets/{bucket_name}/object-locking",
	}
	for _, path := range requiredPaths {
		if _, ok := paths[path]; !ok {
			t.Errorf("Creator Signal console contract is missing %s", path)
		}
	}
}

func TestCreatorSignalOIDCLoginAndCallbackContract(t *testing.T) {
	const (
		providerName = "zitadel"
		clientID     = "creator-signal-minio"
		clientSecret = "test-only-secret"
		authCode     = "test-authorization-code"
	)

	var idp *httptest.Server
	idp = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/.well-known/openid-configuration":
			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(map[string]any{
				"issuer":                                idp.URL,
				"authorization_endpoint":                idp.URL + "/authorize",
				"token_endpoint":                        idp.URL + "/token",
				"response_types_supported":              []string{"code"},
				"scopes_supported":                      []string{"openid", "profile", "email"},
				"token_endpoint_auth_methods_supported": []string{"client_secret_basic"},
			}); err != nil {
				t.Errorf("write discovery document: %v", err)
			}
		case "/token":
			if err := r.ParseForm(); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			if r.Form.Get("code") != authCode {
				http.Error(w, "unexpected authorization code", http.StatusUnauthorized)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(map[string]any{
				"access_token":  "test-access-token",
				"refresh_token": "test-refresh-token",
				"id_token":      "test-id-token",
				"token_type":    "Bearer",
				"expires_in":    3600,
			}); err != nil {
				t.Errorf("write token response: %v", err)
			}
		case "/":
			w.Header().Set("Content-Type", "application/xml")
			_, _ = fmt.Fprintf(w, `<AssumeRoleWithWebIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
<AssumeRoleWithWebIdentityResult>
  <SubjectFromWebIdentityToken>creator-signal-operator</SubjectFromWebIdentityToken>
  <Audience>%s</Audience>
  <AssumedRoleUser>
    <Arn>arn:aws:sts::123456789012:assumed-role/CreatorSignalMinIO/operator</Arn>
    <AssumedRoleId>CREATORSIGNAL:operator</AssumedRoleId>
  </AssumedRoleUser>
  <Credentials>
    <SessionToken>test-session-token</SessionToken>
    <SecretAccessKey>test-secret-key</SecretAccessKey>
    <Expiration>%s</Expiration>
    <AccessKeyId>test-access-key</AccessKeyId>
  </Credentials>
  <Provider>%s</Provider>
</AssumeRoleWithWebIdentityResult>
<ResponseMetadata><RequestId>creator-signal-test</RequestId></ResponseMetadata>
</AssumeRoleWithWebIdentityResponse>`, clientID, time.Now().UTC().Add(time.Hour).Format(time.RFC3339), idp.URL)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(idp.Close)

	t.Setenv(consoleoauth2.ConsoleMinIOServer, idp.URL)
	t.Setenv("CONSOLE_PBKDF_PASSPHRASE", "creator-signal-test-passphrase")
	t.Setenv("CONSOLE_PBKDF_SALT", "creator-signal-test-salt")

	providers := consoleoauth2.OpenIDPCfg{
		providerName: {
			URL:              idp.URL + "/.well-known/openid-configuration",
			DisplayName:      "Creator Signal SSO",
			ClientID:         clientID,
			ClientSecret:     clientSecret,
			HMACSalt:         "creator-signal-deployment",
			HMACPassphrase:   clientID,
			Scopes:           "openid,profile,email",
			RedirectCallback: "https://storage.example.test/oauth_callback",
		},
	}

	req := httptest.NewRequest(http.MethodGet, "https://storage.example.test/api/v1/login", nil)
	details, apiErr := getLoginDetailsResponse(authApi.LoginDetailParams{HTTPRequest: req}, providers)
	if apiErr != nil {
		t.Fatalf("get login details: %v", apiErr)
	}
	if details.LoginStrategy != models.LoginDetailsLoginStrategyRedirect {
		t.Fatalf("login strategy = %q, want %q", details.LoginStrategy, models.LoginDetailsLoginStrategyRedirect)
	}
	if len(details.RedirectRules) != 1 {
		t.Fatalf("redirect rule count = %d, want 1", len(details.RedirectRules))
	}

	redirectURL, err := url.Parse(details.RedirectRules[0].Redirect)
	if err != nil {
		t.Fatalf("parse redirect URL: %v", err)
	}
	state := redirectURL.Query().Get("state")
	if state == "" {
		t.Fatal("OIDC redirect did not include state")
	}

	callbackReq := httptest.NewRequest(http.MethodPost, "https://storage.example.test/api/v1/login/oauth2/auth", nil)
	response, callbackErr := getLoginOauth2AuthResponse(authApi.LoginOauth2AuthParams{
		HTTPRequest: callbackReq,
		Body: &models.LoginOauth2AuthRequest{
			Code:  stringPointer(authCode),
			State: &state,
		},
	}, providers)
	if callbackErr != nil {
		t.Fatalf("complete OIDC callback: %v", callbackErr)
	}
	if response.SessionID == "" {
		t.Fatal("OIDC callback did not mint a console session")
	}
	if response.IDPRefreshToken != "test-refresh-token" {
		t.Fatalf("refresh token = %q, want test-refresh-token", response.IDPRefreshToken)
	}
}

func stringPointer(value string) *string {
	return &value
}
