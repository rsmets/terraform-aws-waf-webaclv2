#####
# WAFv2 web acl
#####
resource "aws_wafv2_web_acl" "main" {
  count = var.enabled ? 1 : 0

  name  = var.name_prefix
  scope = var.scope

  description = var.description

  dynamic "custom_response_body" {
    for_each = var.custom_response_bodies
    content {
      key          = custom_response_body.value.key
      content      = custom_response_body.value.content
      content_type = custom_response_body.value.content_type
    }
  }

  default_action {
    dynamic "allow" {
      for_each = var.allow_default_action ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.allow_default_action ? [] : [1]
      # Despite seemingly would want to add default custom_response defintions here, the docs state an empyt configuration block is required. ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl#default-action
      content {}
    }
  }

  dynamic "rule" {
    for_each = var.rules
    content {
      name     = lookup(rule.value, "name")
      priority = lookup(rule.value, "priority")

      # Action block is required for geo_match, ip_set, and ip_rate_based rules
      dynamic "action" {
        for_each = length(lookup(rule.value, "action", {})) == 0 ? [] : [1]
        content {
          dynamic "allow" {
            for_each = lookup(rule.value, "action", {}) == "allow" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = lookup(rule.value, "action", {}) == "count" ? [1] : []
            content {}
          }

          dynamic "block" {
            for_each = lookup(rule.value, "action", {}) == "block" ? [1] : []
            content {
              dynamic "custom_response" {
                for_each = length(lookup(rule.value, "custom_response", [])) == 0 ? [] : [lookup(rule.value, "custom_response", {})]
                content {
                  custom_response_body_key = lookup(custom_response.value, "custom_response_body_key", null)
                  response_code            = lookup(custom_response.value, "response_code", 403)
                  dynamic "response_header" {
                    for_each = lookup(custom_response.value, "response_headers", [])
                    content {
                      name  = lookup(response_header.value, "name")
                      value = lookup(response_header.value, "value")
                    }
                  }
                }
              }
            }
          }
        }
      }

      # Required for managed_rule_group_statements. Set to none, otherwise count to override the default action
      dynamic "override_action" {
        for_each = length(lookup(rule.value, "override_action", {})) == 0 ? [] : [1]
        content {
          dynamic "none" {
            for_each = lookup(rule.value, "override_action", {}) == "none" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = lookup(rule.value, "override_action", {}) == "count" ? [1] : []
            content {}
          }
        }
      }

      dynamic "rule_label" {
        for_each = try(rule.value.rule_labels, [])
        content {
          name = rule_label.value
        }
      }

      statement {

        dynamic "rule_group_reference_statement" {
          for_each = length(lookup(rule.value, "rule_group_reference_statement", {})) == 0 ? [] : [lookup(rule.value, "rule_group_reference_statement", {})]
          content {
            arn = lookup(rule_group_reference_statement.value, "arn")

            dynamic "excluded_rule" {
              for_each = length(lookup(rule_group_reference_statement.value, "excluded_rule", {})) == 0 ? [] : toset(lookup(rule_group_reference_statement.value, "excluded_rule"))
              content {
                name = excluded_rule.value
              }
            }
          }
        }

        dynamic "managed_rule_group_statement" {
          for_each = length(lookup(rule.value, "managed_rule_group_statement", {})) == 0 ? [] : [lookup(rule.value, "managed_rule_group_statement", {})]
          content {
            name        = lookup(managed_rule_group_statement.value, "name")
            vendor_name = lookup(managed_rule_group_statement.value, "vendor_name", "AWS")
            version     = lookup(managed_rule_group_statement.value, "version", null)

            dynamic "rule_action_override" {
              for_each = lookup(managed_rule_group_statement.value, "rule_action_override", null) == null ? [] : [lookup(managed_rule_group_statement.value, "rule_action_override")]
              content {
                name = lookup(rule_action_override.value, "name")
                dynamic "action_to_use" {
                  for_each = [lookup(rule_action_override.value, "action_to_use")]
                  content {
                    dynamic "count" {
                      for_each = lookup(action_to_use.value, "count", null) == null ? [] : [lookup(action_to_use.value, "count")]
                      content {}
                    }
                  }
                }
              }
            }

            dynamic "scope_down_statement" {
              for_each = length(lookup(managed_rule_group_statement.value, "scope_down_statement", {})) == 0 ? [] : [lookup(managed_rule_group_statement.value, "scope_down_statement", {})]
              content {
                # scope down byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # scope down regex_match_statement
                dynamic "regex_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "regex_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    regex_string = lookup(regex_match_statement.value, "regex_string")
                    text_transformation {
                      priority = lookup(regex_match_statement.value, "priority")
                      type     = lookup(regex_match_statement.value, "type")
                    }
                  }
                }

                # scope down geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                    dynamic "forwarded_ip_config" {
                      for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                      content {
                        fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                        header_name       = lookup(forwarded_ip_config.value, "header_name")
                      }
                    }
                  }
                }

                # scope down NOT statements
                dynamic "not_statement" {
                  for_each = length(lookup(scope_down_statement.value, "not_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "not_statement", {})]
                  content {
                    statement {
                      # Scope down AND ip_set_statement
                      dynamic "ip_set_reference_statement" {
                        for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                        content {
                          arn = lookup(ip_set_reference_statement.value, "arn")
                          dynamic "ip_set_forwarded_ip_config" {
                            for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                              position          = lookup(forwarded_ip_config.value, "position")
                            }
                          }
                        }
                      }
                      # scope down NOT byte_match_statement
                      dynamic "byte_match_statement" {
                        for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                          search_string         = lookup(byte_match_statement.value, "search_string")
                          text_transformation {
                            priority = lookup(byte_match_statement.value, "priority")
                            type     = lookup(byte_match_statement.value, "type")
                          }
                        }
                      }

                      # scope down NOT regex_match_statement
                      dynamic "regex_match_statement" {
                        for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          regex_string = lookup(regex_match_statement.value, "regex_string")
                          text_transformation {
                            priority = lookup(regex_match_statement.value, "priority")
                            type     = lookup(regex_match_statement.value, "type")
                          }
                        }
                      }

                      # scope down NOT geo_match_statement
                      dynamic "geo_match_statement" {
                        for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                        content {
                          country_codes = lookup(geo_match_statement.value, "country_codes")
                          dynamic "forwarded_ip_config" {
                            for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                            }
                          }
                        }
                      }

                      #scope down NOT regex_pattern_set_reference_statement
                      dynamic "regex_pattern_set_reference_statement" {
                        for_each = length(lookup(not_statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_pattern_set_reference_statement", {})]
                        content {
                          arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                          dynamic "field_to_match" {
                            for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          text_transformation {
                            priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                            type     = lookup(regex_pattern_set_reference_statement.value, "type")
                          }
                        }
                      }
                    }
                  }
                }

                ### scope down AND statements (Requires at least two statements)
                dynamic "and_statement" {
                  for_each = length(lookup(scope_down_statement.value, "and_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "and_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(and_statement.value, "statements", {})
                      content {
                        # Scope down AND byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down AND regex_match_statement
                        dynamic "regex_match_statement" {
                          for_each = length(lookup(statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            regex_string = lookup(regex_match_statement.value, "regex_string")
                            text_transformation {
                              priority = lookup(regex_match_statement.value, "priority")
                              type     = lookup(regex_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down AND geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                            dynamic "forwarded_ip_config" {
                              for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                              }
                            }
                          }
                        }

                        # Scope down AND ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                            dynamic "ip_set_forwarded_ip_config" {
                              for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                                position          = lookup(forwarded_ip_config.value, "position")
                              }
                            }
                          }
                        }

                        #scope down AND regex_pattern_set_reference_statement
                        dynamic "regex_pattern_set_reference_statement" {
                          for_each = length(lookup(statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_pattern_set_reference_statement", {})]
                          content {
                            arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                            dynamic "field_to_match" {
                              for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            text_transformation {
                              priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                              type     = lookup(regex_pattern_set_reference_statement.value, "type")
                            }
                          }
                        }

                        dynamic "not_statement" {
                          for_each = length(lookup(statement.value, "not_statement", {})) == 0 ? [] : [lookup(statement.value, "not_statement", {})]
                          content {
                            statement {
                              # Scope down NOT ip_set_statement
                              dynamic "ip_set_reference_statement" {
                                for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                                content {
                                  arn = lookup(ip_set_reference_statement.value, "arn")
                                  dynamic "ip_set_forwarded_ip_config" {
                                    for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                                    content {
                                      fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                      header_name       = lookup(forwarded_ip_config.value, "header_name")
                                      position          = lookup(forwarded_ip_config.value, "position")
                                    }
                                  }
                                }
                              }
                              # scope down NOT byte_match_statement
                              dynamic "byte_match_statement" {
                                for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                                content {
                                  dynamic "field_to_match" {
                                    for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                        content {}
                                      }
                                      dynamic "all_query_arguments" {
                                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                        content {}
                                      }
                                      dynamic "single_header" {
                                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                        content {
                                          name = lower(lookup(single_header.value, "name"))
                                        }
                                      }
                                    }
                                  }
                                  positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                                  search_string         = lookup(byte_match_statement.value, "search_string")
                                  text_transformation {
                                    priority = lookup(byte_match_statement.value, "priority")
                                    type     = lookup(byte_match_statement.value, "type")
                                  }
                                }
                              }

                              # scope down NOT regex_match_statement
                              dynamic "regex_match_statement" {
                                for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                                content {
                                  dynamic "field_to_match" {
                                    for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                        content {}
                                      }
                                      dynamic "all_query_arguments" {
                                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                        content {}
                                      }
                                      dynamic "single_header" {
                                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                        content {
                                          name = lower(lookup(single_header.value, "name"))
                                        }
                                      }
                                    }
                                  }
                                  regex_string = lookup(regex_match_statement.value, "regex_string")
                                  text_transformation {
                                    priority = lookup(regex_match_statement.value, "priority")
                                    type     = lookup(regex_match_statement.value, "type")
                                  }
                                }
                              }

                              # scope down NOT geo_match_statement
                              dynamic "geo_match_statement" {
                                for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                                content {
                                  country_codes = lookup(geo_match_statement.value, "country_codes")
                                  dynamic "forwarded_ip_config" {
                                    for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                                    content {
                                      fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                      header_name       = lookup(forwarded_ip_config.value, "header_name")
                                    }
                                  }
                                }
                              }

                              # Scope down NOT label_match_statement
                              dynamic "label_match_statement" {
                                for_each = length(lookup(not_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "label_match_statement", {})]
                                content {
                                  key   = lookup(label_match_statement.value, "key")
                                  scope = lookup(label_match_statement.value, "scope")
                                }
                              }

                              #scope down NOT regex_pattern_set_reference_statement
                              dynamic "regex_pattern_set_reference_statement" {
                                for_each = length(lookup(not_statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_pattern_set_reference_statement", {})]
                                content {
                                  arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                                  dynamic "field_to_match" {
                                    for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                        content {}
                                      }
                                      dynamic "all_query_arguments" {
                                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                        content {}
                                      }
                                      dynamic "single_header" {
                                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                        content {
                                          name = lower(lookup(single_header.value, "name"))
                                        }
                                      }
                                    }
                                  }
                                  text_transformation {
                                    priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                                    type     = lookup(regex_pattern_set_reference_statement.value, "type")
                                  }
                                }
                              }
                            }
                          }
                        }


                      }
                    }
                  }
                }


                ### scope down OR statements (Requires at least two statements)
                dynamic "or_statement" {
                  for_each = length(lookup(scope_down_statement.value, "or_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "or_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(or_statement.value, "statements", {})
                      content {
                        # Scope down OR byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down OR regex_match_statement
                        dynamic "regex_match_statement" {
                          for_each = length(lookup(statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            regex_string = lookup(regex_match_statement.value, "regex_string")
                            text_transformation {
                              priority = lookup(regex_match_statement.value, "priority")
                              type     = lookup(regex_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down OR geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                            dynamic "forwarded_ip_config" {
                              for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                              }
                            }
                          }
                        }

                        # Scope down OR ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                            dynamic "ip_set_forwarded_ip_config" {
                              for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                                position          = lookup(forwarded_ip_config.value, "position")
                              }
                            }
                          }
                        }

                        #scope down OR regex_pattern_set_reference_statement
                        dynamic "regex_pattern_set_reference_statement" {
                          for_each = length(lookup(statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_pattern_set_reference_statement", {})]
                          content {
                            arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                            dynamic "field_to_match" {
                              for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            text_transformation {
                              priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                              type     = lookup(regex_pattern_set_reference_statement.value, "type")
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        dynamic "byte_match_statement" {
          for_each = length(lookup(rule.value, "byte_match_statement", {})) == 0 ? [] : [lookup(rule.value, "byte_match_statement", {})]
          content {
            dynamic "field_to_match" {
              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
              content {
                dynamic "uri_path" {
                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                  content {}
                }
                dynamic "all_query_arguments" {
                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                  content {}
                }
                dynamic "body" {
                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                  content {}
                }
                dynamic "method" {
                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                  content {}
                }
                dynamic "query_string" {
                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                  content {}
                }
                dynamic "single_header" {
                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                  content {
                    name = lower(lookup(single_header.value, "name"))
                  }
                }
              }
            }
            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
            search_string         = lookup(byte_match_statement.value, "search_string")
            text_transformation {
              priority = lookup(byte_match_statement.value, "priority")
              type     = lookup(byte_match_statement.value, "type")
            }
          }
        }

        dynamic "regex_match_statement" {
          for_each = length(lookup(rule.value, "regex_match_statement", {})) == 0 ? [] : [lookup(rule.value, "regex_match_statement", {})]
          content {
            dynamic "field_to_match" {
              for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
              content {
                dynamic "uri_path" {
                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                  content {}
                }
                dynamic "all_query_arguments" {
                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                  content {}
                }
                dynamic "body" {
                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                  content {}
                }
                dynamic "method" {
                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                  content {}
                }
                dynamic "query_string" {
                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                  content {}
                }
                dynamic "single_header" {
                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                  content {
                    name = lower(lookup(single_header.value, "name"))
                  }
                }
              }
            }
            regex_string = lookup(regex_match_statement.value, "regex_string")
            text_transformation {
              priority = lookup(regex_match_statement.value, "priority")
              type     = lookup(regex_match_statement.value, "type")
            }
          }
        }

        dynamic "geo_match_statement" {
          for_each = length(lookup(rule.value, "geo_match_statement", {})) == 0 ? [] : [lookup(rule.value, "geo_match_statement", {})]
          content {
            country_codes = lookup(geo_match_statement.value, "country_codes")
            dynamic "forwarded_ip_config" {
              for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
              content {
                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                header_name       = lookup(forwarded_ip_config.value, "header_name")
              }
            }
          }
        }

        dynamic "ip_set_reference_statement" {
          for_each = length(lookup(rule.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(rule.value, "ip_set_reference_statement", {})]
          content {
            arn = lookup(ip_set_reference_statement.value, "arn")
            dynamic "ip_set_forwarded_ip_config" {
              for_each = length(lookup(ip_set_reference_statement.value, "ip_set_forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "ip_set_forwarded_ip_config", {})]
              content {
                fallback_behavior = lookup(ip_set_forwarded_ip_config.value, "fallback_behavior")
                header_name       = lookup(ip_set_forwarded_ip_config.value, "header_name")
                position          = lookup(ip_set_forwarded_ip_config.value, "position")
              }
            }
          }
        }

        dynamic "label_match_statement" {
          for_each = length(lookup(rule.value, "label_match_statement", {})) == 0 ? [] : [lookup(rule.value, "label_match_statement", {})]
          content {
            key   = lookup(label_match_statement.value, "key")
            scope = lookup(label_match_statement.value, "scope")
          }
        }

        dynamic "regex_pattern_set_reference_statement" {
          for_each = length(lookup(rule.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(rule.value, "regex_pattern_set_reference_statement", {})]
          content {
            arn = lookup(regex_pattern_set_reference_statement.value, "arn")
            dynamic "field_to_match" {
              for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
              content {
                dynamic "uri_path" {
                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                  content {}
                }
                dynamic "all_query_arguments" {
                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                  content {}
                }
                dynamic "body" {
                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                  content {}
                }
                dynamic "method" {
                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                  content {}
                }
                dynamic "query_string" {
                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                  content {}
                }
                dynamic "single_header" {
                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                  content {
                    name = lower(lookup(single_header.value, "name"))
                  }
                }
              }
            }
            text_transformation {
              priority = lookup(regex_pattern_set_reference_statement.value, "priority")
              type     = lookup(regex_pattern_set_reference_statement.value, "type")
            }
          }
        }

        dynamic "size_constraint_statement" {
          for_each = length(lookup(rule.value, "size_constraint_statement", {})) == 0 ? [] : [lookup(rule.value, "size_constraint_statement", {})]
          content {
            dynamic "field_to_match" {
              for_each = length(lookup(size_constraint_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(size_constraint_statement.value, "field_to_match", {})]
              content {
                dynamic "uri_path" {
                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                  content {}
                }
                dynamic "all_query_arguments" {
                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                  content {}
                }
                dynamic "body" {
                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                  content {
                    #oversize_handling = upper(lookup(body.value, "oversize_handling"))
                  }
                }
                dynamic "method" {
                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                  content {}
                }
                dynamic "query_string" {
                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                  content {}
                }
                dynamic "single_header" {
                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                  content {
                    name = lower(lookup(single_header.value, "name"))
                  }
                }
              }
            }
            comparison_operator = lookup(size_constraint_statement.value, "comparison_operator")
            size                = lookup(size_constraint_statement.value, "size")
            text_transformation {
              priority = lookup(size_constraint_statement.value, "priority")
              type     = lookup(size_constraint_statement.value, "type")
            }
          }
        }

        dynamic "rate_based_statement" {
          for_each = length(lookup(rule.value, "rate_based_statement", {})) == 0 ? [] : [lookup(rule.value, "rate_based_statement", {})]
          content {
            limit              = lookup(rate_based_statement.value, "limit")
            aggregate_key_type = lookup(rate_based_statement.value, "aggregate_key_type", "IP")

            dynamic "forwarded_ip_config" {
              for_each = length(lookup(rate_based_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(rate_based_statement.value, "forwarded_ip_config", {})]
              content {
                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                header_name       = lookup(forwarded_ip_config.value, "header_name")
              }
            }

            dynamic "scope_down_statement" {
              for_each = length(lookup(rate_based_statement.value, "scope_down_statement", {})) == 0 ? [] : [lookup(rate_based_statement.value, "scope_down_statement", {})]
              content {
                # scope down byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # scope down regex_match_statement
                dynamic "regex_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "regex_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    regex_string = lookup(regex_match_statement.value, "regex_string")
                    text_transformation {
                      priority = lookup(regex_match_statement.value, "priority")
                      type     = lookup(regex_match_statement.value, "type")
                    }
                  }
                }

                # scope down geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                    dynamic "forwarded_ip_config" {
                      for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                      content {
                        fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                        header_name       = lookup(forwarded_ip_config.value, "header_name")
                      }
                    }
                  }
                }

                # scope down label_match_statement
                dynamic "label_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "label_match_statement", {})]
                  content {
                    key   = lookup(label_match_statement.value, "key")
                    scope = lookup(label_match_statement.value, "scope")
                  }
                }

                #scope down regex_pattern_set_reference_statement
                dynamic "regex_pattern_set_reference_statement" {
                  for_each = length(lookup(scope_down_statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "regex_pattern_set_reference_statement", {})]
                  content {
                    arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                    dynamic "field_to_match" {
                      for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    text_transformation {
                      priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                      type     = lookup(regex_pattern_set_reference_statement.value, "type")
                    }
                  }
                }

                # scope down NOT statements
                dynamic "not_statement" {
                  for_each = length(lookup(scope_down_statement.value, "not_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "not_statement", {})]
                  content {
                    statement {
                      # Scope down NOT ip_set_statement
                      dynamic "ip_set_reference_statement" {
                        for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                        content {
                          arn = lookup(ip_set_reference_statement.value, "arn")
                          dynamic "ip_set_forwarded_ip_config" {
                            for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                              position          = lookup(forwarded_ip_config.value, "position")
                            }
                          }
                        }
                      }
                      # scope down NOT byte_match_statement
                      dynamic "byte_match_statement" {
                        for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                          search_string         = lookup(byte_match_statement.value, "search_string")
                          text_transformation {
                            priority = lookup(byte_match_statement.value, "priority")
                            type     = lookup(byte_match_statement.value, "type")
                          }
                        }
                      }

                      # scope down NOT regex_match_statement
                      dynamic "regex_match_statement" {
                        for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          regex_string = lookup(regex_match_statement.value, "regex_string")
                          text_transformation {
                            priority = lookup(regex_match_statement.value, "priority")
                            type     = lookup(regex_match_statement.value, "type")
                          }
                        }
                      }

                      # scope down NOT geo_match_statement
                      dynamic "geo_match_statement" {
                        for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                        content {
                          country_codes = lookup(geo_match_statement.value, "country_codes")
                          dynamic "forwarded_ip_config" {
                            for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                            }
                          }
                        }
                      }

                      # Scope down NOT label_match_statement
                      dynamic "label_match_statement" {
                        for_each = length(lookup(not_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "label_match_statement", {})]
                        content {
                          key   = lookup(label_match_statement.value, "key")
                          scope = lookup(label_match_statement.value, "scope")
                        }
                      }
                    }
                  }
                }

                ### scope down AND statements (Requires at least two statements)
                dynamic "and_statement" {
                  for_each = length(lookup(scope_down_statement.value, "and_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "and_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(and_statement.value, "statements", {})
                      content {
                        # Scope down AND byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down AND regex_match_statement
                        dynamic "regex_match_statement" {
                          for_each = length(lookup(statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            regex_string = lookup(regex_match_statement.value, "regex_string")
                            text_transformation {
                              priority = lookup(regex_match_statement.value, "priority")
                              type     = lookup(regex_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down AND geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                            dynamic "forwarded_ip_config" {
                              for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                              }
                            }
                          }
                        }

                        # Scope down AND ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                            dynamic "ip_set_forwarded_ip_config" {
                              for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                                position          = lookup(forwarded_ip_config.value, "position")
                              }
                            }
                          }
                        }

                        # Scope down AND label_match_statement
                        dynamic "label_match_statement" {
                          for_each = length(lookup(statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(statement.value, "label_match_statement", {})]
                          content {
                            key   = lookup(label_match_statement.value, "key")
                            scope = lookup(label_match_statement.value, "scope")
                          }
                        }

                        # Scope down AND not_statement

                        #scope_down -> and_Statement -> statement -> not_statement -> statement -> ip_set


                        dynamic "not_statement" {
                          for_each = length(lookup(statement.value, "not_statement", {})) == 0 ? [] : [lookup(statement.value, "not_statement", {})]
                          content {
                            statement {
                              # Scope down NOT ip_set_statement
                              dynamic "ip_set_reference_statement" {
                                for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                                content {
                                  arn = lookup(ip_set_reference_statement.value, "arn")
                                  dynamic "ip_set_forwarded_ip_config" {
                                    for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                                    content {
                                      fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                      header_name       = lookup(forwarded_ip_config.value, "header_name")
                                      position          = lookup(forwarded_ip_config.value, "position")
                                    }
                                  }
                                }
                              }
                              # scope down NOT byte_match_statement
                              dynamic "byte_match_statement" {
                                for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                                content {
                                  dynamic "field_to_match" {
                                    for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                        content {}
                                      }
                                      dynamic "all_query_arguments" {
                                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                        content {}
                                      }
                                      dynamic "single_header" {
                                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                        content {
                                          name = lower(lookup(single_header.value, "name"))
                                        }
                                      }
                                    }
                                  }
                                  positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                                  search_string         = lookup(byte_match_statement.value, "search_string")
                                  text_transformation {
                                    priority = lookup(byte_match_statement.value, "priority")
                                    type     = lookup(byte_match_statement.value, "type")
                                  }
                                }
                              }

                              # scope down NOT regex_match_statement
                              dynamic "regex_match_statement" {
                                for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                                content {
                                  dynamic "field_to_match" {
                                    for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                        content {}
                                      }
                                      dynamic "all_query_arguments" {
                                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                        content {}
                                      }
                                      dynamic "single_header" {
                                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                        content {
                                          name = lower(lookup(single_header.value, "name"))
                                        }
                                      }
                                    }
                                  }
                                  regex_string = lookup(regex_match_statement.value, "regex_string")
                                  text_transformation {
                                    priority = lookup(regex_match_statement.value, "priority")
                                    type     = lookup(regex_match_statement.value, "type")
                                  }
                                }
                              }

                              # scope down NOT geo_match_statement
                              dynamic "geo_match_statement" {
                                for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                                content {
                                  country_codes = lookup(geo_match_statement.value, "country_codes")
                                  dynamic "forwarded_ip_config" {
                                    for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                                    content {
                                      fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                      header_name       = lookup(forwarded_ip_config.value, "header_name")
                                    }
                                  }
                                }
                              }

                              # Scope down NOT label_match_statement
                              dynamic "label_match_statement" {
                                for_each = length(lookup(not_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "label_match_statement", {})]
                                content {
                                  key   = lookup(label_match_statement.value, "key")
                                  scope = lookup(label_match_statement.value, "scope")
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                ### scope down OR statements (Requires at least two statements)
                dynamic "or_statement" {
                  for_each = length(lookup(scope_down_statement.value, "or_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "or_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(or_statement.value, "statements", {})
                      content {
                        # Scope down OR byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down OR regex_match_statement
                        dynamic "regex_match_statement" {
                          for_each = length(lookup(statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            regex_string = lookup(regex_match_statement.value, "regex_string")
                            text_transformation {
                              priority = lookup(regex_match_statement.value, "priority")
                              type     = lookup(regex_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down OR geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                            dynamic "forwarded_ip_config" {
                              for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                              }
                            }
                          }
                        }

                        # Scope down OR ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                            dynamic "ip_set_forwarded_ip_config" {
                              for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                              content {
                                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                header_name       = lookup(forwarded_ip_config.value, "header_name")
                                position          = lookup(forwarded_ip_config.value, "position")
                              }
                            }
                          }
                        }

                        # Scope down OR label_match_statement
                        dynamic "label_match_statement" {
                          for_each = length(lookup(statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(statement.value, "label_match_statement", {})]
                          content {
                            key   = lookup(label_match_statement.value, "key")
                            scope = lookup(label_match_statement.value, "scope")
                          }
                        }

                        # Scope down OR not_statement
                        dynamic "not_statement" {
                          for_each = length(lookup(statement.value, "not_statement", {})) == 0 ? [] : [lookup(statement.value, "not_statement", {})]
                          content {
                            statement {
                              # scope down NOT byte_match_statement
                              dynamic "byte_match_statement" {
                                for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                                content {
                                  dynamic "field_to_match" {
                                    for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                        content {}
                                      }
                                      dynamic "all_query_arguments" {
                                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                        content {}
                                      }
                                      dynamic "single_header" {
                                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                        content {
                                          name = lower(lookup(single_header.value, "name"))
                                        }
                                      }
                                    }
                                  }
                                  positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                                  search_string         = lookup(byte_match_statement.value, "search_string")
                                  text_transformation {
                                    priority = lookup(byte_match_statement.value, "priority")
                                    type     = lookup(byte_match_statement.value, "type")
                                  }
                                }
                              }

                              # scope down NOT regex_match_statement
                              dynamic "regex_match_statement" {
                                for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                                content {
                                  dynamic "field_to_match" {
                                    for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                        content {}
                                      }
                                      dynamic "all_query_arguments" {
                                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                        content {}
                                      }
                                      dynamic "single_header" {
                                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                        content {
                                          name = lower(lookup(single_header.value, "name"))
                                        }
                                      }
                                    }
                                  }
                                  regex_string = lookup(regex_match_statement.value, "regex_string")
                                  text_transformation {
                                    priority = lookup(regex_match_statement.value, "priority")
                                    type     = lookup(regex_match_statement.value, "type")
                                  }
                                }
                              }

                              # scope down NOT geo_match_statement
                              dynamic "geo_match_statement" {
                                for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                                content {
                                  country_codes = lookup(geo_match_statement.value, "country_codes")
                                  dynamic "forwarded_ip_config" {
                                    for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                                    content {
                                      fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                                      header_name       = lookup(forwarded_ip_config.value, "header_name")
                                    }
                                  }
                                }
                              }

                              # Scope down NOT label_match_statement
                              dynamic "label_match_statement" {
                                for_each = length(lookup(not_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "label_match_statement", {})]
                                content {
                                  key   = lookup(label_match_statement.value, "key")
                                  scope = lookup(label_match_statement.value, "scope")
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        ### NOT STATEMENTS
        dynamic "not_statement" {
          for_each = length(lookup(rule.value, "not_statement", {})) == 0 ? [] : [lookup(rule.value, "not_statement", {})]
          content {
            statement {

              # NOT byte_match_statement
              dynamic "byte_match_statement" {
                for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                content {
                  dynamic "field_to_match" {
                    for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                    content {
                      dynamic "uri_path" {
                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                        content {}
                      }
                      dynamic "all_query_arguments" {
                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                        content {}
                      }
                      dynamic "body" {
                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                        content {}
                      }
                      dynamic "method" {
                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                        content {}
                      }
                      dynamic "query_string" {
                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                        content {
                          name = lower(lookup(single_header.value, "name"))
                        }
                      }
                    }
                  }
                  positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                  search_string         = lookup(byte_match_statement.value, "search_string")
                  text_transformation {
                    priority = lookup(byte_match_statement.value, "priority")
                    type     = lookup(byte_match_statement.value, "type")
                  }
                }
              }

              # NOT regex_match_statement
              dynamic "regex_match_statement" {
                for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                content {
                  dynamic "field_to_match" {
                    for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                    content {
                      dynamic "uri_path" {
                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                        content {}
                      }
                      dynamic "all_query_arguments" {
                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                        content {}
                      }
                      dynamic "body" {
                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                        content {}
                      }
                      dynamic "method" {
                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                        content {}
                      }
                      dynamic "query_string" {
                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                        content {
                          name = lower(lookup(single_header.value, "name"))
                        }
                      }
                    }
                  }
                  regex_string = lookup(regex_match_statement.value, "regex_string")
                  text_transformation {
                    priority = lookup(regex_match_statement.value, "priority")
                    type     = lookup(regex_match_statement.value, "type")
                  }
                }
              }

              # NOT geo_match_statement
              dynamic "geo_match_statement" {
                for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                content {
                  country_codes = lookup(geo_match_statement.value, "country_codes")
                  dynamic "forwarded_ip_config" {
                    for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                    content {
                      fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                      header_name       = lookup(forwarded_ip_config.value, "header_name")
                    }
                  }
                }
              }

              # NOT ip_set_statement
              dynamic "ip_set_reference_statement" {
                for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                content {
                  arn = lookup(ip_set_reference_statement.value, "arn")
                  dynamic "ip_set_forwarded_ip_config" {
                    for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                    content {
                      fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                      header_name       = lookup(forwarded_ip_config.value, "header_name")
                      position          = lookup(forwarded_ip_config.value, "position")
                    }
                  }
                }
              }

              # NOT label_match_statement
              dynamic "label_match_statement" {
                for_each = length(lookup(not_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "label_match_statement", {})]
                content {
                  key   = lookup(label_match_statement.value, "key")
                  scope = lookup(label_match_statement.value, "scope")
                }
              }

              # NOT regex_pattern_set_reference_statement
              dynamic "regex_pattern_set_reference_statement" {
                for_each = length(lookup(not_statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_pattern_set_reference_statement", {})]
                content {
                  arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                  dynamic "field_to_match" {
                    for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                    content {
                      dynamic "uri_path" {
                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                        content {}
                      }
                      dynamic "all_query_arguments" {
                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                        content {}
                      }
                      dynamic "body" {
                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                        content {}
                      }
                      dynamic "method" {
                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                        content {}
                      }
                      dynamic "query_string" {
                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                        content {
                          name = lower(lookup(single_header.value, "name"))
                        }
                      }
                    }
                  }
                  text_transformation {
                    priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                    type     = lookup(regex_pattern_set_reference_statement.value, "type")
                  }
                }
              }
            }
          }
        }

        ### AND STATEMENTS (Requires at least two statements)
        dynamic "and_statement" {
          for_each = length(lookup(rule.value, "and_statement", {})) == 0 ? [] : [lookup(rule.value, "and_statement", {})]
          content {

            dynamic "statement" {
              for_each = lookup(and_statement.value, "statements", {})
              content {

                # AND byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # AND regex_match_statement
                dynamic "regex_match_statement" {
                  for_each = length(lookup(statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    regex_string = lookup(regex_match_statement.value, "regex_string")
                    text_transformation {
                      priority = lookup(regex_match_statement.value, "priority")
                      type     = lookup(regex_match_statement.value, "type")
                    }
                  }
                }

                # AND geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                    dynamic "forwarded_ip_config" {
                      for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                      content {
                        fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                        header_name       = lookup(forwarded_ip_config.value, "header_name")
                      }
                    }
                  }
                }

                # AND ip_set_statement
                dynamic "ip_set_reference_statement" {
                  for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                  content {
                    arn = lookup(ip_set_reference_statement.value, "arn")
                    dynamic "ip_set_forwarded_ip_config" {
                      for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                      content {
                        fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                        header_name       = lookup(forwarded_ip_config.value, "header_name")
                        position          = lookup(forwarded_ip_config.value, "position")
                      }
                    }
                  }
                }

                # AND label_match_statement
                dynamic "label_match_statement" {
                  for_each = length(lookup(statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(statement.value, "label_match_statement", {})]
                  content {
                    key   = lookup(label_match_statement.value, "key")
                    scope = lookup(label_match_statement.value, "scope")
                  }
                }

                # AND regex_pattern_set_reference_statement
                dynamic "regex_pattern_set_reference_statement" {
                  for_each = length(lookup(statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_pattern_set_reference_statement", {})]
                  content {
                    arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                    dynamic "field_to_match" {
                      for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    text_transformation {
                      priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                      type     = lookup(regex_pattern_set_reference_statement.value, "type")
                    }
                  }
                }


                ### AND not_statement
                dynamic "not_statement" {
                  for_each = length(lookup(statement.value, "not_statement", {})) == 0 ? [] : [lookup(statement.value, "not_statement", {})]
                  content {
                    statement {
                      # AND not_statement byte_match_statement
                      dynamic "byte_match_statement" {
                        for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                          search_string         = lookup(byte_match_statement.value, "search_string")
                          text_transformation {
                            priority = lookup(byte_match_statement.value, "priority")
                            type     = lookup(byte_match_statement.value, "type")
                          }
                        }
                      }

                      # AND not_statement regex_match_statement
                      dynamic "regex_match_statement" {
                        for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          regex_string = lookup(regex_match_statement.value, "regex_string")
                          text_transformation {
                            priority = lookup(regex_match_statement.value, "priority")
                            type     = lookup(regex_match_statement.value, "type")
                          }
                        }
                      }

                      # AND not_statement geo_match_statement
                      dynamic "geo_match_statement" {
                        for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                        content {
                          country_codes = lookup(geo_match_statement.value, "country_codes")
                          dynamic "forwarded_ip_config" {
                            for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                            }
                          }
                        }
                      }

                      # AND not_statement ip_set_statement
                      dynamic "ip_set_reference_statement" {
                        for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                        content {
                          arn = lookup(ip_set_reference_statement.value, "arn")
                          dynamic "ip_set_forwarded_ip_config" {
                            for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                              position          = lookup(forwarded_ip_config.value, "position")
                            }
                          }
                        }
                      }

                      # AND not_statement label_match_statement
                      dynamic "label_match_statement" {
                        for_each = length(lookup(not_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "label_match_statement", {})]
                        content {
                          key   = lookup(label_match_statement.value, "key")
                          scope = lookup(label_match_statement.value, "scope")
                        }
                      }

                      # AND not_statement regex_pattern_set_reference_statement
                      dynamic "regex_pattern_set_reference_statement" {
                        for_each = length(lookup(not_statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_pattern_set_reference_statement", {})]
                        content {
                          arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                          dynamic "field_to_match" {
                            for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          text_transformation {
                            priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                            type     = lookup(regex_pattern_set_reference_statement.value, "type")
                          }
                        }
                      }

                    }
                  }
                }
              }
            }
          }
        }

        ### OR STATEMENTS (Requires at least two statements)
        dynamic "or_statement" {
          for_each = length(lookup(rule.value, "or_statement", {})) == 0 ? [] : [lookup(rule.value, "or_statement", {})]
          content {

            dynamic "statement" {
              for_each = lookup(or_statement.value, "statements", {})
              content {

                # OR byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # OR regex_match_statement
                dynamic "regex_match_statement" {
                  for_each = length(lookup(statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    regex_string = lookup(regex_match_statement.value, "regex_string")
                    text_transformation {
                      priority = lookup(regex_match_statement.value, "priority")
                      type     = lookup(regex_match_statement.value, "type")
                    }
                  }
                }

                # OR geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                    dynamic "forwarded_ip_config" {
                      for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                      content {
                        fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                        header_name       = lookup(forwarded_ip_config.value, "header_name")
                      }
                    }
                  }
                }

                # OR ip_set_statement
                dynamic "ip_set_reference_statement" {
                  for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                  content {
                    arn = lookup(ip_set_reference_statement.value, "arn")
                    dynamic "ip_set_forwarded_ip_config" {
                      for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                      content {
                        fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                        header_name       = lookup(forwarded_ip_config.value, "header_name")
                        position          = lookup(forwarded_ip_config.value, "position")
                      }
                    }
                  }
                }

                # OR label_match_statement
                dynamic "label_match_statement" {
                  for_each = length(lookup(statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(statement.value, "label_match_statement", {})]
                  content {
                    key   = lookup(label_match_statement.value, "key")
                    scope = lookup(label_match_statement.value, "scope")
                  }
                }

                # OR regex_pattern_set_reference_statement
                dynamic "regex_pattern_set_reference_statement" {
                  for_each = length(lookup(statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "regex_pattern_set_reference_statement", {})]
                  content {
                    arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                    dynamic "field_to_match" {
                      for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    text_transformation {
                      priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                      type     = lookup(regex_pattern_set_reference_statement.value, "type")
                    }
                  }
                }

                ### OR not_statement
                dynamic "not_statement" {
                  for_each = length(lookup(statement.value, "not_statement", {})) == 0 ? [] : [lookup(statement.value, "not_statement", {})]
                  content {
                    statement {
                      # OR not_statement byte_match_statement
                      dynamic "byte_match_statement" {
                        for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                          search_string         = lookup(byte_match_statement.value, "search_string")
                          text_transformation {
                            priority = lookup(byte_match_statement.value, "priority")
                            type     = lookup(byte_match_statement.value, "type")
                          }
                        }
                      }

                      # OR not_statement regex_match_statement
                      dynamic "regex_match_statement" {
                        for_each = length(lookup(not_statement.value, "regex_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(regex_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          regex_string = lookup(regex_match_statement.value, "regex_string")
                          text_transformation {
                            priority = lookup(regex_match_statement.value, "priority")
                            type     = lookup(regex_match_statement.value, "type")
                          }
                        }
                      }

                      # OR not_statement geo_match_statement
                      dynamic "geo_match_statement" {
                        for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                        content {
                          country_codes = lookup(geo_match_statement.value, "country_codes")
                          dynamic "forwarded_ip_config" {
                            for_each = length(lookup(geo_match_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(geo_match_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                            }
                          }
                        }
                      }

                      # OR not_statement ip_set_statement
                      dynamic "ip_set_reference_statement" {
                        for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                        content {
                          arn = lookup(ip_set_reference_statement.value, "arn")
                          dynamic "ip_set_forwarded_ip_config" {
                            for_each = length(lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(ip_set_reference_statement.value, "forwarded_ip_config", {})]
                            content {
                              fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                              header_name       = lookup(forwarded_ip_config.value, "header_name")
                              position          = lookup(forwarded_ip_config.value, "position")
                            }
                          }
                        }
                      }

                      # OR not_statement label_match_statement
                      dynamic "label_match_statement" {
                        for_each = length(lookup(not_statement.value, "label_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "label_match_statement", {})]
                        content {
                          key   = lookup(label_match_statement.value, "key")
                          scope = lookup(label_match_statement.value, "scope")
                        }
                      }

                      # OR not_statement regex_pattern_set_reference_statement
                      dynamic "regex_pattern_set_reference_statement" {
                        for_each = length(lookup(not_statement.value, "regex_pattern_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "regex_pattern_set_reference_statement", {})]
                        content {
                          arn = lookup(regex_pattern_set_reference_statement.value, "arn")
                          dynamic "field_to_match" {
                            for_each = length(lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(regex_pattern_set_reference_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          text_transformation {
                            priority = lookup(regex_pattern_set_reference_statement.value, "priority")
                            type     = lookup(regex_pattern_set_reference_statement.value, "type")
                          }
                        }
                      }

                    }
                  }
                }
              }
            }
          }
        }
      }

      dynamic "visibility_config" {
        for_each = length(lookup(rule.value, "visibility_config")) == 0 ? [] : [lookup(rule.value, "visibility_config", {})]
        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = lookup(visibility_config.value, "metric_name", "${var.name_prefix}-default-rule-metric-name")
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }
    }
  }

  tags = var.tags

  dynamic "visibility_config" {
    for_each = length(var.visibility_config) == 0 ? [] : [var.visibility_config]
    content {
      cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
      metric_name                = lookup(visibility_config.value, "metric_name", "${var.name_prefix}-default-web-acl-metric-name")
      sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
    }
  }
}

#####
# WAFv2 web acl association with ALB
#####
resource "aws_wafv2_web_acl_association" "main" {
  count = var.enabled && var.create_alb_association && length(var.alb_arn_list) == 0 ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn

  depends_on = [aws_wafv2_web_acl.main]
}

resource "aws_wafv2_web_acl_association" "alb_list" {
  count = var.enabled && var.create_alb_association && length(var.alb_arn_list) > 0 ? length(var.alb_arn_list) : 0

  resource_arn = var.alb_arn_list[count.index]
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn

  depends_on = [aws_wafv2_web_acl.main]
}

#####
# WAFv2 web acl logging configuration with kinesis firehose
#####
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enabled && var.create_logging_configuration ? 1 : 0

  log_destination_configs = var.log_destination_configs
  resource_arn            = aws_wafv2_web_acl.main[0].arn

  dynamic "redacted_fields" {
    for_each = var.redacted_fields
    content {
      dynamic "single_header" {
        for_each = length(lookup(redacted_fields.value, "single_header", {})) == 0 ? [] : [lookup(redacted_fields.value, "single_header", {})]
        content {
          name = lookup(single_header.value, "name", null)
        }
      }

      dynamic "single_query_argument" {
        for_each = length(lookup(redacted_fields.value, "single_query_argument", {})) == 0 ? [] : [lookup(redacted_fields.value, "single_query_argument", {})]
        content {
          name = lookup(single_query_argument.value, "name", null)
        }
      }
    }
  }

  dynamic "logging_filter" {
    for_each = length(var.logging_filter) == 0 ? [] : [var.logging_filter]
    content {
      default_behavior = lookup(logging_filter.value, "default_behavior", "KEEP")

      dynamic "filter" {
        for_each = length(lookup(logging_filter.value, "filter", {})) == 0 ? [] : toset(lookup(logging_filter.value, "filter"))
        content {
          behavior    = lookup(filter.value, "behavior")
          requirement = lookup(filter.value, "requirement", "MEETS_ANY")

          dynamic "condition" {
            for_each = length(lookup(filter.value, "condition", {})) == 0 ? [] : toset(lookup(filter.value, "condition"))
            content {
              dynamic "action_condition" {
                for_each = length(lookup(condition.value, "action_condition", {})) == 0 ? [] : [lookup(condition.value, "action_condition", {})]
                content {
                  action = lookup(action_condition.value, "action")
                }
              }

              dynamic "label_name_condition" {
                for_each = length(lookup(condition.value, "label_name_condition", {})) == 0 ? [] : [lookup(condition.value, "label_name_condition", {})]
                content {
                  label_name = lookup(label_name_condition.value, "label_name")
                }
              }
            }
          }
        }
      }
    }
  }
}
