# 🧪 dsa-test-harnesses

A collection of **Terraform-based AWS test harnesses** designed to deploy realistic, repeatable infrastructure for **testing data pipelines, streaming architectures, and integration scenarios** on AWS.

This repository is intended for:
- 🚦 Load testing and soak testing
- ✅ Functional validation of data pipelines
- 📡 Kafka / Amazon MSK producer and consumer simulations
- 🧪 Infrastructure experimentation in controlled environments
- ♻️ Reproducible test environments that mirror production patterns

The focus is on **real AWS services**, **best-practice networking**, and **infrastructure-as-code** that can be safely created and destroyed.

---

## 🎯 Repository philosophy

This repo follows a few guiding principles:

- **Production-like, not toy examples**  
  Harnesses use real AWS services (e.g. MSK Provisioned, ECS, IAM auth), not simplified mocks.

- **Composable Terraform modules**  
  Each harness is a self-contained module that can be instantiated from a root stack.

- **Safe-by-default networking**  
  Resources deploy into **private subnets** in an existing VPC, with no public exposure.

- **Ephemeral-friendly**  
  Everything is designed to be easy to create, destroy, and recreate for testing.

- **Explicit over implicit**  
  Networking ranges, authentication methods, and scaling characteristics are all deliberate and visible.

---

## 🧰 Current harnesses

### 🔌 `msk-provisioned-ecs-producer`

A harness that deploys:

- **Amazon MSK (Provisioned)**  
  - 🔐 IAM (SASL/IAM) authentication  
  - 🔒 TLS encryption in transit  
  - 🗝️ Encryption at rest using KMS  
  - 🌍 Deployed across 3 Availability Zones  

- **Amazon ECS (Fargate)**  
  - 🐍 Runs a Python-based Kafka producer  
  - 🔑 Uses IAM auth to connect to MSK  
  - 🧱 Deployed into the same private subnets as MSK  

- **Networking**  
  - 🕸️ Creates new private subnets in an existing VPC  
  - 📐 Subnets are carved from a provided supernet CIDR  
  - 🧭 Designed to integrate cleanly with AWS VPC IPAM  

- **Container build & delivery**  
  - 🐳 Builds a Docker image locally via Terraform  
  - 📦 Pushes to an existing or Terraform-managed ECR repository  
  - 🚀 ECS pulls the image using standard task execution roles  

This harness is ideal for:
- Generating synthetic Kafka traffic
- Load testing MSK clusters
- Validating downstream consumers
- Testing MSK IAM authentication end-to-end

See `msk-provisioned-ecs-producer/README.md` for full details.

---

## 🧩 Common patterns across harnesses

### 🏗️ Terraform module design

All harnesses follow these rules:

- **Modules do not define provider blocks**
  - Providers are configured in the root module
  - Avoids “legacy module” behaviour
  - Enables `depends_on`, `count`, and `for_each` on module calls

- **Modules do define `required_providers`**
  - Ensures correct provider namespaces (e.g. `kreuzwerker/docker`)
  - Prevents implicit provider resolution issues

- **Explicit inputs, explicit outputs**
  - Networking inputs are never guessed
  - Useful outputs are exposed for downstream integration and testing

---

### 🌐 Networking and IPAM

Harnesses are designed to work cleanly with **AWS VPC IPAM**:

- 🧮 CIDR blocks are allocated from IPAM **before** subnet creation
- 📦 Modules accept a **supernet CIDR**, not raw subnet CIDRs
- ✂️ Subnets are deterministically carved using `cidrsubnet()`

This ensures:
- No overlapping CIDRs across environments
- Predictable subnet sizing
- Centralised governance of address space

---

### 🔐 Authentication and security

- 🪪 **IAM-based authentication is preferred** (e.g. MSK SASL/IAM)
- 🚫 No static credentials are baked into containers
- 🧑‍⚖️ ECS task roles grant least-privilege access
- 🛡️ Security groups are tightly scoped between components

---

### 🐳 Containers and ECS

- Containers are built using Terraform’s Docker provider
- ECS services use immutable task definitions
- Environment variables are injected via Terraform
- Harnesses are designed for:
  - 📈 steady-state load testing
  - ⏱️ easy conversion to scheduled or one-off tasks

---

## 🛠️ Prerequisites

Before using this repository, you should have:

- Terraform **>= 1.5**
- AWS CLI configured with appropriate permissions
- Docker available locally (for image builds)
- An existing AWS VPC
- (Optional but recommended) AWS VPC IPAM configured
- Permissions to:
  - Create MSK clusters
  - Create ECS clusters and services
  - Push images to ECR
  - Allocate IPAM CIDRs (if used)

---

## 🔁 Typical usage pattern

1. **Allocate networking** (optional but recommended)  
   Allocate a CIDR from IPAM and decide subnet sizing.

2. **Create or reference shared resources**  
   VPC, route tables, and ECR repositories.

3. **Instantiate a harness module**  
   Pass in networking details and workload parameters, then apply Terraform.

4. **Run tests**  
   Observe logs and metrics, and validate downstream systems.

5. **Tear down**  
   Destroy the harness when finished; CIDRs can be released back to IPAM if ephemeral.

---

## 👥 Intended audience

This repository is aimed at:

- Data engineers
- Platform engineers
- Cloud architects
- SREs
- Anyone who needs **realistic AWS test infrastructure** for data systems

It assumes familiarity with:
- Terraform
- AWS networking concepts
- IAM
- Containerised workloads

---

## 🤝 Contributing

New harnesses are welcome!

When adding a new harness:
- Create a top-level directory
- Include a `README.md` explaining the architecture
- Follow the same module and provider patterns
- Avoid hardcoding regions, CIDRs, or credentials

---

## ⚠️ Disclaimer

These harnesses are designed for **testing and experimentation**.  
Always review configurations, limits, and costs before deploying into shared or production environments.
