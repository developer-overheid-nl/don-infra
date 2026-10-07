package apisix.authz

test_allow_response_uses_numeric_client_rate_limit if {
  response := allow_response({
    "client_id": "frontend-client",
    "rate_limit": "4000",
  }) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  object.get(response.headers, "X-OPA-Rate-Limit", "") == "4000"
}

test_allow_response_uses_trusted_bearer_profile_claim if {
  info := {
    "active": true,
    "client_id": "trusted-bearer-client",
    "rate_limit_profile": "trusted",
    "scope": "apis:read",
  }
  response := allow_response(info) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  object.get(response.headers, "X-OPA-Rate-Limit", "") == "500"
  all_required_scopes_present(info, ["apis:read"])
  not all_required_scopes_present(info, ["apis:write"])
}

test_keycloak_untrusted_profile_is_read_only_at_100 if {
  info := keycloak_api_key_info_from_body({
    "clientId": "readonly-client",
    "attributes": {"rate-limit-profile": "untrusted"},
  }, "api-key") with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }
  response := allow_response(info) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  info.client_id == "readonly-client"
  info.profile == "untrusted"
  object.get(response.headers, "X-OPA-Rate-Limit", "") == "100"
  all_required_scopes_present(info, ["apis:read", "events:read"])
  not all_required_scopes_present(info, ["apis:write"])
  not all_required_scopes_present(info, ["tools"])
}

test_keycloak_trusted_profile_can_write_at_500 if {
  info := keycloak_api_key_info_from_body({
    "clientId": "write-client",
    "attributes": {"rate-limit-profile": "trusted"},
  }, "api-key")
  response := allow_response(info)

  info.profile == "trusted"
  object.get(response.headers, "X-OPA-Rate-Limit", "") == "500"
  all_required_scopes_present(info, ["apis:write", "events:write", "tools"])
}

test_keycloak_admin_profile_can_write_at_4000 if {
  info := keycloak_api_key_info_from_body({
    "clientId": "high-volume-client",
    "attributes": {"rate-limit-profile": "admin"},
  }, "api-key")
  response := allow_response(info)

  info.profile == "admin"
  object.get(response.headers, "X-OPA-Rate-Limit", "") == "4000"
  all_required_scopes_present(info, ["apis:write", "events:write", "tools"])
}

test_keycloak_unknown_profile_falls_back_to_untrusted if {
  info := keycloak_api_key_info_from_body({
    "clientId": "misconfigured-client",
    "attributes": {"rate-limit-profile": "unexpected"},
  }, "api-key")
  response := allow_response(info)

  info.profile == "untrusted"
  object.get(response.headers, "X-OPA-Rate-Limit", "") == "100"
  all_required_scopes_present(info, ["apis:read"])
  not all_required_scopes_present(info, ["apis:write"])
}

test_keycloak_missing_profile_falls_back_to_untrusted if {
  info := keycloak_api_key_info_from_body({
    "clientId": "legacy-client",
    "attributes": {},
  }, "api-key")
  response := allow_response(info)

  info.profile == "untrusted"
  object.get(response.headers, "X-OPA-Rate-Limit", "") == "100"
  not all_required_scopes_present(info, ["apis:write"])
}

test_allow_response_falls_back_when_rate_limit_is_missing if {
  response := allow_response({
    "client_id": "existing-client",
  }) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  object.get(response.headers, "X-OPA-Rate-Limit", "") == "100"
}

test_allow_response_falls_back_when_rate_limit_is_invalid if {
  response := allow_response({
    "client_id": "misconfigured-client",
    "rate_limit": "unlimited",
  }) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  object.get(response.headers, "X-OPA-Rate-Limit", "") == "100"
}

test_allow_response_falls_back_when_rate_limit_is_not_positive if {
  response := allow_response({
    "client_id": "misconfigured-client",
    "rate_limit": "0",
  }) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  object.get(response.headers, "X-OPA-Rate-Limit", "") == "100"
}

test_allow_response_falls_back_when_rate_limit_is_negative if {
  response := allow_response({
    "client_id": "misconfigured-client",
    "rate_limit": "-1",
  }) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  object.get(response.headers, "X-OPA-Rate-Limit", "") == "100"
}
