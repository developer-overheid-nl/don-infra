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

test_allow_response_uses_keycloak_client_attribute if {
  info := keycloak_api_key_info_from_body({
    "clientId": "frontend-client",
    "attributes": {"rate-limit": "4000"},
  }, "api-key") with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }
  response := allow_response(info) with data.apisix_auth as {
    "rate_limit": {"default": 100},
  }

  info.client_id == "frontend-client"
  object.get(response.headers, "X-OPA-Rate-Limit", "") == "4000"
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
