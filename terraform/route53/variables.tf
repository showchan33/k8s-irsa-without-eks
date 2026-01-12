variable "var_provider" {
  default = {
    region = "ap-northeast-1"
  }
}

variable "route53_a_record_name" {
  type = string
}

variable "route53_a_record_ip" {
  type = string
}

variable "route53domains_domain" {
  type = object({
    admin_privacy = bool
    auto_renew    = bool
    billing_contact = optional(list(object({
      address_line_1 = string
      address_line_2 = string
      city           = string
      contact_type   = string
      country_code   = string
      email          = string
      extra_param = list(object({
        name  = string
        value = string
      }))
      fax               = string
      first_name        = string
      last_name         = string
      organization_name = string
      phone_number      = string
      state             = string
      zip_code          = string
    })))
    billing_privacy = bool
    domain_name     = string
    name_server = optional(list(object({
      name     = string
      glue_ips = list(string)
    })))
    registrant_privacy = bool
    tech_privacy       = bool
    transfer_lock      = bool
    admin_contact = object({
      address_line_1 = string
      city           = string
      contact_type   = string
      country_code   = string
      email          = string
      first_name     = string
      last_name      = string
      phone_number   = string
      state          = string
      zip_code       = string
    })
    registrant_contact = object({
      address_line_1 = string
      city           = string
      contact_type   = string
      country_code   = string
      email          = string
      first_name     = string
      last_name      = string
      phone_number   = string
      state          = string
      zip_code       = string
    })
    tech_contact = object({
      address_line_1 = string
      city           = string
      contact_type   = string
      country_code   = string
      email          = string
      first_name     = string
      last_name      = string
      phone_number   = string
      state          = string
      zip_code       = string
    })
  })
}

variable "iam_user" {
  type = object({
    name = string
    path = optional(string)
    tags = optional(map(string))
  })
}

variable "iam_policy" {
  type = object({
    name        = string
    description = optional(string)
    path        = optional(string)
    policy      = optional(string)
    tags        = optional(map(string))
  })
}
