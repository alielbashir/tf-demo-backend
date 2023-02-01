terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.28.0"
    }
  }

  required_version = ">= 1.1.0"

}

provider "azurerm" {
  features {}
}

resource "random_password" "password" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}-${var.environment}-${var.location}"
  location = var.location
}

resource "azurerm_mssql_database" "db" {
  name      = "sqldb-${var.project_name}-${var.environment}-${var.location}"
  server_id = azurerm_mssql_server.server.id
  collation = var.collation
  sku_name  = "S0"
}

resource "azurerm_mssql_server" "server" {
  name                         = "sqlsvr-${var.project_name}-${var.environment}-${var.location}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = var.server_version
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.password.result
}

resource "azurerm_mssql_firewall_rule" "fw" {
  name             = "fwrules-${var.project_name}-${var.environment}-${var.location}"
  server_id        = azurerm_mssql_server.server.id
  start_ip_address = var.start_ip_address
  end_ip_address   = var.end_ip_address
}

resource "azurerm_service_plan" "plan" {
  name                = "plan-${var.project_name}-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_linux_web_app" "service" {
  name                = "appservice-${var.project_name}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      dotnet_version = "6.0"

    }
    cors {
      allowed_origins = ["*"]
    }
  }

  connection_string {
    name  = "AZURE_SQL_CONNECTIONSTRING"
    type  = "SQLAzure"
    value = "Data Source=${azurerm_mssql_server.server.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};User ID=${azurerm_mssql_server.server.administrator_login};Password=${azurerm_mssql_server.server.administrator_login_password}"
  }
}

resource "azurerm_static_site" "web" {
  name                = "web-${var.project_name}-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}
