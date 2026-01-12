variable "var_provider" {
  default = {
    region = "ap-northeast-1"
  }
}

variable "oidc_provider" {
  type = object({
    url            = string
    client_id_list = list(string)
  })
}

variable "oidc_assume_role" {
  description = "DEPRECATED: Use oidc_assume_roles instead."
  type = object({
    namespace           = string
    service_account     = string
    audience            = optional(string, "sts.amazonaws.com")
    tags                = optional(map(string))
    managed_policy_arns = optional(list(string), [])
    inline_policy_json  = optional(string)
  })
  default = null
}

variable "oidc_assume_roles" {
  type = map(object({
    namespace           = string
    service_account     = string
    audience            = optional(string, "sts.amazonaws.com")
    tags                = optional(map(string))
    managed_policy_arns = optional(list(string), [])
    inline_policy_json  = optional(string)
  }))
  default = {}

  validation {
    condition = (
      length(var.oidc_assume_roles) > 0 ||
      var.oidc_assume_role != null
    )
    error_message = "Set either oidc_assume_roles (recommended) or oidc_assume_role (legacy)."
  }
}
