# k8s-irsa-without-eks

kubeadm 等で構築した Kubernetes クラスターで、EKS を使わずに IRSA を有効にするための構成を実現します。

このリポジトリでは、主に以下を実施します。

- OIDC Discovery (`/.well-known/openid-configuration`) と JWKS (`/openid/v1/jwks`) の公開
- 公開エンドポイント用の Route53 / ドメイン / DNS レコード作成
- cert-manager, Envoy Gateway, aws-cloud-controller-manager, amazon-eks-pod-identity-webhook の導入
- AWS IAM OIDC Provider と、ServiceAccount 向け IAM Role の作成

## 参照ドキュメント

設計意図や背景は以下の記事を参照してください。

- [Kubernetesで信頼済みTLS証明書を導入してHTTPS公開する手順](https://qiita.com/showchan33/items/6508c7b2790b66fcd35a)
- [EKSなしIRSAへの道 ― 第１回：OIDCメタデータエンドポイントを公開する](https://qiita.com/showchan33/items/cf4805fd061b3730a8e9)
- [EKSなしIRSAへの道 ― 第２回：IAMロールを作ってServiceAccountからAWSにアクセスする](https://qiita.com/showchan33/items/2874110070f79a13c5cc)
- [EKSなしIRSAへの道 ― 第３回：Mutating WebhookでPodを自動書き換えしてIRSAを簡単にする](https://qiita.com/showchan33/items/00b6b44f522b38e895b6)

## 前提条件

- Terraform が使えること
- Kubernetes クラスターに `kubectl` でアクセスできること（事前に対象 context を選択）
- Kubernetes クラスターを動かしている EC2 に EIP が付与されていること
- 443/TCP が利用可能であること
- 本リポジトリの Terraform はローカル state 前提（リモート state 管理環境は未対応）

## 全体の実行順

1. `terraform/route53` を apply
2. `helmfiles` を apply
3. `helm-chart` を install/upgrade
4. kube-apiserver の `issuer` / `jwks_uri` を FQDN に修正
5. `terraform/oidc` を apply

---

## 1. terraform/route53

Route53 関連リソースを作成し、`helm-chart/values.generated.yaml` も生成します。

### 1-1. tfvars を準備

```bash
cp terraform/route53/terraform.tfvars.sample terraform/route53/terraform.tfvars
```

`terraform/route53/terraform.tfvars` の主な項目:

- `var_provider.region`: AWS リージョン
- `route53domains_domain`: 取得/管理するドメイン設定（連絡先情報を含む）
- `iam_user.name`: cert-manager が Route53 DNS-01 で使う IAM User 名
- `iam_policy.name`: 上記 IAM User に付与するポリシー名
- `route53_a_record_name`: 公開に使う FQDN（例: `app.example.com`）
- `route53_a_record_ip`: 上記 FQDN に割り当てるグローバル IP（例: EIP）

### 1-2. 実行

```bash
terraform -chdir=terraform/route53 init
terraform -chdir=terraform/route53 plan
terraform -chdir=terraform/route53 apply
```

`apply` 後、`helm-chart/values.generated.yaml` が更新されます。

### 1-3. 出力確認（任意）

```bash
terraform -chdir=terraform/route53 output
```

---

## 2. helmfiles

Kubernetes クラスターに必要なコンポーネントを導入します。

- cert-manager
- Envoy Gateway
- amazon-eks-pod-identity-webhook
- aws-cloud-controller-manager

### 2-1. vars ファイルを準備

必要に応じて example/sample からコピーして編集します。

```bash
cp helmfiles/vars/cert-manager.yaml.example helmfiles/vars/cert-manager.yaml
cp helmfiles/vars/envoy-gateway.yaml.sample helmfiles/vars/envoy-gateway.yaml
cp helmfiles/vars/aws-cloud-controller-manager.yaml.example helmfiles/vars/aws-cloud-controller-manager.yaml
cp helmfiles/vars/amazon-eks-pod-identity-webhook.yaml.example helmfiles/vars/amazon-eks-pod-identity-webhook.yaml
```

### 2-2. 4つすべて適用

```bash
helmfile -f helmfiles/helmfile.yaml apply
```

### 2-3. 1つだけ適用（推奨）

```bash
release="cert-manager"
helmfile -f helmfiles/helmfile.yaml -l name="${release}" apply
```

`release` には次を指定できます。

- `cert-manager`
- `eg`
- `aws-cloud-controller-manager`
- `amazon-eks-pod-identity-webhook`

### 2-4. 1つだけ適用（個別ファイル指定）

```bash
release="cert-manager"
helmfile \
  -f helmfiles/releases/"${release}".yaml.gotmpl \
  --state-values-file ../vars/"${release}".yaml \
  apply
```

`release` には次を指定できます。

- `cert-manager`
- `envoy-gateway`
- `amazon-eks-pod-identity-webhook`
- `aws-cloud-controller-manager`

---

## 3. helm-chart

kube-apiserver の OIDC Discovery / JWKS を HTTPS で公開するためのリソースをデプロイします。

`terraform/route53` によって生成される `helm-chart/values.generated.yaml` を利用します。

### 3-1. 初回インストール

```bash
helm install k8s-irsa-without-eks ./helm-chart \
  -f helm-chart/values.generated.yaml
```

### 3-2. 2回目以降の更新

```bash
helm upgrade k8s-irsa-without-eks ./helm-chart \
  -f helm-chart/values.generated.yaml
```

---

## 4. kube-apiserver の issuer / jwks_uri を修正

外部サービス（AWS STS）が OIDC メタデータを解釈できるよう、kube-apiserver が返す `issuer` と `jwks_uri` のホスト名を公開 FQDN に合わせます。

### 4-1. 変更内容

kube-apiserverが起動しているノードにおいて、 `/etc/kubernetes/manifests/kube-apiserver.yaml` の `command` にある以下を修正します。

```diff
- --service-account-issuer=https://kubernetes.default.svc.cluster.local
+ --service-account-issuer=https://[FQDN名]
+ --service-account-jwks-uri=https://[FQDN名]/openid/v1/jwks
```

変更後、kube-apiserver が再起動して Ready になるまで待ってください。

#### 注意点

この変更により、いくつかのPod（CNIだとcilium-operator等）が起動しなくなってしまう可能性が高いです。その場合は該当PodのDeploymentやDaemonSetを再起動すると解決するはずです。

### 4-2. 確認

```bash
curl https://[FQDN名]/.well-known/openid-configuration 2>/dev/null | jq
```

期待する出力例:

```json
{
  "issuer": "https://[FQDN名]",
  "jwks_uri": "https://[FQDN名]/openid/v1/jwks"
}
```

補足:

- OIDC 公開用の匿名アクセス許可（ClusterRole/ClusterRoleBinding）は Helm チャートで作成されます
- `kube-apiserver.yaml` のバックアップを同一ディレクトリに置くと static pod として誤認識される場合があります

---

## 5. terraform/oidc

AWS 側に OIDC Provider と IAM Role を作成し、Kubernetes の ServiceAccount と連携します。

### 5-1. tfvars を準備

```bash
cp terraform/oidc/terraform.tfvars.sample terraform/oidc/terraform.tfvars
```

`terraform/oidc/terraform.tfvars` の主な項目:

- `oidc_provider.url`: 公開した OIDC issuer URL（例: `https://app.example.com`）
- `oidc_provider.client_id_list`: 通常は `"sts.amazonaws.com"`
- `oidc_assume_roles`: 作成する IAM Role 一覧
  - `namespace`
  - `service_account`
  - `audience`（通常 `sts.amazonaws.com`）
  - `managed_policy_arns`（任意）
  - `inline_policy_json`（任意）

### 5-2. 実行

```bash
terraform -chdir=terraform/oidc init
terraform -chdir=terraform/oidc plan
terraform -chdir=terraform/oidc apply
```

### 5-3. 出力確認（任意）

```bash
terraform -chdir=terraform/oidc output
```

---

## よく使う確認コマンド

```bash
# OIDC Discovery
curl https://[FQDN名]/.well-known/openid-configuration 2>/dev/null | jq

# JWKS
curl https://[FQDN名]/openid/v1/jwks 2>/dev/null | jq
```
