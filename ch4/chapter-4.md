# Chapter 4

## Workflow: Deploy Chapter 4

This project uses GitHub Actions to automate the deployment of Chapter 3. The workflow is defined in `.github/workflows/deploy-ch3-workflow.yml`.

### Prerequisites

Make sure you have the following perquisite:
- Access to a Azure Subscription with Contributor or higher permissions
- Already configured backend storage account as discussed in Chapter 2 using terraform file `ch2/statestore/statestorage.tf`
- Git for local changes (Optional)
- Terraform CLI for local terraform operations (Optional)
- VS Code Editor for making changes locally on your computer (Optional)

### Steps to run the workflow

1. Clone the repository (Optional):
2. Create following secrets in your GitHUb repo

```
AZURE_CLIENT_ID
AZURE_CLIENT_SECRET
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
```

|Secret Name | Details |
|-------------|---------|
|AZURE_CLIENT_ID|Details|
|AZURE_CLIENT_SECRET|Details|
|AZURE_SUBSCRIPTION_ID|Details|
|AZURE_TENANT_ID|Details|

Once you have created this credentials, you run the Deploy Chapter 3 Action workflow from the actions tab.

