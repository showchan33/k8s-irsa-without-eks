resource "aws_route53domains_domain" "this" {
  admin_privacy      = var.route53domains_domain.admin_privacy
  auto_renew         = var.route53domains_domain.auto_renew
  billing_contact    = var.route53domains_domain.billing_contact
  billing_privacy    = var.route53domains_domain.billing_privacy
  domain_name        = var.route53domains_domain.domain_name
  name_server        = var.route53domains_domain.name_server
  registrant_privacy = var.route53domains_domain.registrant_privacy
  tech_privacy       = var.route53domains_domain.tech_privacy
  transfer_lock      = var.route53domains_domain.transfer_lock

  admin_contact {
    address_line_1 = var.route53domains_domain.admin_contact.address_line_1
    city           = var.route53domains_domain.admin_contact.city
    contact_type   = var.route53domains_domain.admin_contact.contact_type
    country_code   = var.route53domains_domain.admin_contact.country_code
    email          = var.route53domains_domain.admin_contact.email
    first_name     = var.route53domains_domain.admin_contact.first_name
    last_name      = var.route53domains_domain.admin_contact.last_name
    phone_number   = var.route53domains_domain.admin_contact.phone_number
    state          = var.route53domains_domain.admin_contact.state
    zip_code       = var.route53domains_domain.admin_contact.zip_code
  }

  registrant_contact {
    address_line_1 = var.route53domains_domain.registrant_contact.address_line_1
    city           = var.route53domains_domain.registrant_contact.city
    contact_type   = var.route53domains_domain.registrant_contact.contact_type
    country_code   = var.route53domains_domain.registrant_contact.country_code
    email          = var.route53domains_domain.registrant_contact.email
    first_name     = var.route53domains_domain.registrant_contact.first_name
    last_name      = var.route53domains_domain.registrant_contact.last_name
    phone_number   = var.route53domains_domain.registrant_contact.phone_number
    state          = var.route53domains_domain.registrant_contact.state
    zip_code       = var.route53domains_domain.registrant_contact.zip_code
  }

  tech_contact {
    address_line_1 = var.route53domains_domain.tech_contact.address_line_1
    city           = var.route53domains_domain.tech_contact.city
    contact_type   = var.route53domains_domain.tech_contact.contact_type
    country_code   = var.route53domains_domain.tech_contact.country_code
    email          = var.route53domains_domain.tech_contact.email
    first_name     = var.route53domains_domain.tech_contact.first_name
    last_name      = var.route53domains_domain.tech_contact.last_name
    phone_number   = var.route53domains_domain.tech_contact.phone_number
    state          = var.route53domains_domain.tech_contact.state
    zip_code       = var.route53domains_domain.tech_contact.zip_code
  }
}

data "aws_route53_zone" "this" {
  name         = "${var.route53domains_domain.domain_name}."
  private_zone = false
  depends_on   = [aws_route53domains_domain.this]
}
