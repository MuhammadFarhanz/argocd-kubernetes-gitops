nodes = [
  {
    hostname = "talos-cp1"
    ip       = "192.168.1.100"
    cores    = 2
    memory   = 4 * 1024,
    type     = "controlplane"
  },
  {
    hostname = "talos-worker1"
    ip       = "192.168.1.101"
    cores    = 2
    memory   = 4 * 1024,
    type     = "worker"
  },
  {
    hostname = "talos-worker2"
    ip       = "192.168.1.102"
    cores    = 2
    memory   = 4 * 1024,
    type     = "worker"
  }
]

talos_version      = "1.13.6"
kubernetes_version = "1.36.2"
cluster_name       = "talos_cluster"
