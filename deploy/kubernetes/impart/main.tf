terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-sandbox"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace" "sock_shop" {
  metadata {
    name = "sock-shop"
  }
}

resource "kubernetes_deployment" "carts" {
  metadata {
    name      = "carts"
    namespace = "sock-shop"

    labels = {
      name = "carts"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "carts"
      }
    }

    template {
      metadata {
        labels = {
          name = "carts"
        }
      }

      spec {
        volume {
          name = "tmp-volume"

          empty_dir {
            medium = "Memory"
          }
        }

        container {
          name  = "carts"
          image = "weaveworksdemos/carts:0.4.8"

          port {
            container_port = 80
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xms64m -Xmx128m -XX:+UseG1GC -Djava.security.egd=file:/dev/urandom -Dspring.zipkin.enabled=false"
          }

          resources {
            limits = {
              cpu = "300m"

              memory = "500Mi"
            }

            requests = {
              cpu = "100m"

              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }

          security_context {
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["all"]
            }

            run_as_user               = 10001
            run_as_non_root           = true
            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "carts" {
  metadata {
    name      = "carts"
    namespace = "sock-shop"

    labels = {
      name = "carts"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "80"
    }

    selector = {
      name = "carts"
    }
  }
}

resource "kubernetes_deployment" "carts_db" {
  metadata {
    name      = "carts-db"
    namespace = "sock-shop"

    labels = {
      name = "carts-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "carts-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "carts-db"
        }
      }

      spec {
        volume {
          name = "tmp-volume"

          empty_dir {
            medium = "Memory"
          }
        }

        container {
          name  = "carts-db"
          image = "mongo"

          port {
            name           = "mongo"
            container_port = 27017
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }

          security_context {
            capabilities {
              add  = ["CHOWN", "SETGID", "SETUID"]
              drop = ["all"]
            }

            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "carts_db" {
  metadata {
    name      = "carts-db"
    namespace = "sock-shop"

    labels = {
      name = "carts-db"
    }
  }

  spec {
    port {
      port        = 27017
      target_port = "27017"
    }

    selector = {
      name = "carts-db"
    }
  }
}

resource "kubernetes_deployment" "catalogue" {
  metadata {
    name      = "catalogue"
    namespace = "sock-shop"

    labels = {
      name = "catalogue"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "catalogue"
      }
    }

    template {
      metadata {
        labels = {
          name = "catalogue"
        }
      }

      spec {
        container {
          name    = "catalogue"
          image   = "weaveworksdemos/catalogue:0.3.5"
          command = ["/app"]
          args    = ["-port=80"]

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu = "200m"

              memory = "200Mi"
            }

            requests = {
              cpu = "100m"

              memory = "100Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "80"
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "80"
            }

            initial_delay_seconds = 180
            period_seconds        = 3
          }

          security_context {
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["all"]
            }

            run_as_user               = 10001
            run_as_non_root           = true
            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "catalogue" {
  metadata {
    name      = "catalogue"
    namespace = "sock-shop"

    labels = {
      name = "catalogue"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "80"
    }

    selector = {
      name = "catalogue"
    }
  }
}

resource "kubernetes_deployment" "catalogue_db" {
  metadata {
    name      = "catalogue-db"
    namespace = "sock-shop"

    labels = {
      name = "catalogue-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "catalogue-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "catalogue-db"
        }
      }

      spec {
        container {
          name  = "catalogue-db"
          image = "weaveworksdemos/catalogue-db:0.3.0"

          port {
            name           = "mysql"
            container_port = 3306
          }

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "fake_password"
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "socksdb"
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "catalogue_db" {
  metadata {
    name      = "catalogue-db"
    namespace = "sock-shop"

    labels = {
      name = "catalogue-db"
    }
  }

  spec {
    port {
      port        = 3306
      target_port = "3306"
    }

    selector = {
      name = "catalogue-db"
    }
  }
}

resource "kubernetes_deployment" "front_end" {
  metadata {
    name      = "front-end"
    namespace = "sock-shop"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "front-end"
      }
    }

    template {
      metadata {
        labels = {
          name = "front-end"
          # impart
          impart-inspector-injection = "enabled" # STEP 3: add label to the app's deployment
        }
        # impart
        annotations = {
          impart-inspector-sidecar-http-listener-disable-tls = "true" # STEP 4: add annotation to the app's deployment
        }
      }

      spec {
        container {
          name  = "front-end"
          image = "weaveworksdemos/front-end:0.3.12"

          port {
            container_port = 8079
          }

          env {
            name  = "SESSION_REDIS"
            value = "true"
          }

          resources {
            limits = {
              cpu = "300m"

              memory = "1000Mi"
            }

            requests = {
              cpu = "100m"

              memory = "300Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "8079"
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "8079"
            }

            initial_delay_seconds = 30
            period_seconds        = 3
          }

          security_context {
            capabilities {
              drop = ["all"]
            }

            run_as_user               = 10001
            run_as_non_root           = true
            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
  depends_on = [
    helm_release.impart-inspector # STEP 5: Make sure the deployment depends on the helm chart being installed.
  ]
}

resource "kubernetes_service" "front_end" {
  metadata {
    name      = "front-end"
    namespace = "sock-shop"

    labels = {
      name = "front-end"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "8079"
      node_port   = 30001
    }

    selector = {
      name = "front-end"
    }

    type = "NodePort"
  }
}

resource "kubernetes_deployment" "orders" {
  metadata {
    name      = "orders"
    namespace = "sock-shop"

    labels = {
      name = "orders"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "orders"
      }
    }

    template {
      metadata {
        labels = {
          name = "orders"
        }
      }

      spec {
        volume {
          name = "tmp-volume"

          empty_dir {
            medium = "Memory"
          }
        }

        container {
          name  = "orders"
          image = "weaveworksdemos/orders:0.4.7"

          port {
            container_port = 80
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xms64m -Xmx128m -XX:+UseG1GC -Djava.security.egd=file:/dev/urandom -Dspring.zipkin.enabled=false"
          }

          resources {
            limits = {
              cpu = "500m"

              memory = "500Mi"
            }

            requests = {
              cpu = "100m"

              memory = "300Mi"
            }
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }

          security_context {
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["all"]
            }

            run_as_user               = 10001
            run_as_non_root           = true
            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "orders" {
  metadata {
    name      = "orders"
    namespace = "sock-shop"

    labels = {
      name = "orders"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "80"
    }

    selector = {
      name = "orders"
    }
  }
}

resource "kubernetes_deployment" "orders_db" {
  metadata {
    name      = "orders-db"
    namespace = "sock-shop"

    labels = {
      name = "orders-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "orders-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "orders-db"
        }
      }

      spec {
        volume {
          name = "tmp-volume"

          empty_dir {
            medium = "Memory"
          }
        }

        container {
          name  = "orders-db"
          image = "mongo"

          port {
            name           = "mongo"
            container_port = 27017
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }

          security_context {
            capabilities {
              add  = ["CHOWN", "SETGID", "SETUID"]
              drop = ["all"]
            }

            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "orders_db" {
  metadata {
    name      = "orders-db"
    namespace = "sock-shop"

    labels = {
      name = "orders-db"
    }
  }

  spec {
    port {
      port        = 27017
      target_port = "27017"
    }

    selector = {
      name = "orders-db"
    }
  }
}

resource "kubernetes_deployment" "payment" {
  metadata {
    name      = "payment"
    namespace = "sock-shop"

    labels = {
      name = "payment"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "payment"
      }
    }

    template {
      metadata {
        labels = {
          name = "payment"
        }
      }

      spec {
        container {
          name  = "payment"
          image = "weaveworksdemos/payment:0.4.3"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu = "200m"

              memory = "200Mi"
            }

            requests = {
              cpu = "99m"

              memory = "100Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "80"
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "80"
            }

            initial_delay_seconds = 180
            period_seconds        = 3
          }

          security_context {
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["all"]
            }

            run_as_user               = 10001
            run_as_non_root           = true
            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "payment" {
  metadata {
    name      = "payment"
    namespace = "sock-shop"

    labels = {
      name = "payment"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "80"
    }

    selector = {
      name = "payment"
    }
  }
}

resource "kubernetes_deployment" "queue_master" {
  metadata {
    name      = "queue-master"
    namespace = "sock-shop"

    labels = {
      name = "queue-master"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "queue-master"
      }
    }

    template {
      metadata {
        labels = {
          name = "queue-master"
        }
      }

      spec {
        container {
          name  = "queue-master"
          image = "weaveworksdemos/queue-master:0.3.1"

          port {
            container_port = 80
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xms64m -Xmx128m -XX:+UseG1GC -Djava.security.egd=file:/dev/urandom -Dspring.zipkin.enabled=false"
          }

          resources {
            limits = {
              cpu = "300m"

              memory = "500Mi"
            }

            requests = {
              cpu = "100m"

              memory = "300Mi"
            }
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "queue_master" {
  metadata {
    name      = "queue-master"
    namespace = "sock-shop"

    labels = {
      name = "queue-master"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "80"
    }

    selector = {
      name = "queue-master"
    }
  }
}

resource "kubernetes_deployment" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = "sock-shop"

    labels = {
      name = "rabbitmq"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          name = "rabbitmq"
        }

        annotations = {
          "prometheus.io/scrape" = "false"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3.6.8-management"

          port {
            name           = "management"
            container_port = 15672
          }

          port {
            name           = "rabbitmq"
            container_port = 5672
          }

          security_context {
            capabilities {
              add  = ["CHOWN", "SETGID", "SETUID", "DAC_OVERRIDE"]
              drop = ["all"]
            }

            read_only_root_filesystem = true
          }
        }

        container {
          name  = "rabbitmq-exporter"
          image = "kbudde/rabbitmq-exporter"

          port {
            name           = "exporter"
            container_port = 9090
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = "sock-shop"

    labels = {
      name = "rabbitmq"
    }

    annotations = {
      "prometheus.io/port" = "9090"

      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      name        = "rabbitmq"
      port        = 5672
      target_port = "5672"
    }

    port {
      name        = "exporter"
      protocol    = "TCP"
      port        = 9090
      target_port = "exporter"
    }

    selector = {
      name = "rabbitmq"
    }
  }
}

resource "kubernetes_deployment" "session_db" {
  metadata {
    name      = "session-db"
    namespace = "sock-shop"

    labels = {
      name = "session-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "session-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "session-db"
        }

        annotations = {
          "prometheus.io.scrape" = "false"
        }
      }

      spec {
        container {
          name  = "session-db"
          image = "redis:alpine"

          port {
            name           = "redis"
            container_port = 6379
          }

          security_context {
            capabilities {
              add  = ["CHOWN", "SETGID", "SETUID"]
              drop = ["all"]
            }

            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "session_db" {
  metadata {
    name      = "session-db"
    namespace = "sock-shop"

    labels = {
      name = "session-db"
    }
  }

  spec {
    port {
      port        = 6379
      target_port = "6379"
    }

    selector = {
      name = "session-db"
    }
  }
}

resource "kubernetes_deployment" "shipping" {
  metadata {
    name      = "shipping"
    namespace = "sock-shop"

    labels = {
      name = "shipping"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "shipping"
      }
    }

    template {
      metadata {
        labels = {
          name = "shipping"
        }
      }

      spec {
        volume {
          name = "tmp-volume"

          empty_dir {
            medium = "Memory"
          }
        }

        container {
          name  = "shipping"
          image = "weaveworksdemos/shipping:0.4.8"

          port {
            container_port = 80
          }

          env {
            name  = "ZIPKIN"
            value = "zipkin.jaeger.svc.cluster.local"
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xms64m -Xmx128m -XX:+UseG1GC -Djava.security.egd=file:/dev/urandom -Dspring.zipkin.enabled=false"
          }

          resources {
            limits = {
              cpu = "300m"

              memory = "500Mi"
            }

            requests = {
              cpu = "100m"

              memory = "300Mi"
            }
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }

          security_context {
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["all"]
            }

            run_as_user               = 10001
            run_as_non_root           = true
            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "shipping" {
  metadata {
    name      = "shipping"
    namespace = "sock-shop"

    labels = {
      name = "shipping"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "80"
    }

    selector = {
      name = "shipping"
    }
  }
}

resource "kubernetes_deployment" "user" {
  metadata {
    name      = "user"
    namespace = "sock-shop"

    labels = {
      name = "user"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "user"
      }
    }

    template {
      metadata {
        labels = {
          name = "user"
        }
      }

      spec {
        container {
          name  = "user"
          image = "weaveworksdemos/user:0.4.7"

          port {
            container_port = 80
          }

          env {
            name  = "mongo"
            value = "user-db:27017"
          }

          resources {
            limits = {
              cpu = "300m"

              memory = "200Mi"
            }

            requests = {
              cpu = "100m"

              memory = "100Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "80"
            }

            initial_delay_seconds = 300
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "80"
            }

            initial_delay_seconds = 180
            period_seconds        = 3
          }

          security_context {
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["all"]
            }

            run_as_user               = 10001
            run_as_non_root           = true
            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "user" {
  metadata {
    name      = "user"
    namespace = "sock-shop"

    labels = {
      name = "user"
    }

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      port        = 80
      target_port = "80"
    }

    selector = {
      name = "user"
    }
  }
}

resource "kubernetes_deployment" "user_db" {
  metadata {
    name      = "user-db"
    namespace = "sock-shop"

    labels = {
      name = "user-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "user-db"
      }
    }

    template {
      metadata {
        labels = {
          name = "user-db"
        }
      }

      spec {
        volume {
          name = "tmp-volume"

          empty_dir {
            medium = "Memory"
          }
        }

        container {
          name  = "user-db"
          image = "weaveworksdemos/user-db:0.3.0"

          port {
            name           = "mongo"
            container_port = 27017
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }

          security_context {
            capabilities {
              add  = ["CHOWN", "SETGID", "SETUID"]
              drop = ["all"]
            }

            read_only_root_filesystem = true
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "user_db" {
  metadata {
    name      = "user-db"
    namespace = "sock-shop"

    labels = {
      name = "user-db"
    }
  }

  spec {
    port {
      port        = 27017
      target_port = "27017"
    }

    selector = {
      name = "user-db"
    }
  }
}

