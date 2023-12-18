#
# STEP 1: Setup an 'impart inspector token' as a secret.
# To create one from the Impart Console:
#   https://console.impartsecurity.net/orgs/_/settings/tokens#create
#
# NOTE: This will need to be stored in every namespace that an inspector will run.

resource "kubernetes_secret" "impart-demo-inspector-token" {
  metadata {
    name      = "impart-demo-inspector-token"
    namespace = kubernetes_namespace.sock_shop.metadata.0.name # STEP 1: This is the app namespace
    labels = {
      "sensitive" = "true"
    }
  }
  data = {
    # STEP 1: Load the data however secrets are managed.  This example loads from the file system.
    accessToken = trimspace(file("accessToken.secret"))
  }
}

#
# STEP 2: Install the Impart Inspector Helm Chart.
#

resource "kubernetes_namespace" "impart" {
  metadata {
    name = "impart"
  }
}
resource "helm_release" "impart-inspector" {
  name       = "impart-inspector"
  repository = "https://helm.impartsecurity.net"
  chart      = "sidecar-injector"
  namespace  = kubernetes_namespace.impart.metadata.0.name # STEP 2: This can be any namespace - in this example impart.
  # Uncomment this line to pin the version.
  # version    = "0.13.0"
  #added for troubleshooting
  # values = {
  #       inspector {
  #         logLevel = 0 # debug 0, info 1, trace 2 (default), warn 3, error 4
  #       }
  # end troubleshooting
  set {
    name  = "inspector.auth.accessTokenSecretRef"
    value = kubernetes_secret.impart-demo-inspector-token.metadata.0.name
  }

  #added for troubleshooting
  set {
   name  = "inspector.logLevel"
   value = 0
  }
}