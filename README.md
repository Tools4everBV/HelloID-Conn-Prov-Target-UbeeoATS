# HelloID-Conn-Prov-Target-UbeeoATS

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-UbeeoATS](#helloid-conn-prov-target-ubeeoats)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Available lifecycle actions](#available-lifecycle-actions)
    - [Field mapping](#field-mapping)
  - [Remarks](#remarks)
    - [Correlation - Update](#correlation---update)
    - [User provisioning Strategy](#user-provisioning-strategy)
    - [OrgUnits / Roles](#orgunits--roles)
    - [EmailAddress - Reboarding](#emailaddress---reboarding)
    - [Connector limits - No Get Call](#connector-limits---no-get-call)
      - [No GET Endpoint](#no-get-endpoint)
      - [No Compare](#no-compare)
      - [No Enable/Disable action](#no-enabledisable-action)
      - [No Import Entitlements](#no-import-entitlements)
      - [IP Whitelisting](#ip-whitelisting)
    - [API](#api)
      - [Required request body is missing](#required-request-body-is-missing)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-UbeeoATS_ is a _target_ connector. _UbeeoATS_ provides a set of REST API's that allow you to programmatically interact with its data.

## Getting started

### Prerequisites
- [IP Whitelisting](#ip-whitelisting)
- [User provisioning Strategy](#user-provisioning-strategy)

### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                            | Mandatory |
| ------------ | -------------------------------------- | --------- |
| ClientId     | The ClientId to connect to the API     | Yes       |
| ClientSecret | The ClientSecret to connect to the API | Yes       |
| BaseUrl      | The URL to the API                     | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _UbeeoATS_ to a person in _HelloID_.

| Setting                   | Value                             |
| ------------------------- | --------------------------------- |
| Enable correlation        | **`No`**                          |
| Person correlation field  | `PersonContext.Person.ExternalId` |
| Account correlation field | `EmployeeID`                      |

> [!TIP]
> Correlation is handled by Ubeeo. When you send an account to be created with an existing EmployeeID, the existing account will be updated.
> [Correlation - Update](#correlation---update)


> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Available lifecycle actions

The following lifecycle actions are available:

| Action                 | Description                                                                     |
| ---------------------- | ------------------------------------------------------------------------------- |
| create.ps1             | Creates a (new) **Enabled** account.                                            |
| delete.ps1             | Removes an existing account or entity.                                          |
| update.ps1             | Updates the attributes of an account.                                           |
| importEntitlements.ps1 | Not applicable  *- No Get Calls!*                                               |
| configuration.json     | Contains the connection settings and general configuration for the connector.   |
| fieldMapping.json      | Defines mappings between person fields and target system person account fields. |

### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

## Remarks
### Correlation - Update
The **EmployeeID** is used to correlate existing users. If the EmployeeID is found, the current account will be updated. If the EmployeeID is not found, a new account will be created.

### User provisioning Strategy
When the customer wishes to use the user provisioning module, the customer must choose a **'UserName'** strategy. Depending on the chosen strategy, some properties in the User JSON will become mandatory. <br>
*Please check the API documentation for additional information*

### OrgUnits / Roles
The connector is designed to use only the primary contract for orgUnits. Although the API supports a list of orgUnits, we currently add only the primary one. If you want to use a list of units, it is possible, but it requires changes to the connector.

### EmailAddress - Reboarding
The EmailAddress property is unique in Ubeeo. When an account is disabled, the email address remains in the application. Therefore, if a new person joins the company with the same email address, it cannot be added to the new account in Ubeeo.

### Connector limits - No Get Call
#### No GET Endpoint
The API does not support a GET request to retrieve account details. You may need to use alternative methods or endpoints to access account information, such as using a POST request with appropriate parameters.

#### No Compare
There is no comparison in the update script, so a HelloID update trigger always updates the Ubeeo account.

#### No Enable/Disable action
There is no enable/disable call because the disabled state can be overridden by an update action. So, when an update is performed on a disabled account, the account will be automatically enabled. Therefore, the 'disable' call is performed in the delete script.

#### No Import Entitlements
There is no import entitlements script because there is no API available to retrieve users.

#### IP Whitelisting
Please note that Ubeeo will also need to whitelist the IP addresses of the server(s) that will consume the API. Without whitelisting the addresses, the consuming IP address will be blacklisted when calling an endpoint too many times.

### API
The API returns an HTML error page when a `401` or `415` error occurs. The connector handles `401` errors and returns a custom error message when they occur. A `415` error only happens if the Content-Type is incorrect, which is hardcoded—so this error should not occur.

#### Required request body is missing
The error message `Required request body is missing` is not very clear. For example, if orgUnits is sent as a string instead of an array, or if the body contains incorrectly formatted JSON, the error is returned.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint         | Description                  |
| ---------------- | ---------------------------- |
| /api/oauth/token | Retrieve Authorization Token |
| /api/users       | Retrieve user information    |
| /api/users/:id   | Disables an user             |

### API documentation

[api-docs.ubeeo.nl](https://api-docs.ubeeo.nl/)


## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
