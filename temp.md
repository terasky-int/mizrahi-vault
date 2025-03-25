The **general configuration concept** of using AWS KMS to auto-unseal HashiCorp Vault on **ROSA (Red Hat OpenShift Service on AWS)** remains identical; however, the specifics regarding **authentication and IAM permissions** differ slightly due to ROSA's use of OpenShift workloads and IAM integration:

---

## Differences with ROSA vs. EKS/Native Kubernetes:

- **Workload Identity:**  
  ROSA uses AWS STS and IRSA via the **AWS IAM Operator** to assign AWS IAM roles to workloads through **OpenShift Service Accounts**.

- **Annotations and IAM Roles:**  
  ROSA uses the `eks.amazonaws.com/role-arn` annotation similarly to EKS, but via OpenShift mechanisms. The IAM role must have the necessary permissions (`kms:Encrypt`, `kms:Decrypt`, and `kms:DescribeKey`) for the specific KMS key.

- **SecurityContextConstraints (SCC):**  
  Ensure Vault pods run correctly under OpenShift's restricted SCC. Official Helm charts typically support this scenario, but verify pod permissions.

---

## How to Configure Vault Auto Unseal with AWS KMS in ROSA:

### 1\. IAM Role and Trust Relationship  
Create an IAM role with permissions to access AWS KMS:

IAM Policy (same as Kubernetes/EKS):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ],
    "Resource": "<your-kms-key-arn>"
  }]
}
```

IAM Trust Policy for ROSA (replace OIDC provider URL and namespace/serviceaccount):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<account-id>:oidc-provider/<rosa-oidc-provider-url>"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "<rosa-oidc-provider-url>:sub": "system:serviceaccount:vault:vault"
      }
    }
  }]
}
```

Replace placeholders accordingly:
- `<account-id>`
- `<rosa-oidc-provider-url>` (from ROSA OIDC endpoint)

---

### 2\. Deploy Vault via Helm (values.yaml):
```yaml
server:
  extraEnvironmentVars:
    AWS_REGION: "us-west-2"

  ha:
    enabled: true
    replicas: 3

    config: |
      storage "raft" {
        path = "/vault/data"
      }

      seal "awskms" {
        region     = "us-west-2"
        kms_key_id = "<your-kms-key-id>"
      }

      listener "tcp" {
        address     = "0.0.0.0:8200"
        tls_disable = true
      }

serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/<iam-role-name>
```

Deploy using:
```bash
oc new-project vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault -f values.yaml -n vault
```

---

### 3\. Validate Installation:

```bash
oc exec -n vault -it vault-0 -- vault status
```

You should see:
```
Sealed          false
Seal Type       awskms
```

---

### Key Differences Recap:
- IAM trust policy must reference ROSA's specific OIDC provider.
- OpenShift SCC compliance may need verification, though usually handled by Helm.
- Service Account annotations in OpenShift match EKS standards (`eks.amazonaws.com/role-arn`) due to AWS IAM operator usage.

---

## Sources:

- [HashiCorp Vault AWS KMS Auto Unseal](https://developer.hashicorp.com/vault/docs/configuration/seal/awskms)
- [ROSA AWS IAM Operator Documentation](https://docs.openshift.com/rosa/authentication/using-iam-operator.html)
- [OpenShift Service Account IAM Roles](https://docs.openshift.com/rosa/rosa_cluster_admin/rosa-sts-about-iam-resources.html)
- [Helm Chart for Vault on Kubernetes](https://developer.hashicorp.com/vault/docs/platform/k8s/helm)